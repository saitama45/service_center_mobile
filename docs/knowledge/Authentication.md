# Authentication & Authorization

## Token handling

- The raw session token (a Sanctum-style JWT from the server) is stored **only** in
  `flutter_secure_storage` under key `session_token` — Android `EncryptedSharedPreferences`,
  iOS Keychain `first_unlock`.
- The database stores **only `SHA-256(token)`** in `sessions.token_hash` (unique).
  `TokenUtil.hashToken` is the single implementation; `permission_provider.dart` has a private
  `_hashToken` that mirrors it — keep the two identical if either changes.
- `TokenUtil.generateSecureToken()` (256-bit, base64url) exists for locally-issued tokens; the
  current remote-first login uses the server's token instead.

## Sign-in

`LoginUseCase` ([lib/domain/usecases/auth/login_usecase.dart](../../lib/domain/usecases/auth/login_usecase.dart)) is remote-first:

1. `POST /api/login` with `{ email, password, device_name }`, 10s timeout, against
   `https://support.tablegroup.com.ph`. The username field is sent as `email`.
2. **200** → store the token, bcrypt-hash the plaintext password into `users.password_hash`
   (this is what makes later offline logins possible), upsert the user, invalidate previous
   sessions, create a new session row keyed by the token hash.
   The upsert goes through `UserDao.upsertUserForLogin`, which keys on **`username`** (the
   email), not on `users.id`: the server's id is not stable across accounts — staff can delete
   a member in ghelpdesk and the member can sign up again with the same email and get a new
   id. The stale local row is re-pointed at the new id and its old sessions invalidated, so a
   login always leaves exactly one row per email.
3. **401 / 422** → `InvalidCredentialsFailure`, surfacing the server's `message`.
4. **Any exception (unreachable)** → `_attemptLocalLogin`.

Offline path requirements, in order: a cached user exists with a usable bcrypt hash (not the
`REMOTE_AUTH` legacy marker) → account active → not locked → `lastLoginAt` within **14 days**
→ `BCrypt.checkpw` passes. Failure increments `failed_login_count`; **5** failures lock the
account for **30 minutes**. `LoginSuccess.isOffline` is set so the UI can say so.

If no usable offline record exists, the result is a `NetworkFailure` (not invalid-credentials)
so the UI shows "could not connect".

## Sign-up

`RegisterUseCase` (same file) `POST`s `/api/register`; ghelpdesk answers with the identical
`{ token, user, roles }` payload as `/api/login`, so success is handed straight to
`_handleRemoteSuccess` — same local row, same session, same OTP/biometric steps after.

Once the server has answered **200/201 the account exists**, so nothing after that point may
be reported as a connection problem. Only the HTTP call itself yields `NetworkFailure`; a
failure while storing the account locally returns an `UnexpectedFailure` that says the account
was created and to sign in. Getting this wrong is what made a re-registration show "Could not
connect to the server" while the member's account had in fact just been created — the retry
they were being invited to make could only ever come back "the email has already been taken".

## Session restore

`CheckSessionUseCase`: read raw token → hash → `sessionDao.findValidSession(hash)` (not
expired, not invalidated) → load user → reject inactive users. Any failure deletes the stored
token. Runs from Splash via `authProvider.checkSession()`.

`LogoutUseCase`: invalidate the session row, delete the secure-storage token, write an audit
log entry. `AuthNotifier.logout()` additionally invalidates `userPermissionsProvider` and
resets `postLoginStepProvider`.

## Post-login steps (OTP → biometric)

`postLoginStepProvider` (`PostLoginStep.otp | biometric | done`) gates the router: while the
step is not `done`, every route redirects to `/otp` or `/biometric`; once done, those two
screens redirect away. `beginVerification({required bool offline})` records whether the
password step itself was checked offline — `OtpController` uses that, not live connectivity,
to pick a channel.

**The OTP step is a real two-factor check with two channels** ([auth_flow_provider.dart](../../lib/presentation/providers/auth_flow_provider.dart)):

- **Email (online)** — `OtpRemoteDatasource` calls `POST /api/otp/send` /
  `POST /api/otp/verify`. The code is generated, hashed, expired and attempt-limited entirely
  server-side; the device never sees or checks the value. **These routes do not exist on
  `support.tablegroup.com.ph` yet** — until deployed, `send()`/`verify()` get a 404, which
  `OtpController` reports as `OtpSendUnsupported`/`OtpVerifyUnsupported`.
