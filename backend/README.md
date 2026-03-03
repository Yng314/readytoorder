# readytoorder backend (Gemini + DB cache + guardrails)

FastAPI backend for:
- `POST /v1/taste/deck`: return cached dishes first, auto-refill when inventory is low
  - each dish includes `category_tags` (`cuisine` / `flavor` / `ingredient`)
- `POST /v1/taste/analyze`: summarize taste profile from swipe history
- `POST /v1/menu/chat`: menu-image chat + menu-internal recommendations
- `POST /v1/client/error`: client-side error event ingestion
- `GET /health`: health info including current cached dish count

## 1) Install

```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
# optional for tests
pip install -r requirements-dev.txt
```

## 2) Configure

```bash
export APP_ENV="development"               # production requires PostgreSQL URL
export GEMINI_API_KEY="your_key"
# optional
export GEMINI_MODEL="gemini-3-flash-preview"
export GEMINI_IMAGE_MODEL="gemini-3-pro-image-preview"
export GEMINI_API_BASE="https://generativelanguage.googleapis.com"
# optional
export DATABASE_URL="postgresql://..."     # required when APP_ENV=production
export DECK_LOW_WATERMARK="50"
export DECK_REFILL_BATCH="20"
export IMAGE_GENERATION_CONCURRENCY="4"
export MENU_MAX_IMAGES="6"
export MENU_MAX_IMAGE_BYTES="3145728"
export RATE_LIMIT_REQUESTS="60"
export RATE_LIMIT_WINDOW_SECONDS="60"
export CORS_ALLOW_ORIGINS="https://example.com"
export READYTOORDER_API_KEY=""             # optional shared API key gate
export SENTRY_DSN=""                       # optional backend monitoring
export CLEANUP_INTERVAL_SECONDS="3600"
```

## 3) Run

```bash
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

## 4) Request headers (required for all `/v1/*`)

- `X-Device-ID: <uuid>`
- `X-Client-Version: <semantic version>` (e.g. `1.0.0`)
- `X-API-Key: <secret>` only when `READYTOORDER_API_KEY` is configured

Error response contract:

```json
{
  "code": "rate_limited",
  "message": "Too many requests. Please retry in a moment.",
  "request_id": "..."
}
```

## 5) DB migrations

Startup runs Alembic migration `upgrade head` automatically.

Manual migration:

```bash
cd backend
alembic upgrade head
```

Health check:

```bash
curl http://127.0.0.1:8000/health
```

## Notes

- Schema is managed via Alembic (`alembic/versions/0001_initial_schema.py`).
- The deck endpoint prefers DB cache and only calls Gemini when cache is insufficient.
- Dish image prompt template:
  - `生成一个[菜品名]的图片，俯视角，图像比例2:3，食物主体在下方2/3区域内`
- If `GEMINI_API_KEY` is missing or Gemini fails and cache is empty, endpoints return `5xx`.
- A periodic cleanup job removes expired generation jobs, stale client error events and orphaned dish images.
