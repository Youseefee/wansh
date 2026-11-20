import 'package:flutter/material.dart';

import 'app_dependencies.dart';
import 'app_strings.dart';

/// Compact AR/EN toggle chip for headers and floating map overlays.
class LanguageToggleButton extends StatelessWidget {
  const LanguageToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    final deps = AppDependenciesScope.of(context);
    final strings = AppStrings.of(context);
    final theme = Theme.of(context);

    return ActionChip(
      avatar: Icon(
        Icons.language_rounded,
        size: 16,
        color: theme.colorScheme.onSurface,
      ),
      label: Text(
        strings.toggleLanguageLabel,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
      ),
      backgroundColor: theme.colorScheme.surface,
      onPressed: () => deps.authViewModel.toggleLanguageAndSync(),
    );
  }
}
