# Database

## Safety rules (read before any DB work)

- `daviddb` is a **protected** developer database. Never run `DROP`, `TRUNCATE`, delete-all,
  `migrate:fresh` / `migrate:refresh` / `migrate:reset`, `db:wipe`, destructive seeders, or a
  restore-with-replace against it.
- Any Laravel/Pest/PHPUnit suite must be positively verified to target SQLite `:memory:` or a
  database whose name ends in `_test` / `_testing`. `APP_ENV=testing` alone proves nothing.
- Verify the active connection *before* running migrations, seeders, suites, or any
  DB-modifying command. If isolation cannot be proven, stop and report the effective
  connection instead of running it.
- Restore / drop / truncate / bulk-delete is performed by the user manually, outside Claude.
- **This repository contains no Laravel or server database.** Its only store is on-device
  SQLite. Two local destructive paths exist and require explicit user approval:
  - `SeedRunner._runReset()` — `DELETE FROM` every core table, then reseeds.
  - `LoyaltyDao.resetMemberActivity(userId)` — deletes that member's transactions and cards
    (wired to the "reset activity" action on Profile).
- The suite under `test/` is safe by construction: every DAO check builds
  `AppDatabase.forTesting(NativeDatabase.memory())`. Keep it that way — never point a check at
  the on-device file or a developer database.

## Engine

Drift 2.18 over `sqlite3_flutter_libs`. File: `app_database.sqlite` inside
`getApplicationDocumentsDirectory()`, opened by `NativeDatabase.createInBackground`
(`lib/database/app_database.dart`).

`build.yaml` sets `store_date_time_values_as_text: true` — **datetimes are ISO-8601 TEXT, not
integers.** Raw SQL that compares dates must account for that. Timestamps are written in UTC.

Primary keys are client-generated UUID v4 strings (`clientDefault`), so rows can be created
offline and merged later without collisions. Seeded rows instead use deterministic UUID v5
(`uuid.v5(NAMESPACE_URL, 'perm_VIEW')` etc.) so re-seeding is idempotent across installs.

## Tables

`lib/database/tables/rbac_tables.dart`

| Table | Notes |
|---|---|
| `roles` | `code` unique, `is_system`, `is_active` |
| `permissions` | `code` unique, `category` = DATA \| ACTION \| WORKFLOW \| SYSTEM |
| `modules` | `code` unique, self-referencing `parent_module_id`, `route`, `icon`, `display_order` |
| `users` | `username` unique, `password_hash` (bcrypt), `role_id` → roles, lockout fields, `deo_id`/`employee_id` legacy |
| `role_module_permissions` | unique `(role_id, module_id, permission_id)`, `is_granted` |

`lib/database/tables/sync_tables.dart`

| Table | Notes |
|---|---|
| `sessions` | `token_hash` unique = SHA-256(raw token), `expires_at`, `invalidated_at` |
| `audit_logs` | who/what/target + old/new JSON |
| `sync_log` | sync run history: type, direction, status, counts |
| `app_settings` | key/value, unique `(user_id, setting_key)`; `user_id` null = global |

`lib/database/tables/loyalty_tables.dart`

