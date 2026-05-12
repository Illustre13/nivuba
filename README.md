# NiVuba: AI-Powered Loan Intelligence Platform

NiVuba is a full-stack AI-powered loan management system designed to automate credit risk assessment and loan decision-making using machine learning and data engineering pipelines.

It is built as a **monorepo of three interconnected services**:

- **nivuba-ui** → React frontend dashboard  
- **nivuba-core** → NestJS backend API  
- **nivuba-ml** → FastAPI machine learning service  

---

## Live Deployment

Deployed Application: [streamlit](https://rcaa-flight-prediction.streamlit.app/)

## Key Features

- AI-based credit risk scoring system  
- End-to-end loan application workflow automation  
- ETL pipelines for structured data processing  
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
- Data Engineering: ETL pipelines, feature processing  
- DevOps: Docker  

---

## Data Flow

1. User submits loan application via UI  
2. Backend validates and processes request  
3. ETL pipeline prepares structured data  
4. ML service performs risk prediction  
5. Result is returned and stored in database  
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
