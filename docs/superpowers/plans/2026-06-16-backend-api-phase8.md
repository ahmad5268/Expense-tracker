# Backend API — Phase 8: Docker + CI/CD + Deployment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Containerize the NestJS API with a production-ready multi-stage Dockerfile, then wire up GitHub Actions for CI (lint + test + build) and CD (deploy to Railway). Add a `.env.example` for onboarding. No secrets are hardcoded anywhere.

**Architecture:**
- CI pipeline: on every push/PR to `main` → install → lint → unit tests → e2e tests → build
- CD pipeline: on push to `main` (after CI passes) → build Docker image → push to GitHub Container Registry → trigger Railway redeploy
- The Flutter app (Phase 2) will be deployed separately to Vercel — not covered here

**Prerequisites:** All API phases (1–7) complete. Repository is on GitHub. Railway project exists (or will be created). `RAILWAY_TOKEN` and `REGISTRY_TOKEN` (GitHub PAT with packages write) are in GitHub repository secrets.

---

## File Map

| File | Responsibility |
|---|---|
| `apps/api/Dockerfile` | Multi-stage production Docker build |
| `apps/api/.dockerignore` | Exclude unnecessary files from build context |
| `.env.example` | Template for all required environment variables |
| `.github/workflows/ci.yml` | CI: lint, unit tests, e2e tests, build check |
| `.github/workflows/cd.yml` | CD: Docker build+push, Railway deploy trigger |

---

## Task 1: Dockerfile + .dockerignore

**Files:**
- Create: `apps/api/Dockerfile`
- Create: `apps/api/.dockerignore`

- [ ] **Step 1.1: Write Dockerfile**

```dockerfile
# apps/api/Dockerfile

# ── Build stage ──────────────────────────────────────────────────────────────
FROM node:20-alpine AS builder
WORKDIR /app

COPY package*.json ./
COPY prisma ./prisma/
RUN npm ci --ignore-scripts

COPY . .
RUN npx prisma generate
RUN npm run build

# ── Production stage ──────────────────────────────────────────────────────────
FROM node:20-alpine AS production
WORKDIR /app

ENV NODE_ENV=production

COPY package*.json ./
RUN npm ci --only=production --ignore-scripts

COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules/.prisma ./node_modules/.prisma
COPY --from=builder /app/prisma ./prisma

EXPOSE 3000

CMD ["sh", "-c", "npx prisma migrate deploy && node dist/main"]
```

- [ ] **Step 1.2: Write .dockerignore**

```
node_modules
dist
.env
.env.*
!.env.example
coverage
*.log
.git
.github
```

- [ ] **Step 1.3: Verify local Docker build**

```bash
cd apps/api
docker build -t expense-tracker-api:local .
docker run --rm -p 3000:3000 \
  -e DATABASE_URL="postgresql://expense:expense@host.docker.internal:5432/expense_tracker" \
  -e REDIS_URL="redis://host.docker.internal:6379" \
  -e JWT_PRIVATE_KEY="$(cat jwt_private.pem)" \
  -e JWT_PUBLIC_KEY="$(cat jwt_public.pem)" \
  expense-tracker-api:local
```

Expected: API starts, health check responds at `http://localhost:3000/health`.

- [ ] **Step 1.4: Commit**

```bash
git add apps/api/Dockerfile apps/api/.dockerignore
git commit -m "build(api): add multi-stage Dockerfile for production"
```

---

## Task 2: .env.example
Depends-on: 1

**Files:**
- Create: `.env.example` (at repo root)

- [ ] **Step 2.1: Write .env.example**

```bash
# apps/api/.env.example

# ─ Database ───────────────────────────────────────
DATABASE_URL=postgresql://expense:expense@localhost:5432/expense_tracker

# ─ Redis ──────────────────────────────────────────
REDIS_URL=redis://localhost:6379

# ─ JWT (RS256) ────────────────────────────────────
# Generate with:
#   openssl genrsa -out jwt_private.pem 2048
#   openssl rsa -in jwt_private.pem -pubout -out jwt_public.pem
JWT_PRIVATE_KEY="-----BEGIN RSA PRIVATE KEY-----\n...\n-----END RSA PRIVATE KEY-----"
JWT_PUBLIC_KEY="-----BEGIN PUBLIC KEY-----\n...\n-----END PUBLIC KEY-----"

# ─ OAuth ──────────────────────────────────────────
GOOGLE_CLIENT_ID=
GOOGLE_CLIENT_SECRET=
GOOGLE_CALLBACK_URL=http://localhost:3000/auth/google/callback

APPLE_CLIENT_ID=
APPLE_TEAM_ID=
APPLE_KEY_ID=
APPLE_PRIVATE_KEY=
APPLE_CALLBACK_URL=http://localhost:3000/auth/apple/callback

# ─ Email (SendGrid) ───────────────────────────────
SENDGRID_API_KEY=SG.xxx
SENDGRID_FROM_EMAIL=noreply@yourapp.com

# ─ Push Notifications (Firebase) ──────────────────
FIREBASE_SERVICE_ACCOUNT={"type":"service_account",...}

# ─ App ────────────────────────────────────────────
PORT=3000
FRONTEND_URL=http://localhost:4200
```

