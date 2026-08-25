# Architectural Decisions & Pitfalls

## Decisions

**D1 — Offline-first, local SQLite as the source of truth.**
Every read and write hits Drift first; the network is an enhancement. This is why stamps can
be earned with no signal and why `sync_status` columns exist on every mutable table.

**D2 — Drift over raw sqflite.** Type-safe queries, generated companions, and DAO-scoped
accessors. Cost: a `build_runner` step after every schema change, and `*.g.dart` committed.

**D3 — Datetimes stored as ISO-8601 TEXT** (`build.yaml: store_date_time_values_as_text`).
Chosen for readability and for parity with the Postgres mirror. Raw SQL must not assume
integer epochs.

**D4 — Client-generated UUID PKs.** Rows created offline on different devices can merge
without key collisions. Seeded rows use deterministic **UUID v5** from their code so
re-seeding is idempotent.

**D5 — Ledger is the single source of truth for loyalty numbers.** Stamp counts, lifetime
stamps, and balances are all derived from `loyalty_transactions`; `stamp_cards.stamps_collected`
is a cached projection written in the same transaction.

**D6 — Redemption opens a new card at `cycle + 1`** instead of resetting the old one. Cards
stay immutable history, and `(user, campaign, cycle)` is unique.

**D7 — One-time rotating scan token, enforced by a unique index.** `ScanToken` rotates every
30 s; `loyalty_transactions.scan_token` is unique, so a screenshot or double-tap can never
grant a second stamp. The in-code check is only for a nicer error message.

**D8 — A single resolved `PermissionCache`, never ad-hoc permission queries.** Resolution runs
once per session in `userPermissionsProvider`; the router, `PermissionGate`, and the drawer
all read it. Deny-by-default: a missing matrix row means no access.

**D9 — Explicit `loyaltyRevisionProvider` instead of Drift streams.** One integer bump
refreshes every derived loyalty provider, keeping refresh points visible and cheap.

**D10 — Remote-first login with a bcrypt shadow hash.** The server is the authority, but a
bcrypt hash of the last successful password is stored locally so the same credentials work
offline for 14 days.

**D11 — Sync upload intentionally left unimplemented.** The loyalty API doesn't exist; firing
requests would 404 and mark valid rows failed. The queue is correct and waiting.

**D12 — `SeedRunner` reset switch.** A version string in `app_settings` (`arch_reset_v7`)
gates a full wipe-and-reseed, which let the schema churn hard during early development without
manual uninstalls.

## Pitfalls (verified against source)

**P1 — Stale admin route constants.**
`RouteName.users` = `/users`, `RouteName.roles` = `/roles`, `RouteName.auditLog` =
`/audit-log`, but the actual `GoRoute`s are nested under `/dashboard`. Screens and the guard
map hardcode `/dashboard/users`, `/dashboard/roles`, `/dashboard/audit-log`. Navigating with
those constants lands on the error page. `RouteName.comingSoon` is also unrouted.

**P2 — Empty permissions after a server login.**
`LoginUseCase._handleRemoteSuccess` sets `roleId = roleName` (e.g. `"user"`). No `roles.id`
matches, so `resolveAllForUser` returns nothing and the cache denies everything. Only the
seeded offline `admin` resolves. See Authentication.md for the fix sketch.

**P3 — Bumping `arch_reset_v7` wipes the device database.** Current expected value `'12'`
(note the setting *key* still says v7 — key and value are unrelated). Change it only when you
intend every installed device to lose local data on next launch.

**P4 — The OTP is not a second factor.** Generated, printed via `debugPrint`, and verified
entirely on-device.

**P5 — Seeds use handwritten `customStatement` INSERTs.** Adding a non-nullable column without
a default silently breaks seeding — the `SeedRunner` catch block swallows it and only
`debugPrint`s. If a fresh install has no admin user, look there first.

**P6 — `setRolePermissionsBatch` deletes before inserting** because
`insertAllOnConflictUpdate` targets the PK, not the `(role, module, permission)` unique key.
Don't "simplify" it back to a plain upsert — it produces duplicate rows.

**P7 — `resolveAllForUser` is N+1.** One module query and one permission query per matrix row.
Harmless at 3 modules × 19 permissions; convert to a join before adding many modules.

**P8 — Package name vs. product name.** `pubspec name: bms`, so all imports (including tests)
are `package:bms/...`, shared widgets are `Bms*`, the visible title is "TAS Service Center
(SC)", and the folder is `loyalty_campaign`. `README.md` describes it as a service-management
platform; `pubspec.yaml`'s description still says "Bridge Management System — DPWH". CLAUDE.md
is the accurate description.

**P9 — `package:http` is transitive**, not declared in `pubspec.yaml`, yet `ApiClient` imports
it directly.

**P10 — The Supabase migration is misnamed.** Its header says "Harbor Review Center (HRC)" and
nothing connects to Supabase. Reference only.

**P11 — Dead weight from the previous app.** `google_maps_flutter`, `geolocator`, `camera`,
`image_picker`, `screenshot`, `url_launcher`, `assets/data/defect_rules.json`,
`mobile-dtr-guide.md`, `db_backup.db*`, and `Runner.app.zip` (48 MB, committed) are all
leftovers. `google_maps_flutter_ios` is what pins the iOS deployment target to 14.0.

**P12 — `LoyaltyDao.resetMemberActivity` swallows errors** (`try/catch` + `debugPrint`) and
deletes all of a member's transactions and stamp cards. It is reachable from Profile.

**P13 — `ResolvePermissionUseCase`'s doc comment is stale**: it describes a
`user_module_permission_overrides` step that does not exist in the schema or the DAO.
