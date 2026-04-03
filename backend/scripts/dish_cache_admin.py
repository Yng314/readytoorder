from __future__ import annotations

import argparse
import asyncio
from dataclasses import dataclass
import sys
from pathlib import Path

from sqlalchemy import delete, func, select

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from app.db import SessionLocal, init_db
from app.main import (
    DeckRequest,
    DeckDish,
    FeatureScore,
    GEMINI_IMAGE_MODEL,
    _create_generation_job,
    _finish_generation_job,
    _generate_and_store_dishes,
    _generate_dish_image_with_gemini,
    _generate_dish_tags_with_gemini,
)
from app.models import ClientErrorEvent, Dish, DishImage, GenerationJob
from app.tagging import TAGGING_VERSION, CandidateTag, DishTags, build_subtitle, legacy_category_tags_from_tags

MANUAL_METADATA_RETRY_ATTEMPTS = 6
MANUAL_IMAGE_RETRY_ATTEMPTS = 8
MANUAL_IMAGE_DELAY_SECONDS = 2.0


@dataclass(frozen=True)
class ApprovedDishEntry:
    cuisine: str | None
    name: str


@dataclass(frozen=True)
class TaggedDishRecord:
    name: str
    subtitle: str
    tags: DishTags
    candidate_tags: list[CandidateTag]
    raw_tagging_output: dict
    tagging_trace: dict[str, list[str]]


def _parse_feature_score(value: str) -> FeatureScore:
    raw = value.strip()
    if "=" not in raw:
        raise argparse.ArgumentTypeError("feature score must look like spicy=0.9")

    feature_id, raw_score = raw.split("=", 1)
    feature_id = feature_id.strip()
    if not feature_id:
        raise argparse.ArgumentTypeError("feature id cannot be empty")

    try:
        score = float(raw_score)
    except ValueError as exc:
        raise argparse.ArgumentTypeError(f"invalid score: {raw_score}") from exc

    if score < 0 or score > 1:
        raise argparse.ArgumentTypeError("feature score must be between 0 and 1")

    return FeatureScore(id=feature_id, score=score)


def _count_rows(model: type) -> int:
    with SessionLocal() as session:
        return int(session.scalar(select(func.count()).select_from(model)) or 0)


def _load_existing_dish_names() -> list[str]:
    with SessionLocal() as session:
        return list(session.scalars(select(Dish.name)).all())


def _load_name_list(path: str) -> list[ApprovedDishEntry]:
    raw_lines = Path(path).read_text(encoding="utf-8").splitlines()
    entries: list[ApprovedDishEntry] = []
    seen: set[str] = set()

    for raw in raw_lines:
        line = raw.strip()
        if not line or line.startswith("#"):
            continue

        if "|" in line:
            cuisine, name = line.split("|", 1)
        elif "｜" in line:
            cuisine, name = line.split("｜", 1)
        else:
            cuisine, name = "", line

        normalized_name = name.strip()
        normalized_cuisine = cuisine.strip() or None
        if not normalized_name or normalized_name in seen:
            continue

        seen.add(normalized_name)
        entries.append(ApprovedDishEntry(cuisine=normalized_cuisine, name=normalized_name))

    return entries


def clear_app_data() -> dict[str, int]:
    with SessionLocal() as session:
        counts = {
            "dishes": int(session.scalar(select(func.count()).select_from(Dish)) or 0),
            "dish_images": int(session.scalar(select(func.count()).select_from(DishImage)) or 0),
            "generation_jobs": int(session.scalar(select(func.count()).select_from(GenerationJob)) or 0),
            "client_error_events": int(session.scalar(select(func.count()).select_from(ClientErrorEvent)) or 0),
        }

        session.execute(delete(Dish))
        session.execute(delete(DishImage))
        session.execute(delete(GenerationJob))
        session.execute(delete(ClientErrorEvent))
        session.commit()
        return counts


