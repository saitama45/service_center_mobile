# External Integrations

## HTTP API — `ApiClient`

[lib/data/datasources/remote/api_client.dart](../../lib/data/datasources/remote/api_client.dart)

- Base URL defaults to `https://support.tablegroup.com.ph`, overridable via
  `--dart-define=API_BASE_URL=...` (`String.fromEnvironment`) — no code edit needed to point at
  a local backend. **Android debug builds only** additionally get a network security config
  (`android/app/src/debug/`) permitting cleartext HTTP to `10.0.2.2`/`localhost`/`127.0.0.1`, so
  plain `http://` works against a local server; release builds are untouched
  (`usesCleartextTraffic="false"` in the main manifest still applies). To test the OTP feature
  (or anything else) against a local ghelpdesk instance before deploying:
  ```
  # ghelpdesk repo — bind 0.0.0.0 so the emulator's virtual NIC can reach it
  php artisan serve --host=0.0.0.0 --port=8010

  # this repo — 10.0.2.2 is the emulator's alias for the host machine
  flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8010
  ```
  A physical device on the same Wi-Fi needs the host's actual LAN IP instead of `10.0.2.2`
  (and that IP added to the debug `network_security_config.xml` domain list).
- 10-second timeout on every call; `get/post/put/delete` helpers, JSON in and out.
- Headers: `Content-Type`/`Accept: application/json`, plus
  `Authorization: Bearer <session_token>` read from secure storage when present.
- Uses `package:http`, which is a **transitive** dependency (not declared in `pubspec.yaml`).
  If dependencies are ever pruned this import breaks — declare `http:` explicitly if touched.

