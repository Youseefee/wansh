import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:wenshy_core/wenshy_core.dart';

import '../../features/notifications/view_models/notifications_view_model.dart';
import '../driver_strings.dart';
import '../locale_controller.dart';

/// AppBar bell icon with a live unread count badge navigating to `/notifications`.
class NotificationsBellButton extends StatelessWidget {
  const NotificationsBellButton({
    super.key,
    required this.notificationsController,
    required this.localeController,
  });

  final DriverNotificationsController notificationsController;
  final LocaleController localeController;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[
        notificationsController,
        localeController,
      ]),
      builder: (context, _) {
        final unread = notificationsController.unreadCount;
        final locale = localeController.localeCode;
        return IconButton(
          tooltip: DriverStrings.notificationsTitle(locale),
          onPressed: () => context.push('/notifications'),
          icon: Badge(
            isLabelVisible: unread > 0,
            label: Text(unread > 99 ? '99+' : '$unread'),
            backgroundColor: WenshyColors.red,
            textColor: Colors.white,
            child: const Icon(Icons.notifications_outlined),
          ),
        );
      },
    );
  }
}

/// Compact AppBar action button for switching between Arabic (RTL) and English (LTR).
class LocaleToggleButton extends StatelessWidget {
  const LocaleToggleButton({
    super.key,
    required this.localeController,
  });

  final LocaleController localeController;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: localeController,
      builder: (context, _) {
        final code = localeController.localeCode;
        return Padding(
          padding: const EdgeInsetsDirectional.only(end: 8),
          child: ActionChip(
            avatar: const Icon(Icons.language, size: 16),
            label: Text(
              DriverStrings.toggleLanguageLabel(code),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            onPressed: localeController.toggleLocale,
          ),
        );
      },
    );
  }
}

/// Persistent bottom-navigation shell for approved driver screens.
class DriverAppShell extends StatelessWidget {
  const DriverAppShell({
    super.key,
    required this.location,
    required this.localeController,
    required this.child,
  });

  final String location;
  final LocaleController localeController;
  final Widget child;

  static const List<String> _routes = <String>[
    '/home',
    '/history',
    '/complaints',
    '/profile',
  ];

  int _selectedIndex() {
    for (var i = 0; i < _routes.length; i++) {
      if (location.startsWith(_routes[i])) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: localeController,
      builder: (context, _) {
        final locale = localeController.localeCode;
        return Scaffold(
          body: child,
          bottomNavigationBar: NavigationBar(
            selectedIndex: _selectedIndex(),
            onDestinationSelected: (idx) {
              final target = _routes[idx];
              if (target != location) {
                context.go(target);
              }
            },
            destinations: <NavigationDestination>[
              NavigationDestination(
                icon: const Icon(Icons.radar_outlined),
                selectedIcon: const Icon(Icons.radar),
                label: DriverStrings.navHome(locale),
              ),
              NavigationDestination(
                icon: const Icon(Icons.history_outlined),
                selectedIcon: const Icon(Icons.history),
                label: DriverStrings.navHistory(locale),
              ),
              NavigationDestination(
                icon: const Icon(Icons.support_agent_outlined),
                selectedIcon: const Icon(Icons.support_agent),
                label: DriverStrings.navComplaints(locale),
              ),
              NavigationDestination(
                icon: const Icon(Icons.person_outline),
                selectedIcon: const Icon(Icons.person),
                label: DriverStrings.navProfile(locale),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Interactive `flutter_map` widget rendering the driver position, pickup point,
/// dropoff point, and real road (or fallback) route line.
class DriverRouteMap extends StatelessWidget {
  const DriverRouteMap({
    super.key,
    this.driverPoint,
    this.pickupPoint,
    this.dropoffPoint,
    this.routePoints,
    this.mapController,
    this.zoom = 13.0,
    this.showTileLayer = true,
  });

  final LatLng? driverPoint;
  final LatLng? pickupPoint;
  final LatLng? dropoffPoint;

  /// Optional real driving road polyline coordinates (e.g. from OSRM via
  /// `WenshyGeoService.getDrivingRoute`). Falls back to connecting available
  /// anchor pins when null or shorter than 2 points.
  final List<LatLng>? routePoints;
  final MapController? mapController;
  final double zoom;
  final bool showTileLayer;

  /// Cairo default fallback when GPS coordinates are not yet available.
  static const LatLng defaultCenter = LatLng(30.0444, 31.2357);

  LatLng get _effectiveCenter =>
      driverPoint ?? pickupPoint ?? dropoffPoint ?? defaultCenter;

  @override
  Widget build(BuildContext context) {
    final polylinePoints = (routePoints != null && routePoints!.length >= 2)
        ? routePoints!
        : <LatLng>[
            ?driverPoint,
            ?pickupPoint,
            ?dropoffPoint,
          ];

    final markers = <Marker>[
      if (pickupPoint != null)
        Marker(
          point: pickupPoint!,
          width: 44,
          height: 44,
          child: const _MapPinBadge(
            icon: Icons.car_crash_rounded,
            color: WenshyColors.red,
          ),
        ),
      if (dropoffPoint != null)
        Marker(
          point: dropoffPoint!,
          width: 44,
          height: 44,
          child: const _MapPinBadge(
            icon: Icons.flag_rounded,
            color: WenshyColors.emerald,
          ),
        ),
      if (driverPoint != null)
        Marker(
          point: driverPoint!,
          width: 48,
          height: 48,
          child: const _MapPinBadge(
            icon: Icons.local_shipping_rounded,
            color: WenshyColors.amberDark,
            highlighted: true,
          ),
        ),
    ];

    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
        initialCenter: _effectiveCenter,
        initialZoom: zoom,
      ),
      children: <Widget>[
        if (showTileLayer)
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.wenshy.driver',
          ),
        if (polylinePoints.length >= 2)
          PolylineLayer(
            polylines: <Polyline>[
              Polyline(
                points: polylinePoints,
                color: WenshyColors.amberDark,
                strokeWidth: 4.5,
              ),
            ],
          ),
        MarkerLayer(markers: markers),
      ],
    );
  }
}

class _MapPinBadge extends StatelessWidget {
  const _MapPinBadge({
    required this.icon,
    required this.color,
    this.highlighted = false,
  });

  final IconData icon;
  final Color color;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: highlighted ? WenshyColors.deepSlate : Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: highlighted ? 3 : 2.5),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Colors.black26,
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Icon(
        icon,
        color: highlighted ? WenshyColors.amber : color,
        size: highlighted ? 24 : 21,
      ),
    );
  }
}