def _update_generation_job_progress(*, job_id: str, produced_count: int) -> None:
    with SessionLocal() as session:
        job = session.get(GenerationJob, job_id)
        if not job:
            return
        job.produced_count = produced_count
        session.commit()


def _is_retryable_gemini_error(exc: Exception) -> bool:
    message = str(exc).lower()
    retryable_markers = (
        "too many requests",
        "http 408",
        "http 429",
        "http 500",
        "http 502",
        "http 503",
        "http 504",
        "request error",
        "timed out",
    )
    return any(marker in message for marker in retryable_markers)


async def _tag_entry_with_gemini(entry: ApprovedDishEntry) -> TaggedDishRecord:
    last_error: Exception | None = None
    for attempt in range(1, MANUAL_METADATA_RETRY_ATTEMPTS + 1):
        try:
            subtitle, tags, candidate_tags, trace, raw_output = await _generate_dish_tags_with_gemini(
                entry.name,
                cuisine_hint=entry.cuisine or "",
            )
            return TaggedDishRecord(
                name=entry.name,
                subtitle=subtitle or build_subtitle(dish_name=entry.name, tags=tags, cuisine_hint=entry.cuisine or ""),
                tags=tags,
                candidate_tags=candidate_tags,
                raw_tagging_output=raw_output,
                tagging_trace=trace,
            )
        except Exception as exc:
            last_error = exc
            if attempt >= MANUAL_METADATA_RETRY_ATTEMPTS or not _is_retryable_gemini_error(exc):
                break
            wait_seconds = min(18.0, 1.5 * attempt)
            print(
                f"Tagging retry for {entry.name}: attempt={attempt}/{MANUAL_METADATA_RETRY_ATTEMPTS}"
                f" wait={wait_seconds:.1f}s reason={exc}",
                flush=True,
            )
            await asyncio.sleep(wait_seconds)

    if last_error is not None:
        raise last_error
    raise RuntimeError(f"failed to tag dish: {entry.name}")


async def _generate_tagged_records(entries: list[ApprovedDishEntry]) -> list[TaggedDishRecord]:
    records: list[TaggedDishRecord] = []
    for entry in entries:
        record = await _tag_entry_with_gemini(entry)
        records.append(record)
        print(
            f"Tagged {len(records)}/{len(entries)}: {entry.name}"
            f" (candidates={len(record.candidate_tags)})",
            flush=True,
        )
    return records


def _build_metadata_prompt(entry: ApprovedDishEntry, locale: str) -> str:
    item_line = f"{entry.cuisine} | {entry.name}" if entry.cuisine else entry.name
    return f"""
你是餐饮推荐系统的数据整理助手。请基于给定的中文菜名，输出 JSON，不要输出任何额外文本。

任务：
- 只为输入菜名补全卡片元数据。
- 绝对不要改写、翻译、扩写、缩写菜名。
- 返回对象里的 name 必须与输入菜名完全一致。
- 如果输入带有菜系，请把这个菜系当作强约束来理解菜名语境。
- 如果输入带有菜系，请在 category_tags.cuisine 里优先保留该菜系原文或最接近的标准标签。

输出格式：
{{
  "dish": {{
    "name": "与输入完全一致的菜名",
    "subtitle": "8-24字中文简介",
    "signals": {{"featureId": 0.0}},
    "category_tags": {{
      "cuisine": ["菜系标签"],
      "flavor": ["酸|甜|苦|辣|咸|麻|鲜"],
      "ingredient": ["鸡肉|鸭肉|猪肉|牛肉|羊肉|海鲜|豆腐|菌菇"]
    }}
  }}
}}

约束：
- 只允许处理这个输入项：
{item_line}
- subtitle：中文为主，简洁自然，不要营销腔。
- signals：只允许使用系统支持的 featureId；每个菜至少 3 个，最多 6 个；值范围 0.2-1.0。
- category_tags.cuisine：1-2 个标签；如果输入给了菜系，优先保留输入菜系。
- category_tags.flavor：1-4 个标签，只能使用单一口味词「酸、甜、苦、辣、咸、麻、鲜」。
- category_tags.ingredient：1-4 个标签，从「鸡肉、鸭肉、猪肉、牛肉、羊肉、海鲜、豆腐、菌菇」中选。
- locale: {locale}
""".strip()


