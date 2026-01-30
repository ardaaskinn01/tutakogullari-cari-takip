import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:is_takip/core/theme/theme_provider.dart';

class ThemeToggleButton extends ConsumerWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return IconButton(
      onPressed: () {
        ref.read(themeModeProvider.notifier).toggleTheme();
      },
      icon: Icon(
        themeMode == ThemeMode.light ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
      ),
      tooltip: themeMode == ThemeMode.light ? 'Koyu Moda Geç' : 'Aydınlık Moda Geç',
    );
  }
}
