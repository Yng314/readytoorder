# readytoorder backend (Gemini + DB cache)

FastAPI backend for:
- `POST /v1/taste/deck`: return cached dishes first, auto-refill when inventory is low
  - each dish includes `category_tags` (`cuisine` / `flavor` / `ingredient`)
- `POST /v1/taste/analyze`: summarize taste profile from swipe history
- `GET /health`: health info including current cached dish count

## 1) Install

```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

## 2) Configure

```bash
export GEMINI_API_KEY="your_key"
# optional
export GEMINI_MODEL="gemini-3-flash-preview"
export GEMINI_IMAGE_MODEL="gemini-3-pro-image-preview"
export GEMINI_API_BASE="https://generativelanguage.googleapis.com"
# optional
export DATABASE_URL="postgresql://..."  # default: sqlite:///./readytoorder.db
export DECK_LOW_WATERMARK="50"
export DECK_REFILL_BATCH="20"
export IMAGE_GENERATION_CONCURRENCY="4"
```

## 3) Run

```bash
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

Health check:

```bash
curl http://127.0.0.1:8000/health
```

## Notes

- Data tables are auto-created on startup (`dishes`, `dish_images`, `generation_jobs`).
- Startup includes a lightweight compatibility patch for `dishes.category_tags` when upgrading older DB schema.
- The deck endpoint prefers DB cache and only calls Gemini when cache is insufficient.
- Dish image prompt template:
  - `生成一个[菜品名]的图片，俯视角，图像比例2:3，食物主体在下方2/3区域内`
- If `GEMINI_API_KEY` is missing or Gemini fails and cache is empty, endpoints return `5xx`.
