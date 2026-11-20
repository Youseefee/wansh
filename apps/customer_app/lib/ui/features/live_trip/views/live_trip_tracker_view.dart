import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:wenshy_core/wenshy_core.dart';

import '../../../core/app_dependencies.dart';
import '../../../core/app_strings.dart';
import '../../../core/wenshy_map_markers.dart';
import '../view_models/live_trip_view_model.dart';

/// Live Trip Tracker subscribing to private Realtime channel `trip:<request_id>`,
/// animating the tow truck marker smoothly, displaying the 6-step timeline,
/// driver & winch info, Wave-2 dispatch retry, and cancellation.
class LiveTripTrackerView extends StatefulWidget {
  const LiveTripTrackerView({
    super.key,
    required this.requestId,
    this.initialRequest,
    this.initialDispatch,
  });

  final String requestId;
  final RescueRequest? initialRequest;
  final DispatchResult? initialDispatch;

  @override
  State<LiveTripTrackerView> createState() => _LiveTripTrackerViewState();
}

class _LiveTripTrackerViewState extends State<LiveTripTrackerView>
    with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  late final AnimationController _markerAnimController;
  Animation<LatLng>? _markerAnimation;
  LatLng? _animatedDriverPos;

  LiveTripViewModel? _vm;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _markerAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;

    final deps = AppDependenciesScope.of(context);
    final vm = LiveTripViewModel(
      requestId: widget.requestId,
      rescueRepository: deps.rescueRepository,
      mapRepository: deps.mapRepository,
      winchCatalog: deps.winchCatalog,
      initialRequest: widget.initialRequest,
      initialDispatch: widget.initialDispatch,
    );
    _vm = vm;
    vm.addListener(_onViewModelChanged);
    vm.initialize(locale: deps.localeController.languageCode);
  }

  void _onViewModelChanged() {
    final target = _vm?.driverLatLng;
    if (target == null) return;
    if (_animatedDriverPos == null) {
      setState(() {
        _animatedDriverPos = target;
      });
      return;
    }
    if (_animatedDriverPos == target) return;

    final begin = _animatedDriverPos!;
    _markerAnimation = LatLngTween(begin: begin, end: target).animate(
      CurvedAnimation(
        parent: _markerAnimController,
        curve: Curves.easeInOut,
      ),
    );
    _markerAnimController
      ..reset()
      ..forward();
  }

  @override
  void dispose() {
    _vm?.removeListener(_onViewModelChanged);
    _vm?.dispose();
    _markerAnimController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _confirmCancel() async {
    final vm = _vm;
    if (vm == null) return;
    final strings = AppStrings.of(context);
    final localeCode = AppDependenciesScope.of(context).localeController.languageCode;
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(strings.confirmCancelTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(strings.confirmCancelBody),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                hintText: strings.cancelReasonHint,
              ),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(strings.close),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: WenshyColors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(strings.cancelTripBtn),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await vm.cancelTrip(
        reason: reasonController.text,
        locale: localeCode,
      );
    }
    reasonController.dispose();
  }

  Future<void> _callDriver(String phone) async {
    final deps = AppDependenciesScope.of(context);
    final strings = AppStrings.of(context);
    final launched = await deps.phoneDialer.callPhone(phone);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.callFailedError)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final deps = AppDependenciesScope.of(context);
    final vm = _vm!;
    final strings = AppStrings.of(context);
    final theme = Theme.of(context);
    final localeCode = deps.localeController.languageCode;

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.liveTrackingTitle),
        actions: <Widget>[
          IconButton(
            onPressed: () => vm.refresh(locale: localeCode),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge(<Listenable>[vm, _markerAnimController]),
        builder: (context, _) {
          final req = vm.request;
          if (vm.isLoading && req == null) {
            return WenshyLoadingView(message: strings.loading);
          }
          if (req == null) {
            return WenshyErrorView(
              message: vm.errorMessage ?? strings.unexpectedError,
              onRetry: () => vm.refresh(locale: localeCode),
            );
          }

          final pickup = LatLng(req.pickupLat, req.pickupLng);
          final dropoff = LatLng(req.dropoffLat, req.dropoffLng);
          final animatedDriver = _markerAnimation?.value ?? _animatedDriverPos;
          if (_markerAnimation?.value != null) {
            _animatedDriverPos = _markerAnimation!.value;
          }

          return Column(
            children: <Widget>[
              Expanded(
                flex: 5,
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: animatedDriver ?? pickup,
                    initialZoom: 13.0,
                  ),
                  children: <Widget>[
                    if (deps.enableNetworkTiles)
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.wenshy.wenshy_customer',
                      ),
                    PolylineLayer(
                      polylines: <Polyline>[
                        Polyline(
                          points: vm.routePolyline,
                          color: WenshyColors.deepSlate,
                          strokeWidth: 4.5,
                        ),
                      ],
                    ),
                    MarkerLayer(
                      markers: <Marker>[
                        Marker(
                          point: pickup,
                          width: 85,
                          height: 62,
                          alignment: Alignment.topCenter,
                          child: WenshyMapMarkers.pickupPin(
                            label: strings.pickingPickupMode,
                          ),
                        ),
                        Marker(
                          point: dropoff,
                          width: 85,
                          height: 62,
                          alignment: Alignment.topCenter,
                          child: WenshyMapMarkers.dropoffPin(
                            label: strings.pickingDropoffMode,
                          ),
                        ),
                        if (animatedDriver != null)
                          Marker(
                            point: animatedDriver,
                            width: 48,
                            height: 48,
                            child: WenshyMapMarkers.liveTowTruckMarker(
                              headingDegrees: vm.latestDriverPoint?.heading,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 6,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                    boxShadow: const <BoxShadow>[
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 12,
                        offset: Offset(0, -3),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsetsDirectional.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  req.requestCode,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                if (vm.realtimeConnected)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      const Icon(
                                        Icons.circle,
                                        size: 8,
                                        color: WenshyColors.emerald,
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        strings.liveGpsActive,
                                        style:
                                            theme.textTheme.bodySmall?.copyWith(
                                          color: WenshyColors.emerald,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                            WenshyStatusBadge.trip(
                              req.status,
                              locale: localeCode,
                              short: false,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        if (vm.actionMessage != null) ...<Widget>[
                          Container(
                            padding: const EdgeInsetsDirectional.all(10),
                            decoration: BoxDecoration(
                              color: WenshyColors.amberSoft,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              vm.actionMessage!,
                              style: const TextStyle(
                                color: WenshyColors.deepSlate,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                        if (vm.errorMessage != null) ...<Widget>[
                          Text(
                            vm.errorMessage!,
                            style: const TextStyle(
                              color: WenshyColors.red,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],

                        // Searching & Wave-2 Retry Section
                        if (req.status == TripStatus.searching) ...<Widget>[
                          Card(
                            color: WenshyColors.amberSoft,
                            child: Padding(
                              padding: const EdgeInsetsDirectional.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: <Widget>[
                                  Row(
                                    children: <Widget>[
                                      const Icon(
                                        Icons.radar_rounded,
                                        color: WenshyColors.amberDark,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          strings.searchingDriversTitle,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: WenshyColors.deepSlate,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    strings.currentWaveLabel(req.currentWave),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: WenshyColors.deepSlate,
                                    ),
                                  ),
                                  if (vm.lastDispatch != null)
                                    Text(
                                      strings.driversNotifiedLabel(
                                        vm.lastDispatch!.dispatchedCount,
                                      ),
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        color: WenshyColors.deepSlate,
                                      ),
                                    ),
                                  const SizedBox(height: 12),
                                  WenshyPrimaryButton(
                                    label: strings.expandSearchWaveBtn,
                                    icon: Icons.radar_rounded,
                                    isLoading: vm.isDispatchingWave,
                                    onPressed: () =>
                                        vm.retryNextWave(locale: localeCode),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],

                        // 6-step Trip Progress Timeline
                        if (req.status != TripStatus.searching &&
                            req.status != TripStatus.cancelled &&
                            req.status != TripStatus.expired) ...<Widget>[
                          Text(
                            strings.tripProgress,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _SixStepTripTimeline(
                            currentStatus: req.status,
                            localeCode: localeCode,
                          ),
                          const SizedBox(height: 14),
                        ],

                        // Driver & Winch Info
                        if (req.driverId != null) ...<Widget>[
                          _AssignedDriverWinchCard(
                            driver: vm.driver,
                            winch: vm.winch,
                            winchType: vm.winchType,
                            localeCode: localeCode,
                            title: strings.driverAndWinchInfo,
                            callButtonLabel: strings.callDriverBtn,
                            onCallDriver: _callDriver,
                          ),
                          const SizedBox(height: 14),
                        ],

                        // Price & Route Summary
                        Card(
                          child: Padding(
                            padding: const EdgeInsetsDirectional.all(14),
                            child: Column(
                              children: <Widget>[
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: <Widget>[
                                    Text(
                                      req.finalPrice != null
                                          ? strings.finalPriceLabel
                                          : strings.estimatedTotal,
                                      style: theme.textTheme.titleSmall,
                                    ),
                                    Text(
                                      WenshyLabels.formatPrice(
                                        req.displayPrice,
                                        currency: req.currency,
                                        locale: localeCode,
                                      ),
                                      style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w800,
                                        color: WenshyColors.amberDark,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: <Widget>[
                                    Text(
                                      WenshyLabels.paymentMethod(
                                        req.paymentMethod,
                                        locale: localeCode,
                                      ),
                                      style: theme.textTheme.bodySmall,
                                    ),
                                    Text(
                                      WenshyLabels.paymentStatus(
                                        req.paymentStatus,
                                        locale: localeCode,
                                      ),
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Cancellation & Post-Delivery CTAs
                        if (req.status.isCancellable)
                          OutlinedButton.icon(
                            onPressed:
                                vm.isCancelling ? null : _confirmCancel,
                            icon: const Icon(
                              Icons.cancel_outlined,
                              color: WenshyColors.red,
                            ),
                            label: Text(
                              strings.cancelTripBtn,
                              style: const TextStyle(color: WenshyColors.red),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: WenshyColors.red.withValues(alpha: 0.5),
                              ),
                            ),
                          ),

                        if (req.status == TripStatus.delivered) ...<Widget>[
                          WenshyPrimaryButton(
                            label: strings.rateTripCta,
                            icon: Icons.star_rounded,
                            onPressed: () =>
                                context.push('/trip/${req.id}/rate'),
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            onPressed: () => context.push(
                              '/complaints/new?requestId=${req.id}&reportedUserId=${req.driverId ?? ''}',
                            ),
                            icon: const Icon(Icons.report_problem_outlined),
                            label: Text(strings.fileComplaintCta),
                          ),
                        ],

                        if (req.status == TripStatus.cancelled ||
                            req.status == TripStatus.expired) ...<Widget>[
                          if (req.cancellationReason != null &&
                              req.cancellationReason!.isNotEmpty) ...<Widget>[
                            Text(
                              req.cancellationReason!,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: WenshyColors.red,
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],
                          WenshyPrimaryButton(
                            label: strings.newRequestCta,
                            icon: Icons.add_location_alt_outlined,
                            onPressed: () => context.go('/'),
                          ),
                        ],
                      ],
                    ),
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

class _SixStepTripTimeline extends StatelessWidget {
  const _SixStepTripTimeline({
    required this.currentStatus,
    required this.localeCode,
  });

  final TripStatus currentStatus;
  final String localeCode;

  @override
  Widget build(BuildContext context) {
    final steps = TripStatus.activeTimelineSteps;
    final currentIdx = steps.indexOf(currentStatus);

    return Card(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(12),
        child: Column(
          children: <Widget>[
            for (var i = 0; i < steps.length; i++) ...<Widget>[
              Row(
                children: <Widget>[
                  Icon(
                    i < currentIdx
                        ? Icons.check_circle_rounded
                        : i == currentIdx
                            ? Icons.radio_button_checked_rounded
                            : Icons.radio_button_unchecked_rounded,
                    size: 20,
                    color: i <= currentIdx
                        ? (i == steps.length - 1 && currentIdx == i
                            ? WenshyColors.emerald
                            : WenshyColors.amberDark)
                        : WenshyColors.slateMuted,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      WenshyLabels.tripStatus(steps[i], locale: localeCode),
                      style: TextStyle(
                        fontWeight:
                            i == currentIdx ? FontWeight.w800 : FontWeight.w500,
                        color: i <= currentIdx
                            ? Theme.of(context).colorScheme.onSurface
                            : WenshyColors.slateMuted,
                      ),
                    ),
                  ),
                ],
              ),
              if (i < steps.length - 1)
                const Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Padding(
                    padding: EdgeInsetsDirectional.only(start: 9),
                    child: SizedBox(
                      height: 12,
                      child: VerticalDivider(width: 2, thickness: 2),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AssignedDriverWinchCard extends StatelessWidget {
  const _AssignedDriverWinchCard({
    required this.driver,
    required this.winch,
    required this.winchType,
    required this.localeCode,
    required this.title,
    required this.callButtonLabel,
    required this.onCallDriver,
  });

  final DriverProfile? driver;
  final DriverWinch? winch;
  final WinchType? winchType;
  final String localeCode;
  final String title;
  final String callButtonLabel;
  final ValueChanged<String> onCallDriver;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final driverName = driver?.profile?.fullName.isNotEmpty == true
        ? driver!.profile!.fullName
        : '—';
    final driverPhone = driver?.profile?.phone?.trim();
    final hasPhone = driverPhone != null && driverPhone.isNotEmpty;

    return Card(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                const CircleAvatar(
                  backgroundColor: WenshyColors.amberSoft,
                  child: Icon(
                    Icons.person_rounded,
                    color: WenshyColors.deepSlate,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        driverName,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (hasPhone)
                        Text(
                          driverPhone,
                          textDirection: TextDirection.ltr,
                          style: theme.textTheme.bodySmall,
                        ),
                      if (driver != null)
                        Text(
                          '★ ${driver!.avgRating.toStringAsFixed(1)} • ${driver!.totalTrips} trips',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: WenshyColors.amberDark,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
                if (hasPhone) ...<Widget>[
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    key: const Key('call_driver_btn'),
                    onPressed: () => onCallDriver(driverPhone),
                    style: FilledButton.styleFrom(
                      backgroundColor: WenshyColors.emerald,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsetsDirectional.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    icon: const Icon(Icons.call_rounded, size: 18),
                    label: Text(
                      callButtonLabel,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ],
            ),
            if (winch != null || winchType != null) ...<Widget>[
              const Divider(height: 18),
              Row(
                children: <Widget>[
                  const Icon(
                    Icons.local_shipping_outlined,
                    size: 18,
                    color: WenshyColors.slateMuted,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      [
                        if (winchType != null)
                          winchType!.localizedName(localeCode),
                        if (winch != null) winch!.displayLabel,
                        if (winch != null) winch!.plateNumber,
                      ].join(' • '),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
