# readytoorder backend (Gemini + DB cache + guardrails)

FastAPI backend for:
- `POST /v1/taste/deck`: return cached dishes and images already stored in DB
  - each dish includes canonical `tags` grouped by `flavor`, `ingredient`, `texture`, `cooking_method`, `cuisine`, `course`, and `allergen`
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

## 6) Manual dish cache admin

The app no longer auto-generates dishes or images. To rebuild the dish cache manually, use:

```bash
cd backend
PYTHONPATH=. python scripts/dish_cache_admin.py generate --count 40
```

If you already reviewed a curated dish-name list yourself, prefer seeding from that list instead of letting the backend invent names:

```bash
cd backend
PYTHONPATH=. python scripts/dish_cache_admin.py seed-names --input data/approved_dishes.txt
```

`seed-names` accepts either:

```text
菜系|菜名
```

or plain:

```text
菜名
```

When a cuisine is provided, the script uses it both as tagging context and inside the image-generation prompt.
For curated production rebuilds, `seed-names` now uses a slower, safer flow: it tags dishes with Gemini text, normalizes them against the canonical dictionary, stores them one by one, prints progress immediately, and automatically backs off on Gemini rate limits.
The app never runs this tagging flow itself. Tag generation only happens in this manual admin path.

To wipe the current app data before rebuilding:

```bash
cd backend
PYTHONPATH=. python scripts/dish_cache_admin.py clear --yes-i-understand
PYTHONPATH=. python scripts/dish_cache_admin.py seed-names --input data/approved_dishes.txt
```

If you want to seed Railway production from your local machine, use the database public URL:

```bash
cd backend
export DATABASE_URL="$(npx -y @railway/cli variable list --service Postgres-RkMM -e production -k | sed -n 's/^DATABASE_PUBLIC_URL=//p')"
PYTHONUNBUFFERED=1 PYTHONPATH=. .venv/bin/python scripts/dish_cache_admin.py seed-names --input data/approved_dishes.txt
```

## Notes

- Schema is managed via Alembic (`alembic/versions/0001_initial_schema.py`).
- The deck endpoint is cache-only: it returns dishes already stored in DB and never auto-generates new dishes or images.
- Each stored dish now keeps:
  - `tags_json`: final canonical English tags grouped by dimension
  - `raw_tagging_output`: original Gemini tagging JSON
  - `candidate_tags_json`: tags that were not in the canonical dictionary
  - `tagging_trace_json`: alias/decomposition/normalization trace
  - `tagging_version`: prompt/dictionary version used for tagging
- Canonical tag dimensions:
  - `flavor`, `ingredient`, `texture`, `cooking_method`, `cuisine`, `course`, `allergen`
- Canonical tags are stored in English for consistency; the iOS app maps them back to Chinese display labels.
- Dish image prompt template:
  - `生成一张[菜系]料理中的[菜品名]成品食物图片，真实餐厅菜品摄影风格，俯视角，图像比例2:3，食物主体位于画面下方2/3，单道成品，无人物，无手部，无文字，无logo，器皿与该菜系常见呈现方式一致，光线自然，细节清晰。`
- Dish tagging prompt uses Gemini text to output canonical JSON tags, then normalizes them through the backend dictionary before storing them.
- If `GEMINI_API_KEY` is missing or Gemini fails, Gemini-backed endpoints such as taste analysis and menu chat can return `5xx`.
- A periodic cleanup job removes expired generation jobs, stale client error events and orphaned dish images.
- iOS can forward MetricKit diagnostics to `POST /v1/client/error` (scope `ios_diagnostic`) for crash/hang trend monitoring.
