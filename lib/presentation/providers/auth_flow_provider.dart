import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../../core/utils/totp_util.dart';
import '../../data/datasources/local/totp_secret_store.dart';
import '../../data/datasources/remote/otp_remote_datasource.dart';
import 'app_providers.dart';

/// Where the member is in the post-password steps of signing in.
enum PostLoginStep {
  /// Password accepted, one-time code not yet verified.
  otp,

  /// Code verified, biometric enrolment not yet offered.
  biometric,

  /// Fully signed in.
  done,
}

/// Tracks the OTP → biometric hand-off after a successful password login.
///
/// The router reads this to keep a half-authenticated session out of the app.
final postLoginStepProvider =
    StateNotifierProvider<PostLoginStepNotifier, PostLoginStep>((ref) {
  return PostLoginStepNotifier();
});

class PostLoginStepNotifier extends StateNotifier<PostLoginStep> {
  PostLoginStepNotifier() : super(PostLoginStep.done);

  bool _wasOfflineLogin = false;

  /// True when the password was checked against the local bcrypt hash because
  /// the server was unreachable. The OTP step reads this to pick its channel:
  /// an offline login can only be verified by an authenticator app.
  bool get wasOfflineLogin => _wasOfflineLogin;

  /// Call right after a password login succeeds.
  void beginVerification({required bool offline}) {
    _wasOfflineLogin = offline;
    state = PostLoginStep.otp;
  }

  void otpVerified() => state = PostLoginStep.biometric;

  void complete() => state = PostLoginStep.done;

  /// Session ended — the next login starts the steps again.
  void reset() {
    _wasOfflineLogin = false;
    state = PostLoginStep.done;
  }
}

// ── One-time code ─────────────────────────────────────────────────────────────

/// Which factor is being checked on the OTP screen.
enum OtpChannel {
  /// A code generated on the server and emailed to the member. The strong
  /// path — the device never sees the expected value.
  email,

  /// RFC 6238 TOTP from Google Authenticator or similar, verified against a
  /// secret in the platform keystore. The only path that works with no
  /// network, and only as strong as the device's secure storage.
  authenticator,
}

/// What the screen should do once [OtpController.issue] resolves.
enum OtpIssueOutcome {
  /// A code is expected — show the digit boxes.
  ready,

  /// No second factor applies to this sign-in; go straight to biometrics.
  skipped,

  /// Verification is required but cannot proceed. Read `OtpState.blocker`.
  blocked,
}

/// Deployment-level decisions about how strict the second factor is.
abstract class OtpPolicy {
  /// When the server answers `404`/`501` on the OTP routes, this deployment
  /// simply has no email second factor yet, so an online sign-in continues
  /// without one (an authenticator secret is still preferred if enrolled).
  ///
  /// **Flip this to `false` once `/api/otp/send` and `/api/otp/verify` are
  /// deployed on `support.tablegroup.com.ph`.** From that point a missing
  /// route means something is broken, and sign-in should stop rather than
  /// quietly drop a factor. Until then, leaving it `true` is what keeps the
  /// app usable against today's server.
  static const bool allowSkipWhenServerHasNoOtp = true;

  /// Failed authenticator codes tolerated before the member has to sign in
  /// again. The email channel's counter lives on the server.
  static const int maxAuthenticatorAttempts = 5;

  /// Label shown in the authenticator app's entry list. "TAS Service Center"
  /// is reserved for ghelpdesk ticket mail — this is the separate loyalty
  /// app, so it gets the member-facing brand name instead (matches the
  /// email OTP sender name, see `OtpCodeMail` in the ghelpdesk backend).
  static const String issuer = 'Coffee Bean & Tea Leaf';
}

class OtpState {
  const OtpState({
    this.isIssuing = false,
    this.isVerifying = false,
    this.channel,
    this.destination,
    this.expiresAt,
    this.resendAfter = const Duration(seconds: 30),
    this.attemptsRemaining,
    this.error,
    this.blocker,
    this.degraded,
    this.hasAuthenticator = false,
    this.offlineLogin = false,
  });

  /// A code is being requested from the server.
  final bool isIssuing;

  /// An entered code is being checked.
  final bool isVerifying;

  final OtpChannel? channel;

  /// Masked address the server mailed, for the email channel only.
  final String? destination;

