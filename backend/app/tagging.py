from __future__ import annotations

import json
import re
from typing import Any, Sequence

from pydantic import BaseModel, Field

TAGGING_VERSION = "v1"
TAG_DIMENSIONS = (
    "flavor",
    "ingredient",
    "texture",
    "cooking_method",
    "cuisine",
    "course",
    "allergen",
)

DIMENSION_LABELS = {
    "flavor": "味型",
    "ingredient": "食材",
    "texture": "口感",
    "cooking_method": "做法",
    "cuisine": "菜系",
    "course": "餐类",
    "allergen": "过敏原",
}

CANONICAL_TAGS: dict[str, list[str]] = {
    "flavor": [
        "spicy",
        "numbing",
        "sour",
        "sweet",
        "salty",
        "bitter",
        "umami",
        "savory",
        "herbal",
        "smoky",
        "creamy",
        "oily",
        "refreshing",
        "rich",
    ],
    "ingredient": [
        "chicken",
        "duck",
        "pork",
        "beef",
        "lamb",
        "fish",
        "shrimp",
        "crab",
        "shellfish",
        "eel",
        "seafood",
        "tofu",
        "egg",
        "mushroom",
        "vegetable",
        "seaweed",
        "rice",
        "noodle",
        "bread",
        "cheese",
        "milk",
        "peanut",
        "sesame",
        "soy",
        "chili",
        "garlic",
    ],
    "texture": [
        "crispy",
        "crunchy",
        "tender",
        "juicy",
        "chewy",
        "bouncy",
        "silky",
        "soft",
        "sticky",
        "flaky",
    ],
    "cooking_method": [
        "stir_fried",
        "deep_fried",
        "pan_fried",
        "grilled",
        "roasted",
        "braised",
        "stewed",
        "steamed",
        "boiled",
        "poached",
        "baked",
        "raw",
        "cured",
    ],
    "cuisine": [
        "chinese",
        "sichuan",
        "hunan",
        "cantonese",
        "beijing",
        "shanghainese",
        "shandong",
        "jiangsu",
        "zhejiang",
        "anhui",
        "fujianese",
        "hangzhou",
        "japanese",
        "thai",
        "vietnamese",
        "korean",
        "indian",
        "mexican",
        "french",
        "italian",
        "spanish",
    ],
    "course": [
        "appetizer",
        "main",
        "soup",
        "staple",
        "dessert",
        "snack",
        "drink",
    ],
    "allergen": [
        "peanut",
        "tree_nut",
        "sesame",
        "soy",
        "egg",
        "milk",
        "wheat",
        "shellfish",
        "fish",
    ],
}