- **Authenticator app (offline, or as an online fallback)** — `TotpUtil` is a from-scratch
  RFC 6238 implementation (HMAC-SHA1, 6 digits, 30s step, ±1 step drift window) verified
  against a per-user secret in `TotpSecretStore` (`flutter_secure_storage`, keyed by user id —
  never in Drift). Members enrol from Profile → Authenticator App
  (`AuthenticatorSetupScreen`), which shows a `qr_flutter` QR of the `otpauth://` URI and
  writes nothing to the keystore until a code the app actually produced is typed back
  (`AuthenticatorActions.confirmEnrolment`).

`OtpController.issue()` picks the channel:

1. **Offline login** (`beginVerification(offline: true)`) — authenticator if enrolled,
   otherwise skip straight to biometric (agreed behaviour: no second factor exists on this
   device, and the offline path is already capped at a 14-day cached session).
2. **Online login** — request an emailed code. If the server has no OTP routes yet
   (`OtpSendUnsupported`) or is unreachable (`OtpSendUnreachable`), fall back to the
   authenticator channel when enrolled; otherwise skip (routes missing,
   `OtpPolicy.allowSkipWhenServerHasNoOtp = true`) or block (genuinely unreachable, no
   authenticator either).

⚠ **`OtpPolicy.allowSkipWhenServerHasNoOtp`** (in `auth_flow_provider.dart`) must be flipped to
`false` once `/api/otp/send` + `/api/otp/verify` are deployed — otherwise a real outage on a
server that *should* have the routes looks identical to "not deployed yet" and the step quietly
skips instead of blocking.

Biometrics use `local_auth`. `biometricAvailableProvider` checks device support +
`canCheckBiometrics` + at least one enrolled biometric. Opt-in is persisted in `app_settings`
under `biometric_enabled` (`'1'`/`'0'`) via `BiometricActions.setEnabled`, and toggled from
Profile. `authenticate()` uses `biometricOnly: true, stickyAuth: true`.

## Authorization (RBAC)

Model: **role × module × permission** in `role_module_permissions`. There is no per-user
override table — the doc comment on `ResolvePermissionUseCase` still describes a three-step
resolution with `user_module_permission_overrides`, but `resolveAllForUser` implements only
two steps:

1. row in `role_module_permissions` for the user's role → use its `is_granted` (source `role`)
2. no row → **denied** (`PermissionCache.check` defaults to `false`)

Flow: `userPermissionsProvider` → `ResolvePermissionUseCase` → `PermissionMatrixDao
.resolveAllForUser` → `PermissionCache.fromResolved`. The cache keys on
`'MODULE_CODE:PERMISSION_CODE'` and also records the source.

Three enforcement points, all reading the same cache:
- **Router** — `_routeGuards` map plus two regexes in `app_router.dart` (edit-user, edit-role).
  A denied route redirects to `/dashboard`. Note the guards key on `/dashboard/users` etc.
- **`PermissionGate` widget** — hides or replaces a subtree.
- **`AppDrawer`** — builds its module list from `activeModulesProvider` ∩ the cache.

Codes live in `lib/core/constants/module_codes.dart` (`USER_MANAGEMENT`, `ROLE_MANAGEMENT`,
`AUDIT_LOG`) and `permission_codes.dart` (19 codes across DATA/ACTION/WORKFLOW/SYSTEM).
**They must match the seed data** — a typo silently yields "denied" everywhere.

**Always `ref.invalidate(userPermissionsProvider)` after changing the matrix or a user's role.**

## Known gap

Remote login sets `users.role_id` to the role **name** returned by the server
(`userJson['roles'][0]`, e.g. `"user"`), not a `roles.id`. No matrix rows match that value, so
a server-authenticated user resolves to an **empty** `PermissionCache` — every admin module is
hidden and every guarded route redirects. Only the seeded offline `admin` (role UUID
`00000000-0000-0000-0000-000000000001`) currently resolves permissions. Fixing this means
mapping the server role name to a local role row (`roleDao.getRoleByCode`) during
`_handleRemoteSuccess`.

## Password rules

`ChangePasswordUseCase` + `BcryptUtil`. Policy (per `AppStrings.passwordTooWeak`): at least 8
characters, 1 uppercase, 1 number, 1 special character. The seeded admin password is
`Admin@2026!` and `app_settings['admin_password_changed']` starts at `'0'`.
