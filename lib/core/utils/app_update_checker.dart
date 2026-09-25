import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart';

/// Prompts the member to install a newer Play Store build of the app.
///
/// Uses Google Play's in-app update API, so the prompt is Play's own UI and
/// only works on installs that came from the Play Store (any track, including
/// internal/closed testing). Sideloaded APKs, debug runs and iOS are skipped;
/// Play reports those as errors, which are swallowed here — an update check
/// must never get in the way of opening the app.
///
/// Immediate (full-screen) updates are preferred, so a tester can't keep
/// using a stale build by accident; flexible (background download) is the
/// fallback when Play doesn't allow immediate for this install.
class AppUpdateChecker {
  AppUpdateChecker._();

  /// A member who declines is asked again on a later resume, but not on every
  /// app switch in between.
  static const _declineCooldown = Duration(hours: 1);

  static bool _running = false;
  static DateTime? _declinedAt;

  static Future<void> check() async {
    if (kIsWeb || !Platform.isAndroid || _running) return;
    final declinedAt = _declinedAt;
    if (declinedAt != null &&
        DateTime.now().difference(declinedAt) < _declineCooldown) {
      return;
    }

    _running = true;
    try {
      final info = await InAppUpdate.checkForUpdate();

      // A flexible update finished downloading while the app was in the
      // background — install it now (Play restarts the app).
      if (info.installStatus == InstallStatus.downloaded) {
        await InAppUpdate.completeFlexibleUpdate();
        return;
      }

      // An immediate update was interrupted (app killed mid-install) — Play
      // expects it to be resumed.
      if (info.updateAvailability ==
          UpdateAvailability.developerTriggeredUpdateInProgress) {
        await InAppUpdate.performImmediateUpdate();
        return;
      }

      if (info.updateAvailability != UpdateAvailability.updateAvailable) {
        return;
      }

      if (info.immediateUpdateAllowed) {
        _record(await InAppUpdate.performImmediateUpdate());
      } else if (info.flexibleUpdateAllowed) {
        final result = await InAppUpdate.startFlexibleUpdate();
        _record(result);
        if (result == AppUpdateResult.success) {
          await InAppUpdate.completeFlexibleUpdate();
        }
      }
    } catch (e) {
      debugPrint('AppUpdateChecker: skipped, $e');
    } finally {
      _running = false;
    }
  }

  static void _record(AppUpdateResult result) {
    if (result == AppUpdateResult.userDeniedUpdate) {
      _declinedAt = DateTime.now();
    }
  }
}