TAG_LABELS = {
    "spicy": "辣",
    "numbing": "麻",
    "sour": "酸",
    "sweet": "甜",
    "salty": "咸",
    "bitter": "苦",
    "umami": "鲜",
    "savory": "咸香",
    "herbal": "草本香",
    "smoky": "烟熏香",
    "creamy": "奶香",
    "oily": "油润",
    "refreshing": "清爽",
    "rich": "浓郁",
    "chicken": "鸡肉",
    "duck": "鸭肉",
    "pork": "猪肉",
    "beef": "牛肉",
    "lamb": "羊肉",
    "fish": "鱼类",
    "shrimp": "虾",
    "crab": "蟹",
    "shellfish": "贝类海鲜",
    "eel": "鳗鱼",
    "seafood": "海鲜",
    "tofu": "豆腐",
    "egg": "鸡蛋",
    "mushroom": "菌菇",
    "vegetable": "蔬菜",
    "seaweed": "海藻",
    "rice": "米饭",
    "noodle": "面食",
    "bread": "面包",
    "cheese": "芝士",
    "milk": "奶制品",
    "peanut": "花生",
    "sesame": "芝麻",
    "soy": "大豆",
    "chili": "辣椒",
    "garlic": "蒜",
    "crispy": "酥脆",
    "crunchy": "脆爽",
    "tender": "嫩",
    "juicy": "多汁",
    "chewy": "有嚼劲",
    "bouncy": "弹牙",
    "silky": "顺滑",
    "soft": "软",
    "sticky": "软糯",
    "flaky": "酥松",
    "stir_fried": "炒",
    "deep_fried": "油炸",
    "pan_fried": "煎",
    "grilled": "炙烤",
    "roasted": "炉烤",
    "braised": "焖烧",
    "stewed": "炖煮",
    "steamed": "清蒸",
    "boiled": "水煮",
    "poached": "白灼",
    "baked": "烘焙",
    "raw": "生食",
    "cured": "腌制",
    "chinese": "中国菜",
    "sichuan": "川菜",
    "hunan": "湘菜",
    "cantonese": "粤菜",
    "beijing": "北京菜",
    "shanghainese": "上海菜",
    "shandong": "鲁菜",
    "jiangsu": "苏菜",
    "zhejiang": "浙菜",
    "anhui": "徽菜",
    "fujianese": "闽菜",
    "hangzhou": "杭帮菜",
    "japanese": "日本料理",
    "thai": "泰国菜",
    "vietnamese": "越南菜",
    "korean": "韩国菜",
    "indian": "印度菜",
    "mexican": "墨西哥菜",
    "french": "法国菜",
    "italian": "意大利菜",
    "spanish": "西班牙菜",
    "appetizer": "前菜",
    "main": "主菜",
    "soup": "汤品",
    "staple": "主食",
    "dessert": "甜品",
    "snack": "小吃",
    "drink": "饮品",
    "tree_nut": "树坚果",
    "wheat": "小麦",
}

ALLERGEN_FROM_INGREDIENT = {
    "peanut": "peanut",
    "sesame": "sesame",
    "soy": "soy",
    "egg": "egg",
    "milk": "milk",
    "cheese": "milk",
    "shellfish": "shellfish",
    "shrimp": "shellfish",
    "crab": "shellfish",
    "fish": "fish",
    "eel": "fish",
}

_SLUG_PATTERN = re.compile(r"[^a-z0-9_]+")

CANONICAL_SET = {
    dimension: set(values)
    for dimension, values in CANONICAL_TAGS.items()
}

TAG_ALIASES: dict[tuple[str, str], str] = {
    ("flavor", "hot"): "spicy",
    ("flavor", "fresh"): "refreshing",
    ("flavor", "fragrant"): "savory",
    ("flavor", "peppery"): "spicy",
    ("ingredient", "prawn"): "shrimp",
    ("ingredient", "prawns"): "shrimp",
    ("ingredient", "scallop"): "shellfish",
    ("ingredient", "clam"): "shellfish",
    ("ingredient", "mussel"): "shellfish",
    ("ingredient", "oyster"): "shellfish",
    ("ingredient", "peanuts"): "peanut",
    ("ingredient", "chilies"): "chili",
    ("texture", "q_bouncy"): "bouncy",
    ("texture", "smooth"): "silky",
    ("cooking_method", "fried"): "deep_fried",
    ("cooking_method", "tempura"): "deep_fried",
    ("cooking_method", "barbecued"): "grilled",
    ("cooking_method", "bbq"): "grilled",
}

TAG_DECOMPOSITIONS: dict[tuple[str, str], list[str]] = {
    ("flavor", "mala"): ["numbing", "spicy"],
    ("flavor", "sour_spicy"): ["sour", "spicy"],
    ("flavor", "sweet_spicy"): ["sweet", "spicy"],
    ("flavor", "salty_umami"): ["salty", "umami"],
    ("flavor", "umami_spicy"): ["umami", "spicy"],
    ("flavor", "savory_spicy"): ["savory", "spicy"],
    ("flavor", "numbing_savory"): ["numbing", "savory"],
    ("flavor", "rich_savory"): ["rich", "savory"],
    ("flavor", "refreshing_umami"): ["refreshing", "umami"],
    ("flavor", "creamy_savory"): ["creamy", "savory"],
    ("flavor", "oily_savory"): ["oily", "savory"],
    ("flavor", "smoky_savory"): ["smoky", "savory"],
    ("texture", "soft_sticky"): ["soft", "sticky"],
    ("texture", "crispy_crunchy"): ["crispy", "crunchy"],
}


