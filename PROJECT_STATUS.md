# NiVuba — Project Status & Continuation Plan

_Last updated: 2026-11-06 (Milestones A and B done)._

This file records where each service stands, what is broken, and what to do next,
so work can resume without re-auditing the codebase.

---

## 1. Snapshot

| Service | Stack | State |
|---|---|---|
| `nivuba-core` | NestJS 10, TypeORM, Bull, Postgres | **Works end to end.** It has auth, RBAC, organization-scoped access, loan submission, async evaluation with a single configurable decision policy, a status-transition guard, and audit. Unit tests cover the decision and loan flow. |
| `nivuba-ml` | FastAPI, scikit-learn RF pipeline | **Builds and runs offline** (the model is baked into the image). The score still barely depends on the applicant: it uses a third-party model, and most inputs are hardcoded (Milestone C). |
| `nivuba-ui` | Vite + React + react-router, shadcn/ui, Zustand | **Connected to the real API.** It uses the 0–1000 credit score. Documents and notifications are still mock data. |
| Root | docker-compose + Makefile | `make up` builds the full stack from a clean clone, and `make smoke` verifies it end to end. |

The three services are **git submodules**. Quick start:

```bash
make up      # submodules + .env + build + start, waits for health checks
make smoke   # end-to-end check against the running stack
make test    # offline: core unit tests + build, UI typecheck + build
```

### Demo accounts (seeded by migration `BranchesAndDataPool`)

| Role | Email | Password |
|---|---|---|
| Admin | `platform-admin@nivuba.test` (and `SEED_ADMIN_EMAIL`) | `SEED_ADMIN_PASSWORD` (default `Admin@123456!`) |
| Loan officer (org *n*) | `officer1@nivuba.test` … `officer6@nivuba.test` | `Officer@123456!` |
| Applicant | `client1@nivuba.test` … `client120@nivuba.test` | `Applicant@123456!` |

`client{i}` belongs to organization `((i-1) mod 6) + 1`, so `client1` and `officer1` share an organization.
These are demo credentials. Disable that seed before any real deployment (see open items).

### Request flow (as built)

```
UI POST /api/v1.0/loan-applications {requestedAmount, termMonths}
 → core saves PENDING (with org + branch), enqueues `evaluate` (jobId = application id, 5 attempts, exponential backoff)
 → processor: skip if already decided by an officer; set UNDER_REVIEW
 → POST ML /predict → {score 0–1000 (higher = safer), shap_values}
 → DecisionService: APPROVED if score ≥ DECISION_MIN_SCORE (700) and amount/term ≤ DECISION_MAX_PAYMENT_TO_INCOME (35%) × salary;
                    MANUAL_REVIEW (stays UNDER_REVIEW) if no salary; otherwise REJECTED with every failed rule in the reason
 → conditional write (only if still PENDING/UNDER_REVIEW) → notify + audit
 → ML down: the job throws and Bull retries; after the last attempt it stays UNDER_REVIEW for a human (audited)
```

---

## 2. Done

### Milestone A — "Clean clone runs"
- **ML image builds from a clean clone.** The model is downloaded from HF Hub at *build* time (`nivuba-ml/Dockerfile`), and the app prefers that local copy, so startup needs no network.
- **`.env` untracked** in root and `nivuba-ui`, and ignored (`.env.example` kept). ⚠️ The files still exist in **git history**. Rotate any value that was ever real.
- **`npm start` no longer drops the database.** That sequence is now an explicit `npm run db:reset`.
- **CLI data source no longer uses `synchronize: true`.** It used to race the migrations, so migrations now own the schema.
- **Root `Makefile`** (`init`, `up`, `down`, `reset`, `logs`, `ps`, `test`, `smoke`) and **`scripts/smoke.sh`**, an end-to-end check with about 30 assertions.
- Demo data was already seeded by a migration and is documented above.
- **Verified on 2026-11-06** on a clean Docker build with an empty database: `make smoke` passes all 24 checks. An ML outage was also simulated (4 failed attempts, then a successful 5th that notified the applicant and wrote the audit entry).
- Dropped the obsolete `version:` key from compose. `DECISION_*` settings are wired through compose and `.env.example`.

