# Architecture

Flutter 3.41 / Dart 3.11, offline-first, no backend of its own for loyalty data.
Package name is `bms`; import everything as `package:bms/...`.

## Layers

```
presentation/  screens + Riverpod providers        (UI, state, navigation)
    ↓
domain/        usecases + entities                 (auth, permission resolution)
    ↓
database/      Drift tables, DAOs, seeds           (the only SQL in the app)
data/          remote datasources (ApiClient)      (HTTP; used by auth only)
core/          constants, widgets, utils, sync     (cross-cutting)
```

The layering is loose by design: screens read DAOs directly through providers for loyalty
data (`loyaltyDaoProvider`), while auth goes through use cases. There is no repository layer
any more — `lib/data/repositories/` was deleted along with the DTR feature.

## State management — Riverpod 2

Singletons are declared in [lib/presentation/providers/app_providers.dart](../../lib/presentation/providers/app_providers.dart):
`appDatabaseProvider`, `secureStorageProvider`, `apiClientProvider`, `syncManagerProvider`,
`seedRunnerProvider`, `isOfflineProvider`, `activeModulesProvider`.

`appDatabaseProvider` is **overridden in `main.dart`** with an instance created before
`runApp`, so the database is open before the first frame. The provider's own factory is the
fallback used by widget-level construction.

Provider families by concern:

| Provider file | Owns |
|---|---|
| `auth_provider.dart` | `AuthState` (`AuthInitial/Loading/Authenticated/Unauthenticated/Error`), use-case providers |
| `auth_flow_provider.dart` | `PostLoginStep`, OTP controller, biometric availability/enable |
| `permission_provider.dart` | `userPermissionsProvider` → the single `PermissionCache` |
| `loyalty_provider.dart` | campaign progress, ledger, totals, products, `ScanToken`, `LoyaltyActions` |
| `user_management_provider.dart`, `role_management_provider.dart` | admin CRUD screens |

### The loyalty refresh convention

`loyalty_provider.dart` uses a `loyaltyRevisionProvider` (`StateProvider<int>`). Every derived
`FutureProvider` calls `ref.watch(loyaltyRevisionProvider)`, and every mutation in
`LoyaltyActions` increments it. This replaces watching four Drift streams and makes refresh
explicit. **Any new loyalty read provider must watch the revision, or it will go stale.**

### The permission cache convention

`userPermissionsProvider` is the *only* place permissions are resolved. After changing the
permission matrix or a user's role, call `ref.invalidate(userPermissionsProvider)` — screens
read through `PermissionGate` or `ref.watch`, never by querying the matrix directly.

## Navigation — go_router

`appRouterProvider` builds a `GoRouter` whose `refreshListenable` fires on `authProvider` and
`postLoginStepProvider` changes.

`redirect` runs, in order:
1. `/` and `/login` bypass the session requirement (authenticated users at `/login` are sent
   to `/dashboard`).
2. Unauthenticated → `/login`.
3. `PostLoginStep != done` → pinned to `/otp` or `/biometric`.
4. Verified users are bounced out of `/otp` and `/biometric`.
5. Static `_routeGuards` map and two regexes guard the admin routes against `PermissionCache`.

Shell layout — `StatefulShellRoute.indexedStack` with four branches:

| Branch | Root | Screen |
|---|---|---|
| 0 | `/dashboard` | Home (+ nested `users`, `roles`, `audit-log`) |
| 1 | `/dashboard/campaigns` | Rewards |
| 2 | `/dashboard/ledger` | History |
| 3 | `/dashboard/profile` | Profile (+ `change-password`) |

`/scan` and `/scan/success` sit **above** the shell so the bottom nav is hidden while the QR
code is displayed. `/scan/success` reads `ScanSuccessArgs` from `state.extra` and falls back
to `HomeScreen` when deep-linked without it.

## Theming

All visual tokens are constants — `AppColors` (espresso, cream, amber, latte, caramel, gold),
`AppDimensions`, `AppTextStyles`. Fonts: DMSans (body), PlayfairDisplay (display), DMMono
(numerals/IDs). The theme is built once in `app.dart::_buildTheme()`; screens should read from
`Theme.of(context)` or the constants rather than hardcoding colours.

## Code generation

Drift DAOs and the database use `part '*.g.dart'`, all committed. Regenerate with
`dart run build_runner build --delete-conflicting-outputs` after touching tables or DAOs.
`riverpod_generator`, `freezed`, and `json_serializable` are declared in `pubspec.yaml` but
are not currently used by any source file — providers are written by hand.
