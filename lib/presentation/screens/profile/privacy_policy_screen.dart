import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/cbtl_app_bar.dart';

/// The privacy policy, rendered natively so it reads inside the app rather
/// than handing the member off to a browser.
///
/// The same text is published at `/privacy-policy` on the backend — both
/// stores require a public policy URL in the listing metadata — but this
/// screen is self-contained: it needs no network and cannot 404.
///
/// Keep the two copies in step. When the wording changes, update
/// `resources/views/public/privacy-policy.blade.php` in the linkhub repo and
/// the sections below together, and bump [_effectiveDate].
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const String _effectiveDate =
      'Effective and last updated: September 10, 2026';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: CbtlAppBar(
        title: 'Privacy Policy',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.white),
          onPressed: () => context.go('/dashboard/profile'),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppDimensions.md,
            AppDimensions.md,
            AppDimensions.md,
            AppDimensions.xl,
          ),
          children: const [
            _Header(),
            SizedBox(height: AppDimensions.md),
            _Summary(
              'This Privacy Policy explains how Table Group Inc. ("Table '
              'Group," "we," "us," or "our") collects, uses, stores, and '
              'protects information when you use the Coffee Bean & Tea Leaf '
              'Rewards mobile application, which appears on your device as '
              '"CBTL" (the "App").',
            ),

            _Section('1. Information We Collect'),
            _Body(
              'Depending on how you use the App, we collect or process the '
              'following categories of information:',
            ),
            _Bullet(
              'Account and profile information: information you provide when '
              'registering or signing in: your name, email address, a password '
              '(which we store only in hashed form), and, if you choose to '
              'provide it, your mobile number. We also assign a member '
              'identifier to your account.',
            ),
            _Bullet(
              'Authentication information: information required to verify your '
              'identity and keep you signed in, including session tokens, '
              'one-time verification codes, the key used by an authenticator '
              'app if you choose to set one up, and records of sign-in '
              'attempts. We do not receive or store your fingerprint or '
              'facial-recognition data.',
            ),
            _Bullet(
              'Loyalty information: the campaigns you take part in, your stamp '
              'cards and their progress, the stamps you earn and the rewards '
              'you redeem, and related transaction history, including when and '
              'at which store a stamp or reward was processed.',
            ),
            _Bullet(
              'Member and redemption codes: the App displays QR codes that '
              'identify your account or a specific stamp card. When store '
              'staff scan one of these codes, the scan is recorded against '
              'your account.',
            ),
            _Bullet(
              'Device information: your device\'s manufacturer and model name '
              '(for example, "Samsung SM-G991B"), sent when you sign in so '
              'that your session can be labelled on our systems. The App does '
              'not collect advertising IDs or other unique device identifiers.',
            ),
            _Bullet(
              'Server records: like most online services, our servers may '
              'record technical details of the requests they receive, such as '
              'IP address and time, for security and troubleshooting.',
            ),
            _Bullet(
              'Information stored on your device: the App keeps a copy of your '
              'account, session, and loyalty information on your device so '
              'that it works offline, including your member code. '
              'Security-sensitive items, such as your session token, are kept '
              'in your device\'s encrypted secure storage.',
            ),
            _Body(
              'What we do not collect. The App does not collect your location, '
              'and does not access your camera, microphone, photos, contacts, '
              'or files. It contains no advertising or third-party analytics '
              'tools.',
            ),

            _Section('2. How We Use Information'),
            _Body('We use information as reasonably necessary to:'),
            _Bullet('create and manage accounts and authenticate users;'),
            _Bullet(
              'provide loyalty campaigns, stamps, cards, rewards, redemption, '
              'and transaction-history features;',
            ),
            _Bullet(
              'display your member and redemption codes so store staff can '
              'scan them;',
            ),
            _Bullet(
              'maintain app security, prevent fraud or misuse, and troubleshoot '
              'technical issues;',
            ),
            _Bullet(
              'support offline functionality and synchronize your loyalty '
              'information with our systems;',
            ),
            _Bullet(
              'respond to support, privacy, or account-related requests; and',
            ),
            _Bullet(
              'comply with applicable laws and enforce our terms and policies.',
            ),

            _Section('3. App Permissions'),
            _Body(
              'The App requests only the permissions it needs to function: '
              'internet and network-state access, to communicate with our '
              'servers and detect when you are offline; and biometric '
              'authentication, if you choose to unlock the App with your '
              'fingerprint or face.',
            ),
            _Body(
              'The App does not request access to your location, camera, '
              'microphone, photos, contacts, or files.',
            ),
            _Body(
              'When biometric authentication is enabled, verification is '
              'performed by your device\'s operating system. The App receives '
              'only the authentication result and does not receive or store '
              'your biometric template.',
            ),

            _Section('4. Sharing and Disclosure'),
            _Body(
              'We do not sell your personal information, and we do not share '
              'it with advertisers or data brokers. We may disclose '
              'information only as reasonably necessary:',
            ),
            _Bullet(
              'to service providers that help us operate, host, secure, or '
              'support the App, acting on our behalf;',
            ),
            _Bullet(
              'within Table Group Inc. and with authorized personnel, '
              'including store staff, who need the information for legitimate '
              'business purposes such as issuing stamps and redeeming rewards;',
            ),
            _Bullet(
              'to comply with a legal obligation, lawful request, court order, '
              'or regulatory requirement; or',
            ),
            _Bullet(
              'to protect users, Table Group Inc., or others against fraud, '
              'security threats, or harm.',
            ),
            _Body(
              'Service providers are expected to process information only for '
              'authorized purposes and subject to appropriate confidentiality '
              'and security obligations.',
            ),

            _Section('5. Data Retention'),
            _Body(
              'We retain personal information only for as long as reasonably '
              'necessary to provide the App, maintain required business or '
              'transaction records, comply with legal obligations, resolve '
              'disputes, and protect against fraud or misuse. Retention '
              'periods may differ depending on the type of information and the '
              'reason it is processed.',
            ),
            _Body(
              'When you ask us to delete your account, we first close it and '
              'then permanently delete it after a waiting period. Redeemed '
              'rewards are financial records, so an account that has redeemed '
              'a reward is closed but kept in a restricted archive rather than '
              'permanently deleted. What is deleted and what is kept after you '
              'ask us to delete your account, and for how long, is set out on '
              'our Account Deletion page.',
            ),

            _Section('6. Data Security'),
            _Body(
              'We use reasonable administrative, technical, and organizational '
              'safeguards designed to protect information against unauthorized '
              'access, loss, misuse, alteration, or disclosure. All '
              'communication between the App and our servers is encrypted in '
              'transit (HTTPS). Passwords are stored only in hashed form, and '
              'session tokens are kept in your device\'s encrypted secure '
              'storage. No storage or transmission method is completely '
              'secure, so absolute security cannot be guaranteed.',
            ),

            _Section('7. Your Choices and Rights'),
            _Body(
              'You may manage the biometric-unlock setting in the App, sign '
              'out, or uninstall the App. Subject to applicable law, you may '
              'also request access to, correction of, or deletion of your '
              'personal information, or object to or restrict certain '
              'processing.',
            ),
            _Body(
              'Users in the Philippines may have rights under the Data Privacy '
              'Act of 2012 (Republic Act No. 10173) and its implementing '
              'rules. We may need to verify your identity before completing a '
              'request.',
            ),
            _Body(
              'Deleting your account. You can ask us to delete your account '
              'and associated data at any time, free of charge. Use the Delete '
              'Account option on the Profile tab, or email '
              'tasservices@tablegroup.com.ph from your registered email '
              'address with the subject line "Account Deletion Request". '
              'Deleting your account permanently forfeits any unredeemed '
              'stamps and rewards.',
            ),
            _Body(
              'Deleting the App from your device does not delete your account. '
              'It does remove the copy of your information stored in the App. '
              'On iPhone and iPad, a few sign-in items held in the device\'s '
              'secure keychain may remain after the App is deleted; they stop '
              'working once your account is closed.',
            ),

            _Section('8. Children\'s Privacy'),
            _Body(
              'The App is not intended for children under 13, and we do not '
              'knowingly collect personal information from children under 13 '
              'without appropriate authorization. If you believe a child has '
              'provided personal information through the App, please contact '
              'us so we can review and address the matter.',
            ),

            _Section('9. Third-Party Services and Links'),
            _Body(
              'The App is distributed through Google Play and Apple\'s App '
              'Store, which process information about app downloads and '
              'updates under their own privacy policies, available at '
              'policies.google.com/privacy and apple.com/legal/privacy. The '
              'App may also link to third-party services, which process '
              'information under their own privacy policies.',
            ),

            _Section('10. Changes to This Policy'),
            _Body(
              'We may update this Privacy Policy to reflect changes to the '
              'App, our practices, or applicable requirements. We will post '
              'the revised policy at this location and update the effective '
              'date above. Material changes may also be communicated through '
              'the App or another appropriate channel.',
            ),

            _Section('11. Contact Us'),
            _Body(
              'For questions, requests, or concerns relating to this Privacy '
              'Policy or our handling of personal information, contact:',
            ),
            _ContactCard(),
          ],
        ),
      ),
    );
  }
}

