# Backend API — Phase 1: Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Scaffold the NestJS monorepo, define the full Prisma schema, run the first migration, and wire up the global PrismaService and common utilities so every subsequent phase has a working, tested foundation to build on.

**Architecture:** Monorepo at repo root with `apps/api/` (NestJS) and `apps/mobile/` (Flutter). The API uses Prisma as the sole database access layer — no raw SQL in this phase. A global `PrismaModule` exposes `PrismaService` to all feature modules. Common cross-cutting concerns (exception filter, response transform, current-user decorator) are registered globally in `main.ts`.

**Tech Stack:** NestJS 10, Prisma 5, PostgreSQL 16, Node 18, TypeScript strict, Jest, Docker Compose

---

## File Map

| File | Responsibility |
|---|---|
| `docker-compose.yml` | Local PostgreSQL 16 + Redis 7 |
| `apps/api/prisma/schema.prisma` | Full data model for all 9 entities |
| `apps/api/.env` | Local dev secrets (git-ignored) |
| `apps/api/.env.example` | Documented env var template |
| `apps/api/src/prisma/prisma.service.ts` | `PrismaClient` wrapper with lifecycle hooks |
| `apps/api/src/prisma/prisma.module.ts` | Global module exporting `PrismaService` |
| `apps/api/src/common/filters/http-exception.filter.ts` | Global error handler — maps Prisma codes + HTTP exceptions to consistent shape |
| `apps/api/src/common/decorators/current-user.decorator.ts` | `@CurrentUser()` param decorator + `JwtPayload` type |
| `apps/api/src/common/interceptors/transform.interceptor.ts` | Wraps every success response in `{ data: ... }` |
| `apps/api/src/app.module.ts` | Root module wiring ConfigModule, ThrottlerModule, PrismaModule |
| `apps/api/src/main.ts` | Bootstrap: global pipes, filter, interceptor, CORS, port |
| `apps/api/src/app.controller.ts` | DELETE — replaced by a simple health check |
| `apps/api/src/app.service.ts` | DELETE — not needed |
| `apps/api/test/prisma-health.e2e-spec.ts` | Integration test: DB connects and basic query runs |

---

## Task 1: docker-compose + .env files

**Files:**
- Create: `docker-compose.yml`
- Create: `apps/api/.env`
- Create: `apps/api/.env.example`

- [ ] **Step 1.1: Create docker-compose.yml**

```yaml
# docker-compose.yml
services:
  postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: expense
      POSTGRES_PASSWORD: expense
      POSTGRES_DB: expense_tracker
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data

volumes:
  postgres_data:
  redis_data:
```

- [ ] **Step 1.2: Create apps/api/.env.example**

```bash
# apps/api/.env.example
DATABASE_URL="postgresql://expense:expense@localhost:5432/expense_tracker"
REDIS_URL="redis://localhost:6379"

JWT_PRIVATE_KEY="<base64-encoded RS256 private key>"
JWT_PUBLIC_KEY="<base64-encoded RS256 public key>"

GOOGLE_CLIENT_ID=""
GOOGLE_CLIENT_SECRET=""
GOOGLE_CALLBACK_URL="http://localhost:3000/auth/google/callback"

APPLE_CLIENT_ID=""
APPLE_TEAM_ID=""
APPLE_KEY_ID=""
APPLE_PRIVATE_KEY=""
APPLE_CALLBACK_URL="http://localhost:3000/auth/apple/callback"

SENDGRID_API_KEY=""
SENDGRID_FROM_EMAIL="noreply@expensetracker.app"

FIREBASE_SERVICE_ACCOUNT=""

FRONTEND_URL="http://localhost:4000"
PORT=3000
```

- [ ] **Step 1.3: Create apps/api/.env from the example**

```bash
cp apps/api/.env.example apps/api/.env
# Fill in DATABASE_URL and REDIS_URL — defaults already match docker-compose
```

- [ ] **Step 1.4: Add .env to .gitignore**

Append to `apps/api/.gitignore`:
```
.env
```

- [ ] **Step 1.5: Start Docker services and verify**

```bash
docker compose up -d
docker compose ps
```

Expected output: both `postgres` and `redis` show `running`.

