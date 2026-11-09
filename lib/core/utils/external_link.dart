import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens [url] in the device browser. With [preferApp], an app that owns the
/// link (the Play Store or App Store for a store listing) is tried first,
/// since a browser would leave the member on a page they can't update from.
///
/// A tap that silently does nothing is worse than an error, so a failed launch
/// (no browser, or the platform refusing the scheme) surfaces as a SnackBar
/// instead of being swallowed.
Future<void> openExternalUrl(
  BuildContext context,
  Uri url, {
  bool preferApp = false,
}) async {
  final messenger = ScaffoldMessenger.of(context);

  final opened =
      (preferApp && await _launch(url, LaunchMode.externalNonBrowserApplication)) ||
          await _launch(url, LaunchMode.externalApplication);

  if (!opened) {
    messenger.showSnackBar(
      SnackBar(content: Text('Could not open ${url.toString()}')),
    );
  }
}

Future<bool> _launch(Uri url, LaunchMode mode) async {
  try {
    return await launchUrl(url, mode: mode);
  } catch (_) {
    return false;
  }
}
