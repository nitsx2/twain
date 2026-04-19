# Twain AI

Two-app medical consultation platform.

- **Patient app** — sign-in → intake chat with Twain AI (Claude) → get a 4-digit patient code → view diagnoses + signed prescriptions.
- **Doctor app** — sign-in → draw a signature → enter patient code → record consultation → AI transcribes & summarises → chat with Brain AI → draft + sign prescription → PDF pushed to patient.

Backend: FastAPI + PostgreSQL. AI: Claude Sonnet 4.6. Transcription: Qubrid Whisper. PDF: WeasyPrint. All blobs (audio, PDFs, signatures) stored as Postgres `bytea` for the MVP.

## Prereqs

- podman + podman-compose
- flutter
- python3

## Run locally

```bash
# 1. Backend + DB
podman-compose up -d
curl http://localhost:9494/health

# 2. Patient app
cd apps/patient
flutter pub get
flutter run -d web-server --web-port 7474

# 3. Doctor app (new terminal)
cd apps/doctor
flutter pub get
flutter run -d web-server --web-port 7575
```

Open the printed URLs in Chrome.

## Ports

| Service        | Host | Container |
|----------------|------|-----------|
| Backend API    | 9494 | 8000      |
| Postgres       | 5442 | 5432      |
| Patient PWA    | 7474 | —         |
| Doctor PWA     | 7575 | —         |

## Project layout

```
twain/
├── backend/                FastAPI service
│   ├── app/                main, routers, models, clients
│   ├── alembic/            migrations
│   ├── templates/          WeasyPrint Rx template
│   └── Containerfile
├── apps/
│   ├── patient/            Flutter patient app
│   └── doctor/             Flutter doctor app
├── packages/
│   └── twain_core/         Shared Flutter: theme, API client, widgets
├── compose.yaml            podman-compose (backend + postgres)
└── README.md
```

## Deployment

Target: Railway. Backend as a container, Postgres as a plugin, each PWA as its own Railway service. Alembic migrations run as the release command.

### Railway deploy (backend)

1. Create a new Railway project and add a **Postgres** plugin.
2. Connect this repo. Railway auto-detects `railway.toml` at the root.
3. Set these environment variables in the Railway service settings:

   | Variable | Value |
   |----------|-------|
   | `DATABASE_URL` | Provided automatically by the Postgres plugin |
   | `SECRET_KEY` | A long random string (e.g. `openssl rand -hex 32`) |
   | `ANTHROPIC_API_KEY` | Your Anthropic key |
   | `QUBRID_API_KEY` | Your Qubrid key |
   | `ALLOWED_ORIGINS` | Comma-separated PWA URLs (e.g. `https://patient.up.railway.app,https://doctor.up.railway.app`) |

4. Deploy. Railway runs `alembic upgrade head && uvicorn app.main:app --host 0.0.0.0 --port $PORT` on startup.
5. Health check: `GET /health` — Railway will restart the service on failure (up to 3 retries).

### Railway deploy (Flutter PWAs)

Each Flutter app builds to a static site (`flutter build web`) and can be served from any static host (Railway static service, Vercel, Netlify, Cloudflare Pages, etc.).

```bash
# Patient PWA
cd apps/patient
flutter build web --release --base-href /
# Upload build/web/ to your static host

# Doctor PWA
cd apps/doctor
flutter build web --release --base-href /
# Upload build/web/ to your static host
```

Set `BACKEND_URL` (or the equivalent API base URL in `packages/twain_core/lib/api/api_client.dart`) to your Railway backend URL.

## Storage note

Audio recordings, prescription PDFs, and doctor signatures are stored as `bytea` columns in Postgres. This is fine at hackathon scale; at production scale this would move to object storage (Cloudinary / S3 / R2) — the storage layer is isolated to make that swap easy.
