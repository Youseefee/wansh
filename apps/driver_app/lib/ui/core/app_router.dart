import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:wenshy_core/wenshy_core.dart';

import '../../data/repositories/driver_auth_repository.dart';
import '../../data/repositories/driver_dispatch_repository.dart';
import '../../data/repositories/driver_history_repository.dart';
import '../../data/repositories/driver_notification_repository.dart';
import '../../data/repositories/driver_onboarding_repository.dart';
import '../../data/repositories/driver_trip_repository.dart';
import '../../data/services/external_launcher_service.dart';
import '../../data/services/location_service.dart';
import '../../data/services/media_picker_service.dart';
import '../../data/services/push_token_service.dart';
import '../features/auth/view_models/auth_view_model.dart';
import '../features/auth/views/login_view.dart';
import '../features/auth/views/register_view.dart';
import '../features/complaints/view_models/complaints_view_model.dart';
import '../features/complaints/views/complaints_view.dart';
import '../features/history/view_models/trips_history_view_model.dart';
import '../features/history/views/trips_history_view.dart';
import '../features/home/view_models/driver_home_view_model.dart';
import '../features/home/views/driver_home_view.dart';
import '../features/notifications/view_models/notifications_view_model.dart';
import '../features/notifications/views/driver_notifications_view.dart';
import '../features/onboarding/view_models/onboarding_view_model.dart';
import '../features/onboarding/views/approval_gate_view.dart';
import '../features/onboarding/views/kyc_upload_view.dart';
import '../features/onboarding/views/winch_setup_view.dart';
import '../features/profile/views/driver_profile_view.dart';
import '../features/trip/view_models/active_trip_view_model.dart';
import '../features/trip/views/active_trip_view.dart';
import 'driver_session_controller.dart';
import 'locale_controller.dart';
import 'widgets/driver_widgets.dart';

/// Dependency graph for the Wenshy Driver application.
class DriverAppDependencies {
  DriverAppDependencies({
    DriverAuthRepository? authRepository,
    DriverOnboardingRepository? onboardingRepository,
    DriverDispatchRepository? dispatchRepository,
    DriverTripRepository? tripRepository,
    DriverHistoryRepository? historyRepository,
    DriverNotificationRepository? notificationRepository,
    DriverLocationSource? locationSource,
    DriverMediaPicker? mediaPicker,
    WenshyGeoService? geoService,
    DriverExternalLauncher? externalLauncher,
    DriverPushTokenRegistrar? pushTokenRegistrar,
    LocaleController? localeController,
    DriverSessionController? sessionController,
    DriverNotificationsController? notificationsController,
    this.showMapTiles = true,
  }) {
    this.authRepository = authRepository ?? SupabaseDriverAuthRepository();
    this.onboardingRepository =
        onboardingRepository ?? SupabaseDriverOnboardingRepository();
    this.dispatchRepository =
        dispatchRepository ?? SupabaseDriverDispatchRepository();
    this.tripRepository = tripRepository ?? SupabaseDriverTripRepository();
    this.historyRepository =
        historyRepository ?? SupabaseDriverHistoryRepository();
    this.notificationRepository =
        notificationRepository ?? SupabaseDriverNotificationRepository();
    this.locationSource =
        locationSource ?? const GeolocatorDriverLocationSource();
    this.mediaPicker = mediaPicker ?? ImagePickerDriverMedia();
    this.geoService = geoService ?? const WenshyGeoService();
    this.externalLauncher =
        externalLauncher ?? const UrlLauncherDriverExternalLauncher();
    this.pushTokenRegistrar = pushTokenRegistrar ??
        DriverPushTokenRegistrar(
          notificationRepository: this.notificationRepository,
        );

    this.localeController = localeController ??
        LocaleController(
          onPersistLocale: (code) async {
            if (this.authRepository.currentUserId != null) {
              await this.authRepository.updateLocale(code);
            }
          },
        );

    this.sessionController = sessionController ??
        DriverSessionController(
          authRepository: this.authRepository,
          tripRepository: this.tripRepository,
          localeController: this.localeController,
          pushTokenRegistrar: this.pushTokenRegistrar,
        );

    this.notificationsController = notificationsController ??
        DriverNotificationsController(
          notificationRepository: this.notificationRepository,
          sessionController: this.sessionController,
        );
  }

