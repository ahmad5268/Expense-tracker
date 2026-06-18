# Flutter App — Phase 10: CI/CD + Deployment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire up GitHub Actions for Flutter CI (analyze + test + build web on every PR) and CD (build web + deploy to Vercel on push to main). Add `vercel.json` for SPA routing. Add `analysis_options.yaml` enforcing the zero-warnings policy.

**Architecture:**
- CI pipeline: on PR → `flutter pub get` → `flutter analyze` → `flutter test --coverage` → `flutter build web`
- CD pipeline: on push to `main` (after CI passes) → `flutter build web` → deploy `build/web/` to Vercel using the Vercel CLI action
- The existing backend CI/CD (Phase 8 of the backend) runs in parallel — this workflow targets only `apps/mobile/**`

**Prerequisite:** All Flutter phases (1–9) complete. Repository on GitHub. Vercel account exists. `VERCEL_TOKEN`, `VERCEL_ORG_ID`, `VERCEL_PROJECT_ID` added as GitHub repository secrets.

---

## File Map

| File | Responsibility |
|---|---|
| `apps/mobile/analysis_options.yaml` | Strict lint rules — zero warnings policy |
| `apps/mobile/vercel.json` | SPA rewrites so deep links work on Vercel |
| `.github/workflows/flutter-ci.yml` | Analyze, test, build on every push/PR |
| `.github/workflows/flutter-cd.yml` | Build web + deploy to Vercel on main |

---

## Task 1: analysis_options.yaml

**Files:**
- Create: `apps/mobile/analysis_options.yaml`

- [ ] **Step 1.1: Write analysis_options.yaml**

```yaml
# apps/mobile/analysis_options.yaml
include: package:flutter_lints/flutter.yaml

analyzer:
  errors:
    # Treat these as errors, not warnings
    missing_required_param: error
    missing_return: error
    dead_code: warning
    unused_import: warning
    unused_local_variable: warning

  exclude:
    - "**/*.g.dart"
    - "**/*.freezed.dart"
    - "lib/firebase_options.dart"

linter:
  rules:
    # Style
    prefer_const_constructors: true
    prefer_const_declarations: true
    prefer_final_fields: true
    prefer_final_locals: true
    avoid_print: true
    use_key_in_widget_constructors: true

    # Safety
    avoid_dynamic_calls: true
    avoid_empty_else: true
    cancel_subscriptions: true
    close_sinks: true

    # Riverpod
    avoid_manual_providers_as_generated_provider_dependencies: false
```

- [ ] **Step 1.2: Run flutter analyze — fix all warnings**

```bash
cd apps/mobile && flutter analyze
```

Fix any issues flagged. The goal is zero output. Generated files (`.g.dart`, `.freezed.dart`) are excluded.

- [ ] **Step 1.3: Commit**

```bash
git add apps/mobile/analysis_options.yaml
git commit -m "chore(mobile): add strict analysis_options.yaml"
```

---

## Task 2: vercel.json (SPA routing)
Depends-on: 1

**Files:**
- Create: `apps/mobile/vercel.json`

- [ ] **Step 2.1: Write vercel.json**

```json
{
  "rewrites": [
    {
      "source": "/((?!_next|favicon.ico|assets).*)",
      "destination": "/index.html"
    }
  ],
  "headers": [
    {
      "source": "/assets/(.*)",
      "headers": [
        { "key": "Cache-Control", "value": "public, max-age=31536000, immutable" }
      ]
    }
  ]
}
```

This rewrites all non-asset paths to `index.html` so GoRouter deep links (e.g. `/invite/:token`) work on refresh.

- [ ] **Step 2.2: Commit**

```bash
git add apps/mobile/vercel.json
git commit -m "chore(mobile): add vercel.json with SPA rewrite rules"
```

---

## Task 3: Flutter CI pipeline
Depends-on: 1, 2

**Files:**
- Create: `.github/workflows/flutter-ci.yml`

- [ ] **Step 3.1: Create CI workflow**

```yaml
# .github/workflows/flutter-ci.yml
name: Flutter CI

on:
  push:
    branches: [main, develop]
    paths:
      - 'apps/mobile/**'
      - '.github/workflows/flutter-ci.yml'
  pull_request:
    branches: [main]
    paths:
      - 'apps/mobile/**'

jobs:
  analyze-test-build:
    name: Analyze, Test & Build Web
    runs-on: ubuntu-latest

    defaults:
      run:
        working-directory: apps/mobile

    steps:
      - uses: actions/checkout@v4

      # If using Option B (secret injection), write firebase_options.dart before
      # any Flutter commands. Remove this step if using Option A (committed file).
      - name: Write firebase_options.dart
        run: echo "${{ secrets.FIREBASE_OPTIONS_DART }}" > apps/mobile/lib/firebase_options.dart

      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.22.0'
          channel: 'stable'
          cache: true

      - name: Install dependencies
        run: flutter pub get

      - name: Run code generation (build_runner)
        run: dart run build_runner build --delete-conflicting-outputs

      - name: Analyze
        run: flutter analyze --no-fatal-infos

      - name: Run unit + widget tests
        run: flutter test --coverage --reporter=github

      - name: Upload coverage
        uses: codecov/codecov-action@v4
        if: always()
        with:
          directory: apps/mobile/coverage

      - name: Build web (verify no compile errors)
        run: flutter build web --release --dart-define=API_BASE_URL=${{ vars.API_BASE_URL || 'https://api.expensetracker.app' }}
```