def _heuristic_metadata_for_entry(entry: ApprovedDishEntry) -> DeckDish:
    cuisine = entry.cuisine or ""
    name = entry.name
    signals: dict[str, float] = {}
    flavor_tags: list[str] = []
    ingredient_tags: list[str] = []

    def add_signal(feature_id: str, score: float) -> None:
        if feature_id in FEATURE_IDS:
            signals[feature_id] = max(signals.get(feature_id, 0.0), score)

    def add_flavor(tag: str) -> None:
        if tag and tag not in flavor_tags:
            flavor_tags.append(tag)

    def add_ingredient(tag: str) -> None:
        if tag and tag not in ingredient_tags:
            ingredient_tags.append(tag)

    if "川" in cuisine:
        add_signal("chuanStyle", 0.95)
        add_signal("spicy", 0.88)
        add_flavor("辣")
    elif any(token in cuisine for token in ["粤", "广"]):
        add_signal("cantoneseStyle", 0.92)
        add_signal("light", 0.70)
        add_flavor("鲜")
    elif any(token in cuisine for token in ["日", "日本"]):
        add_signal("japaneseStyle", 0.92)
        add_signal("fresh", 0.78)
        add_flavor("鲜")
    elif "泰" in cuisine:
        add_signal("thaiStyle", 0.92)
        add_signal("herbal", 0.76)
        add_signal("spicy", 0.72)
        add_flavor("辣")
    elif any(token in cuisine for token in ["越南"]):
        add_signal("fresh", 0.82)
        add_signal("light", 0.78)
        add_flavor("鲜")
    elif any(token in cuisine for token in ["意大利", "法国", "西班牙"]):
        add_signal("rich", 0.75)
        add_signal("umami", 0.72)
        add_flavor("鲜")
    elif any(token in cuisine for token in ["北京", "杭帮", "上海", "闽"]):
        add_signal("umami", 0.74)
        add_signal("rich", 0.68)
        add_flavor("鲜")

    if any(token in name for token in ["辣", "椒", "麻", "宫保", "鱼香", "水煮", "毛血旺", "担担"]):
        add_signal("spicy", 0.88)
        add_flavor("辣")
    if any(token in name for token in ["麻", "椒麻"]):
        add_signal("numbing", 0.80)
        add_flavor("麻")
    if any(token in name for token in ["汤", "河粉", "米线", "拉面"]):
        add_signal("brothy", 0.76)
    if any(token in name for token in ["河粉", "米线", "拉面", "面"]):
        add_signal("noodle", 0.82)
    if any(token in name for token in ["饭", "烩饭", "海鲜饭", "糯米饭"]):
        add_signal("rice", 0.82)
    if any(token in name for token in ["烤", "烧", "炙", "蒲烧"]):
        add_signal("grilled", 0.84)
        add_signal("smoky", 0.70)
    if any(token in name for token in ["炸", "天妇罗", "春卷", "脆"]):
        add_signal("deepFried", 0.84)
        add_signal("crispy", 0.82)
    if any(token in name for token in ["炖", "煨", "煲", "砂锅", "咖喱", "东坡", "佛跳墙"]):
        add_signal("braised", 0.82)
        add_signal("rich", 0.78)
    if any(token in name for token in ["沙拉", "刺身", "冷汤", "白切"]):
        add_signal("fresh", 0.84)
        add_signal("light", 0.80)
    if any(token in name for token in ["刺身", "寿司"]):
        add_signal("raw", 0.84)
    if any(token in name for token in ["提拉米苏", "糯米饭"]):
        add_signal("sweet", 0.86)
        add_flavor("甜")
    if any(token in name for token in ["冬阴功", "酸"]):
        add_signal("sour", 0.80)
        add_flavor("酸")
    if any(token in name for token in ["芝士", "奶", "黄油", "提拉米苏"]):
        add_signal("rich", 0.84)

    ingredient_map = [
        ("鸡", "鸡肉", "chicken"),
        ("鸭", "鸭肉", "duck"),
        ("猪", "猪肉", "pork"),
        ("肉丝", "猪肉", "pork"),
        ("肉酱", "猪肉", "pork"),
        ("小笼", "猪肉", "pork"),
        ("牛", "牛肉", "beef"),
        ("羊", "羊肉", "lamb"),
        ("虾", "海鲜", "seafood"),
        ("鱼", "海鲜", "seafood"),
        ("鳗", "海鲜", "seafood"),
        ("海鲜", "海鲜", "seafood"),
        ("寿司", "海鲜", "seafood"),
        ("刺身", "海鲜", "seafood"),
        ("豆腐", "豆腐", "tofu"),
        ("菇", "菌菇", "mushroom"),
        ("菌", "菌菇", "mushroom"),
    ]
    for token, tag, feature_id in ingredient_map:
        if token in name:
            add_ingredient(tag)
            add_signal(feature_id, 0.78)

    if len(signals) < 3:
        for feature_id, score in [("umami", 0.72), ("fresh", 0.68), ("rich", 0.66)]:
            if len(signals) >= 3:
                break
            add_signal(feature_id, score)

    if not flavor_tags:
        if signals.get("spicy", 0) >= 0.75:
            add_flavor("辣")
        elif signals.get("sweet", 0) >= 0.75:
            add_flavor("甜")
        else:
            add_flavor("鲜")

    subtitle_prefix = cuisine or "特色"
    subtitle = f"{subtitle_prefix}风味经典菜品，适合口味学习"

    return DeckDish(
        name=name,
        subtitle=subtitle[:24],
        signals=dict(sorted(signals.items(), key=lambda item: item[1], reverse=True)[:6]),
        category_tags=DeckCategoryTags(
            cuisine=[cuisine] if cuisine else [],
            flavor=flavor_tags[:4],
            ingredient=ingredient_tags[:4],
        ),
    )


