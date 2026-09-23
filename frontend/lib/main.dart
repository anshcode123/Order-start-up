import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scanserve/core/network/dio_client.dart';
import 'package:scanserve/core/network/token_storage.dart';
import 'package:scanserve/core/router/app_router.dart';
import 'package:scanserve/core/theme/app_theme.dart';

Future<void> main() async {
  usePathUrlStrategy();
  WidgetsFlutterBinding.ensureInitialized();

  // SharedPreferences loads asynchronously, but providers are built
  // synchronously - so it's loaded once here and handed to
  // tokenStorageProvider as an override, rather than making every
  // consumer of the token deal with a FutureProvider.
  final prefs = await SharedPreferences.getInstance();
  final tokenStorage = TokenStorage(prefs);

  runApp(
    ProviderScope(
      overrides: [tokenStorageProvider.overrideWithValue(tokenStorage)],
      child: const ScanServeApp(),
    ),
  );
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
