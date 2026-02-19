# readytoorder backend (Gemini)

FastAPI backend for:
- `POST /v1/taste/deck`: generate Chinese dish swipe cards
- `POST /v1/taste/analyze`: summarize taste profile from swipe history

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
export GEMINI_API_BASE="https://generativelanguage.googleapis.com"
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

- This backend is Gemini-only. If `GEMINI_API_KEY` is missing or Gemini fails, endpoints return `5xx`.
- iOS simulator can call `http://127.0.0.1:8000` directly.
