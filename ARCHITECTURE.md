# LAMBA Architecture

This document summarizes the architecture defined in the project plans (`Новый документ.pdf` and `Копия ламба (6).pdf`) and reflects the intended MVP structure.

## 1. System Overview

LAMBA is planned as a layered product:

- Mobile App (client)
- Go Backend API (business logic + orchestration)
- PostgreSQL (operational data)
- External ML/Predictive Service
- AI Agent + LLM layer
- RAG knowledge layer for technical support content

The backend is the central API coordinator between the mobile app, ML service, and AI assistant.

## 2. Core Architecture

### 2.1 Target topology

```text
Mobile App
   |
Backend API (Go)
   |
PostgreSQL
   |
   +-- External ML / Prediction Service
   +-- Chat Service / AI Agent Layer
```

### 2.2 Component roles

- Backend API:
  - owns authentication, vehicle data ownership, lifecycle event ingestion, predictions orchestration, chat orchestration, and API contracts
- PostgreSQL:
  - stores users, vehicles, events, parts, predictions, and chat history
- ML Service:
  - computes maintenance predictions from assembled vehicle profile + events + parts
- AI Agent:
  - reads only from backend tools (vehicle, timeline, parts, predictions) and calls backend-defined actions
- LLM:
  - produces conversational responses from backend data and model outputs
- RAG layer:
  - retrieval over maintenance guides, known issues, recalls, complaint summaries, and DTC-like knowledge

## 3. Backend Architecture

Planned Go backend module layout:

- `cmd/api/main.go`
- `internal/config`
- `internal/db`
- `internal/domain` (entities)
- `internal/dto`
- `internal/repository`
- `internal/service`
- `internal/handler`
- `internal/mlclient`
- `internal/agent` (AI agent integration)
- `internal/middleware`
- `internal/router`
- migrations and containerization (`Dockerfile`, `docker-compose.yml`, `go.mod`)

### 3.1 Domain model

Primary entities planned:

- User
- Vehicle
- VehicleEvent
- Part
- Prediction
- ChatMessage
- DigitalTwin (aggregated projection)

### 3.1.1 Main entities

Below are the baseline entity shapes to be implemented in MVP.

- User
  - `id: int64` (PK)
  - `email: string` (unique, required)
  - `password_hash: string` (required)
  - `created_at: timestamp`
  - Owns many `Vehicle` records.

- Vehicle
  - `id: int64` (PK)
  - `user_id: int64` (FK -> users, delete cascade)
  - `brand: string`
  - `model: string`
  - `year: int`
  - `vin: string?`
  - `mileage_km: int`
  - `created_at: timestamp`
  - Has many `VehicleEvent`, `Part`, `Prediction`, and `ChatMessage` rows.

- VehicleEvent
  - `id: int64` (PK)
  - `vehicle_id: int64` (FK -> vehicles, delete cascade)
  - `type: string` (`trip`, `refuel`, `repair`, `service`)
  - `title: string`
  - `description: string?`
  - `mileage_km: int`
  - `cost: numeric(12,2)` (default `0`)
  - `event_date: timestamp`
  - `created_at: timestamp`
  - Supports timeline building and feature generation for ML.

- Part
  - `id: int64` (PK)
  - `vehicle_id: int64` (FK -> vehicles, delete cascade)
  - `name: string`
  - `category: string?`
  - `installed_at_mileage_km: int?`
  - `last_service_mileage_km: int?`
  - `created_at: timestamp`
  - Represents serviceable component state for prediction and maintenance history.

- Prediction
  - `id: int64` (PK)
  - `vehicle_id: int64` (FK -> vehicles, delete cascade)
  - `part_name: string`
  - `risk_level: string` (`low|medium|high`)
  - `remaining_km: int?`
  - `probability: decimal(5,4)?`
  - `recommendation: string`
  - `source: string` (`ml_service`)
  - `model_version: string?`
  - `created_at: timestamp`
  - Stores outputs from ML (or internal updates) and powers twin/chat responses.

- ChatMessage
  - `id: int64` (PK)
  - `vehicle_id: int64` (FK -> vehicles, delete cascade)
  - `role: string` (`user|assistant|system`)
  - `message: string`
  - `created_at: timestamp`
  - Used for conversation history and auditability.

