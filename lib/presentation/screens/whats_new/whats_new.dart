import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/cbtl_button.dart';
import '../../../database/daos/settings_dao.dart';
import '../../providers/app_providers.dart';

/// This release's notes: the same file CI uploads to Play as "What's new", so
/// each release is written once. Members read it in the app on iOS as well,
/// which is why it must never call the app a beta (App Store Guideline 2.2).
final releaseNotesProvider = FutureProvider<String>(
  (ref) => rootBundle.loadString('distribution/whatsnew/whatsnew-en-US'),
);

/// Remembers which release this device has already been told about.
///
/// The key carries the version so each row is written once: `user_id` is NULL
/// here, and SQLite lets NULL repeat inside a unique key, so rewriting a row
/// would leave two and break the read.
class WhatsNewStore {
  WhatsNewStore(this._settings);

  final SettingsDao _settings;

  static String keyFor(String version) => 'whats_new_seen:$version';

  /// True only before the first seeding has written its marker, so this has
  /// to be read before `SeedRunner` runs.
  Future<bool> isFreshInstall() async =>
      (await _settings.getSetting('arch_reset_v7')) == null;

  Future<bool> isSeen(String version) async =>
      (await _settings.getSetting(keyFor(version))) != null;

  Future<void> markSeen(String version) async {
    if (await isSeen(version)) return;
    await _settings.setSetting(
        keyFor(version), DateTime.now().toUtc().toIso8601String());
  }
}

final whatsNewStoreProvider = Provider<WhatsNewStore>(
  (ref) => WhatsNewStore(ref.read(appDatabaseProvider).settingsDao),
);

/// A brand-new member has not updated from anything, so the release they
/// installed is recorded as already announced.
Future<void> skipWhatsNewForThisRelease(WidgetRef ref) async {
  try {
    final version = await ref.read(appVersionProvider.future);
    await ref.read(whatsNewStoreProvider).markSeen(version);
  } catch (e) {
    debugPrint('WhatsNew: could not record this release: $e');
  }
}

/// Shows this release's notes once. Failing to find them must never get in
/// the way of reaching the app, so any problem just skips the popup.
Future<void> showWhatsNewIfDue(BuildContext context, WidgetRef ref) async {
  try {
    final version = await ref.read(appVersionProvider.future);
    final store = ref.read(whatsNewStoreProvider);
    if (await store.isSeen(version)) return;

    final notes = (await ref.read(releaseNotesProvider.future)).trim();
    if (notes.isEmpty || !context.mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => WhatsNewDialog(version: version, notes: notes),
    );
    await store.markSeen(version);
  } catch (e) {
    debugPrint('WhatsNew: skipped: $e');
  }
}

class WhatsNewDialog extends StatelessWidget {
  const WhatsNewDialog({super.key, required this.version, required this.notes});

  final String version;
  final String notes;

  @override
  Widget build(BuildContext context) {
    final lines = notes
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty);

    return AlertDialog(
      backgroundColor: AppColors.creamyWhite,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Roasted Black ink on a California Cream tile, never caramel,
          // which reads at 1.8:1 on cream.
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.californiaCream,
              borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
            ),
            child: const Icon(Icons.auto_awesome_outlined,
                color: AppColors.roastedBlack, size: 22),
          ),
          const SizedBox(height: 14),
          Text(AppTextStyles.caps("What's new"), style: AppTextStyles.h2),
          const SizedBox(height: 4),
          Text(version, style: AppTextStyles.caption),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [for (final line in lines) _NoteLine(line)],
        ),
      ),
      actions: [
        CbtlButton(
          label: 'Got it',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

/// One line of the notes; those written as "- text" become bullets.
class _NoteLine extends StatelessWidget {
  const _NoteLine(this.line);

  final String line;

  @override
  Widget build(BuildContext context) {
    final isBullet = line.startsWith('- ');
    final text = Text(
      isBullet ? line.substring(2) : line,
      style: AppTextStyles.bodyMedium,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: isBullet
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 7, right: 10),
                  child: Icon(Icons.circle,
                      size: 6, color: AppColors.roastedBlack),
                ),
                Expanded(child: text),
              ],
            )
          : text,
    );
  }
}