class CandidateTag(BaseModel):
    dimension: str
    value: str


class DishTags(BaseModel):
    flavor: list[str] = Field(default_factory=list)
    ingredient: list[str] = Field(default_factory=list)
    texture: list[str] = Field(default_factory=list)
    cooking_method: list[str] = Field(default_factory=list)
    cuisine: list[str] = Field(default_factory=list)
    course: list[str] = Field(default_factory=list)
    allergen: list[str] = Field(default_factory=list)

    def by_dimension(self) -> dict[str, list[str]]:
        return {dimension: list(getattr(self, dimension)) for dimension in TAG_DIMENSIONS}


def _ordered_unique(items: Sequence[str]) -> list[str]:
    seen: set[str] = set()
    output: list[str] = []
    for item in items:
        value = str(item).strip()
        if not value or value in seen:
            continue
        seen.add(value)
        output.append(value)
    return output


def normalize_tag_key(value: object) -> str:
    text = str(value or "").strip().lower()
    if not text:
        return ""
    text = text.replace("-", "_").replace(" ", "_").replace("/", "_")
    text = _SLUG_PATTERN.sub("_", text)
    text = re.sub(r"_+", "_", text).strip("_")
    return text


def tag_id(dimension: str, key: str) -> str:
    return f"{dimension}:{key}"


def parse_tag_id(value: str) -> tuple[str, str]:
    raw = str(value or "").strip()
    if ":" not in raw:
        return "", ""
    dimension, key = raw.split(":", 1)
    return normalize_tag_key(dimension), normalize_tag_key(key)


def display_label_for_tag(dimension: str, key: str) -> str:
    label = TAG_LABELS.get(key, key.replace("_", " "))
    dim_label = DIMENSION_LABELS.get(dimension, dimension)
    return f"{dim_label}:{label}"


def build_subtitle(*, dish_name: str, tags: DishTags, cuisine_hint: str | None = None) -> str:
    cuisine_key = (
        normalize_tag_key(cuisine_hint)
        if cuisine_hint
        else (tags.cuisine[0] if tags.cuisine else "")
    )
    cuisine_label = TAG_LABELS.get(cuisine_key, "") if cuisine_key else ""
    if cuisine_label:
        return f"{cuisine_label}经典菜品，适合口味探索"
    return f"{dish_name}，适合口味探索"


def legacy_category_tags_from_tags(tags: DishTags) -> dict[str, list[str]]:
    return {
        "cuisine": [TAG_LABELS.get(key, key) for key in tags.cuisine],
        "flavor": [TAG_LABELS.get(key, key) for key in tags.flavor],
        "ingredient": [TAG_LABELS.get(key, key) for key in tags.ingredient],
    }


def tags_from_legacy_fields(
    category_tags: object | None,
    signals: object | None,
) -> DishTags:
    raw_tags: dict[str, list[str]] = {dimension: [] for dimension in TAG_DIMENSIONS}
    if isinstance(category_tags, dict):
        for dimension in ("cuisine", "flavor", "ingredient"):
            value = category_tags.get(dimension, [])
            if isinstance(value, list):
                raw_tags[dimension] = [normalize_tag_key(item) for item in value]

    if isinstance(signals, dict):
        for raw_key in signals.keys():
            key = normalize_tag_key(raw_key)
            mapped_dimension = ""
            mapped_key = ""
            if key in CANONICAL_SET["flavor"]:
                mapped_dimension = "flavor"
                mapped_key = key
            elif key in CANONICAL_SET["texture"]:
                mapped_dimension = "texture"
                mapped_key = key
            elif key in CANONICAL_SET["ingredient"]:
                mapped_dimension = "ingredient"
                mapped_key = key
            elif key in CANONICAL_SET["cuisine"]:
                mapped_dimension = "cuisine"
                mapped_key = key
            elif key in CANONICAL_SET["cooking_method"]:
                mapped_dimension = "cooking_method"
                mapped_key = key
            if mapped_dimension and mapped_key:
                raw_tags[mapped_dimension].append(mapped_key)

    normalized, _, _ = normalize_tags_payload(raw_tags)
    return normalized


