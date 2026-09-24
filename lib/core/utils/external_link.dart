import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens [url] in the device browser.
///
/// A tap that silently does nothing is worse than an error, so a failed launch
/// (no browser, or the platform refusing the scheme) surfaces as a SnackBar
/// instead of being swallowed.
Future<void> openExternalUrl(BuildContext context, Uri url) async {
  final messenger = ScaffoldMessenger.of(context);

  var opened = false;
  try {
    opened = await launchUrl(url, mode: LaunchMode.externalApplication);
  } catch (_) {
    opened = false;
  }

  if (!opened) {
    messenger.showSnackBar(
      SnackBar(content: Text('Could not open ${url.toString()}')),
    );
  }
}