async def _generate_metadata_for_names(entries: list[ApprovedDishEntry], locale: str) -> list[DeckDish]:
    enriched: list[DeckDish] = []
    for entry in entries:
        success = False
        for attempt in range(1, MANUAL_METADATA_RETRY_ATTEMPTS + 1):
            try:
                prompt = _build_metadata_prompt(entry, locale=locale)
                raw = await _call_gemini_json(prompt, temperature=0.35)
                text = _extract_first_text(raw)
                data = _extract_json(text)
                raw_dish = data.get("dish")
                cleaned = _sanitize_dishes([raw_dish] if isinstance(raw_dish, dict) else [])
                if not cleaned:
                    continue

                dish = cleaned[0].model_copy(update={"name": entry.name})
                if entry.cuisine:
                    curated_cuisines = [entry.cuisine] + [
                        value for value in dish.category_tags.cuisine if value != entry.cuisine
                    ]
                    dish = dish.model_copy(
                        update={
                            "category_tags": DeckCategoryTags(
                                cuisine=curated_cuisines[:2],
                                flavor=dish.category_tags.flavor,
                                ingredient=dish.category_tags.ingredient,
                            )
                        }
                    )

                enriched.append(dish)
                success = True
                break
            except Exception as exc:
                if attempt >= MANUAL_METADATA_RETRY_ATTEMPTS or not _is_retryable_gemini_error(exc):
                    break
                wait_seconds = min(18.0, 1.5 * attempt)
                print(
                    f"Metadata retry for {entry.name}: attempt={attempt}/{MANUAL_METADATA_RETRY_ATTEMPTS}"
                    f" wait={wait_seconds:.1f}s reason={exc}",
                    flush=True,
                )
                await asyncio.sleep(wait_seconds)

        if not success:
            print(f"Metadata fallback for {entry.name}", flush=True)
            enriched.append(_heuristic_metadata_for_entry(entry))

    order = {entry.name: index for index, entry in enumerate(entries)}
    return sorted(enriched, key=lambda dish: order[dish.name])


