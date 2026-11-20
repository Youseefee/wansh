import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:wenshy_core/wenshy_core.dart';

import 'ui/core/app_router.dart';
import 'ui/core/driver_strings.dart';

/// Root widget for the Wenshy Tow-Truck Driver application.
class WenshyDriverApp extends StatefulWidget {
  const WenshyDriverApp({
    super.key,
    required this.dependencies,
    this.router,
  });

  final DriverAppDependencies dependencies;
  final GoRouter? router;

  @override
  State<WenshyDriverApp> createState() => _WenshyDriverAppState();
}

class _WenshyDriverAppState extends State<WenshyDriverApp> {
  late final GoRouter _router;
  late final bool _ownsRouter;

  @override
  void initState() {
    super.initState();
    _ownsRouter = widget.router == null;
    _router = widget.router ?? createDriverRouter(widget.dependencies);
  }

  @override
  void dispose() {
    if (_ownsRouter) {
      _router.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localeController = widget.dependencies.localeController;
    return ListenableBuilder(
      listenable: localeController,
      builder: (context, _) {
        final code = localeController.localeCode;
        return MaterialApp.router(
          debugShowCheckedModeBanner: false,
          title: DriverStrings.appTitle(code),
          theme: WenshyTheme.light(),
          darkTheme: WenshyTheme.dark(),
          locale: localeController.locale,
          supportedLocales: const <Locale>[
            Locale('ar'),
            Locale('en'),
          ],
          localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          routerConfig: _router,
        );
      },
    );
  }
}
