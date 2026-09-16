import 'package:flutter/material.dart';
import 'package:scanserve/core/theme/app_colors.dart';

/// ScanServe wordmark used in the header, login screen, etc.
/// Centralized so the brand mark stays consistent everywhere it appears.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.fontSize = 22});

  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        children: const [
          TextSpan(text: 'Scan'),
          TextSpan(
            text: 'Serve',
            style: TextStyle(color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}