- [ ] **Step 1.6: Commit**

```bash
git add docker-compose.yml apps/api/.env.example apps/api/.gitignore
git commit -m "feat: add docker-compose for local postgres and redis"
```

---

## Task 2: Prisma schema + first migration

**Files:**
- Create: `apps/api/prisma/schema.prisma`

- [ ] **Step 2.1: Install Prisma CLI (dev) and client (prod)**

```bash
cd apps/api
npm install --save-dev prisma
npm install --save @prisma/client
```

- [ ] **Step 2.2: Initialise Prisma**

```bash
cd apps/api
npx prisma init --datasource-provider postgresql
```

This creates `prisma/schema.prisma` and updates `.env` with `DATABASE_URL`.

- [ ] **Step 2.3: Replace schema.prisma with the full data model**

```prisma
// apps/api/prisma/schema.prisma
generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}

model User {
  id               String   @id @default(cuid())
  email            String   @unique
  passwordHash     String?
  name             String
  avatarUrl        String?
  oauthProvider    String?
  oauthId          String?
  refreshTokenHash String?
  createdAt        DateTime @default(now())
  updatedAt        DateTime @updatedAt

  ownedWorkspaces Workspace[]       @relation("WorkspaceOwner")
  memberships     WorkspaceMember[]
  transactions    Transaction[]
  notifications   Notification[]
  sentInvites     WorkspaceInvite[] @relation("InviteSender")

  @@index([oauthProvider, oauthId])
}

model Workspace {
  id        String   @id @default(cuid())
  name      String
  currency  String   @default("USD")
  ownerId   String
  createdAt DateTime @default(now())

  owner          User              @relation("WorkspaceOwner", fields: [ownerId], references: [id])
  members        WorkspaceMember[]
  categories     Category[]
  transactions   Transaction[]
  recurringRules RecurringRule[]
  budgets        Budget[]
  invites        WorkspaceInvite[]
}

enum MemberRole {
  OWNER
  ADMIN
  MEMBER
}

model WorkspaceMember {
  workspaceId String
  userId      String
  role        MemberRole @default(MEMBER)

  workspace Workspace @relation(fields: [workspaceId], references: [id], onDelete: Cascade)
  user      User      @relation(fields: [userId], references: [id], onDelete: Cascade)

  @@id([workspaceId, userId])
}

enum CategoryType {
  EXPENSE
  INCOME
}

model Category {
  id          String       @id @default(cuid())
  workspaceId String
  name        String
  icon        String       @default("category")
  color       String       @default("#6366f1")
  type        CategoryType

  workspace      Workspace       @relation(fields: [workspaceId], references: [id], onDelete: Cascade)
  transactions   Transaction[]
  recurringRules RecurringRule[]
  budgets        Budget[]

  @@unique([workspaceId, name, type])
}

enum TransactionType {
  EXPENSE
  INCOME
}

model Transaction {
  id              String          @id @default(cuid())
  workspaceId     String
  userId          String
  categoryId      String
  amount          Int
  description     String?
  date            DateTime
  type            TransactionType
  recurringRuleId String?
  createdAt       DateTime        @default(now())

  workspace     Workspace      @relation(fields: [workspaceId], references: [id], onDelete: Cascade)
  user          User           @relation(fields: [userId], references: [id])
  category      Category       @relation(fields: [categoryId], references: [id])
  recurringRule RecurringRule? @relation(fields: [recurringRuleId], references: [id], onDelete: SetNull)

  @@index([workspaceId, date])
  @@index([workspaceId, categoryId])
}

enum Frequency {
  DAILY
  WEEKLY
  MONTHLY
  YEARLY
}

model RecurringRule {
  id          String          @id @default(cuid())
  workspaceId String
  categoryId  String
  amount      Int
  description String?
  type        TransactionType
  frequency   Frequency
  startDate   DateTime
  endDate     DateTime?
  nextRunAt   DateTime
  isActive    Boolean         @default(true)
  createdAt   DateTime        @default(now())

  workspace    Workspace     @relation(fields: [workspaceId], references: [id], onDelete: Cascade)
  category     Category      @relation(fields: [categoryId], references: [id])
  transactions Transaction[]

  @@index([nextRunAt, isActive])
}

enum BudgetPeriod {
  MONTHLY
  YEARLY
}

model Budget {
  id          String       @id @default(cuid())
  workspaceId String
  categoryId  String?
  amount      Int
  period      BudgetPeriod
  year        Int
  month       Int?
  createdAt   DateTime     @default(now())

  workspace Workspace @relation(fields: [workspaceId], references: [id], onDelete: Cascade)
  category  Category? @relation(fields: [categoryId], references: [id], onDelete: SetNull)

  @@unique([workspaceId, categoryId, period, year, month])
  @@index([workspaceId, year, month])
}

enum NotificationType {
  BUDGET_ALERT
  RECURRING_REMINDER
  MONTHLY_SUMMARY
  INVITE
}

model Notification {
  id        String           @id @default(cuid())
  userId    String
  type      NotificationType
  payload   Json
  readAt    DateTime?
  createdAt DateTime         @default(now())

  user User @relation(fields: [userId], references: [id], onDelete: Cascade)

  @@index([userId, readAt])
}

enum InviteStatus {
  PENDING
  ACCEPTED
  EXPIRED
}

model WorkspaceInvite {
  id           String       @id @default(cuid())
  workspaceId  String
  invitedEmail String
  invitedById  String
  token        String       @unique @default(cuid())
  status       InviteStatus @default(PENDING)
  expiresAt    DateTime

  workspace Workspace @relation(fields: [workspaceId], references: [id], onDelete: Cascade)
  invitedBy User      @relation("InviteSender", fields: [invitedById], references: [id])

  @@index([token])
}
```