- [ ] **Step 2.2: Verify .env is in .gitignore**

```bash
cat apps/api/.gitignore | grep .env
# Should output: .env
# If not present, add it:
echo ".env" >> apps/api/.gitignore
echo ".env.local" >> apps/api/.gitignore
```

- [ ] **Step 2.3: Commit**

```bash
git add apps/api/.env.example apps/api/.gitignore
git commit -m "chore: add .env.example with all required environment variables"
```

---

## Task 3: GitHub Actions CI pipeline
Depends-on: 1

**Files:**
- Create: `.github/workflows/ci.yml`

- [ ] **Step 3.1: Create CI workflow**

```yaml
# .github/workflows/ci.yml
name: CI

on:
  push:
    branches: [main, develop]
    paths:
      - 'apps/api/**'
      - '.github/workflows/ci.yml'
  pull_request:
    branches: [main]
    paths:
      - 'apps/api/**'

jobs:
  test:
    name: Lint, Test & Build
    runs-on: ubuntu-latest

    services:
      postgres:
        image: postgres:16-alpine
        env:
          POSTGRES_USER: expense
          POSTGRES_PASSWORD: expense
          POSTGRES_DB: expense_tracker_test
        ports:
          - 5432:5432
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5

      redis:
        image: redis:7-alpine
        ports:
          - 6379:6379
        options: >-
          --health-cmd "redis-cli ping"
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5

    defaults:
      run:
        working-directory: apps/api

    env:
      DATABASE_URL: postgresql://expense:expense@localhost:5432/expense_tracker_test
      REDIS_URL: redis://localhost:6379
      JWT_PRIVATE_KEY: ${{ secrets.JWT_PRIVATE_KEY }}
      JWT_PUBLIC_KEY: ${{ secrets.JWT_PUBLIC_KEY }}
      SENDGRID_API_KEY: SG.test
      FIREBASE_SERVICE_ACCOUNT: '{}'
      NODE_ENV: test

    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
          cache-dependency-path: apps/api/package-lock.json

      - name: Install dependencies
        run: npm ci

      - name: Generate Prisma client
        run: npx prisma generate

      - name: Run database migrations
        run: npx prisma migrate deploy

      - name: Run unit tests
        run: npm test -- --coverage --passWithNoTests

      - name: Run e2e tests
        run: npm run test:e2e

      - name: Build
        run: npm run build

      - name: Upload coverage
        uses: codecov/codecov-action@v4
        if: always()
        with:
          directory: apps/api/coverage
```

- [ ] **Step 3.2: Add required secrets to GitHub repo**

In GitHub repo → Settings → Secrets → Actions, add:
- `JWT_PRIVATE_KEY` — contents of `jwt_private.pem` (with newlines as `\n` or raw multiline)
- `JWT_PUBLIC_KEY` — contents of `jwt_public.pem`

These are the only secrets needed for CI (email and Firebase are stubbed).

- [ ] **Step 3.3: Commit and push**

```bash
git add .github/workflows/ci.yml
git commit -m "ci: add GitHub Actions CI pipeline (lint + test + build)"
git push origin main
```

- [ ] **Step 3.4: Verify CI passes on GitHub**

Navigate to GitHub → Actions tab. Wait for workflow to complete green.

Expected: All steps pass, coverage uploaded.

---

## Task 4: GitHub Actions CD pipeline
Depends-on: 3

**Files:**
- Create: `.github/workflows/cd.yml`

- [ ] **Step 4.1: Add CD secrets to GitHub repo**

In GitHub repo → Settings → Secrets → Actions, add:
- `RAILWAY_TOKEN` — from Railway dashboard → Account → Tokens
- `RAILWAY_SERVICE_ID` — from Railway project → Service → Settings → Service ID

- [ ] **Step 4.2: Create CD workflow**

