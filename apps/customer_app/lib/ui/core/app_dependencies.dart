import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:wenshy_core/wenshy_core.dart';

import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/feedback_repository.dart';
import '../../data/repositories/map_and_quote_repository.dart';
import '../../data/repositories/notification_repository.dart';
import '../../data/repositories/rescue_request_repository.dart';
import '../../data/repositories/vehicle_repository.dart';
import '../features/auth/view_models/auth_view_model.dart';
import '../features/notifications/view_models/notifications_view_model.dart';
import 'locale_controller.dart';
import 'phone_dialer.dart';
import 'photo_picker_service.dart';
import 'push_token_service.dart';

/// Dependency container for the Wenshy Customer app, enabling clean injection
/// in both production and widget/viewmodel tests.
class AppDependencies {
  AppDependencies({
    required this.localeController,
    required this.authRepository,
    required this.authViewModel,
    required this.mapRepository,
    required this.vehicleRepository,
    required this.rescueRepository,
    required this.feedbackRepository,
    required this.notificationRepository,
    required this.notificationsViewModel,
    required this.pushTokenRegistrar,
    required this.phoneDialer,
    required this.photoPicker,
    required this.winchCatalog,
    this.enableNetworkTiles = true,
  }) {
    _syncNotificationsWithAuth();
    authViewModel.addListener(_syncNotificationsWithAuth);
  }

  factory AppDependencies.production() {
    final localeController = LocaleController();
    final notificationRepository = SupabaseNotificationRepository();
    final pushTokenRegistrar = PushTokenRegistrar(
      notificationRepository: notificationRepository,
    );
    final notificationsViewModel = NotificationsViewModel(
      repository: notificationRepository,
    );
    final authRepository = SupabaseAuthRepository();
    final authViewModel = AuthViewModel(
      repository: authRepository,
      localeController: localeController,
      pushTokenRegistrar: pushTokenRegistrar,
    );
    return AppDependencies(
      localeController: localeController,
      authRepository: authRepository,
      authViewModel: authViewModel,
      mapRepository: SupabaseMapAndQuoteRepository(),
      vehicleRepository: SupabaseVehicleRepository(),
      rescueRepository: SupabaseRescueRequestRepository(),
      feedbackRepository: SupabaseFeedbackRepository(),
      notificationRepository: notificationRepository,
      notificationsViewModel: notificationsViewModel,
      pushTokenRegistrar: pushTokenRegistrar,
      phoneDialer: const UrlLauncherPhoneDialer(),
      photoPicker: ImagePickerService(),
      winchCatalog: const WinchCatalogService(),
      enableNetworkTiles: true,
    );
  }

  final LocaleController localeController;
  final AuthRepository authRepository;
  final AuthViewModel authViewModel;
  final MapAndQuoteRepository mapRepository;
  final VehicleRepository vehicleRepository;
  final RescueRequestRepository rescueRepository;
  final FeedbackRepository feedbackRepository;
  final NotificationRepository notificationRepository;
  final NotificationsViewModel notificationsViewModel;
  final PushTokenRegistrar pushTokenRegistrar;
  final PhoneDialer phoneDialer;
  final PhotoPickerService photoPicker;
  final WinchCatalogService winchCatalog;
  final bool enableNetworkTiles;

  String? _lastBoundNotificationsUserId;

  void _syncNotificationsWithAuth() {
    final uid = authViewModel.isAuthenticated ? authViewModel.currentUserId : null;
    if (uid == _lastBoundNotificationsUserId) return;
    _lastBoundNotificationsUserId = uid;
    if (uid != null) {
      unawaited(
        notificationsViewModel.initialize(
          uid,
          locale: localeController.languageCode,
        ),
      );
    } else {
      notificationsViewModel.clear();
    }
  }

  void dispose() {
    authViewModel.removeListener(_syncNotificationsWithAuth);
    notificationsViewModel.dispose();
    pushTokenRegistrar.dispose();
    authViewModel.dispose();
    localeController.dispose();
  }
}

/// Exposes [AppDependencies] down the widget tree.
class AppDependenciesScope extends InheritedWidget {
  const AppDependenciesScope({
    super.key,
    required this.dependencies,
    required super.child,
  });

  final AppDependencies dependencies;

  static AppDependencies of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<AppDependenciesScope>();
    assert(scope != null, 'No AppDependenciesScope found in widget tree.');
    return scope!.dependencies;
  }

  @override
  bool updateShouldNotify(AppDependenciesScope oldWidget) =>
      dependencies != oldWidget.dependencies;
}
