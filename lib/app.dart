import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sampan/core/constants/protocol_constants.dart';
import 'package:sampan/core/theme/sampan_theme.dart';
import 'package:sampan/state/sampan_providers.dart';
import 'package:sampan/ui/home/home_shell.dart';
import 'package:sampan/ui/onboarding/onboarding_screen.dart';

/// Root Material 3 widget for Sampan (সাম্পান).
class SampanApp extends ConsumerWidget {
  const SampanApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SampanAppState state = ref.watch(sampanControllerProvider);

    return MaterialApp(
      title: '${SampanConstants.appName} (${SampanConstants.appNameBengali})',
      debugShowCheckedModeBanner: false,
      theme: SampanTheme.buildTheme(state.visualMode),
      home: state.identity == null
          ? const OnboardingScreen()
          : const HomeShell(),
    );
  }
}