- DigitalTwin
  - Not stored as a single physical table in MVP.
  - Computed by aggregator from:
    - Vehicle
    - VehicleEvents/Timeline
    - Parts
    - Last Prediction set
    - AI-generated summary/recommendations
  - Returned via `GET /api/vehicles/:id/twin`.

### 3.2 Core data model (MVP)

Minimum required tables:

- `users`
- `vehicles`
- `vehicle_events`
- `parts`
- `predictions`
- `chat_messages`

### 3.3 Backend responsibility boundaries

- Store and validate all user/vehicle lifecycle data.
- Keep digital twin state synchronized after each action.
- Expose API for auth, vehicles, events, timeline, parts, predictions, digital twin, and chat.
- Do not run ML-only calculations directly in DB/business core for predictions.
- Persist model outputs and serve them back to clients.
- Persist and provide audit/history for chat interactions.

## 4. API Contracts (!!!TO BE UPDATED!!!)

### 4.1 MVP endpoints (selected)

- Health:
  - `GET /health`
- Auth:
  - `POST /api/auth/register`
  - `POST /api/auth/login`
  - `GET /api/me`
- Vehicles:
  - `POST /api/vehicles`
  - `GET /api/vehicles`
  - `GET /api/vehicles/:id`
  - `PATCH /api/vehicles/:id`
  - `DELETE /api/vehicles/:id`
- Events / Timeline:
  - `POST /api/vehicles/:id/events`
  - `GET /api/vehicles/:id/events`
  - `GET /api/vehicles/:id/timeline`
- Parts:
  - `POST /api/vehicles/:id/parts`
  - `GET /api/vehicles/:id/parts`
  - `PATCH /api/vehicles/:id/parts/:partId`
  - `DELETE /api/vehicles/:id/parts/:partId`
- Predictions:
  - `GET /api/vehicles/:id/predictions`
  - `POST /api/vehicles/:id/predictions/refresh`
  - `POST /api/internal/vehicles/:id/predictions`
- Chat:
  - `POST /api/vehicles/:id/chat`
  - `GET /api/vehicles/:id/chat/history`
- Digital twin:
  - `GET /api/vehicles/:id/twin`

### 4.2 Prediction refresh flow

1. Mobile requests refresh
2. Backend loads vehicle, events, parts
3. Backend builds ML request
4. Backend calls ML service (`POST /predict`)
5. ML service returns predictions
6. Backend saves predictions
7. Backend returns normalized result to mobile app

### 4.3 Backend <-> ML contract

- Backend sends:
  - vehicle profile
  - recent events
  - active parts and service state
- ML service returns:
  - model version
  - per-part risk/remaining/probability/recommendation payload
- Internal endpoint allows ML side pushing saved results:
  - `POST /api/internal/vehicles/:id/predictions`

## 5. AI, LLM, and RAG

- AI assistant is treated as a separate layer that uses backend tools only.
- AI Agent does not directly mutate DB; it issues actions through backend APIs/tools.
- Planned tool set includes:
  - get vehicle profile
  - get timeline
  - add events
  - get predictions
  - cost/fuel/maintenance reporting
  - risk explanation and recommendation helpers
- LLM should provide:
  - intent detection
  - entity extraction
  - tool calling decisions
  - user-friendly maintenance explanations
- RAG MVP uses PostgreSQL + pgvector.
- RAG sources include repair manuals/known issues/recalls/complaints/diagnostic references.

## 6. Frontend Architecture Plan

Planned mobile architecture (from project plan): MVVM-based architecture with clear service/repository boundaries.

Planned frontend workstreams:

1. Foundation
   - architecture and wireframes
   - navigation and base UI
2. UI shell + API integration
   - SwiftUI implementation
   - onboarding/navigation
   - Backend API contract wiring
3. Core screens
   - Dashboard
   - Vehicle profile
   - timeline
   - maintenance and trip/refuel/service history
   - predictive signals in dashboard
4. AI Assistant screen
   - chat UI and event history
   - backend chat API integration
5. Analytics and recommendations
   - analytics summaries
   - recommendation presentation
6. MVP stabilization
   - polishing and readiness improvements

## 7. Risks / design notes to keep in mind

- Prediction pipeline depends on stable event/part data quality.
- Ensure strict boundaries: only backend owns data writes; AI/LLM should be mediated.
- Keep digital twin response deterministic and synchronized with underlying events/parts/predictions.
- Plan for explainability and fallback when ML/LLM returns low-confidence outputs.
