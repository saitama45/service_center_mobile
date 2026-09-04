import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';
import '../constants/app_text_styles.dart';

/// The scannable code, written out in full so it can be typed by hand.
///
/// Every QR in this app is scanned by ghelpdesk staff, and every one of those
/// staff-side inputs (Stamps → "Scan Customer QR" and "Scan Redeem QR") is an
/// ordinary text field — a scanner just types into it. So when a scanner
/// won't read a screen (cracked glass, low brightness, a lens that hates
/// backlit displays), the transaction is not lost: the cashier can read this
/// off the member's phone and key it in, and the server verifies the exact
/// same signature either way.
///
/// Shown as [SelectableText] with a copy button because the member may need
/// to send it rather than show it — and because a code you cannot select is a
/// code you cannot check character by character when someone mistypes it.
class BmsManualCode extends StatelessWidget {
  const BmsManualCode({
    super.key,
    required this.code,
    this.label = 'MANUAL ENTRY CODE',
    this.hint = 'If the scanner can\'t read the QR, staff can type this code '
        'in instead — it works exactly the same.',
  });

  final String code;
  final String label;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: AppColors.latte),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.keyboard_alt_outlined,
                  size: 14, color: AppColors.muted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(label,
                    style: AppTextStyles.label.copyWith(color: AppColors.muted)),
              ),
              _CopyButton(code: code),
            ],
          ),
          const SizedBox(height: AppDimensions.sm),
          SelectableText(
            code,
            // Wraps rather than ellipsising: a truncated code is useless, and
            // these run past the width of a phone.
            style: AppTextStyles.monoMedium.copyWith(letterSpacing: 0.4),
          ),
          const SizedBox(height: AppDimensions.sm),
          Text(hint, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}

class _CopyButton extends StatelessWidget {
  const _CopyButton({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
      onTap: () async {
        await Clipboard.setData(ClipboardData(text: code));
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Code copied.'),
            duration: Duration(seconds: 2),
            backgroundColor: AppColors.espresso,
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.copy_rounded, size: 13, color: AppColors.amber),
            const SizedBox(width: 4),
            Text('Copy',
                style: AppTextStyles.chip.copyWith(color: AppColors.amber)),
          ],
        ),
      ),
    );
  }
}