- [ ] **Step 2.4: Run first migration**

```bash
cd apps/api
npx prisma migrate dev --name init
```

Expected: `Your database is now in sync with your schema.` and a new file at `prisma/migrations/TIMESTAMP_init/migration.sql`.

- [ ] **Step 2.5: Generate Prisma client**

```bash
npx prisma generate
```

Expected: `Generated Prisma Client` with path to `node_modules/.prisma/client`.

- [ ] **Step 2.6: Commit**

```bash
git add apps/api/prisma/
git commit -m "feat: add full prisma schema with init migration"
```

---

## Task 3: PrismaService + PrismaModule

**Files:**
- Create: `apps/api/src/prisma/prisma.service.ts`
- Create: `apps/api/src/prisma/prisma.module.ts`
- Create: `apps/api/src/prisma/prisma.service.spec.ts`

- [ ] **Step 3.1: Write the failing unit test**

```typescript
// apps/api/src/prisma/prisma.service.spec.ts
import { Test } from '@nestjs/testing';
import { PrismaService } from './prisma.service';

describe('PrismaService', () => {
  let service: PrismaService;

  beforeEach(async () => {
    const module = await Test.createTestingModule({
      providers: [PrismaService],
    }).compile();
    service = module.get(PrismaService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  it('should extend PrismaClient', () => {
    expect(typeof service.$connect).toBe('function');
    expect(typeof service.$disconnect).toBe('function');
  });
});
```

- [ ] **Step 3.2: Run test — verify it fails**

```bash
cd apps/api
npm test -- --testPathPattern=prisma.service
```

Expected: FAIL — `Cannot find module './prisma.service'`

- [ ] **Step 3.3: Implement PrismaService**

```typescript
// apps/api/src/prisma/prisma.service.ts
import { Injectable, OnModuleInit, OnModuleDestroy } from '@nestjs/common';
import { PrismaClient } from '@prisma/client';

@Injectable()
export class PrismaService extends PrismaClient implements OnModuleInit, OnModuleDestroy {
  async onModuleInit() {
    await this.$connect();
  }

  async onModuleDestroy() {
    await this.$disconnect();
  }
}
```

- [ ] **Step 3.4: Implement PrismaModule**

```typescript
// apps/api/src/prisma/prisma.module.ts
import { Global, Module } from '@nestjs/common';
import { PrismaService } from './prisma.service';

@Global()
@Module({
  providers: [PrismaService],
  exports: [PrismaService],
})
export class PrismaModule {}
```

- [ ] **Step 3.5: Run test — verify it passes**