def normalize_tags_payload(
    raw_tags: object | None,
    *,
    raw_candidates: object | None = None,
) -> tuple[DishTags, list[CandidateTag], dict[str, list[str]]]:
    result: dict[str, list[str]] = {dimension: [] for dimension in TAG_DIMENSIONS}
    trace = {
        "aliases": [],
        "decomposed": [],
        "promoted_allergens": [],
    }

    if isinstance(raw_tags, DishTags):
        raw_by_dimension = raw_tags.by_dimension()
    elif isinstance(raw_tags, dict):
        raw_by_dimension = {
            dimension: raw_tags.get(dimension, [])
            for dimension in TAG_DIMENSIONS
        }
    else:
        raw_by_dimension = {dimension: [] for dimension in TAG_DIMENSIONS}

    candidates: list[CandidateTag] = []

    for dimension in TAG_DIMENSIONS:
        values = raw_by_dimension.get(dimension, [])
        if not isinstance(values, list):
            continue

        for raw in values:
            key = normalize_tag_key(raw)
            if not key:
                continue

            if key in CANONICAL_SET[dimension]:
                result[dimension].append(key)
                continue

            alias_target = TAG_ALIASES.get((dimension, key))
            if alias_target:
                result[dimension].append(alias_target)
                trace["aliases"].append(f"{dimension}:{key}->{alias_target}")
                continue

            decomposed = TAG_DECOMPOSITIONS.get((dimension, key))
            if decomposed:
                result[dimension].extend(decomposed)
                trace["decomposed"].append(
                    f"{dimension}:{key}->{','.join(decomposed)}"
                )
                continue

            candidates.append(CandidateTag(dimension=dimension, value=key))

    if isinstance(raw_candidates, list):
        for item in raw_candidates:
            if isinstance(item, dict):
                candidate_dimension = normalize_tag_key(item.get("dimension"))
                candidate_value = normalize_tag_key(item.get("value"))
            else:
                candidate_dimension = ""
                candidate_value = normalize_tag_key(item)
            if candidate_dimension in TAG_DIMENSIONS and candidate_value:
                candidates.append(
                    CandidateTag(dimension=candidate_dimension, value=candidate_value)
                )

    allergens = list(result["allergen"])
    for ingredient in list(result["ingredient"]):
        allergen = ALLERGEN_FROM_INGREDIENT.get(ingredient)
        if not allergen:
            continue
        allergens.append(allergen)
        trace["promoted_allergens"].append(f"{ingredient}->{allergen}")
    result["allergen"] = allergens

    cleaned = DishTags(
        **{
            dimension: _ordered_unique(result[dimension])
            for dimension in TAG_DIMENSIONS
        }
    )
    cleaned_candidates = []
    seen_candidates: set[tuple[str, str]] = set()
    for candidate in candidates:
        key = (candidate.dimension, candidate.value)
        if key in seen_candidates:
            continue
        seen_candidates.add(key)
        cleaned_candidates.append(candidate)

    return cleaned, cleaned_candidates, trace


