import 'dart:convert';
// This app is Flutter Web only for now (per project scope), so a direct
// dart:html import is fine here for triggering a browser file download.
// If a non-web target is ever added, gate this behind a conditional
// import instead.
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scanserve/core/network/api_exception.dart';
import 'package:scanserve/core/theme/app_colors.dart';
import 'package:scanserve/core/theme/app_text_styles.dart';
import 'package:scanserve/core/utils/responsive.dart';
import 'package:scanserve/features/super_admin/providers/restaurant_providers.dart';
import 'package:scanserve/shared/widgets/app_button.dart';
import 'package:scanserve/shared/widgets/app_dialogs.dart';

class RestaurantQrScreen extends ConsumerWidget {
  const RestaurantQrScreen({super.key, required this.restaurantId});

  final String restaurantId;

  void _downloadQr(String dataUrl, String restaurantName) {
    final fileName = '${restaurantName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-')}-qr.png';
    final anchor = html.AnchorElement(href: dataUrl)..download = fileName;
    html.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
  }

  Future<void> _copyMenuUrl(BuildContext context, String menuUrl) async {
    await Clipboard.setData(ClipboardData(text: menuUrl));
    if (context.mounted) showSuccessSnackBar(context, 'Menu URL copied');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final qrAsync = ref.watch(restaurantQrProvider(restaurantId));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(Responsive.pagePadding(context)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: qrAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => Text(
                apiErrorMessage(error),
                style: AppTextStyles.body.copyWith(color: AppColors.error),
              ),
              data: (qr) {
                final base64Data = qr.qrDataUrl.split(',').last;
                final bytes = base64Decode(base64Data);

                return Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      Text(qr.restaurantName, style: AppTextStyles.headline, textAlign: TextAlign.center),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.border),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Image.memory(bytes, width: 240, height: 240),
                      ),
                      const SizedBox(height: 20),
                      Text('Menu URL', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted)),
                      const SizedBox(height: 4),
                      SelectableText(
                        qr.menuUrl,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: AppOutlinedButton(
                              label: 'Copy Menu URL',
                              expand: true,
                              onPressed: () => _copyMenuUrl(context, qr.menuUrl),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: AppPrimaryButton(
                              label: 'Download QR',
                              expand: true,
                              onPressed: () => _downloadQr(qr.qrDataUrl, qr.restaurantName),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
