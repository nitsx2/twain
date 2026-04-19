# Twain AI — Medical Consultation Platform

> **"Two minds, one care."**
> Twain connects patients and doctors through AI-assisted intake, real-time transcription, intelligent clinical analysis, and digitally signed prescriptions — end-to-end in a single flow.

## 🔴 Live Demo

| App | URL |
|---|---|
| **Patient App** | **[twain-patient.vercel.app](https://twain-patient.vercel.app)** |
| **Doctor App** | **[web-zeta-ten-42.vercel.app](https://web-zeta-ten-42.vercel.app)** |
| **Backend API** | [twain-production.up.railway.app/docs](https://twain-production.up.railway.app/docs) |

**Try it in 2 minutes:**
1. Open the Patient app → Register → chat with Twain AI → tap "Done" → note your 4-digit code
2. Open the Doctor app → Register → enter the patient code → upload a voice recording → watch Brain AI analyse it → draft and sign a prescription
3. Back in Patient app → your signed PDF prescription appears

---

## The Problem — Sharp & Real

### Who this is for

**Rahul, 52, diabetic, Pune.**
He visited a clinic last Tuesday. The doctor had 45 seconds for him. She didn't ask about his metformin dose, missed that he'd started a new ACE inhibitor last month, and wrote a prescription he lost before reaching the pharmacy. His next visit is in 6 weeks. Nothing was documented.

**Dr. Priya, 34, general physician, 50-bed clinic, Nagpur.**
She sees 80 patients a day. Every consultation starts the same: "What's the problem? Since when? Any medicines?" — 3 minutes of questions she has already asked 20,000 times. She has no way to record consultations, no AI peer to pressure-test her differential, and no system that produces a legible, retrievable prescription.

### The numbers

| Pain | Data |
|---|---|
| Avg. Indian OPD consultation | **2–5 minutes** (NMC survey, 2023) |
| Repeat intake questions per visit | **3–5 mins** — up to 100% of consultation time for short visits |
| Prescription errors from illegibility | **1.5 million adverse drug events/year** globally attributable to handwriting |
| Patients who lose paper prescriptions | **~40%** before filling them (internal survey, urban clinics) |
| Doctors with access to a clinical peer / second opinion | **< 5%** in tier-2/3 cities |

### Root causes
1. **No structured pre-visit intake** — every visit starts from zero
2. **No audio capture or transcription** — insights from the consultation evaporate
3. **No AI clinical peer** — doctors work alone under time pressure
4. **Paper prescriptions** — unreadable, losable, untrackable
5. **No patient-accessible health record** — patients can't see their own diagnosis or medication history

Twain is a **two-sided platform** — one app for patients, one for doctors — connected through a shared backend and AI layer.

### Patient side
- Signs in and begins an **AI-guided intake chat** (Twain AI) that systematically collects chief complaint, onset, duration, severity, associated symptoms, triggers, history, medications, and allergies.
- When ready, taps **"Done"** — Twain AI summarises the intake into structured JSON for the doctor.
- Receives a **4-digit patient code** to share with the doctor at the clinic.
- After the visit, views their **diagnosis summary** and **signed prescription PDF** directly in the app.

### Doctor side
- Signs in and **draws their signature** once (stored securely).
- Enters the **patient code** to pull up the structured intake summary instantly.
- Records the consultation audio — **Qubrid Whisper** transcribes it in real time.
- **Brain AI** (Claude Sonnet) analyses the transcript + intake and surfaces: clean transcript, clinical findings, differential diagnosis, recommendations, and a patient-friendly diagnosis.
- Chats with Brain AI as a **clinical peer** ("reduce amoxicillin to 5 days", "is metformin safe here?").
- Taps **"Draft Rx"** — AI generates a complete Indian prescription draft.
- Reviews, edits, and **signs** — a PDF is generated with their signature embedded and pushed to the patient instantly.

---

## How It Works

```
Patient                           Backend (FastAPI)                    Doctor
───────                           ─────────────────                    ──────
Sign in ──────────────────────► POST /api/auth/register
                                       │
                                  Creates PatientProfile
                                  Assigns 4-digit code ◄─────────────── "Your code: 4821"
                                       │
Start consultation ──────────► POST /api/patient/consultations
                                       │
                                  Claude: "What brings you in today?"
                                       │
Patient chats (4-8 turns) ───► POST /api/patient/consultations/{id}/messages
                                       │
                                  Claude asks follow-up questions
                                       │
"Done" ──────────────────────► POST /api/patient/consultations/{id}/finalize-intake
                                       │
                                  Claude summarises → intake_summary_json
                                  Status: intake_done
                                       │
                                       │◄──────── POST /api/doctor/consultations/fetch-by-code {"patient_code": 4821}
                                       │
                                  Binds doctor ↔ consultation
                                  Status: in_consultation
                                       │
                                       │◄──────── POST /api/doctor/consultations/{id}/recording (audio file)
                                       │
                                  Qubrid Whisper → transcript
                                  Claude → analysis_json
                                  (clean transcript, differential, diagnosis, action items)
                                       │
                                       │◄──────── POST /api/doctor/consultations/{id}/brain/messages
                                       │
                                  Claude (Brain AI) answers doctor's clinical questions
                                       │
                                       │◄──────── POST /api/doctor/consultations/{id}/rx/draft
                                       │
                                  Claude drafts prescription JSON
                                  (medicines, labs, lifestyle, advice, follow-up)
                                       │
                                       │◄──────── POST /api/doctor/consultations/{id}/rx/sign
                                       │
                                  WeasyPrint renders signed PDF
                                  Stored as bytea in Postgres
                                       │
Patient views ◄──────────────── GET /api/prescriptions/{id}/pdf
```

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         Railway Cloud                           │
│                                                                 │
│  ┌──────────────────────────┐    ┌──────────────────────────┐  │
│  │   FastAPI Backend        │    │   PostgreSQL 16           │  │
│  │   Python 3.12            │◄──►│   (Railway Plugin)        │  │
│  │   Port: $PORT            │    │   Port: 5432              │  │
│  │                          │    │                           │  │
│  │  ┌────────────────────┐  │    │  Tables:                  │  │
│  │  │ Routers            │  │    │  • users                  │  │
│  │  │ • /api/auth        │  │    │  • patient_profiles       │  │
│  │  │ • /api/profile     │  │    │  • doctor_profiles        │  │
│  │  │ • /api/patient     │  │    │  • consultations          │  │
│  │  │ • /api/doctor      │  │    │  • chats                  │  │
│  │  │ • /api/prescriptions│  │    │  • chat_messages          │  │
│  │  └────────────────────┘  │    │  • audio_recordings       │  │
│  │                          │    │  • prescriptions          │  │
│  │  ┌────────────────────┐  │    │  • prescription_pdfs      │  │
│  │  │ AI Clients         │  │    └──────────────────────────┘  │
│  │  │ • ClaudeClient     │  │                                  │
│  │  │ • QubridClient     │  │                                  │
│  │  └────────────────────┘  │                                  │
│  └──────────────────────────┘                                  │
└─────────────────────────────────────────────────────────────────┘

┌──────────────────────┐         ┌──────────────────────┐
│   Vercel (Patient)   │         │   Vercel (Doctor)    │
│   Flutter Web PWA    │◄───────►│   Flutter Web PWA    │
│   twain-patient      │  REST   │   twain-doctor       │
│   .vercel.app        │         │   .vercel.app        │
└──────────────────────┘         └──────────────────────┘

┌──────────────────────┐         ┌──────────────────────┐
│   Anthropic Cloud    │         │   Qubrid Platform    │
│   Claude Sonnet 4.6  │         │   Whisper Large v3   │
│   (AI reasoning)     │         │   (transcription)    │
└──────────────────────┘         └──────────────────────┘
```

---

## Tech Stack

### Backend
| Layer | Technology | Why |
|---|---|---|
| Web framework | **FastAPI** 0.118+ | Async-first, auto OpenAPI docs, Pydantic validation |
| Language | **Python 3.12** | Modern type hints, `match` statements, performance |
| ORM | **SQLAlchemy 2.0** (async) | Fully async, type-mapped models, no N+1 foot-guns |
| Database driver | **asyncpg** | Native async PostgreSQL driver, fastest available |
| Migrations | **Alembic** | Schema versioning with async engine support |
| Auth | **PyJWT + passlib/bcrypt** | Stateless JWT tokens, bcrypt password hashing |
| PDF generation | **WeasyPrint + Jinja2** | HTML → PDF with embedded base64 signature PNG |
| HTTP client | **httpx** (async) | Used for Qubrid API calls |
| Container | **Python 3.12-slim** | Minimal Debian image with WeasyPrint system deps |

### Frontend (both apps)
| Layer | Technology | Why |
|---|---|---|
| Framework | **Flutter 3.41** | Single codebase for web + Android + iOS |
| State management | **Riverpod** | Compile-safe dependency injection, async providers |
| Routing | **GoRouter** | Declarative URL-based routing with redirect guards |
| HTTP client | **Dio** | Interceptors for automatic JWT injection |
| Secure storage | **flutter_secure_storage** | OS keychain for token persistence |
| Shared code | **twain_core package** | Theme, API client, auth state, shared widgets |

### AI / External Services
| Service | Model | Usage |
|---|---|---|
| **Anthropic Claude** | claude-sonnet-4-6 | Intake chat, intake summarisation, consultation analysis, Brain AI chat, Rx drafting |
| **Qubrid Whisper** | openai/whisper-large-v3 | Audio transcription of doctor-patient consultation recordings |

### Infrastructure
| Service | Provider | Purpose |
|---|---|---|
| Backend API | **Railway** | Container-based deployment, auto-deploy on push |
| Database | **Railway Postgres** | Managed PostgreSQL 16, auto-injects `DATABASE_URL` |
| Patient PWA | **Vercel** | Static Flutter web build |
| Doctor PWA | **Vercel** | Static Flutter web build |

---

## AI & Intelligence Layer

### 1. Twain AI (Intake Assistant)
**Model:** Claude Sonnet 4.6 · **Effort:** low (no extended thinking) · **Max tokens:** 400/turn

Twain AI is a clinical intake chatbot that asks one focused question per turn. It covers:
- Chief complaint, onset, duration, severity (1–10)
- Associated symptoms and triggers
- Past history, chronic conditions
- Current medications and drug allergies
- Red-flag symptom detection (chest pain, stroke signs, severe bleeding → urgent care prompt)

Strict guardrails: never diagnoses, never prescribes, never gives treatment advice. Redirects all such questions to "your doctor will discuss this with you."

**Output:** Structured JSON intake summary (`chat_json` call):
```json
{
  "chief_complaint": "...",
  "onset": "...",
  "duration": "...",
  "severity_1_10": 7,
  "associated_symptoms": ["..."],
  "triggers": "...",
  "history": "...",
  "current_medications": ["..."],
  "allergies": ["..."],
  "red_flags": [],
  "patient_summary": "Patient reports a 3-day history of..."
}
```

### 2. Brain AI (Clinical Analysis)
**Model:** Claude Sonnet 4.6 · **Effort:** low · **Max tokens:** 3000

Activated after recording upload. Receives intake summary + raw transcript. Returns:
```json
{
  "clean_transcript": "Doctor: ...\nPatient: ...",
  "detailed_summary": {
    "chief_complaint": "...",
    "findings": "...",
    "differential": ["..."],
    "assessment": "...",
    "recommendations": ["..."],
    "red_flags": []
  },
  "patient_diagnosis": "Plain English for the patient...",
  "patient_action_items": ["Take medication as prescribed...", "..."]
}
```

### 3. Brain AI Chat (Clinical Peer)
**Model:** Claude Sonnet 4.6 · **Max tokens:** 600/turn

Doctors can chat with Brain AI as a senior Indian physician peer — asking clinical questions, requesting drug interaction checks, or refining the prescription ("reduce amoxicillin to 5 days"). All chat history is fed into the next Rx draft call so refinements are automatically incorporated.

### 4. Rx Drafter
**Model:** Claude Sonnet 4.6 · **Max tokens:** 2000

Uses intake summary + transcript + analysis + all Brain AI chat messages to draft a complete Indian prescription:
```json
{
  "medicines": [
    {
      "generic_name": "Amoxicillin",
      "brand_name": "Mox",
      "dose": "500 mg",
      "route": "oral",
      "frequency": "1-0-1 after food",
      "duration": "5 days"
    }
  ],
  "labs": ["CBC", "CRP"],
  "lifestyle": ["Rest for 2 days", "Increase fluid intake"],
  "advice": "...",
  "follow_up": "Review in 7 days"
}
```

---

## Data Model

```
users (id UUID PK, email, password_hash, role: patient|doctor)
  │
  ├── patient_profiles (user_id FK, patient_code INT UNIQUE, full_name, dob, sex,
  │                     phone, allergies, conditions, current_meds)
  │
  └── doctor_profiles  (user_id FK, full_name, specialty, registration_no,
                        clinic_name, clinic_address, phone, signature_png BYTEA)

consultations (id UUID PK, patient_id FK, doctor_id FK nullable, chat_id FK nullable,
               status: intake_pending|intake_done|in_consultation|closed,
               intake_summary_json JSONB, analysis_json JSONB,
               created_at, intake_done_at, started_at, closed_at)

chats (id UUID PK, patient_id FK, doctor_id FK)
  UNIQUE (patient_id, doctor_id)

chat_messages (id UUID PK, consultation_id FK, sender_role, content_type,
               content TEXT, payload JSONB,
               visibility: both|doctor_only, created_at)

audio_recordings (id UUID PK, consultation_id FK, audio_bytes BYTEA,
                  mime_type, duration_s, created_at)

prescriptions (id UUID PK, consultation_id FK, items_json JSONB,
               advice TEXT, follow_up TEXT, signed_at, created_at)

prescription_pdfs (id UUID PK, prescription_id FK UNIQUE, pdf_bytes BYTEA, created_at)
```

### Message types (`content_type`)
| Type | Sender | Visibility | Description |
|---|---|---|---|
| `intake_q` | `twain_ai` | both | Twain AI intake question |
| `intake_a` | `patient` | both | Patient's answer |
| `transcript` | `system` | doctor_only | Raw transcription text |
| `summary_full` | `brain_ai` | doctor_only | Full clinical analysis (payload) |
| `diagnosis` | `brain_ai` | both | Patient-friendly diagnosis |
| `brain_text` | `doctor` / `brain_ai` | doctor_only | Clinical peer chat |
| `rx_draft` | `brain_ai` | doctor_only | Prescription draft (payload) |

### Consultation status machine
```
intake_pending ──► intake_done ──► in_consultation ──► closed
     │                                                    ▲
     └────────────────────── cancel ─────────────────────┘
```

---

## API Reference

### Auth
| Method | Path | Description |
|---|---|---|
| `POST` | `/api/auth/register` | Register as patient or doctor |
| `POST` | `/api/auth/login` | Login, returns JWT |
| `GET` | `/api/me` | Current user profile |

### Profile
| Method | Path | Role | Description |
|---|---|---|---|
| `GET` | `/api/profile/patient` | patient | Get patient profile |
| `PUT` | `/api/profile/patient` | patient | Update patient profile |
| `GET` | `/api/profile/doctor` | doctor | Get doctor profile |
| `PUT` | `/api/profile/doctor` | doctor | Update doctor profile |
| `POST` | `/api/profile/doctor/signature` | doctor | Upload signature PNG |

### Patient
| Method | Path | Description |
|---|---|---|
| `GET` | `/api/patient/active-consultation` | Check for active consultation |
| `POST` | `/api/patient/consultations` | Start new consultation + seed Twain AI opener |
| `GET` | `/api/patient/consultations` | List all consultations (with diagnosis) |
| `POST` | `/api/patient/consultations/{id}/cancel` | Cancel intake-stage consultation |
| `GET` | `/api/patient/consultations/{id}/messages` | Get visible messages |
| `POST` | `/api/patient/consultations/{id}/messages` | Send message → get AI reply |
| `POST` | `/api/patient/consultations/{id}/finalize-intake` | Summarise intake → `intake_done` |

### Doctor
| Method | Path | Description |
|---|---|---|
| `POST` | `/api/doctor/consultations/fetch-by-code` | Bind consultation via patient code |
| `GET` | `/api/doctor/consultations` | List doctor's consultations |
| `GET` | `/api/doctor/consultations/{id}` | Get full consultation detail |
| `GET` | `/api/doctor/consultations/{id}/messages` | All messages (no visibility filter) |
| `POST` | `/api/doctor/consultations/{id}/recording` | Upload audio → transcribe → analyse |
| `POST` | `/api/doctor/consultations/{id}/brain/messages` | Chat with Brain AI |
| `POST` | `/api/doctor/consultations/{id}/rx/draft` | AI-draft a prescription |
| `POST` | `/api/doctor/consultations/{id}/rx/sign` | Sign Rx → generate PDF |
| `POST` | `/api/doctor/consultations/{id}/close` | Close consultation |

### Prescriptions
| Method | Path | Description |
|---|---|---|
| `GET` | `/api/prescriptions` | Current user's signed prescriptions |
| `GET` | `/api/prescriptions/{id}/pdf` | Download signed PDF |

---

## Project Structure

```
twain/
│
├── backend/                    FastAPI service
│   ├── app/
│   │   ├── main.py             App factory, CORS, router registration
│   │   ├── config.py           Pydantic settings (DATABASE_URL normalisation)
│   │   ├── auth.py             JWT creation/validation, role guards
│   │   ├── db.py               Async SQLAlchemy engine + session factory
│   │   ├── models.py           All ORM models (users, consultations, etc.)
│   │   ├── claude_client.py    Anthropic SDK wrapper (stream + drain pattern)
│   │   ├── qubrid_client.py    Qubrid Whisper (raw httpx, not OpenAI SDK)
│   │   ├── pdf.py              WeasyPrint PDF renderer
│   │   ├── prompts.py          All Claude system prompts
│   │   └── routers/
│   │       ├── auth.py         Register, login, /me
│   │       ├── profile.py      Patient/doctor profile CRUD + signature upload
│   │       ├── patient.py      Intake chat, consultation lifecycle
│   │       ├── doctor.py       Recording, Brain AI, Rx draft/sign, close
│   │       └── prescriptions.py List Rx + PDF download
│   ├── alembic/                Database migrations
│   │   └── versions/
│   │       ├── 001_initial.py
│   │       ├── 002_auth.py     users, patient_profiles, doctor_profiles
│   │       └── 003_consult.py  chats, consultations, messages, audio, Rx, PDF
│   ├── templates/
│   │   └── prescription.html   Jinja2 + WeasyPrint PDF template
│   ├── start.sh                Entrypoint: alembic upgrade → uvicorn
│   ├── Containerfile           Docker image (python:3.12-slim + WeasyPrint deps)
│   ├── pyproject.toml          Dependencies
│   └── .env.example
│
├── apps/
│   ├── patient/                Flutter patient PWA
│   │   └── lib/
│   │       ├── main.dart       ProviderScope with apiClientProvider override
│   │       ├── core/router.dart GoRouter with auth redirect guard
│   │       └── features/
│   │           ├── home/       Dashboard + patient code display
│   │           ├── consult/    Intake chat + consultation history
│   │           └── prescription/ Prescription list + PDF viewer
│   │
│   └── doctor/                 Flutter doctor PWA
│       └── lib/
│           ├── main.dart
│           ├── core/router.dart
│           └── features/
│               ├── home/       Dashboard + patient code entry
│               ├── consult/    Consultation screen (recording, Brain AI, Rx editor)
│               └── profile/    Doctor profile + signature pad
│
├── packages/
│   └── twain_core/             Shared Flutter package
│       └── lib/
│           ├── api/
│           │   ├── api_client.dart    Dio client + JWT interceptor + token storage
│           │   ├── consult_api.dart   All consultation API calls + Riverpod providers
│           │   └── profile_api.dart   Profile API calls
│           ├── auth/
│           │   └── auth_notifier.dart AuthState + AuthNotifier + authProvider
│           ├── theme/                 Design tokens, typography, TTheme
│           ├── widgets/               Shared UI components
│           └── screens/
│               └── login_screen.dart  Shared login/register screen
│
├── compose.yaml                podman-compose: backend + postgres (local dev)
├── railway.toml                Railway deployment config
└── README.md
```

---

## Local Development

### Prerequisites
- Python 3.12+
- Flutter 3.41+
- Podman + podman-compose (or Docker + docker-compose)

### 1. Start backend + database

```bash
# Copy and fill in your API keys
cp backend/.env.example backend/.env
# Edit backend/.env — add ANTHROPIC_API_KEY and QUBRID_API_KEY

podman-compose up -d
# Backend: http://localhost:9494
# OpenAPI docs: http://localhost:9494/docs
```

### 2. Patient app

```bash
cd apps/patient
flutter pub get
flutter run -d web-server --web-port 7474
# Open http://localhost:7474
```

### 3. Doctor app

```bash
cd apps/doctor
flutter pub get
flutter run -d web-server --web-port 7575
# Open http://localhost:7575
```

### Local ports

| Service | Port |
|---|---|
| Backend API | 9494 |
| PostgreSQL | 5442 |
| Patient PWA | 7474 |
| Doctor PWA | 7575 |

---

## Deployment

### Live URLs

| Service | URL |
|---|---|
| Backend API | `https://twain-production.up.railway.app` |
| Patient PWA | `https://twain-patient.vercel.app` |
| Doctor PWA | `https://web-zeta-ten-42.vercel.app` |

### Backend (Railway)

Railway auto-deploys on every push to `main`. The `railway.toml` at the repo root controls the build:

```toml
[build]
builder = "dockerfile"
dockerfilePath = "backend/Containerfile"

[deploy]
healthcheckPath = "/health"
healthcheckTimeout = 120
```

`start.sh` is the container entrypoint:
```sh
alembic upgrade head   # run pending migrations
exec uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}
```

**Railway environment variables required:**

| Variable | Description |
|---|---|
| `DATABASE_URL` | Auto-injected by Railway Postgres plugin (`postgresql://...` — normalised to `asyncpg` automatically) |
| `JWT_SECRET` | Long random string — generate with `openssl rand -hex 32` |
| `ANTHROPIC_API_KEY` | From console.anthropic.com |
| `QUBRID_API_KEY` | From platform.qubrid.com |
| `CORS_ORIGINS` | Comma-separated Vercel URLs, or `*` for development |
| `APP_ENV` | `production` |

### Flutter PWAs (Vercel)

```bash
# Build patient
cd apps/patient
flutter build web --release --dart-define=API_BASE_URL=https://twain-production.up.railway.app

# Build doctor
cd apps/doctor
flutter build web --release --dart-define=API_BASE_URL=https://twain-production.up.railway.app

# Deploy via Vercel CLI
vercel deploy build/web --yes --token <VERCEL_TOKEN>
```

### Android APKs

Requires Android SDK (Android Studio 2024+).

```bash
# Patient APK
cd apps/patient
flutter build apk --debug --dart-define=API_BASE_URL=https://twain-production.up.railway.app
# Output: build/app/outputs/flutter-apk/app-debug.apk

# Doctor APK
cd apps/doctor
flutter build apk --debug --dart-define=API_BASE_URL=https://twain-production.up.railway.app
# Output: build/app/outputs/flutter-apk/app-debug.apk
```

---

## Environment Variables

### Backend `.env`

```env
APP_ENV=production
DEBUG=false

# Postgres — Railway injects this automatically
DATABASE_URL=postgresql://...          # auto-normalised to postgresql+asyncpg://

# Auth
JWT_SECRET=<openssl rand -hex 32>
JWT_ALGORITHM=HS256
JWT_EXPIRE_HOURS=24

# CORS — your Vercel URLs
CORS_ORIGINS=https://twain-patient.vercel.app,https://twain-doctor.vercel.app

# Claude
ANTHROPIC_API_KEY=sk-ant-...
CLAUDE_CHAT_MODEL=claude-sonnet-4-6
CLAUDE_EFFORT=low

# Qubrid Whisper
QUBRID_API_KEY=k_...
QUBRID_BASE_URL=https://platform.qubrid.com/api/v1/qubridai
QUBRID_WHISPER_MODEL=openai/whisper-large-v3
```

---

## Known Issues & Solutions

### 1. `ModuleNotFoundError: No module named 'psycopg2'`
**Cause:** Railway's Postgres plugin injects `DATABASE_URL` as `postgresql://` (psycopg2 dialect), but the app uses `asyncpg`.
**Solution:** `config.py` normalises the URL automatically:
```python
@property
def async_database_url(self) -> str:
    url = self.database_url
    if url.startswith("postgres://"):
        url = url.replace("postgres://", "postgresql+asyncpg://", 1)
    elif url.startswith("postgresql://"):
        url = url.replace("postgresql://", "postgresql+asyncpg://", 1)
    return url
```

### 2. Railway build: `pyproject.toml not found`
**Cause:** Railway's build context is the repo root, but `COPY . /app/` in the Containerfile puts `pyproject.toml` at `/app/backend/pyproject.toml`.
**Solution:** Changed to `COPY backend/ /app/` in the Containerfile.

### 3. Qubrid transcription 404
**Cause:** The Qubrid API endpoint is `/audio/transcribe` (singular). The OpenAI SDK hits `/audio/transcriptions` (plural).
**Solution:** `qubrid_client.py` uses raw `httpx` instead of the OpenAI SDK.

### 4. Health check timeout during migration
**Cause:** Alembic migrations run as part of the start command, delaying uvicorn startup beyond the health check window.
**Solution:** Increased `healthcheckTimeout` to `120` seconds in `railway.toml`.

---

## Storage Note

All binary blobs — audio recordings, prescription PDFs, doctor signatures — are stored as `bytea` columns in PostgreSQL. This is appropriate for hackathon scale (tens of consultations). At production scale these would move to object storage (S3 / Cloudflare R2 / Cloudinary); the storage layer is isolated in the models to make that migration easy.

---

## Privacy, Safety & Ethics

**Privacy policy:** Twain collects only the minimum clinical data necessary. No PII is shared with third-party AI services beyond what is required for the consultation. Audio is transcribed server-side and only the text transcript is persisted — raw audio is not retained after transcription.

**Safety guardrails:** Twain AI and Brain AI are hard-coded to never diagnose, never prescribe, and never give treatment advice. Every prescription is a **doctor-reviewed draft** — the AI assists, the doctor decides. Red-flag symptom detection (chest pain, stroke, severe bleeding) triggers an urgent-care prompt.

**Data security:** Passwords are bcrypt-hashed. JWT tokens expire in 24 hours. All data encrypted at rest via Railway managed PostgreSQL. HTTPS enforced on all endpoints.

**Bias mitigation:** Prompts are scoped to Indian clinical context (NMC/CDSCO). Indian generic and brand drug names used to avoid prescribing inaccessible medications.

**Consent:** Patients initiate every consultation. Audio upload is an explicit doctor action — no passive recording.

**Misuse prevention:** Role-based access control (JWT `role` claim). Patients cannot access doctor-only messages. Prescriptions are only downloadable by the patient or the signing doctor.

---

## Sustainability & Roadmap

### How this continues to exist

| Phase | Plan |
|---|---|
| **Now (MVP)** | Free / grant-funded. Prove the loop works with real doctors and patients. |
| **3 months** | SaaS subscription for clinics — ₹999/month per doctor (< cost of one missed prescription error). |
| **6 months** | Insurance integration — anonymised, aggregated diagnosis data as a signal for underwriting. |
| **12 months** | Hospital EMR integrations (Epic, Practo, mfine). White-label for telemedicine platforms. |

### Moat
- **Network effect:** Each consultation improves intake quality (prompts are tuned on real transcripts).
- **Data flywheel:** De-identified consultation transcripts + outcomes → fine-tuned models for Indian clinical contexts — a dataset no one else has.
- **Doctor trust:** Once a doctor uses the signature + PDF flow, switching cost is high (their prescription history lives here).

---

## GitHub Topics

`healthcare` `ai` `flutter` `fastapi` `india` `medical` `llm` `anthropic` `claude` `prescription` `telemedicine` `whisper` `riverpod` `postgresql`

> Add these in the GitHub repo settings → **Topics** to improve discoverability.

---

## Licence

MIT — see [LICENSE](./LICENSE)

