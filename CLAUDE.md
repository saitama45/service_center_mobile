# CLAUDE.md — Project Map

Concise knowledge map for this repository. **Read this file first in every session.**
Details live in `docs/knowledge/*.md` — open only the note relevant to the task.

## Session rules (permanent)

1. At the start of every new session, read this file and Claude auto memory **first**.
2. Do **not** start a task by broadly or recursively scanning the whole repository.
3. Use this map to locate the relevant subsystem, then read only the files that task needs.
4. Explore more broadly **only** when docs are missing, stale, or contradicted by source.
5. **Source code is authoritative** when it conflicts with documentation.
6. After a verified architectural or workflow change, update this file and the affected
   note in `docs/knowledge/`.
7. Save reusable discoveries, conventions, debugging insights, and architectural knowledge
   to auto memory.
8. Do **not** save temporary progress, speculative conclusions, or task status as memory.
9. Keep this file concise to minimise startup tokens; put depth in `docs/knowledge/`.
10. Before ending a significant task, check whether docs or memory went stale and update them.

## Database safety (hard rules)

- `daviddb` is a **protected** local developer database. Never run destructive operations
  against it: no `DROP`, `TRUNCATE`, delete-all, `migrate:fresh|refresh|reset`, `db:wipe`,
  destructive seeders, or restore-with-replace.
- Laravel/Pest/PHPUnit suites must run against an **isolated** database — SQLite `:memory:`
  or a name ending in `_test` / `_testing`. Never infer safety from `APP_ENV=testing`.
- **Verify the active connection** before any migration, seeder, suite run, or DB-modifying
  command. If isolation cannot be proven, stop and report the unsafe connection.
- Restoring, dropping, truncating, or bulk-deleting is executed by the user manually.
- This repo has no Laravel/MySQL component; its store is on-device SQLite (see below).
  One local destructive path still exists and needs explicit approval:
  `SeedRunner._runReset()` (wipes + reseeds). `LoyaltyDao.resetMemberActivity()` and the
  "Reset my stamp activity" row on Profile were **deleted 2026-09-05** — a member's history
  is not disposable, so no in-app path clears it any more.

## What this is

Flutter (Dart) **offline-first mobile app** — a coffee-shop style **stamp-card loyalty
program**. Members collect stamps per campaign, redeem rewards when a card fills, and view a
transaction ledger. Bundled with it is a full **RBAC admin console** (users, roles, permission
matrix, audit log) inherited from the app's earlier life as a DPWH bridge/DTR application.

Features: static signed member QR staff scan on ghelpdesk to award a real stamp; campaign
catalogue + real progress synced down; card redemption + cycle restart; ledger with
earned/redeemed/balance; remote-first login with offline fallback; OTP + biometric post-login
steps; module × permission RBAC.

Naming carries history: pubspec `name: bms` (imports are `package:bms/...`), shared widgets
are prefixed `Bms*`, the UI title is "TAS Service Center (SC)", the folder is
`loyalty_campaign`. All four refer to this one app.

## Entry points

- `lib/main.dart` — binding, orientation/status bar, constructs `AppDatabase`, overrides
  `appDatabaseProvider`, runs `ProviderScope(child: BmsApp())`.
- `lib/app.dart` — `MaterialApp.router` and the entire espresso/cream/amber theme.
- `lib/routing/app_router.dart` — GoRouter, redirect guards, `StatefulShellRoute` (4 tabs).
- `lib/presentation/screens/splash/splash_screen.dart` — runs seeds, checks session, routes.

## Directory responsibilities

| Path | Responsibility |
|---|---|
| `lib/core/constants/` | Colors, dimensions, text styles, strings, `ModuleCodes`, `PermissionCodes` |
| `lib/core/widgets/` | Shared UI (`Bms*`, `AppDrawer`, `PermissionGate`, dialogs) |
| `lib/core/utils/` | `TokenUtil` (SHA-256), `BcryptUtil`, date/device/watermark helpers |
| `lib/core/sync/` | `SyncManager` — offline push queue |
| `lib/data/datasources/remote/` | `ApiClient` (HTTP), `SupabaseSyncDatasource` (stub) |
| `lib/database/tables/` | Drift table definitions (rbac / sync / loyalty) |
| `lib/database/daos/` | All SQL access, one DAO per concern |
| `lib/database/seeds/` | First-run seed data + `SeedRunner` |
| `lib/domain/entities/` | `UserEntity`, `RoleEntity`, `PermissionCache`, `AuditLogEntity` |
| `lib/domain/usecases/` | Auth (login/logout/session/password) + permission resolution |
| `lib/presentation/providers/` | Riverpod state — auth, auth-flow, permissions, loyalty, admin |
| `lib/presentation/screens/` | One folder per screen |
| `supabase/migrations/` | Postgres mirror of the RBAC schema (**not wired up**) |
| `test/unit/` | Drift in-memory DAO checks + util checks |