Endpoints called today: **`POST /api/login`**, **`POST /api/register`**,
**`GET /api/campaigns`**, **`GET /api/loyalty/qr-card`**, and **`GET /api/loyalty/my-cards`** are
live on ghelpdesk. Two OTP routes the client calls **do not exist on the server yet** —
`OtpRemoteDatasource` treats their 404 as "not deployed" rather than an error (see
[Authentication.md](Authentication.md#post-login-steps-otp--biometric)).

```json
// POST /api/login response
{ "token": "...", "user": { "id": 1, "first_name": "", "last_name": "",
                            "email": "", "roles": ["admin"] } }

// POST /api/register { name, email, phone?, password, device_name? }
// 201 — identical shape to /api/login above (auto-signs in on success).
// Server creates a linked ghelpdesk `customers` row (Stamps module CRM) +
// a `users` row with zero roles. See Api\RegisterController.

// GET /api/campaigns  (auth:sanctum)
// 200 { "campaigns": [ { "code": "SP-3", "name": "...", "description": "...",
//   "emoji": "🍂", "tag": "...", "required_stamps": 12,
//   "eligible_items_description": "...", "reward_description": "...",
//   "terms_and_conditions": "...", "starts_at": "...", "ends_at": "...",
//   "is_active": true, "display_order": 1, "updated_at": "..." } ] }
// Mirrors ghelpdesk's stamp_programs (the staff Loyalty Stamps module),
// strictly scoped to the CBTL entity server-side. See CatalogRemoteDatasource.

// GET /api/loyalty/qr-card  (auth:sanctum)
// 200 { "token": "LCARD1:123:abcdef0123456789abcdef01" }
// 422 { "message": "This account is not linked to a loyalty member record." }
// Signed, STATIC (never rotates) member code for the "My Member Code" screen.
// ghelpdesk staff scan this on the Stamps module's "Scan Customer" flow
// (StampController::resolveScan/scanAddStamp) to add a real stamp. See
// LoyaltyMemberRemoteDatasource + memberQrProvider + MemberQrCache (offline).

// GET /api/loyalty/my-cards  (auth:sanctum)
// 200 { "cards": [ { "code": "SP-3", "stamps_count": 4, "stamps_required": 12,
//   "status": "active" } ] }
// The member's REAL stamp progress (ghelpdesk stamp_cards), keyed by the same
// `code` the catalogue pull upserts local campaigns by. Pulled by
// SyncManager._pullProgress right after _pullCatalog, and only for entries
// whose program is CBTL-scoped — same reasoning as /api/campaigns.

// GET /api/loyalty/my-transactions  (auth:sanctum)
// 200 { "transactions": [ { "reference": "SE-42", "type": "earn", "points": 1,
//   "campaign_code": "SP-3", "product_name": null, "store_name": "...",
//   "occurred_at": "..." } ] }
// The individual-event counterpart to my-cards (ghelpdesk stamp_entries +
// stamp_redemptions) — my-cards alone only moves a card's running count, it
// never populates the History screen's transaction list. Redemption points
// are the FULL card cost (-stamps_required), not the reward item quantity,
// matching the local redeemReward convention. Pulled by
// SyncManager._pullTransactions, right after _pullProgress, upserted by
// `reference` into local loyalty_transactions.

// POST /api/otp/send  — NOT YET IMPLEMENTED SERVER-SIDE
// 200 { "destination": "j***@example.com", "expires_in": 300, "resend_after": 30 }

// POST /api/otp/verify { "code": "123456" }  — NOT YET IMPLEMENTED SERVER-SIDE
// 200 { "verified": true }
```

Full contracts (status codes, error shapes) are documented in the doc comments of
[otp_remote_datasource.dart](../../lib/data/datasources/remote/otp_remote_datasource.dart) and
[catalog_remote_datasource.dart](../../lib/data/datasources/remote/catalog_remote_datasource.dart).

`ApiClient` is available to any feature via `apiClientProvider`. The loyalty *transaction*
upload direction (stamps/redemptions pushed up) still has no server endpoint — see Sync below.

## Supabase — declared, not wired

`supabase/migrations/20260419130000_init_rbac_uuid.sql` mirrors the RBAC schema in Postgres
(UUID PKs, same table/column names). `SupabaseSyncDatasource` is a **stub**: `isOnline()`
works, `uploadPendingRecords()` and `downloadReferenceData()` are TODO no-ops, and
`isAuthenticated` returns `false`. No Supabase package is in `pubspec.yaml` and nothing
constructs the datasource. Treat both as design intent, not live integration.

## Sync

`SyncManager` (`lib/core/sync/sync_manager.dart`) reconciles in both directions:

- **Pull, step 1** (`_pullCatalog`, real) — `CatalogRemoteDatasource.fetchCampaigns()` →
  `GET /api/campaigns` → upserts local `campaigns` by `code` (explicit `DoUpdate(target:
  [campaigns.code])` — `insertOnConflictUpdate` resolves on the primary key `id`, which is
  useless here since `id` is a fresh UUID every call) and deactivates (never deletes) any local
  campaign the server didn't return, so the on-device demo seed disappears the first time a
  real sync succeeds.
- **Pull, step 2** (`_pullProgress`, real, needs a `userId`) —
  `LoyaltyMemberRemoteDatasource.fetchMyCards()` → `GET /api/loyalty/my-cards` → overwrites the
  local open `stamp_cards` row's `stampsCollected` (matched to a local campaign by `code`) for
  each returned card. This is what makes a stamp ghelpdesk staff just scanned in show up here.
  Runs AFTER step 1 (a remote card with no matching local campaign yet is skipped, retried next
  sync) and is skipped entirely if `sync()` wasn't given a `userId`.
- **Pull, step 3** (`_pullTransactions`, real, needs a `userId`) —
  `fetchMyTransactions()` → `GET /api/loyalty/my-transactions` → upserts local
  `loyalty_transactions` by `reference` (explicit `DoUpdate` target, same PK-vs-unique-key fix
  as step 1 — `reference` is the business key, not the row `id`). This is what actually
  populates the History screen — step 2 alone only moves a card's running count. Runs AFTER
  step 2 for the same reason step 2 runs after step 1: it needs a local campaign row (by
  `campaignCode`) to attach to, and links `stampCardId` to whichever local card step 2 just
  created/updated for that campaign. All three pull steps fire `onCatalogUpdated` (bumps
  `loyaltyRevisionProvider`) on a real change.
- **Push** — `_pushChanges()` only counts pending `loyalty_transactions` and logs —
  deliberately, so requests don't 404 and mark good rows failed; no upload endpoint exists yet.
  `pendingTransactionCount()` feeds the "pending sync" chip on Home. (Moot for earning now
  anyway — see the "server-authoritative" pitfall in CLAUDE.md.)

Triggered from: Splash (after a **resumed** session only — a fresh interactive login reaches
the dashboard through `biometric_screen.dart`'s `_finish()` instead, which triggers it
separately) and pull-to-refresh on Home/Campaigns/**Ledger** — all pass `userId:
ref.read(currentUserProvider)?.id` so steps 2–3 actually run. `isOfflineProvider`'s
offline→online trigger (in `app_providers.dart`) deliberately does NOT — it can't reach
`currentUserProvider` without a circular import (see the comment on `loyaltyRevisionProvider`
in that file), so a reconnect there only refreshes the catalogue; progress and history still
catch up on the next resume/refresh/login.

## Device plugins

| Plugin | Used for | Where |
|---|---|---|
| `flutter_secure_storage` | session token (Keystore / Keychain) | `secureStorageProvider`, auth use cases |
| `local_auth` | Face ID / fingerprint | `auth_flow_provider.dart`, `biometric_screen.dart` |
| `connectivity_plus` | online/offline stream, sync triggers | `app_providers.dart`, `SyncManager` |
| `device_info_plus` | `device_name` sent to `/api/login` | `LoginUseCase._resolveDeviceName` |
| `qr_flutter` | renders the static signed member QR | `scan_screen.dart` |
| `path_provider` | resolves the SQLite file location | `app_database.dart` |
| `bcrypt` | pure-Dart password hashing (no native bindings) | `BcryptUtil`, `LoginUseCase` |
| `crypto` | SHA-256 token hashing | `TokenUtil`, `permission_provider.dart` |
| `uuid` | client-generated PKs, deterministic v5 seed ids | tables, `SeedRunner` |

## Declared but currently unused

`google_maps_flutter`, `geolocator`, `camera`, `image_picker`, `image`, `screenshot`,
`url_launcher`, `cached_network_image`, `flutter_svg` — carried over from the bridge-inspection
feature set. `assets/data/defect_rules.json` is likewise a leftover from that era. Removing
them is safe only after confirming no screen imports them; `google_maps_flutter_ios` is what
forces the **iOS minimum deployment target of 14.0** (see the commit history).

## Platform notes

- Android: `flutter_launcher_icons` generates `launcher_icon` from
  `assets/images/app_logo_v2.png`, `min_sdk 21`.
- iOS: minimum deployment target 14.0.
- `start_emulator.ps1` launches the `Pixel_6_API_35` AVD.
- Fonts are bundled locally in `assets/fonts/` (DMSans, PlayfairDisplay, DMMono) — no network
  font loading.
