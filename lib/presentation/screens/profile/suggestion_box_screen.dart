import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/cbtl_app_bar.dart';
import '../../../core/widgets/cbtl_button.dart';
import '../../../core/widgets/cbtl_card.dart';
import '../../../core/widgets/cbtl_loading_overlay.dart';
import '../../../core/widgets/cbtl_text_field.dart';
import '../../../data/datasources/remote/suggestion_remote_datasource.dart';
import '../../providers/app_providers.dart';

/// Profile → Suggestion Box. Sends a free-text message straight to the
/// server (`SuggestionRemoteDatasource`); staff read it on the web console.
/// Online only — on failure the text stays in the fields to send again.
class SuggestionBoxScreen extends ConsumerStatefulWidget {
  const SuggestionBoxScreen({super.key});

  @override
  ConsumerState<SuggestionBoxScreen> createState() =>
      _SuggestionBoxScreenState();
}

class _SuggestionBoxScreenState extends ConsumerState<SuggestionBoxScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subjectCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();

  bool _isSending = false;
  String? _error;

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _onSend() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isSending = true;
      _error = null;
    });

    final outcome = await ref.read(suggestionRemoteDatasourceProvider).send(
          subject: _subjectCtrl.text,
          message: _messageCtrl.text,
        );

    if (!mounted) return;
    setState(() => _isSending = false);

    switch (outcome) {
      case SuggestionSent():
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thank you! Your message has been sent.'),
            backgroundColor: AppColors.success,
          ),
        );
        context.go('/dashboard/profile');
      case SuggestionRejected(:final message):
      case SuggestionFailed(:final message):
        setState(() => _error = message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final length = _messageCtrl.text.trim().length;
    const max = SuggestionRemoteDatasource.maxMessageLength;

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: CbtlAppBar(
        title: 'Suggestion Box',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.white),
          onPressed: () => context.go('/dashboard/profile'),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(AppDimensions.md),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Have an idea, a compliment, or something we could do '
                    'better? Tell us — every message is read by our team.',
                    style: AppTextStyles.bodyMedium,
                  ),
                  const SizedBox(height: AppDimensions.md),
                  CbtlCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        CbtlTextField(
                          label: 'Subject',
                          hint: 'Optional',
                          controller: _subjectCtrl,
                          prefixIcon: Icons.short_text,
                          validator: (v) => (v?.trim().length ?? 0) >
                                  SuggestionRemoteDatasource.maxSubjectLength
                              ? 'Keep the subject under '
                                  '${SuggestionRemoteDatasource.maxSubjectLength} characters'
                              : null,
                        ),
                        const SizedBox(height: AppDimensions.md),
                        CbtlTextField(
                          label: 'Message',
                          isRequired: true,
                          hint: 'Write your suggestion or message',
                          controller: _messageCtrl,
                          maxLines: 7,
                          keyboardType: TextInputType.multiline,
                          textInputAction: TextInputAction.newline,
                          onChanged: (_) => setState(() {}),
                          validator: (v) {
                            final text = v?.trim() ?? '';
                            if (text.isEmpty) return 'Please write a message';
                            if (text.length > max) {
                              return 'Keep your message under $max characters';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '$length / $max',
                          textAlign: TextAlign.right,
                          style: AppTextStyles.caption.copyWith(
                            color:
                                length > max ? AppColors.danger : AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: AppDimensions.md),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withValues(alpha: 0.08),
                        borderRadius:
                            BorderRadius.circular(AppDimensions.radiusMd),
                        border: Border.all(color: AppColors.danger),
                      ),
                      child: SelectableText(_error!,
                          style: AppTextStyles.errorText),
                    ),
                  ],
                  const SizedBox(height: AppDimensions.lg),
                  CbtlButton(
                    label: 'Send Message',
                    onPressed: _onSend,
                    isFullWidth: true,
                    icon: Icons.send_outlined,
                  ),
                ],
              ),
            ),
          ),
          if (_isSending) const CbtlLoadingOverlay(),
        ],
      ),
    );
  }
}
