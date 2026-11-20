import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:wenshy_core/wenshy_core.dart';

import '../../data/repositories/models.dart';
import '../features/auth/views/login_view.dart';
import '../features/auth/views/profile_view.dart';
import '../features/auth/views/signup_view.dart';
import '../features/feedback/views/complaints_view.dart';
import '../features/feedback/views/file_complaint_view.dart';
import '../features/feedback/views/rate_trip_view.dart';
import '../features/home_map/views/home_map_view.dart';
import '../features/live_trip/views/live_trip_tracker_view.dart';
import '../features/notifications/views/notifications_view.dart';
import '../features/request_rescue/views/request_rescue_view.dart';
import '../features/trips_history/views/trip_details_view.dart';
import '../features/trips_history/views/trip_history_view.dart';
import '../features/vehicles/views/vehicles_view.dart';
import 'app_dependencies.dart';
import 'home_shell_view.dart';

/// Builds the declarative [GoRouter] for the Wenshy Customer app with reactive
/// authentication redirect guards.
GoRouter createCustomerRouter(
  AppDependencies deps, {
  String initialLocation = '/',
  GlobalKey<NavigatorState>? navigatorKey,
}) {
  return GoRouter(
    navigatorKey: navigatorKey,
    initialLocation: initialLocation,
    refreshListenable: deps.authViewModel,
    redirect: (context, state) {
      final loggedIn = deps.authViewModel.isAuthenticated;
      final loc = state.matchedLocation;
      final isAuthRoute = loc == '/login' || loc == '/signup';

      if (!loggedIn && !isAuthRoute) {
        return '/login';
      }
      if (loggedIn && isAuthRoute) {
        return '/';
      }
      if (loc == '/request' && state.extra is! RouteSelection) {
        return '/';
      }
      return null;
    },
    routes: <RouteBase>[
      GoRoute(
        path: '/login',
        builder: (_, _) => const LoginView(),
      ),
      GoRoute(
        path: '/signup',
        builder: (_, _) => const SignupView(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (_, _, navigationShell) => HomeShellView(
          navigationShell: navigationShell,
        ),
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/',
                builder: (_, _) => const HomeMapView(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/trips',
                builder: (_, _) => const TripHistoryView(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/vehicles',
                builder: (_, _) => const VehiclesView(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/profile',
                builder: (_, _) => const ProfileView(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/request',
        builder: (_, state) {
          final selection = state.extra! as RouteSelection;
          return RequestRescueView(routeSelection: selection);
        },
      ),
      GoRoute(
        path: '/trip/:id',
        builder: (_, state) {
          final id = state.pathParameters['id']!;
          final extra = state.extra;
          RescueRequest? initialRequest;
          DispatchResult? initialDispatch;

          if (extra is CreateRescueRequestResult) {
            initialRequest = extra.request;
            initialDispatch = extra.dispatch;
          } else if (extra is RescueRequest) {
            initialRequest = extra;
          }

          return LiveTripTrackerView(
            requestId: id,
            initialRequest: initialRequest,
            initialDispatch: initialDispatch,
          );
        },
      ),
      GoRoute(
        path: '/trip/:id/details',
        builder: (_, state) {
          final id = state.pathParameters['id']!;
          return TripDetailsView(requestId: id);
        },
      ),
      GoRoute(
        path: '/trip/:id/rate',
        builder: (_, state) {
          final id = state.pathParameters['id']!;
          return RateTripView(requestId: id);
        },
      ),
      GoRoute(
        path: '/notifications',
        builder: (_, _) => const NotificationsView(),
      ),
      GoRoute(
        path: '/complaints',
        builder: (_, _) => const ComplaintsView(),
      ),
      GoRoute(
        path: '/complaints/new',
        builder: (_, state) {
          return FileComplaintView(
            requestId: state.uri.queryParameters['requestId'],
            reportedUserId: state.uri.queryParameters['reportedUserId'],
          );
        },
      ),
    ],
  );
}