async def _generate_image_for_seed(
    dish: TaggedDishRecord,
    *,
    cuisine: str | None,
    image_delay_seconds: float,
    image_max_retries: int,
) -> tuple[str, str, str] | tuple[str, str, None]:
    for attempt in range(1, max(1, image_max_retries) + 1):
        try:
            return await _generate_dish_image_with_gemini(dish.name, cuisine=cuisine)
        except Exception as exc:
            if attempt >= image_max_retries or not _is_retryable_gemini_error(exc):
                raise
            wait_seconds = min(45.0, max(1.0, image_delay_seconds) * (2 ** (attempt - 1)))
            print(
                f"Image retry for {dish.name}: attempt={attempt}/{image_max_retries}"
                f" wait={wait_seconds:.1f}s reason={exc}",
                flush=True,
            )
            await asyncio.sleep(wait_seconds)
    return "", "image/png", None


async def _store_manual_dishes(
    dishes: list[TaggedDishRecord],
    entries_by_name: dict[str, ApprovedDishEntry] | None = None,
    *,
    job_id: str | None,
    source: str,
    with_images: bool,
    image_delay_seconds: float,
    image_max_retries: int,
    refresh_images: bool,
) -> int:
    created_count = 0

    with SessionLocal() as session:
        for index, dish in enumerate(dishes, start=1):
            entry = entries_by_name.get(dish.name) if entries_by_name else None
            primary_cuisine = entry.cuisine if entry and entry.cuisine else (
                dish.tags.cuisine[0] if dish.tags.cuisine else None
            )
            existing_dish = session.scalar(select(Dish).where(Dish.name == dish.name))
            image_prompt = ""
            image_mime = "image/png"
            image_data_url: str | None = None

            should_generate_image = with_images and (
                refresh_images
                or existing_dish is None
                or not existing_dish.image_id
            )

            if should_generate_image:
                image_prompt, image_mime, image_data_url = await _generate_image_for_seed(
                    dish,
                    cuisine=primary_cuisine,
                    image_delay_seconds=image_delay_seconds,
                    image_max_retries=image_max_retries,
                )

            image_id = None
            if image_data_url:
                image = DishImage(
                    provider="gemini",
                    model=GEMINI_IMAGE_MODEL,
                    prompt=image_prompt,
                    mime_type=image_mime,
                    data_url=image_data_url,
                )
                session.add(image)
                session.flush()
                image_id = image.id
            elif existing_dish is not None:
                image_id = existing_dish.image_id

            payload = {
                "subtitle": dish.subtitle,
                "signals": {},
                "category_tags": legacy_category_tags_from_tags(dish.tags),
                "tags_json": dish.tags.by_dimension(),
                "raw_tagging_output": dish.raw_tagging_output,
                "candidate_tags_json": [item.model_dump() for item in dish.candidate_tags],
                "tagging_trace_json": dish.tagging_trace,
                "tagging_version": TAGGING_VERSION,
                "status": "ready",
                "source": source,
                "image_id": image_id,
            }

            if existing_dish is None:
                session.add(
                    Dish(
                        name=dish.name,
                        **payload,
                    )
                )
                action_label = "Stored"
            else:
                for key, value in payload.items():
                    setattr(existing_dish, key, value)
                action_label = "Updated"

            created_count += 1
            session.commit()
            if job_id:
                _update_generation_job_progress(job_id=job_id, produced_count=created_count)
            print(
                f"{action_label} {index}/{len(dishes)}: {dish.name}"
                f" (produced={created_count}, images={'yes' if image_data_url else 'no'})",
                flush=True,
            )

            if with_images and image_delay_seconds > 0 and index < len(dishes):
                await asyncio.sleep(image_delay_seconds)

    return created_count