- [ ] **Step 3.2: Commit and push**

```bash
git add .github/workflows/flutter-ci.yml
git commit -m "ci(mobile): add Flutter CI pipeline (analyze + test + build web)"
git push origin main
```

- [ ] **Step 3.3: Verify CI passes on GitHub**

Navigate to GitHub → Actions → Flutter CI. Wait for workflow to complete green.

Expected: All steps pass.

---

## Task 4: Flutter CD pipeline (Vercel deploy)
Depends-on: 3

**Files:**
- Create: `.github/workflows/flutter-cd.yml`

- [ ] **Step 4.1: Add Vercel secrets to GitHub**

In GitHub repo → Settings → Secrets → Actions, add:
- `VERCEL_TOKEN` — from Vercel Account Settings → Tokens
- `VERCEL_ORG_ID` — from Vercel project settings → Team ID
- `VERCEL_PROJECT_ID` — from Vercel project settings → Project ID

Also add a Repository Variable (`vars`, not `secrets`):
- `API_BASE_URL` — e.g. `https://api.expensetracker.app`

- [ ] **Step 4.2: Create CD workflow**

```yaml
# .github/workflows/flutter-cd.yml
name: Flutter CD

on:
  push:
    branches: [main]
    paths:
      - 'apps/mobile/**'
  workflow_run:
    workflows: [Flutter CI]
    types: [completed]
    branches: [main]

jobs:
  deploy-web:
    name: Build & Deploy Flutter Web to Vercel
    runs-on: ubuntu-latest
    if: ${{ github.event.workflow_run.conclusion == 'success' || github.event_name == 'push' }}

    defaults:
      run:
        working-directory: apps/mobile

    steps:
      - uses: actions/checkout@v4

      # If using Option B (secret injection), write firebase_options.dart before
      # any Flutter commands. Remove this step if using Option A (committed file).
      - name: Write firebase_options.dart
        run: echo "${{ secrets.FIREBASE_OPTIONS_DART }}" > apps/mobile/lib/firebase_options.dart

      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.22.0'
          channel: 'stable'
          cache: true

      - name: Install dependencies
        run: flutter pub get

      - name: Run code generation
        run: dart run build_runner build --delete-conflicting-outputs

      - name: Build Flutter web
        run: |
          flutter build web --release \
            --dart-define=API_BASE_URL=${{ vars.API_BASE_URL }}

      - name: Install Vercel CLI
        run: npm install -g vercel@latest

      - name: Deploy to Vercel (production)
        run: |
          vercel deploy build/web \
            --token=${{ secrets.VERCEL_TOKEN }} \
            --scope=${{ secrets.VERCEL_ORG_ID }} \
            --prod \
            --yes
        env:
          VERCEL_ORG_ID: ${{ secrets.VERCEL_ORG_ID }}
          VERCEL_PROJECT_ID: ${{ secrets.VERCEL_PROJECT_ID }}
```

- [ ] **Step 4.3: Commit and push**

```bash
git add .github/workflows/flutter-cd.yml
git commit -m "cd(mobile): add Flutter CD pipeline (build web + Vercel deploy)"
git push origin main
```

- [ ] **Step 4.4: Verify CD run on GitHub**

Navigate to GitHub → Actions → Flutter CD. Confirm deploy completes and Vercel URL is reachable.

---

## Task 5: Firebase Messaging setup (one-time manual step)

**Not automated — done once per platform**

- [ ] **Step 5.1: Add Firebase project**

```bash
# Install FlutterFire CLI
dart pub global activate flutterfire_cli

# Configure Firebase for the mobile app
cd apps/mobile
flutterfire configure
```

This generates `lib/firebase_options.dart` (already excluded from analysis).

- [ ] **Step 5.2: Complete `lib/main.dart` with Firebase + FCM setup**

Replace the pseudocode in the existing `main.dart` with the complete implementation below. This uses raw `Dio` (not the Riverpod `ApiClient`) so FCM token sync works before `ProviderScope` is fully mounted, and falls back silently if the user is not yet logged in.