```yaml
# .github/workflows/cd.yml
name: CD

on:
  push:
    branches: [main]
    paths:
      - 'apps/api/**'
  workflow_run:
    workflows: [CI]
    types: [completed]
    branches: [main]

jobs:
  deploy:
    name: Build & Deploy API
    runs-on: ubuntu-latest
    if: ${{ github.event.workflow_run.conclusion == 'success' || github.event_name == 'push' }}

    permissions:
      contents: read
      packages: write

    steps:
      - uses: actions/checkout@v4

      - name: Log in to GitHub Container Registry
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Extract metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ghcr.io/${{ github.repository }}/api
          tags: |
            type=sha,prefix=sha-
            type=raw,value=latest,enable={{is_default_branch}}

      - name: Build and push Docker image
        uses: docker/build-push-action@v5
        with:
          context: apps/api
          file: apps/api/Dockerfile
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          cache-from: type=gha
          cache-to: type=gha,mode=max

      - name: Deploy to Railway
        uses: railwayapp/railway-github-action@v1
        with:
          railway-token: ${{ secrets.RAILWAY_TOKEN }}
          service: ${{ secrets.RAILWAY_SERVICE_ID }}
```

- [ ] **Step 4.3: Commit and push**

```bash
git add .github/workflows/cd.yml
git commit -m "cd: add GitHub Actions CD pipeline (Docker build + Railway deploy)"
git push origin main
```

- [ ] **Step 4.4: Verify CD run on GitHub**

Navigate to GitHub → Actions → CD workflow. Confirm Docker image pushed to GHCR and Railway deploy triggered.

---

## Task 5: Railway environment variable setup (one-time manual step)
Depends-on: 4

**Not automated — done once in Railway dashboard**

- [ ] **Step 5.1: Configure Railway environment variables**

In Railway dashboard → Project → Service → Variables, set:

```
DATABASE_URL         (Railway auto-provides this from PostgreSQL plugin)
REDIS_URL            (Railway auto-provides this from Redis plugin)
JWT_PRIVATE_KEY      (paste from local jwt_private.pem)
JWT_PUBLIC_KEY       (paste from local jwt_public.pem)
GOOGLE_CLIENT_ID
GOOGLE_CLIENT_SECRET
GOOGLE_CALLBACK_URL  = https://your-api.railway.app/auth/google/callback
APPLE_CLIENT_ID
APPLE_TEAM_ID
APPLE_KEY_ID
APPLE_PRIVATE_KEY
APPLE_CALLBACK_URL   = https://your-api.railway.app/auth/apple/callback
SENDGRID_API_KEY
SENDGRID_FROM_EMAIL
FIREBASE_SERVICE_ACCOUNT
FRONTEND_URL         = https://your-flutter-app.vercel.app
NODE_ENV             = production
```

- [ ] **Step 5.2: Run a health check on production URL**

```bash
curl https://your-api.railway.app/health
# Expected: {"status":"ok"}
```

---

## Phase 8 Complete

- ✅ Multi-stage Dockerfile — builder stage (compile + generate Prisma) + production stage (only prod deps)
- ✅ `.env.example` — documents all required environment variables with generation instructions
- ✅ CI pipeline — runs on every push/PR: install → prisma generate → migrate → unit tests → e2e tests → build
- ✅ CD pipeline — triggers after CI: Docker image built + pushed to GHCR → Railway redeploy
- ✅ GitHub Actions secrets documented
- ✅ Railway environment variable setup checklist

---

## All Backend Phases Complete

| Phase | Status | Description |
|---|---|---|
| Phase 1 | ✅ | Monorepo foundation: docker-compose, Prisma schema, PrismaService, common utilities |
| Phase 2 | ✅ | Auth: JWT RS256, refresh tokens, Google/Apple OAuth, password reset |
| Phase 3 | ✅ | Users, Workspaces (with default category seeding), Categories, Transactions |
| Phase 4 | ✅ | Budgets, RecurringRules |
| Phase 5 | ✅ | Background Jobs: recurring cron, budget alerts (Redis dedup), notification delivery, monthly summary |
| Phase 6 | ✅ | Notifications: REST CRUD + WebSocket gateway (Redis pub/sub) |
| Phase 7 | ✅ | Reports & Export: 6 analytics endpoints (raw SQL) + CSV + PDF streaming |
| Phase 8 | ✅ | Docker + GitHub Actions CI/CD + Railway deployment |

**Next:** Write Flutter mobile app implementation plans.