## Key components (exact paths)

- Local DB: [lib/database/app_database.dart](lib/database/app_database.dart) — `schemaVersion 7`
- Loyalty engine: [lib/database/daos/loyalty_dao.dart](lib/database/daos/loyalty_dao.dart)
  (`earnStamp`, `redeemReward`, `getCampaignProgress`, `getLedgerTotals`)
- Permission resolution: [permission_matrix_dao.dart:90](lib/database/daos/permission_matrix_dao.dart#L90) → [resolve_permission_usecase.dart](lib/domain/usecases/permission/resolve_permission_usecase.dart) → [permission_cache.dart](lib/domain/entities/permission_cache.dart)
- Login: [lib/domain/usecases/auth/login_usecase.dart](lib/domain/usecases/auth/login_usecase.dart) (remote-first + offline fallback)
- Session check: [lib/domain/usecases/auth/check_session_usecase.dart](lib/domain/usecases/auth/check_session_usecase.dart)
- Auth state: [lib/presentation/providers/auth_provider.dart](lib/presentation/providers/auth_provider.dart)
- OTP / biometric steps: [lib/presentation/providers/auth_flow_provider.dart](lib/presentation/providers/auth_flow_provider.dart)
- TOTP primitives: [lib/core/utils/totp_util.dart](lib/core/utils/totp_util.dart) (RFC 6238, own impl)
- OTP server contract: [lib/data/datasources/remote/otp_remote_datasource.dart](lib/data/datasources/remote/otp_remote_datasource.dart)
- Authenticator secret storage: [lib/data/datasources/local/totp_secret_store.dart](lib/data/datasources/local/totp_secret_store.dart) (secure storage, keyed by user id)
- Loyalty state + member QR (`memberQrProvider`): [lib/presentation/providers/loyalty_provider.dart](lib/presentation/providers/loyalty_provider.dart)
- Singletons (db, secure storage, api, sync, connectivity): [lib/presentation/providers/app_providers.dart](lib/presentation/providers/app_providers.dart)
- Seeding: [lib/database/seeds/seed_runner.dart](lib/database/seeds/seed_runner.dart)
- HTTP: [lib/data/datasources/remote/api_client.dart](lib/data/datasources/remote/api_client.dart)

## Database (summary → `docs/knowledge/Database.md`)

On-device SQLite via **Drift**, file `app_database.sqlite` in the app documents directory.
Tables: `roles`, `permissions`, `modules`, `users`, `role_module_permissions`, `sessions`,
`audit_logs`, `sync_log`, `app_settings`, `products`, `campaigns`, `stamp_cards`,
`loyalty_transactions`. All PKs are client-generated UUID **text**; datetimes stored **as
text** (`build.yaml`). Generated `*.g.dart` is committed — regenerate after schema edits.

## Auth & authorization (summary → `docs/knowledge/Authentication.md`)

Login POSTs `/api/login` to the remote API; on network failure it falls back to a local bcrypt
check (14-day cached-session limit, 5 attempts → 30-min lockout). The raw token lives only in
`flutter_secure_storage`; only `SHA-256(token)` is stored in `sessions`. After the password
step: OTP screen → biometric screen → `PostLoginStep.done`; the router blocks the app until
done. Authorization is `role_module_permissions` (role × module × permission), resolved once
into a `PermissionCache` and read via `PermissionGate` / router guards. **No row = denied.**

## Commands

Flutter lives at `D:/flutter/bin/` on this machine.

```
"D:/flutter/bin/flutter.bat" pub get
"D:/flutter/bin/dart.bat" run build_runner build --delete-conflicting-outputs   # after DB/provider edits
"D:/flutter/bin/flutter.bat" analyze          # lint: flutter_lints + analysis_options.yaml rules
"D:/flutter/bin/flutter.bat" run              # debug on attached device/emulator
"D:/flutter/bin/flutter.bat" build apk        # release build
./start_emulator.ps1                          # launches Pixel_6_API_35
```

The suite in `test/` runs with `flutter.bat` + the `test` subcommand; it uses only
`NativeDatabase.memory()`, never a developer database.

## Known pitfalls (details → `docs/knowledge/Decisions.md`)

- **Admin route constants are stale.** `RouteName.users`/`roles`/`auditLog` say `/users`, but
  the real routes are nested: `/dashboard/users`, `/dashboard/roles`, `/dashboard/audit-log`.
  Screens and router guards hardcode the `/dashboard/...` strings. Don't trust the constants.
- **Bumping `arch_reset_v7` in `SeedRunner` wipes the on-device database** on next launch.
  The current expected value is `'12'`.
- **Remote login stores the role *name* in `users.role_id`** (e.g. `"user"`), which matches no
  `roles.id`, so permission resolution returns an empty cache for server-authenticated users.
  The offline/seeded `admin` (role UUID `...0001`) resolves normally.
- **OTP is now a real two-channel second factor** (email server-issued online, TOTP
  authenticator app offline) — see `docs/knowledge/Authentication.md`. The email channel's
  server routes (`POST /api/otp/send|verify`) are **not deployed yet**; until they are,
  `OtpPolicy.allowSkipWhenServerHasNoOtp` (in `auth_flow_provider.dart`) lets online sign-in
  through without a code. Flip that flag once the backend ships.
- **`SyncManager` pulls the campaign catalogue AND real stamp progress** (`GET /api/campaigns`,
  `GET /api/loyalty/my-cards` — mirrors ghelpdesk's `stamp_programs`/`stamp_cards`, see
  `docs/knowledge/Integrations.md`), but **upload is still a deliberate no-op**; the
  loyalty-transaction endpoint doesn't exist server-side yet — it only counts pending rows.
  `SupabaseSyncDatasource` is an unused stub.
- **Earning a stamp is now server-authoritative, not an on-device simulation.** The old
  rotating `ScanToken` + "Simulate POS scan" button on the earn screen are gone (deleted
  2026-08-25) — a member's QR is now a static, signed code (`GET /api/loyalty/qr-card`,
  `memberQrProvider`) that ghelpdesk staff actually scan and act on (Stamps module "Scan
  Customer" flow), and `SyncManager._pullProgress` pulls the real count back down. The local
  `earnStamp`/`ScanToken` DAO machinery still exists (and is still unit-tested) but has no UI
  caller left — do not wire a new screen back into it without first checking whether the real
  server flow already covers the need.
- **Redeeming is server-authoritative too, and works the same way** (added 2026-09-04).
  "Redeem Now" no longer redeems on-device; it shows a signed, per-card code
  (`LoyaltyRedeemQrService`, `LRDM1:{stamp_card_id}:{sig}`) that staff scan on the Stamps
  module's **"Scan Redeem QR"** button — `StampController::resolveRedeemScan` verifies it and
  opens the existing Redeem Reward modal for that exact card. It stops at the modal on
  purpose: a redemption deducts specific coded inventory units, which only the person at the
  counter can pick. The code is issued with the ordinary `my-cards` progress pull and cached
  on the local card row, so it displays offline exactly like the member QR. Replay is
  prevented by the card, not the code — a scanned card whose status has left `completed` is
  refused. The sheet closes on a **positive** signal only: it follows the one card row it was
  opened for through `campaignCardsProvider` (which keeps redeemed cards) and waits for
  `redeemed_at`. Never infer it from the card vanishing out of `campaignProgressProvider` — a
  provider being *refreshed* looks identical through `maybeWhen(data:)` while still reporting
  `hasValue`, and the sync fired on open triggers exactly that, which made the sheet
  congratulate the member a second after it opened. `LoyaltyDao.redeemReward` still exists and is still unit-tested, but like
  `earnStamp` it now has **no UI caller**.
- **Pre-v6 devices carried phantom redemptions in the ledger** (repaired 2026-09-04). The
  retired on-device "Redeem Now" wrote a local `redeem` row with no server event behind it, so
  once ghelpdesk's real redemption synced down a member saw the same claim twice (real "OREO
  TUMBLER" `SR-4` **and** local "CBTL Campaign (Free Reward)" `TXN-…`) and History
  double-counted it. The **v6 migration deletes never-synced `redeem` rows** — after v5 no
  legitimate one can exist. Earn rows are deliberately left alone: a pending earn may be the
  only record of a stamp, whereas a phantom redeem always has a server twin. Seeds create no
  ledger rows at all, so any `TXN-` row came from the retired local paths. **v7** finishes the
  job on the card side: it deletes closed cards with no `remote_card_id` that were never
  synced and that no ledger row references — the retired path opened a replacement card too,
  which showed up as a second "claimed" card in Rewards for a campaign ghelpdesk redeemed
  once. Open cards with no `remote_card_id` are left alone (the server just hasn't caught up).
- **A server-side redemption now closes the local card** (fixed 2026-09-04). `_pullProgress`
  used to flatten `redeemed` into `completed`, so a reward staff had already handed over kept
  showing "Redeem Now" in the app. Local cards are now keyed on ghelpdesk's own
  `stamp_cards.id` (`stampCards.remoteCardId`, schema v5) rather than the campaign code —
  after a redemption a member legitimately has two cards for one program, and code-keying let
  them overwrite each other. Rows predating the column are adopted once, by matching the
  still-open local card.
- **Every QR must also show its exact code as text** (`BmsManualCode`,
  `lib/core/widgets/bms_manual_code.dart`). Scanners fail — cracked screens, low
  brightness, backlit displays — and every staff-side scan field in ghelpdesk is an
  ordinary text input, so a cashier can key the same string and hit the identical
  server-side verification. Applies to any new barcode/QR work, on both sides. Two rules
  with it: never truncate a code, and **never name "ghelpdesk" in member-facing copy** —
  to a member it is just "the cashier".
- **The member QR works fully offline once fetched.** It's static (not rotating) specifically so
  a cached copy is exactly as valid as a fresh one — `MemberQrCache` (secure storage, keyed by
  user id) is what makes it survive with zero connectivity. It's proactively fetched right after
  every login/registration and app resume (`prefetchMemberQr`), not only when the member happens
  to open "My Member Code" while online — a member who's never been online even once (e.g.
  account created through someone else's device) still won't have anything to show; that's an
  inherent limit of a server-signed code, not a bug to chase here.
- **Self-registration is real** (`POST /api/register`) — creates a linked ghelpdesk `customers`
  + roleless `users` row, then behaves exactly like a fresh login (same OTP/biometric steps).
  **A 200/201 means the account already exists**: never report anything that fails after that
  as a connection error, or the member retries into "the email has already been taken".
- Stamp replay protection is the **unique index on `loyalty_transactions.scan_token`**, not the
  friendly pre-check inside `earnStamp`.
- `package:bms/...` is the import prefix everywhere, including in `test/`.
- **`insertOnConflictUpdate` resolves on the primary key, not a table's business unique key.**
  Every Drift table here has a client-generated UUID `id`, which never collides — an upsert
  meant to key on something else (e.g. `campaigns.code`) needs the explicit form:
  `insert(companion, onConflict: DoUpdate((_) => companion, target: [table.column]))`. Found in
  `SyncManager`; `SeedRunner` has the identical latent bug, dormant only because seeding runs
  once against an empty table. It also bit `users`, whose ids come from the **server**: a
  member whose account was deleted in ghelpdesk and re-registered got a new id, and the insert
  hit `UNIQUE (username)` — fixed in `UserDao.upsertUserForLogin` (re-key the existing row),
  covered by `test/unit/user_dao_test.dart` and `test/unit/register_usecase_test.dart`.
- **A rebuilt debug APK can silently ignore a changed `--dart-define`.** If `API_BASE_URL`
  seems stuck on the production default after a rebuild, `flutter clean && flutter pub get`
  before rebuilding — don't trust a kernel-blob string-presence check to prove which value
  actually resolved (debug/JIT builds keep both branches' literals in the pool regardless).

## Knowledge notes

- [docs/knowledge/Architecture.md](docs/knowledge/Architecture.md) — layers, state, navigation
- [docs/knowledge/Data-Flows.md](docs/knowledge/Data-Flows.md) — startup, login, earn, redeem, sync
- [docs/knowledge/Database.md](docs/knowledge/Database.md) — schema, migrations, seeding, safety
- [docs/knowledge/Authentication.md](docs/knowledge/Authentication.md) — sessions, OTP, biometrics, RBAC
- [docs/knowledge/Integrations.md](docs/knowledge/Integrations.md) — API, Supabase, device plugins
- [docs/knowledge/Decisions.md](docs/knowledge/Decisions.md) — architectural decisions + pitfalls