```bash
npm test -- --testPathPattern=prisma.service
```

Expected: PASS — `PrismaService > should be defined` ✓

- [ ] **Step 3.6: Commit**

```bash
git add apps/api/src/prisma/
git commit -m "feat: add PrismaService and global PrismaModule"
```

---

## Task 4: Common utilities

**Files:**
- Create: `apps/api/src/common/filters/http-exception.filter.ts`
- Create: `apps/api/src/common/filters/http-exception.filter.spec.ts`
- Create: `apps/api/src/common/decorators/current-user.decorator.ts`
- Create: `apps/api/src/common/interceptors/transform.interceptor.ts`
- Create: `apps/api/src/common/interceptors/transform.interceptor.spec.ts`

- [ ] **Step 4.1: Write failing test for GlobalExceptionFilter**

```typescript
// apps/api/src/common/filters/http-exception.filter.spec.ts
import { GlobalExceptionFilter } from './http-exception.filter';
import { HttpException, HttpStatus } from '@nestjs/common';
import { ArgumentsHost } from '@nestjs/common';

function mockHost(json: jest.Mock, url = '/test'): ArgumentsHost {
  return {
    switchToHttp: () => ({
      getResponse: () => ({
        status: () => ({ json }),
      }),
      getRequest: () => ({ url }),
    }),
  } as unknown as ArgumentsHost;
}

describe('GlobalExceptionFilter', () => {
  let filter: GlobalExceptionFilter;

  beforeEach(() => {
    filter = new GlobalExceptionFilter();
  });

  it('maps HttpException to correct shape', () => {
    const json = jest.fn();
    const host = mockHost(json);
    filter.catch(new HttpException('Not found', HttpStatus.NOT_FOUND), host);
    expect(json).toHaveBeenCalledWith(
      expect.objectContaining({ statusCode: 404, error: expect.any(String), message: 'Not found', path: '/test' }),
    );
  });

  it('maps unknown errors to 500', () => {
    const json = jest.fn();
    const host = mockHost(json);
    filter.catch(new Error('boom'), host);
    expect(json).toHaveBeenCalledWith(expect.objectContaining({ statusCode: 500 }));
  });
});
```

- [ ] **Step 4.2: Run test — verify it fails**

```bash
npm test -- --testPathPattern=http-exception.filter
```

Expected: FAIL — `Cannot find module './http-exception.filter'`

- [ ] **Step 4.3: Implement GlobalExceptionFilter**

```typescript
// apps/api/src/common/filters/http-exception.filter.ts
import {
  ExceptionFilter, Catch, ArgumentsHost,
  HttpException, HttpStatus, Logger,
} from '@nestjs/common';
import { Request, Response } from 'express';
import { Prisma } from '@prisma/client';

@Catch()
export class GlobalExceptionFilter implements ExceptionFilter {
  private readonly logger = new Logger(GlobalExceptionFilter.name);

  catch(exception: unknown, host: ArgumentsHost) {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<Response>();
    const request = ctx.getRequest<Request>();

    let status = HttpStatus.INTERNAL_SERVER_ERROR;
    let error = 'INTERNAL_SERVER_ERROR';
    let message = 'An unexpected error occurred';

    if (exception instanceof HttpException) {
      status = exception.getStatus();
      const res = exception.getResponse() as any;
      error = res.error ?? exception.name;
      message = Array.isArray(res.message) ? res.message[0] : (res.message ?? exception.message);
    } else if (exception instanceof Prisma.PrismaClientKnownRequestError) {
      if (exception.code === 'P2002') {
        status = HttpStatus.CONFLICT;
        error = 'CONFLICT';
        message = 'Resource already exists';
      } else if (exception.code === 'P2025') {
        status = HttpStatus.NOT_FOUND;
        error = 'NOT_FOUND';
        message = 'Resource not found';
      }
    } else {
      this.logger.error(exception);
    }

    response.status(status).json({ statusCode: status, error, message, path: request.url });
  }
}
```

- [ ] **Step 4.4: Implement CurrentUser decorator**

