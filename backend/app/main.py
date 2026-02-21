import asyncio
import base64
import json
import logging
import os
import random
import re
from datetime import datetime, timezone
from typing import Dict, List, Sequence

import httpx
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from .db import SessionLocal, init_db
from .models import Dish, DishImage, GenerationJob

FEATURE_IDS = [
    "chuanStyle", "cantoneseStyle", "japaneseStyle", "thaiStyle",
    "spicy", "numbing", "sweet", "sour", "umami", "salty", "smoky", "herbal", "rich", "light", "fresh",
    "crispy", "tender", "chewy", "juicy", "brothy",
    "stirFried", "grilled", "braised", "deepFried", "steamed", "raw",
    "noodle", "rice", "seafood", "beef", "pork", "chicken", "lamb", "duck", "tofu", "mushroom", "cheese", "cilantro", "garlic",
    "highProtein", "lowCarb", "veggieForward",
]

FEATURE_NAME_MAP = {
    "chuanStyle": "川味", "cantoneseStyle": "粤式", "japaneseStyle": "日式", "thaiStyle": "泰式",
    "spicy": "辛辣", "numbing": "麻感", "sweet": "偏甜", "sour": "偏酸", "umami": "鲜味", "salty": "咸香",
    "smoky": "烟火香", "herbal": "香草香料", "rich": "厚重浓郁", "light": "清爽清淡", "fresh": "清新感",
    "crispy": "酥脆", "tender": "软嫩", "chewy": "筋道", "juicy": "多汁", "brothy": "汤感",
    "stirFried": "爆炒", "grilled": "炙烤", "braised": "红烧/炖煮", "deepFried": "油炸", "steamed": "清蒸", "raw": "冷食/生食",
    "noodle": "面食", "rice": "米饭搭配", "seafood": "海鲜", "beef": "牛肉", "pork": "猪肉", "chicken": "鸡肉", "lamb": "羊肉",
    "duck": "鸭肉", "tofu": "豆腐", "mushroom": "菌菇", "cheese": "芝士奶香", "cilantro": "香菜", "garlic": "蒜香",
    "highProtein": "高蛋白偏好", "lowCarb": "低碳倾向", "veggieForward": "蔬菜导向",
}

GEMINI_MODEL = os.getenv("GEMINI_MODEL", "gemini-3-flash-preview")
GEMINI_IMAGE_MODEL = os.getenv("GEMINI_IMAGE_MODEL", "gemini-3-pro-image-preview")
GEMINI_API_BASE = os.getenv("GEMINI_API_BASE", "https://generativelanguage.googleapis.com")
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY", "")
GEMINI_READ_TIMEOUT_SECONDS = float(os.getenv("GEMINI_READ_TIMEOUT_SECONDS", "70"))
GEMINI_CONNECT_TIMEOUT_SECONDS = float(os.getenv("GEMINI_CONNECT_TIMEOUT_SECONDS", "12"))
GEMINI_MAX_RETRIES = int(os.getenv("GEMINI_MAX_RETRIES", "3"))
GEMINI_IMAGE_MAX_BYTES = int(os.getenv("GEMINI_IMAGE_MAX_BYTES", "5242880"))

DECK_LOW_WATERMARK = int(os.getenv("DECK_LOW_WATERMARK", "50"))
DECK_REFILL_BATCH = int(os.getenv("DECK_REFILL_BATCH", "16"))
BOOTSTRAP_MIN_READY = int(os.getenv("BOOTSTRAP_MIN_READY", "8"))

REFILL_LOCK = asyncio.Lock()
logger = logging.getLogger("readytoorder.backend")


class FeatureScore(BaseModel):
    id: str
    score: float


class RecentEvent(BaseModel):
    dish_name: str
    action: str
    features: List[str] = Field(default_factory=list)


class DeckRequest(BaseModel):
    count: int = Field(default=20, ge=6, le=40)
    feature_scores: Dict[str, float] = Field(default_factory=dict)
    top_positive: List[FeatureScore] = Field(default_factory=list)
    top_negative: List[FeatureScore] = Field(default_factory=list)
    recent_likes: List[str] = Field(default_factory=list)
    avoid_names: List[str] = Field(default_factory=list)
    locale: str = "zh-CN"