  /// When the emailed code stops working. Null for the authenticator channel,
  /// whose codes roll on their own 30-second schedule.
  final DateTime? expiresAt;

  final Duration resendAfter;

  /// Attempts left before the member is turned away. Null when unknown
  /// (the server did not say).
  final int? attemptsRemaining;

  /// Recoverable — a wrong code. The member can try again.
  final String? error;

  /// Unrecoverable for this sign-in. The screen shows this instead of the
  /// digit boxes.
  final String? blocker;

  /// Set when the flow fell back to a weaker or different channel than
  /// intended, so the screen can say why rather than silently switching.
  final String? degraded;

  /// Whether this member has an authenticator secret on this device — drives
  /// whether "Use authenticator app instead" can be offered on the email
  /// channel.
  final bool hasAuthenticator;

  /// Whether the password step itself was checked offline. Email is never
  /// offered while this is true (there is no connection to send it over).
  final bool offlineLogin;

  bool get isExpired {
    final at = expiresAt;
    return at != null && DateTime.now().isAfter(at);
  }

  /// On the authenticator channel, online, there's always an email fallback
  /// to offer — enrolled or not, the server can still mail a code.
  bool get canSwitchToEmail =>
      channel == OtpChannel.authenticator && !offlineLogin;

  /// On the email channel, switching back needs an actual secret to check
  /// against.
  bool get canSwitchToAuthenticator =>
      channel == OtpChannel.email && hasAuthenticator;

  OtpState copyWith({
    bool? isIssuing,
    bool? isVerifying,
    OtpChannel? channel,
    String? destination,
    DateTime? expiresAt,
    Duration? resendAfter,
    int? attemptsRemaining,
    String? error,
    String? blocker,
    String? degraded,
    bool? hasAuthenticator,
    bool? offlineLogin,
    bool clearError = false,
    bool clearBlocker = false,
    bool clearDegraded = false,
  }) {
    return OtpState(
      isIssuing: isIssuing ?? this.isIssuing,
      isVerifying: isVerifying ?? this.isVerifying,
      channel: channel ?? this.channel,
      destination: destination ?? this.destination,
      expiresAt: expiresAt ?? this.expiresAt,
      resendAfter: resendAfter ?? this.resendAfter,
      attemptsRemaining: attemptsRemaining ?? this.attemptsRemaining,
      error: clearError ? null : (error ?? this.error),
      blocker: clearBlocker ? null : (blocker ?? this.blocker),
      degraded: clearDegraded ? null : (degraded ?? this.degraded),
      hasAuthenticator: hasAuthenticator ?? this.hasAuthenticator,
      offlineLogin: offlineLogin ?? this.offlineLogin,
    );
  }
}

/// Drives the six-digit step between the password and the app.
///
/// Two real factors:
///
/// * **Authenticator app** — an RFC 6238 code checked against a secret held
///   in the platform keystore. Instant, no network involved. This is the
///   **default whenever a secret is enrolled**, online or offline — it's
///   faster and stronger than email (email OTP is only as safe as the
///   member's inbox, and a real SMTP round trip measured 10–25s in testing).
/// * **Email** — asks the server to mail a code, then asks the server to
///   check it. The code is never generated or validated on the device.
///   This is the fallback: the only option when no authenticator is
///   enrolled (online), and always reachable via "Use email instead" when
///   one is (online only — there's nothing to send it over offline).
///
/// The member can switch between the two mid-flow via [switchToEmail] /
/// [switchToAuthenticator] — see `OtpState.canSwitchToEmail` /
/// `canSwitchToAuthenticator`. Neither choice is remembered between sign-ins;
/// the default is recomputed fresh from enrolment + connectivity every time.
///
/// An offline sign-in with no enrolled authenticator has no second factor
/// available at all, so the step is skipped and the (already functional)
/// biometric step carries the local check — the behaviour agreed for the
/// offline-first flow.
final otpControllerProvider =
    StateNotifierProvider<OtpController, OtpState>((ref) {
  return OtpController(
    ref.read(otpRemoteDatasourceProvider),
    ref.read(totpSecretStoreProvider),
  );
});

class OtpController extends StateNotifier<OtpState> {
  OtpController(this._remote, this._secrets) : super(const OtpState());

  final OtpRemoteDatasource _remote;
  final TotpSecretStore _secrets;