  late final DriverAuthRepository authRepository;
  late final DriverOnboardingRepository onboardingRepository;
  late final DriverDispatchRepository dispatchRepository;
  late final DriverTripRepository tripRepository;
  late final DriverHistoryRepository historyRepository;
  late final DriverNotificationRepository notificationRepository;
  late final DriverLocationSource locationSource;
  late final DriverMediaPicker mediaPicker;
  late final WenshyGeoService geoService;
  late final DriverExternalLauncher externalLauncher;
  late final DriverPushTokenRegistrar pushTokenRegistrar;
  late final LocaleController localeController;
  late final DriverSessionController sessionController;
  late final DriverNotificationsController notificationsController;
  final bool showMapTiles;

  AuthViewModel createAuthViewModel() => AuthViewModel(
        authRepository: authRepository,
        sessionController: sessionController,
        localeController: localeController,
      );

  OnboardingViewModel createOnboardingViewModel() => OnboardingViewModel(
        onboardingRepository: onboardingRepository,
        sessionController: sessionController,
        mediaPicker: mediaPicker,
        localeController: localeController,
      );

  DriverHomeViewModel createDriverHomeViewModel() => DriverHomeViewModel(
        dispatchRepository: dispatchRepository,
        tripRepository: tripRepository,
        locationSource: locationSource,
        sessionController: sessionController,
        localeController: localeController,
      );

  ActiveTripViewModel createActiveTripViewModel() => ActiveTripViewModel(
        tripRepository: tripRepository,
        locationSource: locationSource,
        sessionController: sessionController,
        localeController: localeController,
        geoService: geoService,
        externalLauncher: externalLauncher,
      );

  TripsHistoryViewModel createTripsHistoryViewModel() => TripsHistoryViewModel(
        historyRepository: historyRepository,
        sessionController: sessionController,
      );

  ComplaintsViewModel createComplaintsViewModel() => ComplaintsViewModel(
        historyRepository: historyRepository,
        sessionController: sessionController,
        mediaPicker: mediaPicker,
        localeController: localeController,
      );

  void dispose() {
    notificationsController.dispose();
    sessionController.dispose();
    localeController.dispose();
  }
}