class DeckDish(BaseModel):
    name: str
    subtitle: str
    signals: Dict[str, float]
    image_data_url: str | None = None


class DeckResponse(BaseModel):
    dishes: List[DeckDish]
    source: str


class AnalyzeRequest(BaseModel):
    total_swipes: int = 0
    top_positive: List[FeatureScore] = Field(default_factory=list)
    top_negative: List[FeatureScore] = Field(default_factory=list)
    recent_events: List[RecentEvent] = Field(default_factory=list)


class AnalyzeResponse(BaseModel):
    summary: str
    avoid: str
    strategy: str
    source: str


app = FastAPI(title="readytoorder-backend", version="0.3.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)


def utc_now() -> datetime:
    return datetime.now(timezone.utc)


def _normalized_avoid_names(items: Sequence[str]) -> set[str]:
    return {item.strip() for item in items if item and item.strip()}


def _clamp(value: float, low: float = -1.0, high: float = 1.0) -> float:
    return max(low, min(high, value))


def _top_feature_pairs(items: List[FeatureScore], limit: int = 5) -> str:
    if not items:
        return "无"
    parts = []
    for feature in items[:limit]:
        cname = FEATURE_NAME_MAP.get(feature.id, feature.id)
        parts.append(f"{cname}({feature.score:.2f})")
    return "、".join(parts)


def _extract_first_text(resp: dict) -> str:
    candidates = resp.get("candidates", [])
    if not candidates:
        raise ValueError("Gemini returned no candidates")
    content = candidates[0].get("content", {})
    for part in content.get("parts", []):
        text = part.get("text")
        if text:
            return text
    raise ValueError("Gemini returned no text part")


def _extract_json(raw: str) -> dict:
    fenced = re.search(r"```json\s*(\{.*\})\s*```", raw, re.DOTALL)
    if fenced:
        return json.loads(fenced.group(1))

    start = raw.find("{")
    end = raw.rfind("}")
    if start >= 0 and end > start:
        return json.loads(raw[start : end + 1])

    return json.loads(raw)


def _extract_first_inline_image(resp: dict) -> tuple[str, str]:
    candidates = resp.get("candidates", [])
    for candidate in candidates:
        content = candidate.get("content", {})
        for part in content.get("parts", []):
            inline = part.get("inlineData") or part.get("inline_data")
            if not isinstance(inline, dict):
                continue
            data = inline.get("data")
            if not data:
                continue
            mime = inline.get("mimeType") or inline.get("mime_type") or "image/png"
            return str(mime), str(data)
    raise ValueError("Gemini image response has no inline image data")


def _sanitize_dishes(raw_dishes: list) -> List[DeckDish]:
    cleaned: List[DeckDish] = []
    seen_names = set()

    for item in raw_dishes:
        if not isinstance(item, dict):
            continue
        name = str(item.get("name", "")).strip()
        subtitle = str(item.get("subtitle", "")).strip()
        signal_map = item.get("signals", {})

        if not name or name in seen_names or not isinstance(signal_map, dict):
            continue

        normalized: Dict[str, float] = {}
        for key, value in signal_map.items():
            if key not in FEATURE_IDS:
                continue
            if not isinstance(value, (int, float)):
                continue
            score = abs(_clamp(float(value), -1.0, 1.0))
            if score < 0.2:
                continue
            normalized[key] = round(score, 3)

        if len(normalized) < 2:
            continue

        seen_names.add(name)
        cleaned.append(
            DeckDish(
                name=name,
                subtitle=subtitle or "口味特征生成",
                signals=normalized,
            )
        )

    return cleaned


async def _call_gemini_api(payload: dict, *, model: str) -> dict:
    if not GEMINI_API_KEY:
        raise RuntimeError("GEMINI_API_KEY is not set")

    url = f"{GEMINI_API_BASE.rstrip('/')}/v1beta/models/{model}:generateContent"
    headers = {
        "Content-Type": "application/json",
        "x-goog-api-key": GEMINI_API_KEY,
    }
    timeout = httpx.Timeout(
        connect=GEMINI_CONNECT_TIMEOUT_SECONDS,
        read=GEMINI_READ_TIMEOUT_SECONDS,
        write=30.0,
        pool=30.0,
    )
    retryable_statuses = {408, 429, 500, 502, 503, 504}
    last_error: Exception | None = None

    async with httpx.AsyncClient(timeout=timeout) as client:
        for attempt in range(1, GEMINI_MAX_RETRIES + 1):
            try:
                resp = await client.post(url, headers=headers, json=payload)
                if resp.status_code in retryable_statuses and attempt < GEMINI_MAX_RETRIES:
                    wait_seconds = min(8.0, 1.2 * attempt)
                    logger.warning(
                        "Gemini transient status=%s model=%s attempt=%s/%s retry=%.1fs",
                        resp.status_code,
                        model,
                        attempt,
                        GEMINI_MAX_RETRIES,
                        wait_seconds,
                    )
                    await asyncio.sleep(wait_seconds)
                    continue

                resp.raise_for_status()
                return resp.json()
            except httpx.HTTPStatusError as exc:
                body = exc.response.text[:1200] if exc.response is not None else ""
                last_error = RuntimeError(
                    f"Gemini HTTP {exc.response.status_code if exc.response is not None else 'unknown'} model={model}: {body}"
                )
                if (
                    attempt < GEMINI_MAX_RETRIES
                    and exc.response is not None
                    and exc.response.status_code in retryable_statuses
                ):
                    wait_seconds = min(8.0, 1.2 * attempt)
                    await asyncio.sleep(wait_seconds)
                    continue
                break
            except httpx.RequestError as exc:
                last_error = RuntimeError(f"Gemini request error model={model} ({type(exc).__name__}): {exc!r}")
                if attempt < GEMINI_MAX_RETRIES:
                    wait_seconds = min(8.0, 1.2 * attempt)
                    await asyncio.sleep(wait_seconds)
                    continue
                break

    if last_error is not None:
        raise last_error
    raise RuntimeError("Gemini request failed unexpectedly")


async def _call_gemini_json(prompt: str, *, temperature: float = 0.4) -> dict:
    payload = {
        "contents": [{"role": "user", "parts": [{"text": prompt}]}],
        "generationConfig": {
            "temperature": temperature,
            "responseMimeType": "application/json",
        },
    }
    return await _call_gemini_api(payload, model=GEMINI_MODEL)


async def _generate_dish_image_with_gemini(dish_name: str) -> tuple[str, str, str]:
    prompt = f"生成一个{dish_name}的图片，俯视角，图像比例2:3，食物主体在下方2/3区域内"
    payload = {
        "contents": [{"role": "user", "parts": [{"text": prompt}]}],
        "generationConfig": {
            "temperature": 0.6,
            "responseModalities": ["TEXT", "IMAGE"],
        },
    }
    raw = await _call_gemini_api(payload, model=GEMINI_IMAGE_MODEL)
    mime_type, base64_data = _extract_first_inline_image(raw)
    raw_bytes = base64.b64decode(base64_data, validate=True)
    if len(raw_bytes) > GEMINI_IMAGE_MAX_BYTES:
        raise ValueError(f"image too large: {len(raw_bytes)} > {GEMINI_IMAGE_MAX_BYTES}")
    data_url = f"data:{mime_type};base64,{base64_data}"
    return prompt, mime_type, data_url


def _build_deck_prompt(req: DeckRequest, needed: int, used_names: Sequence[str]) -> str:
    merged_avoid_names = sorted(set((req.avoid_names or []) + list(used_names)))
    used_block = "无"
    if merged_avoid_names:
        used_block = "、".join(merged_avoid_names[:160])

    return f"""
你是餐饮推荐系统的数据生成器，请输出 JSON，不要输出任何额外文本。

目标：仅生成 {needed} 个用于口味学习的中文菜品卡片。

约束：
- 只能返回一个 JSON 对象，格式：
  {{
    "dishes": [
      {{"name": "菜名", "subtitle": "简短描述", "signals": {{"featureId": 0.0}}}}
    ]
  }}
- dishes 数组长度必须等于 {needed}。
- name：中文为主，2-10字，不能重复，且不能出现在“禁用菜名”列表里。
- subtitle：中文为主，8-24字。
- signals：只允许以下 featureId，值范围 0.2-1.0：
  {", ".join(FEATURE_IDS)}
- 每个菜至少 3 个 signals，最多 6 个。
- 结合用户偏好提高多样性，避免全是同一种菜系。

用户画像输入：
- top_positive: {_top_feature_pairs(req.top_positive)}
- top_negative: {_top_feature_pairs(req.top_negative)}
- recent_likes: {"、".join(req.recent_likes[:8]) if req.recent_likes else "无"}

禁用菜名（不能重复生成）：
{used_block}
""".strip()


async def _generate_deck_with_gemini(req: DeckRequest, *, extra_avoid_names: Sequence[str] = ()) -> List[DeckDish]:
    collected: List[DeckDish] = []
    used_names = _normalized_avoid_names(req.avoid_names).union(_normalized_avoid_names(extra_avoid_names))
    attempts = 0
    max_attempts = 5

    while len(collected) < req.count and attempts < max_attempts:
        remaining = req.count - len(collected)
        needed = min(remaining, 8)
        prompt = _build_deck_prompt(req, needed=needed, used_names=sorted(used_names))

        raw = await _call_gemini_json(prompt, temperature=0.45)
        text = _extract_first_text(raw)
        data = _extract_json(text)
        cleaned = _sanitize_dishes(data.get("dishes", []))

        for dish in cleaned:
            if dish.name in used_names:
                continue
            used_names.add(dish.name)
            collected.append(dish)
            if len(collected) >= req.count:
                break

        attempts += 1

    if len(collected) < req.count:
        raise ValueError(
            f"Gemini returned insufficient valid dishes after {attempts} attempts: {len(collected)} < {req.count}"
        )
    return collected[: req.count]


def _count_ready_dishes(session: Session) -> int:
    return int(
        session.scalar(
            select(func.count())
            .select_from(Dish)
            .where(Dish.status == "ready")
        )
        or 0
    )


def _load_ready_dishes(session: Session, *, count: int, avoid_names: set[str]) -> List[Dish]:
    rows = session.scalars(
        select(Dish).where(Dish.status == "ready")
    ).all()
    filtered = [row for row in rows if row.name not in avoid_names]
    random.shuffle(filtered)
    return filtered[:count]


def _load_image_map(session: Session, dishes: Sequence[Dish]) -> Dict[str, DishImage]:
    image_ids = [row.image_id for row in dishes if row.image_id]
    if not image_ids:
        return {}
    rows = session.scalars(
        select(DishImage).where(DishImage.id.in_(image_ids))
    ).all()
    return {row.id: row for row in rows}


def _to_deck_dish(row: Dish, image: DishImage | None) -> DeckDish:
    signal_map = row.signals if isinstance(row.signals, dict) else {}
    normalized: Dict[str, float] = {}
    for key, value in signal_map.items():
        if key not in FEATURE_IDS:
            continue
        if not isinstance(value, (int, float)):
            continue
        normalized[key] = round(max(0.2, min(1.0, float(value))), 3)

    return DeckDish(
        name=row.name,
        subtitle=row.subtitle,
        signals=normalized,
        image_data_url=image.data_url if image else None,
    )


def _create_generation_job(*, kind: str, target_count: int) -> str:
    with SessionLocal() as session:
        job = GenerationJob(
            kind=kind,
            status="running",
            target_count=target_count,
            produced_count=0,
            error="",
            created_at=utc_now(),
            started_at=utc_now(),
        )
        session.add(job)
        session.commit()
        session.refresh(job)
        return job.id


def _finish_generation_job(*, job_id: str, produced_count: int, error: str = "") -> None:
    with SessionLocal() as session:
        job = session.get(GenerationJob, job_id)
        if not job:
            return
        job.produced_count = produced_count
        job.error = error
        job.status = "done" if not error else "failed"
        job.finished_at = utc_now()
        session.commit()


async def _generate_and_store_dishes(
    req: DeckRequest,
    *,
    needed: int,
    extra_avoid_names: Sequence[str] = (),
) -> int:
    if needed <= 0:
        return 0

    request_for_generation = DeckRequest(
        count=needed,
        feature_scores=req.feature_scores,
        top_positive=req.top_positive,
        top_negative=req.top_negative,
        recent_likes=req.recent_likes,
        avoid_names=req.avoid_names,
        locale=req.locale,
    )
    generated = await _generate_deck_with_gemini(
        request_for_generation,
        extra_avoid_names=extra_avoid_names,
    )

    prepared: list[tuple[DeckDish, str, str, str | None]] = []
    for dish in generated:
        image_prompt = f"生成一个{dish.name}的图片，俯视角，图像比例2:3，食物主体在下方2/3区域内"
        image_mime = "image/png"
        image_data_url: str | None = None
        try:
            image_prompt, image_mime, image_data_url = await _generate_dish_image_with_gemini(dish.name)
        except Exception:
            logger.exception("dish image generation failed dish=%s", dish.name)
        prepared.append((dish, image_prompt, image_mime, image_data_url))

    created_count = 0
    with SessionLocal() as session:
        existing_names = set(
            session.scalars(
                select(Dish.name).where(Dish.name.in_([item[0].name for item in prepared]))
            ).all()
        )
        for dish, image_prompt, image_mime, image_data_url in prepared:
            if dish.name in existing_names:
                continue

            image_id = None
            if image_data_url:
                image = DishImage(
                    provider="gemini",
                    model=GEMINI_IMAGE_MODEL,
                    prompt=image_prompt,
                    mime_type=image_mime,
                    data_url=image_data_url,
                    created_at=utc_now(),
                )
                session.add(image)
                session.flush()
                image_id = image.id

            db_dish = Dish(
                name=dish.name,
                subtitle=dish.subtitle,
                signals=dish.signals,
                status="ready",
                source="gemini",
                image_id=image_id,
                created_at=utc_now(),
                updated_at=utc_now(),
            )
            session.add(db_dish)
            existing_names.add(dish.name)
            created_count += 1

        session.commit()
    return created_count


async def _run_refill_job(seed_request: DeckRequest, target_count: int) -> None:
    if REFILL_LOCK.locked():
        return

    async with REFILL_LOCK:
        job_id = _create_generation_job(kind="deck_refill", target_count=target_count)
        produced = 0
        error_message = ""
        try:
            with SessionLocal() as session:
                existing_names = set(
                    session.scalars(select(Dish.name).where(Dish.status == "ready")).all()
                )
            produced = await _generate_and_store_dishes(
                seed_request,
                needed=target_count,
                extra_avoid_names=list(existing_names),
            )
        except Exception as exc:
            error_message = str(exc)
            logger.exception("deck refill job failed")
        finally:
            _finish_generation_job(
                job_id=job_id,
                produced_count=produced,
                error=error_message,
            )


async def _trigger_background_refill_if_needed(req: DeckRequest) -> None:
    if REFILL_LOCK.locked():
        return

    with SessionLocal() as session:
        ready_count = _count_ready_dishes(session)

    if ready_count >= DECK_LOW_WATERMARK:
        return

    refill_request = DeckRequest(
        count=DECK_REFILL_BATCH,
        feature_scores=req.feature_scores,
        top_positive=req.top_positive,
        top_negative=req.top_negative,
        recent_likes=req.recent_likes,
        avoid_names=req.avoid_names,
        locale=req.locale,
    )
    logger.info("inventory low ready=%s threshold=%s, scheduling refill=%s", ready_count, DECK_LOW_WATERMARK, DECK_REFILL_BATCH)
    asyncio.create_task(_run_refill_job(refill_request, target_count=DECK_REFILL_BATCH))


async def _analyze_with_gemini(req: AnalyzeRequest) -> AnalyzeResponse:
    event_lines = []
    for event in req.recent_events[:18]:
        feature_names = [FEATURE_NAME_MAP.get(fid, fid) for fid in event.features[:4]]
        event_lines.append(f"- {event.action}: {event.dish_name} ({'、'.join(feature_names) if feature_names else '无'})")

    prompt = f"""
你是中文餐饮口味分析助手。请输出 JSON，不要输出其他内容。

输出格式：
{{
  "summary": "一句到两句的用户口味画像总结",
  "avoid": "一句当前应避开的口味建议",
  "strategy": "一句下次点菜策略"
}}

输入：
- total_swipes: {req.total_swipes}
- top_positive: {_top_feature_pairs(req.top_positive, 6)}
- top_negative: {_top_feature_pairs(req.top_negative, 6)}
- recent_events:\n{chr(10).join(event_lines) if event_lines else "- 无"}

要求：
- 中文输出，简洁，不要夸张。
- 结论要可执行，不要空话。
""".strip()

    raw = await _call_gemini_json(prompt, temperature=0.3)
    text = _extract_first_text(raw)
    data = _extract_json(text)

    return AnalyzeResponse(
        summary=str(data.get("summary", ""))[:140] or "Gemini 暂未返回总结。",
        avoid=str(data.get("avoid", ""))[:120] or "Gemini 暂未返回避雷建议。",
        strategy=str(data.get("strategy", ""))[:120] or "Gemini 暂未返回点菜策略。",
        source="gemini",
    )


@app.on_event("startup")
async def startup() -> None:
    init_db()
    logger.info("database initialized")
    with SessionLocal() as session:
        ready_count = _count_ready_dishes(session)
    if ready_count < BOOTSTRAP_MIN_READY and not REFILL_LOCK.locked():
        logger.info("bootstrap refill scheduled ready=%s min=%s", ready_count, BOOTSTRAP_MIN_READY)
        asyncio.create_task(
            _run_refill_job(
                DeckRequest(count=max(6, DECK_REFILL_BATCH)),
                target_count=max(6, DECK_REFILL_BATCH),
            )
        )


@app.get("/health")
async def health() -> dict:
    with SessionLocal() as session:
        ready_count = _count_ready_dishes(session)
    return {
        "ok": True,
        "model": GEMINI_MODEL,
        "image_model": GEMINI_IMAGE_MODEL,
        "gemini_configured": bool(GEMINI_API_KEY),
        "ready_dishes": ready_count,
    }


@app.post("/v1/taste/deck", response_model=DeckResponse)
async def generate_taste_deck(req: DeckRequest) -> DeckResponse:
    avoid_names = _normalized_avoid_names(req.avoid_names)
    source_parts: List[str] = []

    with SessionLocal() as session:
        cached_rows = _load_ready_dishes(
            session,
            count=req.count,
            avoid_names=avoid_names,
        )
        image_map = _load_image_map(session, cached_rows)
    dishes = [_to_deck_dish(row, image_map.get(row.image_id or "")) for row in cached_rows]
    if dishes:
        source_parts.append("cache")

    if len(dishes) < req.count:
        missing = req.count - len(dishes)
        try:
            generated_count = await _generate_and_store_dishes(
                req,
                needed=missing,
                extra_avoid_names=list(avoid_names.union({dish.name for dish in dishes})),
            )
            if generated_count > 0:
                with SessionLocal() as session:
                    refill_rows = _load_ready_dishes(
                        session,
                        count=missing,
                        avoid_names=avoid_names.union({dish.name for dish in dishes}),
                    )
                    refill_images = _load_image_map(session, refill_rows)
                dishes.extend(
                    _to_deck_dish(row, refill_images.get(row.image_id or ""))
                    for row in refill_rows
                )
                source_parts.append("gemini_fill")
        except Exception as exc:
            logger.exception("sync fill failed")
            if not dishes:
                raise HTTPException(status_code=502, detail=f"Deck sync fill failed: {exc}") from exc

    await _trigger_background_refill_if_needed(req)

    if len(dishes) < req.count:
        raise HTTPException(
            status_code=503,
            detail=f"Not enough dishes available: {len(dishes)} < {req.count}",
        )

    return DeckResponse(
        dishes=dishes[: req.count],
        source="+".join(source_parts) if source_parts else "cache",
    )


@app.post("/v1/taste/analyze", response_model=AnalyzeResponse)
async def analyze_taste(req: AnalyzeRequest) -> AnalyzeResponse:
    try:
        return await _analyze_with_gemini(req)
    except Exception as exc:
        logger.exception("taste analysis failed")
        raise HTTPException(status_code=502, detail=f"Gemini analysis failed: {exc}") from exc