```typescript
// apps/api/src/common/decorators/current-user.decorator.ts
import { createParamDecorator, ExecutionContext } from '@nestjs/common';

export interface JwtPayload {
  sub: string;
  email: string;
}

export const CurrentUser = createParamDecorator(
  (_data: unknown, ctx: ExecutionContext): JwtPayload => {
    return ctx.switchToHttp().getRequest().user;
  },
);
```

- [ ] **Step 4.5: Write failing test for TransformInterceptor**

```typescript
// apps/api/src/common/interceptors/transform.interceptor.spec.ts
import { TransformInterceptor } from './transform.interceptor';
import { of } from 'rxjs';
import { ExecutionContext, CallHandler } from '@nestjs/common';

const mockContext = {} as ExecutionContext;

describe('TransformInterceptor', () => {
  it('wraps response in { data }', (done) => {
    const interceptor = new TransformInterceptor();
    const handler: CallHandler = { handle: () => of({ id: '1' }) };
    interceptor.intercept(mockContext, handler).subscribe((result) => {
      expect(result).toEqual({ data: { id: '1' } });
      done();
    });
  });
});
```

- [ ] **Step 4.6: Implement TransformInterceptor**

```typescript
// apps/api/src/common/interceptors/transform.interceptor.ts
import { Injectable, NestInterceptor, ExecutionContext, CallHandler } from '@nestjs/common';
import { Observable } from 'rxjs';
import { map } from 'rxjs/operators';

@Injectable()
export class TransformInterceptor<T> implements NestInterceptor<T, { data: T }> {
  intercept(_ctx: ExecutionContext, next: CallHandler): Observable<{ data: T }> {
    return next.handle().pipe(map((data) => ({ data })));
  }
}
```

- [ ] **Step 4.7: Run tests — verify both pass**

```bash
npm test -- --testPathPattern="http-exception.filter|transform.interceptor"
```

Expected: PASS — 3 tests passing

- [ ] **Step 4.8: Commit**

```bash
git add apps/api/src/common/
git commit -m "feat: add global exception filter, transform interceptor, current-user decorator"
```

---

## Task 5: AppModule + main.ts + health check

**Files:**
- Modify: `apps/api/src/app.module.ts`
- Modify: `apps/api/src/main.ts`
- Modify: `apps/api/src/app.controller.ts` (replace with health check)
- Delete: `apps/api/src/app.service.ts`
- Delete: `apps/api/src/app.controller.spec.ts`

- [ ] **Step 5.1: Rewrite app.module.ts**

```typescript
// apps/api/src/app.module.ts
import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { ThrottlerModule } from '@nestjs/throttler';
import { PrismaModule } from './prisma/prisma.module';
import { AppController } from './app.controller';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    ThrottlerModule.forRoot([{ ttl: 60000, limit: 10 }]),
    PrismaModule,
  ],
  controllers: [AppController],
})
export class AppModule {}
```

- [ ] **Step 5.2: Replace app.controller.ts with a health check**

```typescript
// apps/api/src/app.controller.ts
import { Controller, Get } from '@nestjs/common';

@Controller()
export class AppController {
  @Get('health')
  health() {
    return { status: 'ok' };
  }
}
```

- [ ] **Step 5.3: Rewrite main.ts**

```typescript
// apps/api/src/main.ts
import { NestFactory } from '@nestjs/core';
import { ValidationPipe } from '@nestjs/common';
import { AppModule } from './app.module';
import { GlobalExceptionFilter } from './common/filters/http-exception.filter';
import { TransformInterceptor } from './common/interceptors/transform.interceptor';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);

  app.enableCors({ origin: process.env.FRONTEND_URL ?? '*' });
  app.useGlobalPipes(new ValidationPipe({ whitelist: true, forbidNonWhitelisted: true, transform: true }));
  app.useGlobalFilters(new GlobalExceptionFilter());
  app.useGlobalInterceptors(new TransformInterceptor());

  await app.listen(process.env.PORT ?? 3000);
}

bootstrap();
```

- [ ] **Step 5.4: Delete unused scaffold files**

```bash
cd apps/api
rm src/app.service.ts src/app.controller.spec.ts
```

- [ ] **Step 5.5: Start the API and verify health check**

```bash
npm run start:dev
# In a separate terminal:
curl http://localhost:3000/health
```

