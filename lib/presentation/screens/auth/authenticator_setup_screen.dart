import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/date_format_util.dart';
import '../../../core/utils/totp_util.dart';
import '../../../core/widgets/cbtl_app_bar.dart';
import '../../../core/widgets/cbtl_button.dart';
import '../../../core/widgets/cbtl_card.dart';
import '../../../core/widgets/confirmation_dialog.dart';
import '../../providers/auth_flow_provider.dart';
import '../../providers/auth_provider.dart';

/// Enrol or remove the Google-Authenticator-compatible TOTP secret used to
/// verify sign-in when the device has no connection to the server.
///
/// Enrolment is a scan-then-confirm flow: the candidate secret is shown as a
/// QR code, and nothing is written to the keystore until the member types
/// back a code their app actually generated from it. That way an abandoned
/// setup — closed mid-scan, or scanned into the wrong account — never leaves
/// a secret in place that the member cannot reproduce a code for.
class AuthenticatorSetupScreen extends ConsumerStatefulWidget {
  const AuthenticatorSetupScreen({super.key});

  @override
  ConsumerState<AuthenticatorSetupScreen> createState() =>
      _AuthenticatorSetupScreenState();
}

class _AuthenticatorSetupScreenState
    extends ConsumerState<AuthenticatorSetupScreen> {
  String? _candidateSecret;
  final _codeCtrl = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Not logged in')));
    }

    final enrolledAsync = ref.watch(authenticatorEnrolledProvider(user.id));

    return Scaffold(
      backgroundColor: AppColors.creamyWhite,
      // Members see no hamburger: the drawer's only unique content is the
      // admin module links.
      appBar: const CbtlAppBar(title: 'Authenticator App'),
      body: enrolledAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.roastedBlack)),
        error: (e, _) => Center(child: Text('Could not check enrolment: $e')),
        data: (enrolled) {
          if (enrolled && _candidateSecret == null) {
            return _EnrolledView(userId: user.id);
          }
          return _EnrollView(
            userId: user.id,
            email: user.email ?? user.username,
            candidateSecret: _candidateSecret,
            codeCtrl: _codeCtrl,
            error: _error,
            busy: _busy,
            onGenerate: () => setState(() {
              _candidateSecret = ref
                  .read(authenticatorActionsProvider)
                  .generateCandidateSecret();
              _error = null;
              _codeCtrl.clear();
            }),
            onConfirm: _confirm,
          );
        },
      ),
    );
  }

  Future<void> _confirm(String userId) async {
    final secret = _candidateSecret;
    if (secret == null || _codeCtrl.text.trim().length != 6) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    final error = await ref.read(authenticatorActionsProvider).confirmEnrolment(
          userId: userId,
          secret: secret,
          code: _codeCtrl.text.trim(),
        );

    if (!mounted) return;
    setState(() => _busy = false);

    if (error != null) {
      setState(() => _error = error);
      return;
    }

    setState(() {
      _candidateSecret = null;
      _codeCtrl.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Authenticator app connected.')),
    );
  }
}

// ── Not yet enrolled: generate → scan → confirm ─────────────────────────────

class _EnrollView extends ConsumerWidget {
  const _EnrollView({
    required this.userId,
    required this.email,
    required this.candidateSecret,
    required this.codeCtrl,
    required this.error,
    required this.busy,
    required this.onGenerate,
    required this.onConfirm,
  });

