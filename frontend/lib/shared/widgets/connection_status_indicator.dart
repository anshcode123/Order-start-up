import 'package:flutter/material.dart';
import 'package:scanserve/core/network/socket_connection_status.dart';
import 'package:scanserve/core/theme/app_colors.dart';
import 'package:scanserve/core/theme/app_text_styles.dart';

class ConnectionStatusIndicator extends StatelessWidget {
  const ConnectionStatusIndicator({super.key, required this.status});

  final SocketConnectionStatus status;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      SocketConnectionStatus.connected => (AppColors.success, 'Live'),
      SocketConnectionStatus.connecting => (AppColors.textMuted, 'Connecting...'),
      SocketConnectionStatus.disconnected => (AppColors.error, 'Offline'),
      SocketConnectionStatus.error => (AppColors.error, 'Connection issue'),
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: AppTextStyles.bodySmall.copyWith(color: color)),
      ],
    );
  }
}