Expected: `{"data":{"status":"ok"}}`

- [ ] **Step 5.6: Commit**

```bash
git add apps/api/src/
git commit -m "feat: wire up AppModule, global pipes/filter/interceptor, health endpoint"
```

---

## Task 6: Integration test — DB connectivity

**Files:**
- Create: `apps/api/test/prisma-health.e2e-spec.ts`
- Modify: `apps/api/test/jest-e2e.json`

- [ ] **Step 6.1: Update jest-e2e.json to set test timeout**

```json
// apps/api/test/jest-e2e.json
{
  "moduleFileExtensions": ["js", "json", "ts"],
  "rootDir": ".",
  "testEnvironment": "node",
  "testRegex": ".e2e-spec.ts$",
  "transform": { "^.+\\.(t|j)s$": "ts-jest" },
  "testTimeout": 30000
}
```

- [ ] **Step 6.2: Write the failing integration test**

```typescript
// apps/api/test/prisma-health.e2e-spec.ts
import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication, ValidationPipe } from '@nestjs/common';
import * as request from 'supertest';
import { AppModule } from '../src/app.module';
import { GlobalExceptionFilter } from '../src/common/filters/http-exception.filter';
import { TransformInterceptor } from '../src/common/interceptors/transform.interceptor';
import { PrismaService } from '../src/prisma/prisma.service';

describe('App bootstrap + DB (e2e)', () => {
  let app: INestApplication;
  let prisma: PrismaService;

  beforeAll(async () => {
    const module: TestingModule = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = module.createNestApplication();
    app.useGlobalPipes(new ValidationPipe({ whitelist: true, forbidNonWhitelisted: true, transform: true }));
    app.useGlobalFilters(new GlobalExceptionFilter());
    app.useGlobalInterceptors(new TransformInterceptor());
    await app.init();

    prisma = module.get(PrismaService);
  });

  afterAll(async () => {
    await app.close();
  });

  it('GET /health returns ok', () => {
    return request(app.getHttpServer())
      .get('/health')
      .expect(200)
      .expect({ data: { status: 'ok' } });
  });

  it('PrismaService can query the database', async () => {
    const count = await prisma.user.count();
    expect(typeof count).toBe('number');
  });
});
```

- [ ] **Step 6.3: Run integration test — verify it fails (no DB yet)**

```bash
cd apps/api
npm run test:e2e -- --testPathPattern=prisma-health
```

Expected: FAIL — connection refused (Docker not running yet)

- [ ] **Step 6.4: Start Docker, run migration, run test again**

```bash
# From repo root
docker compose up -d
# Wait 5 seconds for postgres to be ready
cd apps/api
npx prisma migrate deploy
npm run test:e2e -- --testPathPattern=prisma-health
```

Expected: PASS — both tests green

- [ ] **Step 6.5: Commit**

```bash
git add apps/api/test/
git commit -m "test: add e2e test for app bootstrap and db connectivity"
```

---

## Task 7: .gitignore + final cleanup

**Files:**
- Modify: `.gitignore` (repo root)

- [ ] **Step 7.1: Create root .gitignore**

```gitignore
# Root .gitignore
node_modules/
.env
dist/
*.log
.DS_Store
```

- [ ] **Step 7.2: Run the full unit test suite — all must pass**

```bash
cd apps/api
npm test
```

Expected: All tests pass. Zero failures.

- [ ] **Step 7.3: Final commit**

```bash
git add .gitignore
git commit -m "chore: add root gitignore"
```

---

## Phase 1 Complete

At the end of this phase you have:
- ✅ Local Postgres + Redis via `docker compose up -d`
- ✅ Full Prisma schema with all 9 entities, migrated
- ✅ `PrismaService` injectable everywhere
- ✅ Global exception filter (maps Prisma P2002/P2025, HTTP exceptions)
- ✅ Global transform interceptor (`{ data: ... }` wrapper)
- ✅ `@CurrentUser()` decorator ready for auth phase
- ✅ Health check at `GET /health`
- ✅ Integration test proving DB connectivity

**Next plan:** `2026-06-16-backend-api-phase2.md` — Auth module (register, login, JWT, Google/Apple OAuth, password reset)
