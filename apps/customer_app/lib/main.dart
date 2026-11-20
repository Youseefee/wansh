import 'package:flutter/material.dart';
import 'package:wenshy_core/wenshy_core.dart';

import 'app.dart';
import 'ui/core/app_dependencies.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await SupabaseConfig.initialize();
  } catch (error) {
    runApp(_SupabaseConfigMissingApp(errorMessage: error.toString()));
    return;
  }

  final dependencies = AppDependencies.production();
  await dependencies.authViewModel.loadProfile();

  runApp(WenshyCustomerApp(dependencies: dependencies));
}

class _SupabaseConfigMissingApp extends StatelessWidget {
  const _SupabaseConfigMissingApp({required this.errorMessage});

  final String errorMessage;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(
                  Icons.settings_ethernet_rounded,
                  size: 56,
                  color: WenshyColors.amberDark,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Wenshy Supabase Configuration Required',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                Text(
                  'Run with --dart-define=SUPABASE_URL=... '
                  '--dart-define=SUPABASE_ANON_KEY=...\n\n$errorMessage',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