/// Declarative [GoRouter] configured with auth & driver approval-gate guards.
GoRouter createDriverRouter(
  DriverAppDependencies deps, {
  String initialLocation = '/splash',
}) {
  return GoRouter(
    initialLocation: initialLocation,
    refreshListenable: deps.sessionController,
    redirect: (context, state) {
      final loc = state.matchedLocation;
      final session = deps.sessionController;

      if (session.status == DriverSessionStatus.initializing) {
        return loc == '/splash' ? null : '/splash';
      }

      if (session.status == DriverSessionStatus.unauthenticated) {
        if (loc == '/login' || loc == '/register') return null;
        return '/login';
      }

      // Authenticated driver
      if (!session.isApproved) {
        const allowedUnapproved = <String>{
          '/approval-gate',
          '/onboarding/winch',
          '/onboarding/kyc',
          '/notifications',
        };
        return allowedUnapproved.contains(loc) ? null : '/approval-gate';
      }

      if (loc == '/splash' ||
          loc == '/login' ||
          loc == '/register' ||
          loc == '/approval-gate') {
        return '/home';
      }

      return null;
    },
    routes: <RouteBase>[
      GoRoute(
        path: '/splash',
        builder: (_, _) => const Scaffold(
          body: WenshyLoadingView(),
        ),
      ),
      GoRoute(
        path: '/login',
        builder: (_, _) => _OwnedVmPage<AuthViewModel>(
          create: deps.createAuthViewModel,
          builder: (vm) => LoginView(
            viewModel: vm,
            localeController: deps.localeController,
          ),
        ),
      ),
      GoRoute(
        path: '/register',
        builder: (_, _) => _OwnedVmPage<AuthViewModel>(
          create: deps.createAuthViewModel,
          builder: (vm) => RegisterView(
            viewModel: vm,
            localeController: deps.localeController,
          ),
        ),
      ),
      GoRoute(
        path: '/approval-gate',
        builder: (_, _) => _OwnedVmPage<OnboardingViewModel>(
          create: deps.createOnboardingViewModel,
          builder: (vm) => ApprovalGateView(
            viewModel: vm,
            sessionController: deps.sessionController,
            localeController: deps.localeController,
            notificationsController: deps.notificationsController,
          ),
        ),
      ),
      GoRoute(
        path: '/onboarding/winch',
        builder: (_, _) => _OwnedVmPage<OnboardingViewModel>(
          create: deps.createOnboardingViewModel,
          builder: (vm) => WinchSetupView(
            viewModel: vm,
            localeController: deps.localeController,
          ),
        ),
      ),
      GoRoute(
        path: '/onboarding/kyc',
        builder: (_, _) => _OwnedVmPage<OnboardingViewModel>(
          create: deps.createOnboardingViewModel,
          builder: (vm) => KycUploadView(
            viewModel: vm,
            localeController: deps.localeController,
          ),
        ),
      ),
      GoRoute(
        path: '/notifications',
        builder: (_, _) => DriverNotificationsView(
          controller: deps.notificationsController,
          localeController: deps.localeController,
        ),
      ),
      GoRoute(
        path: '/trip/:id',
        builder: (_, state) {
          final requestId = state.pathParameters['id']!;
          return _OwnedVmPage<ActiveTripViewModel>(
            create: deps.createActiveTripViewModel,
            builder: (vm) => ActiveTripView(
              requestId: requestId,
              viewModel: vm,
              localeController: deps.localeController,
              showMapTiles: deps.showMapTiles,
            ),
          );
        },
      ),
      ShellRoute(
        builder: (_, state, child) => DriverAppShell(
          location: state.matchedLocation,
          localeController: deps.localeController,
          child: child,
        ),
        routes: <RouteBase>[
          GoRoute(
            path: '/home',
            builder: (_, _) => _OwnedVmPage<DriverHomeViewModel>(
              create: deps.createDriverHomeViewModel,
              builder: (vm) => DriverHomeView(
                viewModel: vm,
                localeController: deps.localeController,
                notificationsController: deps.notificationsController,
                showMapTiles: deps.showMapTiles,
              ),
            ),
          ),
          GoRoute(
            path: '/history',
            builder: (_, _) => _OwnedVmPage<TripsHistoryViewModel>(
              create: deps.createTripsHistoryViewModel,
              builder: (vm) => TripsHistoryView(
                viewModel: vm,
                localeController: deps.localeController,
              ),
            ),
          ),
          GoRoute(
            path: '/complaints',
            builder: (_, _) => _OwnedVmPage<ComplaintsViewModel>(
              create: deps.createComplaintsViewModel,
              builder: (vm) => ComplaintsView(
                viewModel: vm,
                localeController: deps.localeController,
              ),
            ),
          ),
          GoRoute(
            path: '/profile',
            builder: (_, _) => DriverProfileView(
              sessionController: deps.sessionController,
              localeController: deps.localeController,
              notificationsController: deps.notificationsController,
            ),
          ),
        ],
      ),
    ],
  );
}

class _OwnedVmPage<T extends ChangeNotifier> extends StatefulWidget {
  const _OwnedVmPage({
    required this.create,
    required this.builder,
  });

  final T Function() create;
  final Widget Function(T vm) builder;

  @override
  State<_OwnedVmPage<T>> createState() => _OwnedVmPageState<T>();
}

class _OwnedVmPageState<T extends ChangeNotifier>
    extends State<_OwnedVmPage<T>> {
  late final T _vm;

  @override
  void initState() {
    super.initState();
    _vm = widget.create();
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(_vm);
}
