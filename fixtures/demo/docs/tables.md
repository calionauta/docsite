# Tables

## A wide table

| Layer | Choice | Runtime opt-out | What it buys |
|---|---|---|---|
| **Language** | Go 1.27 | — | Fast compilation, easy deploy, lean runtime |
| **Search** | Own layers — no external engine | `trim search` | One `Searcher` seam with `substring`, `fuzzy` and `bm25` selectable at runtime; a boot-time heal re-indexes rows so enabling it never answers "no results" for data you can see |
| **Offline sync** | Service Worker + NATS Leaf Node + idempotency key | `OFFLINE_SYNC_ENABLED=false` | Mutations queue in the browser and replay on reconnect, deduped by an idempotency key the database backs with a unique index |

## A token table

| Variable | Default | Purpose |
|---|---|---|
| `BYOK_PROVIDERS` | unset | `openai=https://api.openai.com/v1,groq=https://api.groq.com/openai/v1` |
| `TURSO_DB_PATH` | `data/app.db` | Turso Database file for the flat stack |