  /// Cached for the authenticator channel so `verify` needs no round trip.
  String? _authenticatorSecret;

  /// Remembered so [switchToEmail] / a mid-flow retry know the sign-in's
  /// connectivity without the caller re-passing it.
  bool _offlineLogin = false;

  /// Requests (or selects) a code for this sign-in.
  ///
  /// [offlineLogin] is whether the password itself was checked offline —
  /// not merely whether connectivity looks down right now.
  Future<OtpIssueOutcome> issue({
    required String userId,
    required bool offlineLogin,
  }) async {
    state = const OtpState(isIssuing: true);
    _offlineLogin = offlineLogin;

    _authenticatorSecret = await _secrets.readSecret(userId);
    final hasAuthenticator = _authenticatorSecret != null;

    // Authenticator is the default whenever one is enrolled — faster and
    // stronger than email, and consistent whether or not this sign-in
    // reached the server. Email stays one tap away via switchToEmail().
    if (hasAuthenticator) {
      state = OtpState(
        channel: OtpChannel.authenticator,
        attemptsRemaining: OtpPolicy.maxAuthenticatorAttempts,
        hasAuthenticator: true,
        offlineLogin: offlineLogin,
      );
      return OtpIssueOutcome.ready;
    }

    if (offlineLogin) {
      debugPrint('OTP: offline sign-in with no authenticator — step skipped.');
      state = const OtpState();
      return OtpIssueOutcome.skipped;
    }

    return _issueEmail(hasAuthenticatorFallback: false);
  }

  /// Member tapped "Use email instead" while on the authenticator channel.
  /// A no-op if offline (nothing to send the email over) or already on
  /// email.
  Future<void> switchToEmail() async {
    if (!state.canSwitchToEmail) return;
    state = state.copyWith(isIssuing: true, clearError: true);
    await _issueEmail(hasAuthenticatorFallback: state.hasAuthenticator);
  }

  /// Member tapped "Use authenticator app instead" while on the email
  /// channel. Purely local — the secret is already cached, no round trip.
  void switchToAuthenticator() {
    if (!state.canSwitchToAuthenticator) return;
    state = OtpState(
      channel: OtpChannel.authenticator,
      attemptsRemaining: OtpPolicy.maxAuthenticatorAttempts,
      hasAuthenticator: true,
      offlineLogin: state.offlineLogin,
    );
  }

  /// Asks the server for an emailed code and lands on whichever state that
  /// implies. [hasAuthenticatorFallback] controls what happens if email
  /// turns out not to work: silently drop back to the authenticator when
  /// there is one, otherwise block or skip exactly as today.
  Future<OtpIssueOutcome> _issueEmail({required bool hasAuthenticatorFallback}) async {
    final outcome = await _remote.send();

    switch (outcome) {
      case OtpSendAccepted(:final destination, :final validity, :final resendAfter):
        state = OtpState(
          channel: OtpChannel.email,
          destination: destination,
          expiresAt: DateTime.now().add(validity),
          resendAfter: resendAfter,
          hasAuthenticator: hasAuthenticatorFallback,
          offlineLogin: _offlineLogin,
        );
        return OtpIssueOutcome.ready;

      case OtpSendThrottled(:final retryAfter, :final message):
        // The previous code is still live — let them type it.
        state = OtpState(
          channel: OtpChannel.email,
          resendAfter: retryAfter,
          error: message,
          hasAuthenticator: hasAuthenticatorFallback,
          offlineLogin: _offlineLogin,
        );
        return OtpIssueOutcome.ready;

      case OtpSendUnsupported(:final reason):
        debugPrint('OTP: $reason');
        if (hasAuthenticatorFallback) {
          state = OtpState(
            channel: OtpChannel.authenticator,
            attemptsRemaining: OtpPolicy.maxAuthenticatorAttempts,
            hasAuthenticator: true,
            offlineLogin: _offlineLogin,
            degraded: 'Email codes are not available on this server yet, so '
                'we switched back to your authenticator app.',
          );
          return OtpIssueOutcome.ready;
        }
        if (OtpPolicy.allowSkipWhenServerHasNoOtp) {
          state = const OtpState();
          return OtpIssueOutcome.skipped;
        }
        state = OtpState(blocker: reason);
        return OtpIssueOutcome.blocked;

      case OtpSendUnreachable(:final message):
      case OtpSendFailed(:final message):
        if (hasAuthenticatorFallback) {
          state = OtpState(
            channel: OtpChannel.authenticator,
            attemptsRemaining: OtpPolicy.maxAuthenticatorAttempts,
            hasAuthenticator: true,
            offlineLogin: _offlineLogin,
            degraded: '$message Switched back to your authenticator app.',
          );
          return OtpIssueOutcome.ready;
        }
        state = OtpState(blocker: message);
        return OtpIssueOutcome.blocked;
    }
  }

