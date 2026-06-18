# API Contract — Wave 1: Foundation

**Generated:** 2026-06-18
**Plans covered:** be-1, fl-1
**Adds to previous contracts:** none

---

## Global Conventions

These apply to every wave. Every subsequent contract copies this section verbatim.

### Response envelope
Every success response: `{ "data": <payload> }`
Every error response: `{ "statusCode": number, "error": string, "message": string, "path": string }`

### Money
All amount fields are **integers (cents)**. Never floats. $12.50 = `1250`.
Frontend converts to display string only at the UI render layer.

### IDs
All entity IDs are `cuid()` strings. Never integers.

### Timestamps
All date/time fields are ISO 8601 strings (e.g. `"2026-06-18T10:00:00.000Z"`).

### Authentication
Protected routes require header: `Authorization: Bearer <accessToken>`
Unauthenticated → 401. Not a workspace member → 403.

### camelCase
All JSON field names use camelCase. `accessToken` not `access_token`. Flutter must match exactly.

---

## New Endpoints This Wave

No new endpoints. This wave is pure infrastructure.

**be-1** establishes: docker-compose (PostgreSQL + Redis), Prisma schema, PrismaService, GlobalExceptionFilter, TransformInterceptor, CurrentUser decorator, AppModule bootstrap.

**fl-1** establishes: pubspec.yaml dependencies, SecureStorageService (flutter_secure_storage on mobile, shared_preferences on web), Dio ApiClient with JWT interceptor (auto-refresh on 401), AppTheme (design tokens), GoRouter skeleton.

---

## Contract Violations

Any deviation from the Global Conventions above by any agent in any wave is a **REVIEWER CRITICAL issue**.

Deviations include:
- Float used for a money field
- Integer used for an entity ID
- Snake_case field name (`access_token` instead of `accessToken`)
- Success response not wrapped in `{ "data": ... }`
- Hardcoded secret or URL (use environment variables)