async def generate_cache(args: argparse.Namespace) -> int:
    if args.clear_first:
        cleared = clear_app_data()
        print(
            "Cleared app data:"
            f" dishes={cleared['dishes']},"
            f" images={cleared['dish_images']},"
            f" jobs={cleared['generation_jobs']},"
            f" client_errors={cleared['client_error_events']}"
        )

    remaining = args.count
    produced_total = 0
    job_kind = "manual_reseed" if args.clear_first else "manual_seed"
    job_id = _create_generation_job(kind=job_kind, target_count=args.count)

    try:
        while remaining > 0:
            batch_size = min(40, remaining)
            request = DeckRequest(
                count=batch_size,
                top_positive=args.top_positive,
                top_negative=args.top_negative,
                recent_likes=args.recent_likes,
                avoid_names=args.avoid_names,
                locale=args.locale,
            )
            existing_names = _load_existing_dish_names()
            produced = await _generate_and_store_dishes(
                request,
                needed=batch_size,
                extra_avoid_names=existing_names,
            )
            produced_total += produced
            remaining -= batch_size
            print(
                f"Batch finished: requested={batch_size}, produced={produced},"
                f" total_produced={produced_total}, remaining_batches_target={remaining}"
            )

        _finish_generation_job(job_id=job_id, produced_count=produced_total)
        print(
            "Generation complete:"
            f" requested={args.count}, produced={produced_total},"
            f" ready_dishes={_count_rows(Dish)}, ready_images={_count_rows(DishImage)}"
        )
        return 0
    except Exception as exc:
        _finish_generation_job(job_id=job_id, produced_count=produced_total, error=str(exc))
        print(f"Generation failed after produced={produced_total}: {exc}", file=sys.stderr)
        return 1