  /// Returns null when the code is accepted, otherwise a message to show.
  Future<String?> verify(String entered) async {
    final channel = state.channel;
    if (channel == null) return 'Request a code before verifying.';
    if (state.isVerifying) return null;

    state = state.copyWith(isVerifying: true, clearError: true);

    final String? failure = switch (channel) {
      OtpChannel.email => await _verifyEmail(entered),
      OtpChannel.authenticator => _verifyAuthenticator(entered),
    };

    state = state.copyWith(isVerifying: false, error: failure);
    return failure;
  }

  Future<String?> _verifyEmail(String entered) async {
    if (state.isExpired) {
      return 'That code has expired. Request a new one.';
    }

    final outcome = await _remote.verify(entered);

    switch (outcome) {
      case OtpVerifyAccepted():
        return null;

      case OtpVerifyRejected(:final message, :final attemptsRemaining):
        if (attemptsRemaining != null) {
          state = state.copyWith(attemptsRemaining: attemptsRemaining);
          if (attemptsRemaining > 0) {
            return '$message $attemptsRemaining '
                '${attemptsRemaining == 1 ? 'attempt' : 'attempts'} left.';
          }
        }
        return message;

      case OtpVerifyExpired(:final message):
        state = state.copyWith(expiresAt: DateTime.now());
        return message;

      case OtpVerifyUnsupported(:final reason):
        // The route vanished between send and verify — do not wave it through.
        debugPrint('OTP: $reason');
        state = state.copyWith(
            blocker: 'Verification is unavailable right now. Please sign in '
                'again in a moment.');
        return 'Verification is unavailable right now.';

      case OtpVerifyUnreachable(:final message):
      case OtpVerifyFailed(:final message):
        return message;
    }
  }

  String? _verifyAuthenticator(String entered) {
    final secret = _authenticatorSecret;
    if (secret == null) {
      return 'No authenticator is set up on this device.';
    }

    final left = state.attemptsRemaining ?? OtpPolicy.maxAuthenticatorAttempts;
    if (left <= 0) {
      return 'Too many attempts. Please sign in again.';
    }

    if (TotpUtil.verify(secret, entered)) {
      return null;
    }

    final remaining = left - 1;
    state = state.copyWith(attemptsRemaining: remaining);
    if (remaining <= 0) {
      state = state.copyWith(
          blocker: 'Too many incorrect codes. Please sign in again.');
      return 'Too many attempts. Please sign in again.';
    }
    return 'Incorrect code. $remaining '
        '${remaining == 1 ? 'attempt' : 'attempts'} left.';
  }

  /// Asks the server for a new emailed code. Only meaningful on the email
  /// channel — an authenticator code cannot be resent, it just rotates.
  Future<String?> resend() async {
    if (state.channel != OtpChannel.email) return null;

    state = state.copyWith(isIssuing: true, clearError: true);
    final outcome = await _remote.send();

    switch (outcome) {
      case OtpSendAccepted(:final destination, :final validity, :final resendAfter):
        state = OtpState(
          channel: OtpChannel.email,
          destination: destination ?? state.destination,
          expiresAt: DateTime.now().add(validity),
          resendAfter: resendAfter,
        );
        return null;

      case OtpSendThrottled(:final retryAfter, :final message):
        state = state.copyWith(
            isIssuing: false, resendAfter: retryAfter, error: message);
        return message;

      case OtpSendUnsupported(:final reason):
        state = state.copyWith(isIssuing: false, error: reason);
        return reason;

      case OtpSendUnreachable(:final message):
      case OtpSendFailed(:final message):
        state = state.copyWith(isIssuing: false, error: message);
        return message;
    }
  }

  void clearError() {
    if (state.error != null) state = state.copyWith(clearError: true);
  }

