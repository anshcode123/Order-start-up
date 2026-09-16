import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scanserve/core/router/app_router.dart';
import 'package:scanserve/core/theme/app_theme.dart';

void main() {
  runApp(const ProviderScope(child: ScanServeApp()));
}

class ScanServeApp extends ConsumerWidget {
  const ScanServeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'ScanServe',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: router,
    );
  }
}