| Table | Notes |
|---|---|
| `products` | `code` unique (PROD-00x), name, category, emoji, price, `is_active` |
| `campaigns` | `code` unique, `required_stamps` (default 10), `holiday_stamps` (how many of those slots are Holiday slots, default 0), `max_cards_per_customer` (nullable = no limit), `eligible_product_codes` **CSV — empty means every product**, `tag`, `starts_at`/`ends_at`, `display_order` |
| `stamp_cards` | unique `(user_id, campaign_id, cycle)`; `stamps_collected`, `holiday_count` (how many of those sit in Holiday slots; the rest are regular), `card_number` (ghelpdesk's 1-based position among all the member's cards for the program, nullable), `completed_at`, `redeemed_at`, `remote_card_id` (ghelpdesk's `stamp_cards.id` — the sync identity), `redeem_token` (signed code for staff to scan, full unredeemed cards only) |
| `loyalty_transactions` | unique `reference`, unique `scan_token`; `type` `earn`/`redeem`; `points` +1 / −requiredStamps; `occurred_at` |

The **unique index on `scan_token`** is the enforcement that a QR code cannot be replayed —
the check inside `earnStamp` exists only to produce a friendlier message.

Sync-status constants (`loyalty_tables.dart`): `0 pending`, `1 synced`, `2 syncing`,
`3 failed`. RBAC tables carry the same `sync_status` + `is_deleted` pair.

## Migrations

`schemaVersion = 10`.

- `from < 10` adds `loyalty_transactions.note` (nullable): the reason a cashier gave when
  taking stamps back ("Deduct Stamps" in the LINK portal). Only a stamp correction carries
  one — it syncs as an `earn` with negative points, `product_name` "Stamp correction".
- `from < 9` adds `campaigns.holiday_stamps` (default 0), `campaigns.max_cards_per_customer`
  (nullable), `stamp_cards.holiday_count` (default 0) and `stamp_cards.card_number`
  (nullable) — Holiday slots and the per-member card cap. Additive only; existing rows read as
  a plain card until the next pull. Each `ADD COLUMN` is skipped if the column already exists
  (`_addColumnIfMissing`), because the migration tests replay older steps on a database
  `createAll()` already built at the current version, and the `from < N` guards then run this
  step too. Guarded by `test/unit/holiday_slots_migration_test.dart` (a real v8-shaped
  database upgraded to v9).
- `from < 8` deletes the bootstrap `admin` login earlier builds seeded
  (`AppDatabase.legacySeededAdminId`, the same `uuid.v5(NAMESPACE_URL, 'user_admin')` the seed
  used) and its `sessions` rows first, so a device signed in as `admin` cannot resume that
  session. Only that fixed id is matched. Guarded by `test/unit/seeded_admin_removal_test.dart`.

- `from < 4` drops the retired DTR tables (`offline_dtr_logs`, `cached_dtr_schedules`,
  `cached_attendance_logs`) and creates the four loyalty tables. Those legacy tables held
  only cached server data plus an upload queue, so dropping them lost nothing re-derivable.
- `from < 7` deletes `stamp_cards` rows that are closed (`redeemed_at IS NOT NULL`), have no
  `remote_card_id`, are still `sync_status = 0`, and that **no** `loyalty_transactions` row
  references — the card half of the same phantom cleanup. The `NOT EXISTS` guard is
  deliberate: orphaning real history would be worse than leaving a duplicate visible.
- `from < 6` deletes `loyalty_transactions` rows with `type = 'redeem'` and
  `sync_status = 0` — the phantom redemptions the retired on-device redeem path left behind,
  which double-counted against the real `SR-…` rows pulled from ghelpdesk. Scoped to
  redemptions on purpose (see CLAUDE.md), and it runs once at upgrade so it can only ever see
  rows written before redemption became server-authoritative.
- `from < 5` adds `stamp_cards.remote_card_id` and `stamp_cards.redeem_token`. Both are
  additive and nullable, so existing rows stay valid and are backfilled by the next progress
  pull. `remote_card_id` is what stops a redeemed card and its replacement — two cards for
  one campaign — from overwriting each other.

Bumping the schema means: edit the table class → add an `onUpgrade` branch → bump
`schemaVersion` → `dart run build_runner build --delete-conflicting-outputs`.

### Codegen versions (pinned on purpose, 2026-10-23)

Flutter 3.47 / Dart 3.13 broke the old stack: `analyzer` 7.6.0 crashed with `Missing
implementation of visitDotShorthandPropertyAccess` on Flutter's own sources and build_runner
then hung — after `--delete-conflicting-outputs` had already deleted all 10 `.g.dart` files.
Fixed in `pubspec.yaml`, where each pin carries its reason:

- **Drift is the only generator in use.** riverpod_generator, freezed, json_serializable and
  mockito (and their annotation packages) had no annotations anywhere but still ran on every
  file under the old analyzer, so they were removed.
- **`drift` / `drift_dev` held at 2.31.x** — the newest on `sqlite3` 2.x. drift ≥2.32 needs
  `sqlite3` 3.x, which retires `sqlite3_flutter_libs` and bundles SQLite through native build
  hooks: a packaging change for the Android/iOS builds that deserves its own release.
- **`analyzer` held below 10.** drift_dev 2.31 accepts analyzer 10, but there a class name in
  `references(Users, #id)` stops being an `Identifier` node: it warns "This parameter should be
  a simple class name" and **drops every foreign key** from the generated schema while the
  build still "succeeds". Analyzer 9 generates them correctly (it warns that the SDK language
  version is newer — harmless).

After any regeneration: `grep -c REFERENCES lib/database/app_database.g.dart` must be **17**.
When moving to drift ≥2.32, lift both pins together and re-check that count.

## Seeding

`SeedRunner.runIfNeeded()` (`lib/database/seeds/seed_runner.dart`) runs from Splash.

- It reads `app_settings['arch_reset_v7']`. If the value is not `'13'`, it **wipes every core
  table** (`_runReset`) and reseeds, then stores `'13'`.
  → Changing that literal is a deliberate "nuke the device DB on next launch" switch.
- Otherwise, if `db_initialized` is not set, it seeds without wiping.

Seed order: permissions → modules (parents, then children by code) → roles → full permission
matrix for ADMIN → products/campaigns → flags. **No user is seeded** (since 2026-09-28): every
login comes from the server.

Defaults created:
- Role `ADMIN`, fixed id `00000000-0000-0000-0000-000000000001`.
- ADMIN is granted every permission on every module (cartesian product).
- Modules seeded: `USER_MANAGEMENT`, `ROLE_MANAGEMENT`, `AUDIT_LOG` only. The loyalty screens
  are **not** module-gated.
- `products` / `campaigns` from `loyalty_seed.dart` via `insertOnConflictUpdate`.

Seeds use `customStatement` with explicit column lists rather than companions, so adding a
non-nullable column without a default breaks seeding — update the INSERT strings too.

## DAOs (`lib/database/daos/`)

`LoyaltyDao` (loyalty engine), `UserDao`, `RoleDao`, `PermissionDao`, `ModuleDao`,
`PermissionMatrixDao` (`resolveAllForUser`), `SessionDao`, `AuditLogDao`, `SettingsDao`.
All SQL belongs here — screens and use cases must not build queries inline.

`PermissionMatrixDao.resolveAllForUser` currently issues one query per matrix row to resolve
module and permission codes (N+1). Fine at seed scale (3 modules × 19 permissions); worth a
join if the module list grows.

## Mirror schema

`supabase/migrations/20260419130000_init_rbac_uuid.sql` is a Postgres mirror of the RBAC
tables. Its header names a different product ("Harbor Review Center") and nothing in the app
connects to Supabase — treat it as a reference artifact, not a live schema.