  /// Wipes anything held for the previous sign-in.
  void reset() {
    _authenticatorSecret = null;
    _offlineLogin = false;
    state = const OtpState();
  }
}

// ── Authenticator enrolment ───────────────────────────────────────────────────

/// Whether the signed-in member has an authenticator secret on this device.
///
/// Depends on the user id rather than reading the current user, so it can be
/// watched from the profile screen and invalidated after enrol/remove.
final authenticatorEnrolledProvider =
    FutureProvider.family<bool, String>((ref, userId) {
  return ref.read(totpSecretStoreProvider).isEnrolled(userId);
});

final authenticatorEnrolledAtProvider =
    FutureProvider.family<DateTime?, String>((ref, userId) {
  return ref.read(totpSecretStoreProvider).enrolledAt(userId);
});

final authenticatorActionsProvider = Provider<AuthenticatorActions>((ref) {
  return AuthenticatorActions(ref);
});

class AuthenticatorActions {
  AuthenticatorActions(this._ref);
  final Ref _ref;

  /// A candidate secret for the setup screen. Nothing is persisted until
  /// [confirmEnrolment] sees a code the member's app actually produced —
  /// so an abandoned setup cannot lock anybody out.
  String generateCandidateSecret() => TotpUtil.generateSecret();

  String provisioningUri({
    required String secret,
    required String account,
  }) {
    return TotpUtil.provisioningUri(
      base32Secret: secret,
      account: account,
      issuer: OtpPolicy.issuer,
    );
  }

  /// Saves [secret] only if [code] verifies against it. Returns null on
  /// success, otherwise a message to show.
  Future<String?> confirmEnrolment({
    required String userId,
    required String secret,
    required String code,
  }) async {
    if (!TotpUtil.verify(secret, code)) {
      return 'That code does not match. Check your authenticator app and, if '
          'it keeps failing, make sure the phone\'s clock is set automatically.';
    }
    await _ref.read(totpSecretStoreProvider).saveSecret(userId, secret);
    _ref.invalidate(authenticatorEnrolledProvider(userId));
    _ref.invalidate(authenticatorEnrolledAtProvider(userId));
    return null;
  }

  Future<void> remove(String userId) async {
    await _ref.read(totpSecretStoreProvider).deleteSecret(userId);
    _ref.invalidate(authenticatorEnrolledProvider(userId));
    _ref.invalidate(authenticatorEnrolledAtProvider(userId));
  }
}

// ── Biometrics ────────────────────────────────────────────────────────────────

final localAuthProvider = Provider<LocalAuthentication>((ref) {
  return LocalAuthentication();
});

/// Whether this device can actually do Face ID / fingerprint.
final biometricAvailableProvider = FutureProvider<bool>((ref) async {
  final auth = ref.read(localAuthProvider);
  try {
    final supported = await auth.isDeviceSupported();
    if (!supported) return false;
    final canCheck = await auth.canCheckBiometrics;
    if (!canCheck) return false;
    final enrolled = await auth.getAvailableBiometrics();
    return enrolled.isNotEmpty;
  } catch (e) {
    debugPrint('Biometrics: availability check failed: $e');
    return false;
  }
});

/// Whether the member has opted in. Persisted in app_settings.
final biometricEnabledProvider = FutureProvider<bool>((ref) async {
  final db = ref.read(appDatabaseProvider);
  final value = await db.settingsDao.getSetting('biometric_enabled');
  return value == '1';
});

final biometricActionsProvider = Provider<BiometricActions>((ref) {
  return BiometricActions(ref);
});

class BiometricActions {
  BiometricActions(this._ref);
  final Ref _ref;

  /// Prompts for a fingerprint / face scan.
  /// Returns null on success, otherwise a message to show.
  Future<String?> authenticate({
    String reason = 'Confirm it\'s you to continue',
  }) async {
    final auth = _ref.read(localAuthProvider);
    try {
      final ok = await auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
      return ok ? null : 'Biometric check was cancelled.';
    } catch (e) {
      debugPrint('Biometrics: authenticate failed: $e');
      return 'Biometric authentication is unavailable on this device.';
    }
  }

  Future<void> setEnabled(bool enabled) async {
    final db = _ref.read(appDatabaseProvider);
    await db.settingsDao.setSetting('biometric_enabled', enabled ? '1' : '0');
    _ref.invalidate(biometricEnabledProvider);
  }
}
