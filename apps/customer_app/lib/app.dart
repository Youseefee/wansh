import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:wenshy_core/wenshy_core.dart';

import 'ui/core/app_dependencies.dart';
import 'ui/core/app_router.dart';

/// Root Material 3 widget for the Wenshy Customer app, defaulting to Arabic
/// RTL (`Locale('ar')`) with runtime AR/EN toggle support.
class WenshyCustomerApp extends StatefulWidget {
  const WenshyCustomerApp({
    super.key,
    required this.dependencies,
    this.router,
    this.initialLocation = '/',
  });

  final AppDependencies dependencies;
  final GoRouter? router;
  final String initialLocation;

  @override
  State<WenshyCustomerApp> createState() => _WenshyCustomerAppState();
}

class _WenshyCustomerAppState extends State<WenshyCustomerApp> {
  late final GoRouter _router;
  late final bool _ownsRouter;

  @override
  void initState() {
    super.initState();
    if (widget.router != null) {
      _router = widget.router!;
      _ownsRouter = false;
    } else {
      _router = createCustomerRouter(
        widget.dependencies,
        initialLocation: widget.initialLocation,
      );
      _ownsRouter = true;
    }
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
    return AppDependenciesScope(
      dependencies: widget.dependencies,
      child: ListenableBuilder(
        listenable: widget.dependencies.localeController,
        builder: (context, _) {
          final locale = widget.dependencies.localeController.locale;
          return MaterialApp.router(
            debugShowCheckedModeBanner: false,
            title: locale.languageCode == 'ar' ? 'ونشي' : 'Wenshy',
            locale: locale,
            supportedLocales: const <Locale>[
              Locale('ar'),
              Locale('en'),
            ],
            localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            theme: WenshyTheme.light(),
            darkTheme: WenshyTheme.dark(),
            themeMode: ThemeMode.system,
            routerConfig: _router,
          );
        },
      ),
    );
  }
}
