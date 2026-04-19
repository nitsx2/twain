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

Target: Railway. Backend as a container, Postgres as a plugin, each PWA as its own Railway service. Alembic migrations run as the release command. Details in Phase 8.

## Storage note

Audio recordings, prescription PDFs, and doctor signatures are stored as `bytea` columns in Postgres. This is fine at hackathon scale; at production scale this would move to object storage (Cloudinary / S3 / R2) — the storage layer is isolated to make that swap easy.