async def seed_approved_names(args: argparse.Namespace) -> int:
    approved_entries = _load_name_list(args.input)
    if not approved_entries:
        print("No approved dish names were found in the input file.", file=sys.stderr)
        return 2

    if args.clear_first:
        cleared = clear_app_data()
        print(
            "Cleared app data:"
            f" dishes={cleared['dishes']},"
            f" images={cleared['dish_images']},"
            f" jobs={cleared['generation_jobs']},"
            f" client_errors={cleared['client_error_events']}"
        )

    job_kind = "manual_name_reseed" if args.clear_first else "manual_name_seed"
    job_id = _create_generation_job(kind=job_kind, target_count=len(approved_entries))
    produced_total = 0

    try:
        entries_by_name = {entry.name: entry for entry in approved_entries}
        tagged_records = await _generate_tagged_records(approved_entries)
        produced_total = await _store_manual_dishes(
            tagged_records,
            entries_by_name=entries_by_name,
            job_id=job_id,
            source="manual_seed",
            with_images=not args.skip_images,
            image_delay_seconds=args.image_delay_seconds,
            image_max_retries=args.image_max_retries,
            refresh_images=args.refresh_images,
        )
        _finish_generation_job(job_id=job_id, produced_count=produced_total)
        print(
            "Approved-name seed complete:"
            f" requested={len(approved_entries)},"
            f" updated={produced_total},"
            f" ready_dishes={_count_rows(Dish)},"
            f" ready_images={_count_rows(DishImage)}"
        )
        return 0
    except Exception as exc:
        _finish_generation_job(job_id=job_id, produced_count=produced_total, error=str(exc))
        print(f"Approved-name seed failed after produced={produced_total}: {exc}", file=sys.stderr)
        return 1


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Manual dish/image cache admin for readytoorder."
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    clear_parser = subparsers.add_parser(
        "clear",
        help="Delete all dishes, dish images, generation jobs, and client error events.",
    )
    clear_parser.add_argument(
        "--yes-i-understand",
        action="store_true",
        help="Required safety flag before deleting app data.",
    )

    generate_parser = subparsers.add_parser(
        "generate",
        help="Generate dishes and images manually, then store them in the database.",
    )
    generate_parser.add_argument(
        "--count",
        type=int,
        required=True,
        help="How many new dishes to try to generate in total.",
    )
    generate_parser.add_argument(
        "--locale",
        default="zh-CN",
        help="Locale hint passed into Gemini deck generation.",
    )
    generate_parser.add_argument(
        "--recent-like",
        action="append",
        dest="recent_likes",
        default=[],
        help="Optional recent liked dish name. Repeat the flag to pass multiple values.",
    )
    generate_parser.add_argument(
        "--avoid-name",
        action="append",
        dest="avoid_names",
        default=[],
        help="Optional dish name to avoid. Repeat the flag to pass multiple values.",
    )
    generate_parser.add_argument(
        "--top-positive",
        action="append",
        type=_parse_feature_score,
        default=[],
        help="Optional feature score like spicy=0.9. Repeat the flag to pass multiple values.",
    )
    generate_parser.add_argument(
        "--top-negative",
        action="append",
        type=_parse_feature_score,
        default=[],
        help="Optional feature score like sweet=0.8. Repeat the flag to pass multiple values.",
    )
    generate_parser.add_argument(
        "--clear-first",
        action="store_true",
        help="Clear all app data before generating a fresh cache.",
    )

    seed_names_parser = subparsers.add_parser(
        "seed-names",
        help="Seed the cache from an approved dish-name list, then generate metadata and images for those names only.",
    )
    seed_names_parser.add_argument(
        "--input",
        required=True,
        help="UTF-8 text file with one approved dish per line. Format: cuisine|name or plain name.",
    )
    seed_names_parser.add_argument(
        "--locale",
        default="zh-CN",
        help="Locale hint passed into Gemini when enriching approved names.",
    )
    seed_names_parser.add_argument(
        "--clear-first",
        action="store_true",
        help="Clear all app data before seeding the approved names.",
    )
    seed_names_parser.add_argument(
        "--skip-images",
        action="store_true",
        help="Only store text metadata for approved names and skip image generation.",
    )
    seed_names_parser.add_argument(
        "--metadata-mode",
        choices=("heuristic", "gemini"),
        default="gemini",
        help="How to fill subtitle and tags for approved names. Default uses Gemini tagging with canonical normalization.",
    )
    seed_names_parser.add_argument(
        "--image-delay-seconds",
        type=float,
        default=MANUAL_IMAGE_DELAY_SECONDS,
        help="Delay between successful image generations to reduce Gemini rate limiting.",
    )
    seed_names_parser.add_argument(
        "--image-max-retries",
        type=int,
        default=MANUAL_IMAGE_RETRY_ATTEMPTS,
        help="How many times to retry a single image on Gemini rate limits or transient failures.",
    )
    seed_names_parser.add_argument(
        "--refresh-images",
        action="store_true",
        help="Regenerate images even when a dish already has an image.",
    )

    return parser


async def async_main(args: argparse.Namespace) -> int:
    init_db()

    if args.command == "clear":
        if not args.yes_i_understand:
            print("Refusing to clear data without --yes-i-understand.", file=sys.stderr)
            return 2

        counts = clear_app_data()
        print(
            "Deleted app data:"
            f" dishes={counts['dishes']},"
            f" images={counts['dish_images']},"
            f" jobs={counts['generation_jobs']},"
            f" client_errors={counts['client_error_events']}"
        )
        return 0

    if args.command == "generate":
        if args.count <= 0:
            print("--count must be greater than 0.", file=sys.stderr)
            return 2
        return await generate_cache(args)

    if args.command == "seed-names":
        return await seed_approved_names(args)

    print(f"Unknown command: {args.command}", file=sys.stderr)
    return 2


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    return asyncio.run(async_main(args))


if __name__ == "__main__":
    raise SystemExit(main())