def build_tagging_prompt(dish_name: str, *, cuisine_hint: str = "") -> str:
    dictionary_lines = []
    for dimension in TAG_DIMENSIONS:
        dictionary_lines.append(f"{dimension}: {', '.join(CANONICAL_TAGS[dimension])}")

    cuisine_input = cuisine_hint.strip() or ""
    return f"""
You are a food taxonomy annotator for a restaurant recommendation system.

Your task is to read a dish name and output structured English tags only.
These tags are used for recommendation, preference analysis, and dietary filtering.

You must follow these rules strictly:
1. Output valid JSON only. Do not output any explanation.
2. Use English canonical tags only.
3. Prefer precision over recall. If uncertain, omit the tag.
4. Do not output Chinese tags.
5. Do not output free-text descriptions outside subtitle.
6. Do not output combined flavor labels. Decompose compound concepts into atomic tags.
7. If a concept does not fit the canonical dictionary, put it into candidate_tags instead of the main fields.
8. Remove duplicates.
9. Allergen tags should be conservative. Only include them when clearly supported by the dish name or very strong dish semantics.
10. subtitle must be concise Chinese text, 8-24 characters, and should sound natural.

Return this exact JSON shape:
{{
  "subtitle": "8-24字中文简介",
  "tags": {{
    "flavor": [],
    "ingredient": [],
    "texture": [],
    "cooking_method": [],
    "cuisine": [],
    "course": [],
    "allergen": []
  }},
  "candidate_tags": []
}}

candidate_tags must be an array of objects:
{{
  "dimension": "flavor|ingredient|texture|cooking_method|cuisine|course|allergen",
  "value": "raw_tag"
}}

Canonical dictionary:
{chr(10).join(dictionary_lines)}

Normalization rules:
- "麻辣" must become ["numbing", "spicy"]
- "酸辣" must become ["sour", "spicy"]
- "甜辣" must become ["sweet", "spicy"]
- "咸鲜" must become ["salty", "umami"]
- "鲜辣" must become ["umami", "spicy"]
- "香辣" usually becomes ["savory", "spicy"]
- Do not output compound flavor labels such as mala or sour_spicy in the main fields.
- If a dish is clearly a soup or noodle/rice staple, classify course accordingly.
- If a dish includes a known allergen ingredient, it may appear in both ingredient and allergen.

Examples:
Input:
{{"dish_name": "宫保鸡丁", "cuisine_hint": "sichuan"}}
Output:
{{"subtitle": "川味咸香鸡丁，带花生香气", "tags": {{"flavor": ["spicy", "savory"], "ingredient": ["chicken", "peanut", "chili"], "texture": [], "cooking_method": ["stir_fried"], "cuisine": ["sichuan"], "course": ["main"], "allergen": ["peanut"]}}, "candidate_tags": []}}

Input:
{{"dish_name": "三文鱼刺身", "cuisine_hint": "japanese"}}
Output:
{{"subtitle": "细嫩鲜甜的日式生食鱼片", "tags": {{"flavor": ["umami", "refreshing"], "ingredient": ["fish"], "texture": ["silky", "soft"], "cooking_method": ["raw"], "cuisine": ["japanese"], "course": ["main"], "allergen": ["fish"]}}, "candidate_tags": []}}

Input:
{{"dish_name": "冬阴功虾汤", "cuisine_hint": "thai"}}
Output:
{{"subtitle": "酸辣草本风味的经典虾汤", "tags": {{"flavor": ["sour", "spicy", "herbal"], "ingredient": ["shrimp"], "texture": [], "cooking_method": ["boiled"], "cuisine": ["thai"], "course": ["soup"], "allergen": ["shellfish"]}}, "candidate_tags": []}}

Input:
{{"dish_name": "提拉米苏", "cuisine_hint": "italian"}}
Output:
{{"subtitle": "绵密奶香的经典意式甜品", "tags": {{"flavor": ["sweet", "creamy", "rich"], "ingredient": ["milk", "egg"], "texture": ["soft"], "cooking_method": ["baked"], "cuisine": ["italian"], "course": ["dessert"], "allergen": ["milk", "egg"]}}, "candidate_tags": []}}

Input:
{json.dumps({"dish_name": dish_name, "cuisine_hint": cuisine_input}, ensure_ascii=False)}
""".strip()
