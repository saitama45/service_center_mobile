import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/app_urls.dart';
import '../../../core/utils/external_link.dart';
import '../../../data/datasources/remote/account_remote_datasource.dart';
import '../../providers/auth_provider.dart';
/// Two confirmations, because this is the one irreversible action in the app
/// and the row that opens it sits one tap away from the rest of Profile.
///
///   1. [DeleteAccountStage.confirm]  — what closing the account costs. Nothing has
///      happened yet, and the plain-looking button is the one that keeps the
///      account.
///   2. [DeleteAccountStage.password] — re-enter the password. Not ceremony: the handset
///      may be unlocked and shared, so the tap alone must not be enough.
///
/// A mis-tap on the Profile row therefore reaches an explanation, never a
/// deletion — and never, as it used to, the web page straight away.
enum DeleteAccountStage { confirm, password }

class DeleteAccountDialog extends ConsumerStatefulWidget {
  const DeleteAccountDialog({super.key});

  @override
  ConsumerState<DeleteAccountDialog> createState() =>
      DeleteAccountDialogState();
}

class DeleteAccountDialogState extends ConsumerState<DeleteAccountDialog> {
  final _password = TextEditingController();
  DeleteAccountStage _stage = DeleteAccountStage.confirm;
  bool _obscured = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_password.text.isEmpty) {
      setState(() => _error = 'Enter your password to confirm.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    final outcome =
        await ref.read(authProvider.notifier).deleteAccount(_password.text);

    if (!mounted) return;

    switch (outcome) {
      case AccountDeleted():
        Navigator.pop(context, true);
      case AccountDeletionWrongPassword(:final message):
      case AccountDeletionRefused(:final message):
      case AccountDeletionFailed(:final message):
        setState(() {
          _busy = false;
          _error = message;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _stage == DeleteAccountStage.confirm ? _confirmStage() : _passwordStage();
  }

  /// Step 1 — no input and nothing destructive. "Continue" only advances.
  Widget _confirmStage() {
    return AlertDialog(
      title: const Text('Delete Account?', style: AppTextStyles.h2),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Closing your account deletes your personal data and signs you '
              'out on every device.',
              style: AppTextStyles.bodyMedium,
            ),
            const SizedBox(height: AppDimensions.sm),
            const Text(
              'Any unredeemed stamps and rewards are forfeited. This cannot be '
              'undone, and creating a new account later will not bring them '
              'back.',
              style: AppTextStyles.bodyMedium,
            ),
            const SizedBox(height: AppDimensions.sm),
            const Text(
              'Rewards you have already redeemed are financial records, so they '
              'are kept in a restricted archive for the retention period set '
              'out in our policy.',
              style: AppTextStyles.bodySmall,
            ),
            const SizedBox(height: AppDimensions.sm),
            InkWell(
              onTap: () => openExternalUrl(context, AppUrls.accountDeletion),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  'Read the full deletion policy',
                  style: TextStyle(
                    color: AppColors.caramel,
                    decoration: TextDecoration.underline,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Keep My Account'),
        ),
        TextButton(
          onPressed: () => setState(() => _stage = DeleteAccountStage.password),
          child: const Text('Continue',
              style: TextStyle(color: AppColors.danger)),
        ),
      ],
    );
  }

  /// Step 2 — re-authenticate, then the request goes out.
  Widget _passwordStage() {
    return AlertDialog(
      title: const Text('Confirm Deletion', style: AppTextStyles.h2),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your password to close your account. This takes effect '
              'immediately.',
              style: AppTextStyles.bodyMedium,
            ),
            const SizedBox(height: AppDimensions.md),
            TextField(
              controller: _password,
              enabled: !_busy,
              obscureText: _obscured,
              autofocus: true,
              autofillHints: const [AutofillHints.password],
              decoration: InputDecoration(
                labelText: 'Your password',
                errorText: _error,
                suffixIcon: IconButton(
                  icon: Icon(_obscured
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => _obscured = !_obscured),
                ),
              ),
              onSubmitted: _busy ? null : (_) => _submit(),
            ),
          ],
        ),
      ),
      actions: [
        // Back, not Cancel: changing your mind here should not throw away the
        // explanation you just read.
        TextButton(
          onPressed: _busy
              ? null
              : () => setState(() {
                    _stage = DeleteAccountStage.confirm;
                    _error = null;
                    _password.clear();
                  }),
          child: const Text('Back'),
        ),
        TextButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Delete My Account',
                  style: TextStyle(color: AppColors.danger)),
        ),
      ],
    );
  }
}