  final String userId;
  final String? email;
  final String? candidateSecret;
  final TextEditingController codeCtrl;
  final String? error;
  final bool busy;
  final VoidCallback onGenerate;
  final ValueChanged<String> onConfirm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final secret = candidateSecret;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(AppDimensions.gutter,
          AppDimensions.md, AppDimensions.gutter, AppDimensions.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CbtlCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Why set this up?', style: AppTextStyles.h3),
                const SizedBox(height: 6),
                Text(
                  'When your phone has no signal, we can\'t email you a code. '
                  'An authenticator app (Google Authenticator, Authy, Microsoft '
                  'Authenticator) generates codes on-device, so you can still '
                  'verify a sign-in offline.',
                  style:
                      AppTextStyles.bodyMedium.copyWith(color: AppColors.ink2),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimensions.md),
          if (secret == null)
            CbtlButton(
              label: 'Set Up Authenticator',
              isFullWidth: true,
              icon: Icons.qr_code_2,
              onPressed: onGenerate,
            )
          else ...[
            CbtlCard(
              child: Column(
                children: [
                  const Text('1. Scan this with your authenticator app',
                      style: AppTextStyles.h3, textAlign: TextAlign.center),
                  const SizedBox(height: AppDimensions.md),
                  // QR plate: pure white (the one place it is used, since
                  // scanners want the most contrast), Roasted Black modules
                  // and outline.
                  Container(
                    padding: const EdgeInsets.all(AppDimensions.md - 2),
                    decoration: BoxDecoration(
                      color: AppColors.pureWhite,
                      borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                      border:
                          Border.all(color: AppColors.roastedBlack, width: 1.5),
                    ),
                    child: QrImageView(
                      data: ref.read(authenticatorActionsProvider).provisioningUri(
                            secret: secret,
                            account: email ?? userId,
                          ),
                      version: QrVersions.auto,
                      size: 188,
                      backgroundColor: AppColors.pureWhite,
                      eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: AppColors.roastedBlack),
                      dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: AppColors.roastedBlack),
                    ),
                  ),
                  const SizedBox(height: AppDimensions.md),
                  Text("Can't scan? Enter this key manually:",
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.ink2)),
                  const SizedBox(height: 6),
                  SelectableText(
                    TotpUtil.formatSecretForDisplay(secret),
                    style: AppTextStyles.monoMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimensions.md),
            CbtlCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('2. Enter the 6-digit code it shows',
                      style: AppTextStyles.h3, textAlign: TextAlign.center),
                  const SizedBox(height: AppDimensions.md),
                  TextField(
                    controller: codeCtrl,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.monoLarge,
                    cursorColor: AppColors.roastedBlack,
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: '000000',
                      hintStyle: AppTextStyles.monoLarge
                          .copyWith(color: AppColors.ink3),
                    ),
                    onChanged: (_) {},
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 8),
                    Text(error!, style: AppTextStyles.errorText, textAlign: TextAlign.center),
                  ],
                  const SizedBox(height: AppDimensions.md),
                  CbtlButton(
                    label: 'Confirm & Enable',
                    isFullWidth: true,
                    isLoading: busy,
                    onPressed: busy ? null : () => onConfirm(userId),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Already enrolled: status + remove ───────────────────────────────────────

class _EnrolledView extends ConsumerWidget {
  const _EnrolledView({required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enrolledAt = ref.watch(authenticatorEnrolledAtProvider(userId)).valueOrNull;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(AppDimensions.gutter,
          AppDimensions.md, AppDimensions.gutter, AppDimensions.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CbtlCard(
            child: Column(
              children: [
                // Connected reads in the base colours: Roasted Black, no green.
                const Icon(Icons.verified_user_outlined,
                    size: 40, color: AppColors.roastedBlack),
                const SizedBox(height: AppDimensions.sm),
                const Text('Authenticator app connected',
                    style: AppTextStyles.h3, textAlign: TextAlign.center),
                if (enrolledAt != null) ...[
                  const SizedBox(height: 4),
                  Text('Set up ${DateFormatUtil.formatDateTime(enrolledAt)}',
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.ink2),
                      textAlign: TextAlign.center),
                ],
                const SizedBox(height: 8),
                Text(
                  'When you sign in without a connection, we\'ll ask for the '
                  'code from your authenticator app instead of emailing one.',
                  style:
                      AppTextStyles.bodyMedium.copyWith(color: AppColors.ink2),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimensions.md),
          CbtlButton(
            label: 'Remove Authenticator',
            variant: CbtlButtonVariant.danger,
            isFullWidth: true,
            icon: Icons.delete_outline,
            onPressed: () => _confirmRemove(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmRemove(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirmationDialog(
      context,
      title: 'Remove authenticator',
      message: 'Without an authenticator app, offline sign-in will have no '
          'second factor available until you set one up again.',
      confirmLabel: 'Remove',
    );
    if (confirmed != true || !context.mounted) return;

    await ref.read(authenticatorActionsProvider).remove(userId);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Authenticator app removed.')),
    );
  }
}
