import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/auth_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: SkillBridgeApp()));
}

class SkillBridgeApp extends ConsumerStatefulWidget {
  const SkillBridgeApp({super.key});

  @override
  ConsumerState<SkillBridgeApp> createState() => _SkillBridgeAppState();
}

class _SkillBridgeAppState extends ConsumerState<SkillBridgeApp> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(
      () => ref.read(authControllerProvider.notifier).bootstrap(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'SkillBridge AI',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      routerConfig: router,
    );
  }
}
