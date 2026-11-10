# NiVuba: AI-Powered Loan Intelligence Platform

NiVuba is a full-stack AI-powered loan management system designed to automate credit risk assessment and loan decision-making using machine learning and data engineering pipelines.

It is built as a **monorepo of three interconnected services**:

- **nivuba-ui** → React frontend dashboard  
- **nivuba-core** → NestJS backend API  
- **nivuba-ml** → FastAPI machine learning service  

---

## Live Deployment

Not deployed yet. See [PROJECT_STATUS.md](PROJECT_STATUS.md) for the current state and roadmap.

## Key Features

- AI-based credit risk scoring system  
- End-to-end loan application workflow automation  
- Feature preprocessing pipeline for model inputs (dedicated ETL is on the roadmap)  
- Real-time ML inference for decision support  
- Secure authentication (JWT + RBAC)  
- Asynchronous task processing with Redis BullMQ  
- Scalable PostgreSQL data architecture  

---

## System Architecture

### 1. Frontend (nivuba-ui)
React-based dashboard for users to submit loan applications and view credit decisions.

### 2. Backend (nivuba-core)
NestJS API handling:
- Loan workflows
- User management
- Authentication (JWT + RBAC)
- Integration with ML service

### 3. ML Service (nivuba-ml)
FastAPI service providing:
- Loan default prediction model (Random Forest)
- REST API for inference
- Feature engineering and prediction pipeline

---

## Tech Stack

- Frontend: React.js, TailwindCSS  
- Backend: NestJS, Node.js  
- ML Service: FastAPI, scikit-learn  
- Database: PostgreSQL  
- Queue System: Redis BullMQ  
- Authentication: JWT, RBAC  
- Data Engineering: scikit-learn feature pipeline (ETL planned)  
- DevOps: Docker  

---

## Data Flow

1. User submits loan application via UI  
2. Backend validates and processes request  
3. Backend queues an evaluation job (Redis/Bull)  
4. ML service performs risk prediction (score 0–1000)  
5. Backend applies the decision rule (score ≥ 700 and affordability ≤ 35% of salary) and stores the result  
6. UI displays final decision and score  

---

## Project Highlights

This project demonstrates:
- Full-stack system architecture design  
- Machine learning integration in production systems  
- Data engineering and ETL workflows  
- Scalable backend and API development  
- Secure, role-based enterprise application design  

---

## Repository Structure

```bash
nivuba/
├── nivuba-ui/      # React frontend
├── nivuba-core/    # NestJS backend API
├── nivuba-ml/      # FastAPI ML service
```

---

## Getting Started

Requires Docker, git, and `make`. (`jq` and `curl` are also needed for the smoke test.)

```bash
git clone https://github.com/Illustre13/nivuba.git
cd nivuba
make up       # fetches the submodules, creates .env from .env.example, builds, starts, waits for health
make smoke    # end-to-end check: submit -> ML scoring -> decision -> officer review
```

Run `make help` for the other targets, such as `test`, `logs`, `down` and `reset`. Demo accounts are listed in [PROJECT_STATUS.md](PROJECT_STATUS.md#demo-accounts-seeded-by-migration-branchesanddatapool).

| Service | URL |
|---|---|
| UI | http://localhost:8876 |
| Core API / Swagger | http://localhost:3000/api/v1.0 · http://localhost:3000/docs |
| ML service | http://localhost:7860 |
| Bull Board | http://localhost:3001 |
