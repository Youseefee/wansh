import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:wenshy_core/wenshy_core.dart';

import 'app.dart';
import 'ui/core/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await SupabaseConfig.initialize(debug: kDebugMode);
  } on StateError catch (error) {
    runApp(_MissingConfigApp(message: error.message));
    return;
  }

  final deps = DriverAppDependencies();
  unawaited(deps.sessionController.initialize());

  runApp(WenshyDriverApp(dependencies: deps));
}

class _MissingConfigApp extends StatelessWidget {
  const _MissingConfigApp({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: WenshyTheme.light(),
      home: Scaffold(
        body: WenshyErrorView(
          title: 'Supabase Configuration Missing',
          message: message,
        ),
      ),
    );
  }
}
