import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/app_drawer.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.white,
      drawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: AppColors.white,
        elevation: 2,
        centerTitle: true,
        // The default leading hamburger icon will appear since we added a drawer
        title: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(AppStrings.appName, style: AppTextStyles.appBarTitle),
            Text(
              AppStrings.appFullName,
              style: TextStyle(
                color: AppColors.white,
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        actions: const [],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/app_logo_v2.png',
              width: 200,
            ),
            const SizedBox(height: 24),
            const Text('TAS Service Center', style: AppTextStyles.h1),
          ],
        ),
      ),
    );
  }
}