```dart
// lib/main.dart — complete Firebase + FCM setup
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/auth/secure_storage.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Request push permission (iOS explicit; Android 13+ explicit; web prompt)
  final messaging = FirebaseMessaging.instance;
  final settings = await messaging.requestPermission(
    alert: true, badge: true, sound: true,
  );

  if (settings.authorizationStatus == AuthorizationStatus.authorized) {
    // Get initial FCM token and sync to backend
    final token = await messaging.getToken();
    if (token != null) await _syncFcmToken(token);

    // Re-sync whenever Firebase rotates the token
    messaging.onTokenRefresh.listen(_syncFcmToken);
  }

  runApp(const ProviderScope(child: App()));
}

/// Syncs an FCM token to PUT /users/me/fcm-token using raw Dio + stored access token.
/// Called before ProviderScope is available, so we use SecureStorageService directly.
Future<void> _syncFcmToken(String token) async {
  try {
    // Read the stored access token directly — ProviderScope is not yet mounted
    final accessToken = await SecureStorageService.getAccessToken();
    if (accessToken == null) return; // not logged in yet; sync happens on next login
    await Dio().put(
      '${const String.fromEnvironment('API_BASE_URL', defaultValue: 'https://api.expensetracker.app')}/users/me/fcm-token',
      data: {'fcmToken': token},
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );
  } catch (_) {
    // Non-fatal: push won't work until next app restart syncs the token
  }
}
```

> After a successful login, the auth flow should also call `_syncFcmToken` (or inline equivalent) to sync the token for users who grant notification permission after first login.

- [ ] **Step 5.3: CI strategy for `lib/firebase_options.dart`**

`flutterfire configure` generates `lib/firebase_options.dart`. This file **must not be gitignored** in CI because GitHub Actions cannot run the interactive FlutterFire CLI.

Choose **one** of two approaches:

**Option A — Commit the file directly (simplest):**
Remove `lib/firebase_options.dart` from `.gitignore`. The file contains no secrets (only project IDs, not API keys).

**Option B — Inject via GitHub Actions secret (more secure):**
```bash
# In .gitignore — keep the line so the file is NOT committed to git
lib/firebase_options.dart
```
In GitHub repository → Settings → Secrets → Actions, add:
- `FIREBASE_OPTIONS_DART` — paste the entire contents of `lib/firebase_options.dart`

Then add this step to **both** `flutter-ci.yml` and `flutter-cd.yml`, **immediately after `actions/checkout@v4`** and **before** any Flutter commands:

```yaml
- name: Write firebase_options.dart
  run: |
    mkdir -p lib
    echo "${{ secrets.FIREBASE_OPTIONS_DART }}" > lib/firebase_options.dart
  working-directory: apps/mobile
```

This step must appear in both `.github/workflows/flutter-ci.yml` and `.github/workflows/flutter-cd.yml` immediately after `actions/checkout@v4`. The `working-directory: apps/mobile` scopes the path correctly to the mobile app root.

> Note: The existing CI workflow in this plan already has a `Write firebase_options.dart` step at the top-level path (`apps/mobile/lib/firebase_options.dart`). Replace that step with the version above that uses `working-directory` for consistency.

- [ ] **Step 5.4: Commit**

```bash
git add apps/mobile/lib/firebase_options.dart apps/mobile/lib/main.dart
git commit -m "feat(mobile): configure Firebase, sync FCM token to backend, handle token refresh"
```

---

## Phase 10 Complete

- ✅ `analysis_options.yaml` — strict lints, zero-warnings policy, excludes generated files
- ✅ `vercel.json` — SPA rewrite so GoRouter deep links work on Vercel (including `/invite/:token`)
- ✅ CI pipeline — on every push/PR to `apps/mobile/**`: install → codegen → analyze → test (coverage) → build web
- ✅ **Firebase CI strategy** — both `flutter-ci.yml` and `flutter-cd.yml` include a `Write firebase_options.dart` step using `working-directory: apps/mobile` (from `FIREBASE_OPTIONS_DART` secret) immediately after `actions/checkout@v4`, before any Flutter commands
- ✅ CD pipeline — on push to `main`: build web → Vercel CLI → production deploy
- ✅ **Complete `main.dart` Firebase + FCM setup** — full implementation with `Firebase.initializeApp`, `requestPermission`, `getToken` → sync via raw Dio + stored access token (pre-ProviderScope), `onTokenRefresh` listener for token rotation; non-fatal error handling so push failure doesn't crash the app

---

## All Flutter Phases Complete

| Phase | Description |
|---|---|
| Phase 1 | Foundation: pubspec, Dio+JWT, SecureStorage, GoRouter, AppTheme |
| Phase 2 | Auth: User model, AuthProvider, Login/Register/ForgotPassword, OAuth |
| Phase 3 | Shared models (all Freezed), CurrencyFormatter, WorkspaceProvider |
| Phase 4 | Dashboard: SummaryCard, BudgetProgressBar, RecentTransactions, BottomNav shell |
| Phase 5 | Transactions: paginated list, filters, AmountField, CategoryPicker, AddSheet |
| Phase 6 | Workspaces: list/switcher, create, settings, members, invite, accept invite |
| Phase 7 | Budgets + Recurring: lists with progress bars, create/edit sheets |
| Phase 8 | Reports: 6 FL Chart tabs (line, pie, bar, heatmap) + CSV/PDF export |
| Phase 9 | Notifications: WebSocket client, NotificationBell badge, NotificationsScreen |
| Phase 10 | CI/CD: GitHub Actions (analyze, test, build) + Vercel deploy |
