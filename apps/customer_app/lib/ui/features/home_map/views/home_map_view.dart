import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:wenshy_core/wenshy_core.dart';

import '../../../../data/repositories/models.dart';
import '../../../core/app_dependencies.dart';
import '../../../core/app_strings.dart';
import '../../../core/language_toggle_button.dart';
import '../../../core/wenshy_map_markers.dart';
import '../view_models/home_map_view_model.dart';

/// Customer Home Map screen powered by `flutter_map` + `latlong2` + `geolocator`
/// + `WenshyGeoService` (Nominatim place search/reverse geocode & OSRM routing).
class HomeMapView extends StatefulWidget {
  const HomeMapView({super.key});

  @override
  State<HomeMapView> createState() => _HomeMapViewState();
}

class _HomeMapViewState extends State<HomeMapView> {
  final MapController _mapController = MapController();
  final TextEditingController _pickupAddressController = TextEditingController();
  final TextEditingController _dropoffAddressController =
      TextEditingController();

  HomeMapViewModel? _viewModel;
  String _lastSyncedPickupAddress = '';
  String _lastSyncedDropoffAddress = '';
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final deps = AppDependenciesScope.of(context);
    final vm = HomeMapViewModel(
      mapRepository: deps.mapRepository,
      rescueRepository: deps.rescueRepository,
    );
    _viewModel = vm;
    vm.addListener(_onViewModelChanged);
    vm.initialize(
      customerId: deps.authViewModel.currentUserId,
      locale: deps.localeController.languageCode,
    ).then((_) {
      if (!mounted) return;
      _syncAddressControllers(vm);
      _safeMoveMap(vm.pickupPoint, 13.5);
    });
  }

  void _onViewModelChanged() {
    final vm = _viewModel;
    if (vm == null || !mounted) return;
    _syncAddressControllers(vm);
  }

  void _syncAddressControllers(HomeMapViewModel vm) {
    if (vm.pickupAddress != _lastSyncedPickupAddress) {
      _lastSyncedPickupAddress = vm.pickupAddress;
      if (_pickupAddressController.text != vm.pickupAddress) {
        _pickupAddressController.text = vm.pickupAddress;
      }
    }
    if (vm.dropoffAddress != _lastSyncedDropoffAddress) {
      _lastSyncedDropoffAddress = vm.dropoffAddress;
      if (_dropoffAddressController.text != vm.dropoffAddress) {
        _dropoffAddressController.text = vm.dropoffAddress;
      }
    }
  }

  void _safeMoveMap(LatLng center, double zoom) {
    try {
      _mapController.move(center, zoom);
    } catch (_) {
      // MapController may not be attached yet in headless widget tests.
    }
  }

  @override
  void dispose() {
    _viewModel?.removeListener(_onViewModelChanged);
    _mapController.dispose();
    _pickupAddressController.dispose();
    _dropoffAddressController.dispose();
    _viewModel?.dispose();
    super.dispose();
  }

  Future<void> _onDetectLocation() async {
    final vm = _viewModel;
    if (vm == null) return;
    final deps = AppDependenciesScope.of(context);
    final strings = AppStrings.of(context);
    final loc = await vm.detectCurrentLocation(
      locale: deps.localeController.languageCode,
    );
    if (!mounted) return;
    _syncAddressControllers(vm);
    if (loc != null) {
      _safeMoveMap(loc, 14.5);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.locationPermissionDenied)),
      );
    }
  }

  Future<void> _openPlaceSearchSheet(MapPickMode target) async {
    final vm = _viewModel;
    if (vm == null) return;
    final deps = AppDependenciesScope.of(context);
    final localeCode = deps.localeController.languageCode;
    vm.setPickMode(target);
    vm.clearSearchResults();

    final selected = await showModalBottomSheet<GeoPlaceSuggestion>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _PlaceSearchSheet(
        viewModel: vm,
        target: target,
        localeCode: localeCode,
        initialQuery: target == MapPickMode.pickup
            ? ''
            : _dropoffAddressController.text,
      ),
    );

    if (selected != null && mounted) {
      await vm.selectPlaceSuggestion(
        selected,
        target: target,
        locale: localeCode,
      );
      if (!mounted) return;
      _syncAddressControllers(vm);
      _safeMoveMap(LatLng(selected.lat, selected.lng), 14.5);
    }
  }

  void _onProceedToRequest() {
    final vm = _viewModel;
    if (vm == null) return;
    final strings = AppStrings.of(context);
    final selection = vm.buildRouteSelection();
    if (selection == null) {
      vm.setPickMode(MapPickMode.dropoff);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.selectPickupAndDropoffFirst)),
      );
      return;
    }
    context.push('/request', extra: selection);
  }

  @override
  Widget build(BuildContext context) {
    final deps = AppDependenciesScope.of(context);
    final vm = _viewModel!;
    final strings = AppStrings.of(context);
    final theme = Theme.of(context);
    final localeCode = deps.localeController.languageCode;

    return Scaffold(
      body: ListenableBuilder(
        listenable: vm,
        builder: (context, _) {
          final markers = <Marker>[
            Marker(
              point: vm.pickupPoint,
              width: 90,
              height: 64,
              alignment: Alignment.topCenter,
              child: WenshyMapMarkers.pickupPin(label: strings.pickingPickupMode),
            ),
            if (vm.dropoffPoint != null)
              Marker(
                point: vm.dropoffPoint!,
                width: 90,
                height: 64,
                alignment: Alignment.topCenter,
                child: WenshyMapMarkers.dropoffPin(
                  label: strings.pickingDropoffMode,
                ),
              ),
            for (final driver in vm.nearbyDrivers)
              Marker(
                point: LatLng(driver.currentLat, driver.currentLng),
                width: 44,
                height: 44,
                child: WenshyMapMarkers.nearbyWinchMarker(
                  isSelected: vm.focusedDriver?.driverId == driver.driverId,
                  onTap: () => vm.focusDriver(driver),
                ),
              ),
          ];

          final routePoints = vm.routePolylinePoints;
          final polylines = <Polyline>[
            if (routePoints.length >= 2)
              Polyline(
                points: routePoints,
                color: WenshyColors.deepSlate,
                strokeWidth: 4.5,
              ),
          ];

          return Stack(
            children: <Widget>[
              Positioned.fill(
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: vm.pickupPoint,
                    initialZoom: 13.5,
                    onTap: (_, point) async {
                      await vm.onMapTapped(point, locale: localeCode);
                      if (mounted) _syncAddressControllers(vm);
                    },
                  ),
                  children: <Widget>[
                    if (deps.enableNetworkTiles)
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.wenshy.wenshy_customer',
                      ),
                    if (polylines.isNotEmpty) PolylineLayer(polylines: polylines),
                    MarkerLayer(markers: markers),
                  ],
                ),
              ),
              // Floating Top Header
              PositionedDirectional(
                top: 0,
                start: 0,
                end: 0,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 14, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            Container(
                              padding: const EdgeInsetsDirectional.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surface,
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: const <BoxShadow>[
                                  BoxShadow(
                                    color: Colors.black12,
                                    blurRadius: 8,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  const Icon(
                                    Icons.local_shipping_rounded,
                                    color: WenshyColors.amber,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    strings.appName,
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              children: <Widget>[
                                ListenableBuilder(
                                  listenable: deps.notificationsViewModel,
                                  builder: (context, _) {
                                    final unread =
                                        deps.notificationsViewModel.unreadCount;
                                    return IconButton.filledTonal(
                                      key: const Key('notifications_bell_btn'),
                                      onPressed: () =>
                                          context.push('/notifications'),
                                      tooltip: strings.notificationsTitle,
                                      icon: Badge(
                                        isLabelVisible: unread > 0,
                                        backgroundColor: WenshyColors.red,
                                        label: Text(
                                          unread > 99 ? '99+' : '$unread',
                                        ),
                                        child: const Icon(
                                          Icons.notifications_outlined,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(width: 6),
                                IconButton.filledTonal(
                                  onPressed:
                                      vm.isLocating ? null : _onDetectLocation,
                                  tooltip: strings.detectMyLocation,
                                  icon: vm.isLocating
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.my_location_rounded),
                                ),
                                const SizedBox(width: 6),
                                const LanguageToggleButton(),
                              ],
                            ),
                          ],
                        ),
                        if (vm.activeTrip != null) ...<Widget>[
                          const SizedBox(height: 8),
                          Material(
                            color: WenshyColors.deepSlate,
                            borderRadius: BorderRadius.circular(14),
                            elevation: 3,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () => context.push(
                                '/trip/${vm.activeTrip!.id}',
                                extra: vm.activeTrip,
                              ),
                              child: Padding(
                                padding: const EdgeInsetsDirectional.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                child: Row(
                                  children: <Widget>[
                                    const Icon(
                                      Icons.radar_rounded,
                                      color: WenshyColors.amber,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        '${strings.activeTripBanner} (${vm.activeTrip!.requestCode})',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      strings.resumeTracking,
                                      style: const TextStyle(
                                        color: WenshyColors.amber,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                        if (vm.focusedDriver != null) ...<Widget>[
                          const SizedBox(height: 8),
                          _NearbyDriverCard(
                            driver: vm.focusedDriver!,
                            localeCode: localeCode,
                            onClose: () => vm.focusDriver(null),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              // Bottom Rescue Control Sheet
              PositionedDirectional(
                start: 0,
                end: 0,
                bottom: 0,
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                    boxShadow: const <BoxShadow>[
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 16,
                        offset: Offset(0, -4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: ChoiceChip(
                              selected: vm.pickMode == MapPickMode.pickup,
                              label: Text(strings.pickingPickupMode),
                              avatar: const Icon(
                                Icons.car_crash_rounded,
                                size: 16,
                              ),
                              onSelected: (_) =>
                                  vm.setPickMode(MapPickMode.pickup),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ChoiceChip(
                              selected: vm.pickMode == MapPickMode.dropoff,
                              label: Text(strings.pickingDropoffMode),
                              avatar: const Icon(Icons.flag_rounded, size: 16),
                              onSelected: (_) =>
                                  vm.setPickMode(MapPickMode.dropoff),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              vm.pickMode == MapPickMode.pickup
                                  ? strings.tapMapForPickup
                                  : strings.tapMapForDropoff,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          if (vm.isLoadingRoute)
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          else if (vm.roadRoute != null)
                            Container(
                              key: const Key('route_distance_badge'),
                              padding: const EdgeInsetsDirectional.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: WenshyColors.info.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${WenshyLabels.formatDistanceKm(vm.roadRoute!.distanceKm, locale: localeCode)} • ${WenshyLabels.formatEtaMinutes(vm.roadRoute!.durationMinutes, locale: localeCode)}',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: WenshyColors.info,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: TextField(
                              key: const Key('pickup_address_field'),
                              controller: _pickupAddressController,
                              onChanged: (v) {
                                _lastSyncedPickupAddress = v;
                                vm.updatePickupAddress(v);
                              },
                              onTap: () => vm.setPickMode(MapPickMode.pickup),
                              decoration: InputDecoration(
                                isDense: true,
                                labelText: strings.pickupPointLabel,
                                hintText: strings.pickupAddressHint,
                                prefixIcon: const Icon(
                                  Icons.my_location_rounded,
                                  color: WenshyColors.amberDark,
                                  size: 18,
                                ),
                                suffixIcon: IconButton(
                                  key: const Key('search_pickup_btn'),
                                  tooltip: strings.searchPlaceTitlePickup,
                                  onPressed: () =>
                                      _openPlaceSearchSheet(MapPickMode.pickup),
                                  icon: const Icon(Icons.search_rounded, size: 18),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              key: const Key('dropoff_address_field'),
                              controller: _dropoffAddressController,
                              onChanged: (v) {
                                _lastSyncedDropoffAddress = v;
                                vm.updateDropoffAddress(v);
                              },
                              onTap: () => vm.setPickMode(MapPickMode.dropoff),
                              decoration: InputDecoration(
                                isDense: true,
                                labelText: strings.dropoffPointLabel,
                                hintText: strings.dropoffAddressHint,
                                prefixIcon: const Icon(
                                  Icons.flag_rounded,
                                  color: WenshyColors.emerald,
                                  size: 18,
                                ),
                                suffixIcon: IconButton(
                                  key: const Key('search_dropoff_btn'),
                                  tooltip: strings.searchPlaceTitleDropoff,
                                  onPressed: () => _openPlaceSearchSheet(
                                    MapPickMode.dropoff,
                                  ),
                                  icon: const Icon(Icons.search_rounded, size: 18),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (vm.winchTypes.isNotEmpty) ...<Widget>[
                        SizedBox(
                          height: 42,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: vm.winchTypes.length,
                            separatorBuilder: (_, _) => const SizedBox(width: 8),
                            itemBuilder: (context, index) {
                              final type = vm.winchTypes[index];
                              final selected =
                                  vm.selectedWinchType?.id == type.id;
                              return FilterChip(
                                selected: selected,
                                label: Text(
                                  '${type.localizedName(localeCode)} • ${WenshyLabels.formatPrice(type.minimumFare, locale: localeCode)}',
                                ),
                                onSelected: (_) => vm.selectWinchType(
                                  type,
                                  locale: localeCode,
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      Row(
                        children: <Widget>[
                          Icon(
                            Icons.local_shipping_outlined,
                            size: 18,
                            color: vm.nearbyDrivers.isEmpty
                                ? WenshyColors.slateMuted
                                : WenshyColors.emerald,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              vm.nearbyDrivers.isEmpty
                                  ? strings.noNearbyWinches
                                  : '${strings.nearbyWinchesCount}: ${vm.nearbyDrivers.length}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            onPressed: vm.isLoadingDrivers
                                ? null
                                : () => vm.refreshNearbyDrivers(
                                      locale: localeCode,
                                    ),
                            icon: vm.isLoadingDrivers
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.refresh_rounded, size: 18),
                          ),
                        ],
                      ),
                      if (vm.errorMessage != null) ...<Widget>[
                        Text(
                          vm.errorMessage!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: WenshyColors.red,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 6),
                      ],
                      const SizedBox(height: 4),
                      WenshyPrimaryButton(
                        label: strings.requestWinchCta,
                        icon: Icons.sos_rounded,
                        onPressed: _onProceedToRequest,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PlaceSearchSheet extends StatefulWidget {
  const _PlaceSearchSheet({
    required this.viewModel,
    required this.target,
    required this.localeCode,
    this.initialQuery = '',
  });

  final HomeMapViewModel viewModel;
  final MapPickMode target;
  final String localeCode;
  final String initialQuery;

  @override
  State<_PlaceSearchSheet> createState() => _PlaceSearchSheetState();
}

class _PlaceSearchSheetState extends State<_PlaceSearchSheet> {
  late final TextEditingController _queryController;
  Timer? _debounce;
  bool _hasSearched = false;

  @override
  void initState() {
    super.initState();
    _queryController = TextEditingController(text: widget.initialQuery);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _queryController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _hasSearched = false;
      });
      widget.viewModel.clearSearchResults();
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() {
        _hasSearched = true;
      });
      widget.viewModel.searchPlaces(trimmed, locale: widget.localeCode);
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final theme = Theme.of(context);
    final isPickup = widget.target == MapPickMode.pickup;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.65,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 16, 12, 8),
              child: Row(
                children: <Widget>[
                  Icon(
                    isPickup ? Icons.my_location_rounded : Icons.flag_rounded,
                    color: isPickup
                        ? WenshyColors.amberDark
                        : WenshyColors.emerald,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isPickup
                          ? strings.searchPlaceTitlePickup
                          : strings.searchPlaceTitleDropoff,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
              child: TextField(
                key: const Key('place_search_input'),
                controller: _queryController,
                autofocus: true,
                onChanged: _onQueryChanged,
                textInputAction: TextInputAction.search,
                onSubmitted: (val) {
                  _debounce?.cancel();
                  if (val.trim().isNotEmpty) {
                    setState(() {
                      _hasSearched = true;
                    });
                    widget.viewModel.searchPlaces(
                      val.trim(),
                      locale: widget.localeCode,
                    );
                  }
                },
                decoration: InputDecoration(
                  hintText: strings.searchPlaceHint,
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _queryController.text.isNotEmpty
                      ? IconButton(
                          onPressed: () {
                            _queryController.clear();
                            _onQueryChanged('');
                          },
                          icon: const Icon(Icons.clear_rounded),
                        )
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListenableBuilder(
                listenable: widget.viewModel,
                builder: (context, _) {
                  if (widget.viewModel.isSearchingPlaces) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final results = widget.viewModel.searchResults;
                  if (results.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsetsDirectional.all(24),
                        child: Text(
                          _hasSearched
                              ? strings.searchPlaceNoResults
                              : strings.searchPlaceStartTyping,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsetsDirectional.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    itemCount: results.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final suggestion = results[index];
                      return ListTile(
                        key: Key('place_suggestion_$index'),
                        leading: CircleAvatar(
                          backgroundColor: isPickup
                              ? WenshyColors.amberSoft
                              : WenshyColors.emerald.withValues(alpha: 0.14),
                          child: Icon(
                            Icons.location_on_rounded,
                            color: isPickup
                                ? WenshyColors.amberDark
                                : WenshyColors.emerald,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          suggestion.shortName,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: Text(
                          suggestion.displayName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => Navigator.of(context).pop(suggestion),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NearbyDriverCard extends StatelessWidget {
  const _NearbyDriverCard({
    required this.driver,
    required this.localeCode,
    required this.onClose,
  });

  final NearbyDriver driver;
  final String localeCode;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(12),
        child: Row(
          children: <Widget>[
            const CircleAvatar(
              backgroundColor: WenshyColors.amberSoft,
              child: Icon(
                Icons.local_shipping_rounded,
                color: WenshyColors.deepSlate,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    driver.fullName,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '${driver.winchBrand} ${driver.winchModel} • ${driver.plateNumber}',
                    style: theme.textTheme.bodySmall,
                  ),
                  Text(
                    '★ ${driver.avgRating.toStringAsFixed(1)} • ${WenshyLabels.formatDistanceMeters(driver.distanceMeters, locale: localeCode)} • ${WenshyLabels.formatEtaMinutes(driver.etaMinutes, locale: localeCode)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: WenshyColors.amberDark,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onClose,
              icon: const Icon(Icons.close_rounded, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}
