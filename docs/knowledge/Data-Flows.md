# Data Flows

## 1. App startup

```
main.dart
  ├─ ensureInitialized, orientation, status-bar style
  ├─ AppDatabase()                       (Drift opens app_database.sqlite lazily)
  └─ ProviderScope(overrides: appDatabaseProvider) → BmsApp → GoRouter → '/'  (Splash)

SplashScreen._initialize()
  ├─ seedRunnerProvider.runIfNeeded()    (see Database.md)
  ├─ authProvider.checkSession()         (secure storage → sessions row → UserEntity)
  └─ authenticated ? syncManager.sync() + go('/dashboard') : go('/login')
```

Splash navigates imperatively **and** the router redirect runs — both agree because
`checkSession()` has already settled `AuthState` before `context.go`.

## 2. Login

`LoginScreen` → `authProvider.login(username, password)` → `LoginUseCase.call`:

```
POST https://support.tablegroup.com.ph/api/login
     { email, password, device_name }        timeout 10s
  ├─ 200      → _handleRemoteSuccess
  │             ├─ store JWT in flutter_secure_storage['session_token']
  │             ├─ bcrypt-hash the plaintext password → users.password_hash
  │             │     (this is what enables the offline path later)
  │             ├─ userDao.upsertUser(...)   ⚠ role_id = role NAME from the server
  │             ├─ sessionDao.invalidateAllUserSessions(userId)
  │             └─ sessionDao.createSession(tokenHash: SHA-256(jwt))
  ├─ 401/422  → InvalidCredentialsFailure (server message surfaced)
  ├─ other    → UnexpectedFailure
  └─ throws   → _attemptLocalLogin  (network unreachable)
```

`_attemptLocalLogin` requires a cached user with a real bcrypt hash, active account, no active
lockout, and `lastLoginAt` within 14 days. Wrong password increments `failed_login_count`;
5 failures set `locked_until = now + 30min`.

On success `AuthNotifier` invalidates and awaits `userPermissionsProvider`, then sets
`AuthAuthenticated`. `LoginScreen` calls `postLoginStepProvider.beginVerification()`, which
forces the router to `/otp`.

## 3. Post-login verification

```
/otp        OtpController.issue()  → 6 random digits, 5-min validity, 5 attempts
            verify() OK → postLoginStepProvider.otpVerified() → /biometric
/biometric  local_auth prompt (or skip) → complete() → PostLoginStep.done → /dashboard
```

Logout resets the step so the next sign-in walks the flow again.

## 4. Earn a stamp (the core loop)

```
Home FAB → push('/scan')            (above the shell — nav bar hidden)

ScanScreen
  ├─ scanTokenProvider issues ScanToken.generate(userId)  → 'SC-<user6>-<8 hex bytes>'
  ├─ 1s ticker rotates the token every 30s (ScanToken.ttlSeconds)
  ├─ QrImageView renders token.value
  └─ member picks a campaign → _claim(progress)
        ├─ _pickEligibleProduct: campaign.eligibleProductCodes (CSV; empty = any product)
        └─ LoyaltyActions.earnStamp(campaignId, scanToken, productId, productName, storeName)

LoyaltyDao.earnStamp — one Drift transaction
  1. campaign exists / isActive / not past endsAt   → else LoyaltyException
  2. replay pre-check on scan_token                 → 'This code has already been used.'
  3. _openCard(userId, campaignId)                  → reuse open card, else insert cycle 1
  4. card already full                              → 'redeem your reward first'
  5. stamps_collected += 1; completed_at set when full; sync_status = pending
  6. insert loyalty_transactions row (type 'earn', points +1, reference TXN-XXXXXX,
     scan_token stored under a UNIQUE index ← the real replay guard)

→ revision bumped → home/campaigns/ledger providers refetch
→ token rotated (burned) → pushReplacement('/scan/success', extra: ScanSuccessArgs)
```

## 5. Redeem a reward

`LoyaltyDao.redeemReward` — one transaction:
1. Find the open card (`redeemed_at IS NULL`); reject if `stamps_collected < requiredStamps`.
2. Set `redeemed_at`, `sync_status = pending`.
3. Insert a `redeem` transaction with `points = -requiredStamps`, name
   `"<campaign> (Free Reward)"`.
4. **Insert a fresh card at `cycle + 1`** so collecting continues immediately — this mirrors
   a paper punch card and is why `stamp_cards` is unique on `(userId, campaignId, cycle)`.

## 6. Reads that feed the UI

| Provider | DAO call | Screen |
|---|---|---|
| `featuredCampaignProvider` | `getFeaturedProgress` — unlocked first, then highest progress, expired excluded | Home hero |
| `campaignProgressProvider` | `getCampaignProgress` — every active campaign + the member's open card | Home list, Rewards, Scan |
| `transactionsProvider` | `getTransactions` (limit 100, newest first) | History |
| `ledgerTotalsProvider` | `getLedgerTotals` — sums earn vs. abs(redeem) in Dart | History summary strip |
| `productsProvider` | `getProducts(activeOnly)` | Scan product picker |

`CampaignProgress` derives `stamps`, `remaining`, `progress`, `isUnlocked`, `isExpired` — use
it rather than recomputing from raw rows.

## 7. Connectivity & sync

`isOfflineProvider` streams `connectivity_plus`; on an offline→online edge it fires
`syncManagerProvider.sync()`.

`SyncManager.sync()` guards re-entry, checks online, then `_pushChanges()` — which today only
counts `loyalty_transactions` with `sync_status = 0` and logs. Nothing is uploaded: the
loyalty endpoints don't exist yet, and firing them would 404 and mark good rows failed.
`pendingTransactionCount()` drives the "pending sync" chip on Home.

When the API lands, implement the upload inside `SyncManager` — the queue semantics
(`loyaltySyncPending/Synced/Syncing/SyncFailed` in `loyalty_tables.dart`) are already correct.

## 8. Admin flows

User/role CRUD screens go through `user_management_provider.dart` /
`role_management_provider.dart` → `UserDao` / `RoleDao` / `PermissionMatrixDao`.
`PermissionMatrixScreen` writes with `setRolePermissionsBatch`, which deletes the role's rows
first (because `insertAllOnConflictUpdate` targets the PK, not the `(role, module, permission)`
unique key). Every such change must be followed by `ref.invalidate(userPermissionsProvider)`.
`AuditLogDao.logAction` records the mutation.