### Milestone B — "Decisions are trustworthy"
- **One decision policy:** `src/loan-applications/decision/decision.service.ts`. Thresholds come from env. A missing salary now leads to manual review instead of a silent reject.
- **One evaluation path.** The duplicate `ml.inference.queue` processor (which skipped notifications and audit) is gone. Retries use Bull's own attempts and backoff, and failures are handed to a human.
- **No more lost updates.** Automated results never overwrite an officer's decision, and manual updates use optimistic concurrency (409 on conflict).
- **Status-transition guard** (`loan-status.transitions.ts`). Manual approval sets `approvedAmount`, which defaults to the requested amount and cannot exceed it.
- **Officer scoping.** Officers see loan applications and users of their own organization only. Unassigned officers see nothing, and out-of-scope records return 404.
- **`ml_score` is now an integer from 0 to 1000** (migration `20261106000000-MlScoreScale`). This fixes the overflow at 1000. It also fixes the scale conflict: seed data held P(default) values from 0 to 1, which the UI read as risk, while live scores ran 0–1000. Seed values were converted. A CHECK constraint and scoping indexes were added.
- **UI** uses `creditScore` (0–1000) for risk bands and the review page. It shows "—" for debt-to-income (DTI) and coverage when income is unknown, instead of dividing by 1.
- **Tests:** the dead legacy specs were deleted and replaced with 62 unit tests (decision policy, every transition pair, scoping, concurrency, and processor retry and race behavior).

---

## 3. Open items

### Correctness (Milestone C)
1. **The ML score is mostly fixed values.** `POST /predict` in `nivuba-ml/backend/app.py` hardcodes age, profession, city, state and house years, and derives *experience* from **loan term**. The model (`JensBender/loan-default-prediction-pipeline`) was trained on an Indian dataset. Only salary and term move the score.
2. **`shap_values` are global `feature_importances_`**, so they are the same for every applicant. Either compute per-prediction SHAP values or rename them.
3. **The affordability check ignores interest.** It uses `amount / term`. Add the interest rate and existing debt once the product defines them.

### Technical debt
4. **Template leftovers remain:** the `CPF`/`CNPJ` validators and the `users.cpf` column, and the legacy migration `1709084394389-Migrate.ts`. That migration creates unused `companies`/`employees`/`loans` tables. Because of how TypeORM reads timestamps, it sorts and runs **last**.
5. **Demo data is seeded by a migration**, so it runs in every environment. Move it to a `seed` script or put it behind `SEED_DEMO_DATA=true`.
6. **ML tests import a missing `frontend/` package** (`tests/*/test_frontend.py`). The Hugging Face deploy workflow is commented out.
7. **The notification processor is a stub** (no email or SMS).
8. **The UI never calls `/auth/refresh`**, so users are logged out when the access token expires.
9. **CORS is wide open.** Add an allow-list, plus helmet and rate limiting.
10. **No CI** runs `make test` or the smoke test.
11. **The UI may decide `UNDER_REVIEW` applications that are still being scored** (it shows them as "pending"). The backend handles this safely, since the automated result is discarded, but the UI could show "scoring…" until `mlScore` is set.

### UI gaps (mock data and placeholders)
- Document upload and download are client-side only (no storage or endpoint).
- The apply form collects `purpose`, `loanType`, income, expenses and debt, but the backend accepts only `requestedAmount` and `termMonths`. Affordability uses the **profile salary**.
- The notifications bell is client-side only.

---

## 4. Roadmap

**Milestone A — "Clean clone runs"** ✅

**Milestone B — "Decisions are trustworthy"** ✅

**Milestone C — "A model that fits the product"** (≈1–2 weeks)
- [ ] Define the applicant feature set: age, employment years, monthly income, existing debt, payroll-linked or not, sector, district, and so on
- [ ] Add those fields to `users` (or to an `applicant_profile` table) and to `CreateLoanApplicationDto`, and collect them in the UI (§3 UI gaps)
- [ ] Train a NiVuba-specific model (synthetic data until real data exists) and version it on HF Hub or as an artifact
- [ ] Compute per-applicant SHAP values and show the top reasons on the review page (item 2)
- [ ] An actual ETL/feature step

**Milestone D — "Production-ready"** (ongoing)
- [ ] Move the demo seed out of migrations; clean up template leftovers (items 4, 5)
- [ ] Document storage and endpoints; real notifications (item 7)
- [ ] UI token refresh (item 8)
- [ ] CORS allow-list, rate limiting, helmet (item 9)
- [ ] CI: `make test` per PR, plus the compose build and `make smoke` (item 10)
- [ ] Deployment target and a "Live Deployment" link in the README

---

## 5. Local endpoints (`make up`)

| What | URL |
|---|---|
| UI | http://localhost:8876 |
| Core API | http://localhost:3000/api/v1.0 |
| Swagger | http://localhost:3000/docs |
| ML service | http://localhost:7860 (`/health`, `/predict`, `/api/predict`) |
| Bull Board | http://localhost:3001 |
| Postgres | localhost:5432 (set `POSTGRES_HOST_PORT` if that port is taken) |
| Redis | localhost:**6380** (mapped from 6379) |
