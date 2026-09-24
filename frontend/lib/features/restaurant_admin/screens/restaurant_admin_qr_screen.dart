import 'dart:convert';
import 'package:web/web.dart' as web;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scanserve/core/network/api_exception.dart';
import 'package:scanserve/core/theme/app_colors.dart';
import 'package:scanserve/core/theme/app_text_styles.dart';
import 'package:scanserve/core/utils/responsive.dart';
import 'package:scanserve/features/restaurant_admin/providers/menu_providers.dart';
import 'package:scanserve/shared/widgets/app_button.dart';
import 'package:scanserve/shared/widgets/app_dialogs.dart';

class RestaurantAdminQrScreen extends ConsumerWidget {
  const RestaurantAdminQrScreen({super.key});

  void _downloadQr(String dataUrl, String restaurantName) {
    final fileName =
        '${restaurantName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-')}-qr.png';
    final anchor = web.HTMLAnchorElement()
      ..href = dataUrl
      ..download = fileName;
    web.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
  }

  Future<void> _copyMenuUrl(BuildContext context, String menuUrl) async {
    await Clipboard.setData(ClipboardData(text: menuUrl));
    if (context.mounted) {
      showSuccessSnackBar(context, 'Menu URL copied to clipboard');
    }
  }

  void _openPublicMenu(String menuUrl) {
    web.window.open(menuUrl, '_blank');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final qrAsync = ref.watch(ownRestaurantQrProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(Responsive.pagePadding(context)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: qrAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 80),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      apiErrorMessage(error),
                      style:
                          AppTextStyles.body.copyWith(color: AppColors.error),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    AppPrimaryButton(
                      label: 'Retry',
                      onPressed: () => ref.refresh(ownRestaurantQrProvider),
                    ),
                  ],
                ),
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  qr.restaurantName,
                                  style: AppTextStyles.headline,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Public QR Code & Menu Link',
                                  style: AppTextStyles.bodySmall
                                      .copyWith(color: AppColors.textMuted),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Refresh QR',
                            icon: const Icon(Icons.refresh,
                                color: AppColors.textSecondary),
                            onPressed: () {
                              ref.invalidate(ownRestaurantQrProvider);
                              showSuccessSnackBar(context, 'QR code refreshed');
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: AppColors.border),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Image.memory(bytes, width: 240, height: 240),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Direct Public Menu URL',
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textMuted),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: SelectableText(
                          qr.menuUrl,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w500),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: AppOutlinedButton(
                              label: 'Copy URL',
                              expand: true,
                              onPressed: () =>
                                  _copyMenuUrl(context, qr.menuUrl),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: AppPrimaryButton(
                              label: 'Download QR',
                              expand: true,
                              onPressed: () =>
                                  _downloadQr(qr.qrDataUrl, qr.restaurantName),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      AppOutlinedButton(
                        label: 'Open Public Menu in New Tab',
                        expand: true,
                        onPressed: () => _openPublicMenu(qr.menuUrl),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Print this QR code and place it on dining tables. Customers can scan to instantly browse your menu and order without logging in.',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textMuted, fontSize: 12),
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