// ── Building blocks ─────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('The Fine Print – Made Simple',
            style: AppTextStyles.chip.copyWith(color: AppColors.amber)),
        const SizedBox(height: 6),
        Text('Privacy Policy', style: AppTextStyles.h1),
        const SizedBox(height: 4),
        Text('Coffee Bean & Tea Leaf Rewards · CBTL App',
            style: AppTextStyles.bodySmall),
        const SizedBox(height: 2),
        Text(PrivacyPolicyScreen._effectiveDate,
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.muted)),
      ],
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(
          left: BorderSide(color: AppColors.brown, width: 4),
        ),
        borderRadius: BorderRadius.horizontal(right: Radius.circular(12)),
      ),
      child: Text(text, style: AppTextStyles.bodyMedium),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppDimensions.lg, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.h3),
          const SizedBox(height: 6),
          const Divider(height: 1, color: AppColors.latte),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(text, style: AppTextStyles.bodyMedium),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 7, right: 10),
            child: Container(
              width: 5,
              height: 5,
              decoration: const BoxDecoration(
                color: AppColors.amber,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Expanded(child: Text(text, style: AppTextStyles.bodyMedium)),
        ],
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard();

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
          Text('Table Group Inc.',
              style:
                  AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const _Body(
            'Privacy questions: info@tablegroup.com.ph '
            '(subject line: CBTL Privacy Request)',
          ),
          const _Body(
            'Account deletion: tasservices@tablegroup.com.ph '
            '(subject line: Account Deletion Request)',
          ),
        ],
      ),
    );
  }
}
