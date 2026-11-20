import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:wenshy_core/wenshy_core.dart';

import '../../../../data/services/external_launcher_service.dart';
import '../../../core/driver_strings.dart';
import '../../../core/locale_controller.dart';
import '../../../core/widgets/driver_widgets.dart';
import '../view_models/active_trip_view_model.dart';

/// Active Trip Execution screen:
/// - Pickup, Dropoff, and live Driver markers on `flutter_map`
/// - Live GPS broadcast status indicator
/// - 6-step trip progress timeline
/// - Stage progression CTA (`driver_update_trip_stage`)
/// - Customer & vehicle details + breakdown photo previews
class ActiveTripView extends StatefulWidget {
  const ActiveTripView({
    super.key,
    required this.requestId,
    required this.viewModel,
    required this.localeController,
    this.showMapTiles = true,
  });

  final String requestId;
  final ActiveTripViewModel viewModel;
  final LocaleController localeController;
  final bool showMapTiles;

  @override
  State<ActiveTripView> createState() => _ActiveTripViewState();
}

class _ActiveTripViewState extends State<ActiveTripView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.viewModel.loadTrip(widget.requestId);
    });
  }

  Future<void> _confirmCancel(String locale) async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: Text(DriverStrings.cancelTrip(locale)),
          content: TextField(
            controller: reasonController,
            decoration: InputDecoration(
              labelText: DriverStrings.t(
                locale,
                'سبب الإلغاء (اختياري)',
                'Cancellation reason (optional)',
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(false),
              child: Text(DriverStrings.t(locale, 'تراجع', 'Back')),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: WenshyColors.red),
              onPressed: () => Navigator.of(dialogCtx).pop(true),
              child: Text(DriverStrings.cancelTrip(locale)),
            ),
          ],
        );
      },
    );

    final reason = reasonController.text.trim();
    reasonController.dispose();

    if (confirmed == true && mounted) {
      final ok = await widget.viewModel.cancelTrip(
        reason: reason.isEmpty ? null : reason,
      );
      if (ok && mounted) {
        context.go('/home');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[
        widget.viewModel,
        widget.localeController,
      ]),
      builder: (context, _) {
        final locale = widget.localeController.localeCode;
        final theme = Theme.of(context);
        final vm = widget.viewModel;
        final trip = vm.trip;

        return Scaffold(
          appBar: AppBar(
            title: Text(
              trip != null
                  ? '${DriverStrings.activeTripTitle(locale)} (${trip.requestCode})'
                  : DriverStrings.activeTripTitle(locale),
            ),
            actions: <Widget>[
              LocaleToggleButton(localeController: widget.localeController),
            ],
          ),
          body: vm.isLoading && trip == null
              ? const WenshyLoadingView()
              : trip == null
                  ? WenshyErrorView(
                      message: vm.errorMessage ??
                          DriverStrings.t(
                            locale,
                            'تعذر تحميل بيانات الرحلة',
                            'Could not load trip details',
                          ),
                      onRetry: () => vm.loadTrip(widget.requestId),
                    )
                  : Column(
                      children: <Widget>[
                        SizedBox(
                          height: 240,
                          child: Stack(
                            children: <Widget>[
                              DriverRouteMap(
                                driverPoint: vm.driverPosition != null
                                    ? LatLng(
                                        vm.driverPosition!.lat,
                                        vm.driverPosition!.lng,
                                      )
                                    : null,
                                pickupPoint: LatLng(
                                  trip.pickupLat,
                                  trip.pickupLng,
                                ),
                                dropoffPoint: LatLng(
                                  trip.dropoffLat,
                                  trip.dropoffLng,
                                ),
                                routePoints: vm.routePolylinePoints.isNotEmpty
                                    ? vm.routePolylinePoints
                                    : null,
                                showTileLayer: widget.showMapTiles,
                              ),
                              if (vm.isGpsStreaming)
                                PositionedDirectional(
                                  top: 12,
                                  start: 12,
                                  child: WenshyStatusBadge(
                                    label: DriverStrings.liveGpsActive(locale),
                                    color: WenshyColors.emerald,
                                    backgroundColor: Colors.white,
                                    icon: Icons.sensors_rounded,
                                  ),
                                ),
                              if (vm.activeRoute != null)
                                PositionedDirectional(
                                  bottom: 12,
                                  end: 12,
                                  child: WenshyStatusBadge(
                                    label:
                                        '${WenshyLabels.formatDistanceKm(vm.activeRoute!.distanceKm, locale: locale)} • ${WenshyLabels.formatEtaMinutes(vm.activeRoute!.durationMinutes, locale: locale)}',
                                    color: WenshyColors.deepSlate,
                                    backgroundColor: Colors.white,
                                    icon: Icons.route_rounded,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: ListView(
                            padding: const EdgeInsetsDirectional.all(16),
                            children: <Widget>[
                              if (vm.errorMessage != null) ...<Widget>[
                                Container(
                                  padding: const EdgeInsetsDirectional.all(12),
                                  decoration: BoxDecoration(
                                    color: WenshyColors.red
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    vm.errorMessage!,
                                    style: const TextStyle(
                                      color: WenshyColors.red,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],
                              Card(
                                child: Padding(
                                  padding: const EdgeInsetsDirectional.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: <Widget>[
                                          WenshyStatusBadge.trip(
                                            trip.status,
                                            locale: locale,
                                            short: false,
                                          ),
                                          Text(
                                            WenshyLabels.formatPrice(
                                              trip.displayPrice,
                                              currency: trip.currency,
                                              locale: locale,
                                            ),
                                            style: theme.textTheme.titleMedium
                                                ?.copyWith(
                                              fontWeight: FontWeight.w800,
                                              color: WenshyColors.amberDark,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 14),
                                      _TripStageTimeline(
                                        currentStatus: trip.status,
                                        locale: locale,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Card(
                                child: Padding(
                                  padding: const EdgeInsetsDirectional.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      _LocationBlock(
                                        icon: Icons.my_location_rounded,
                                        color: WenshyColors.red,
                                        title:
                                            DriverStrings.pickupPoint(locale),
                                        address: trip.pickupAddress,
                                      ),
                                      const Divider(height: 20),
                                      _LocationBlock(
                                        icon: Icons.flag_rounded,
                                        color: WenshyColors.emerald,
                                        title:
                                            DriverStrings.dropoffPoint(locale),
                                        address: trip.dropoffAddress,
                                      ),
                                      if (vm.navigationTarget != null) ...<Widget>[
                                        const SizedBox(height: 14),
                                        Row(
                                          children: <Widget>[
                                            Expanded(
                                              child: FilledButton.icon(
                                                key: const Key(
                                                  'navigate_google_maps_btn',
                                                ),
                                                style: FilledButton.styleFrom(
                                                  backgroundColor:
                                                      WenshyColors.deepSlate,
                                                  foregroundColor:
                                                      WenshyColors.amber,
                                                ),
                                                onPressed: () =>
                                                    vm.openExternalNavigation(
                                                  provider: ExternalNavProvider
                                                      .googleMaps,
                                                ),
                                                icon: const Icon(
                                                  Icons.navigation_rounded,
                                                ),
                                                label: Text(
                                                  vm.navigationTarget!.isDropoff
                                                      ? DriverStrings
                                                          .navigateToDropoff(
                                                          locale,
                                                        )
                                                      : DriverStrings
                                                          .navigateToPickup(
                                                          locale,
                                                        ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            OutlinedButton.icon(
                                              key: const Key(
                                                'navigate_waze_btn',
                                              ),
                                              onPressed: () =>
                                                  vm.openExternalNavigation(
                                                provider:
                                                    ExternalNavProvider.waze,
                                              ),
                                              icon: const Icon(
                                                Icons.alt_route_rounded,
                                                size: 18,
                                              ),
                                              label: Text(
                                                DriverStrings.openInWaze(
                                                  locale,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Card(
                                child: Padding(
                                  padding: const EdgeInsetsDirectional.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Row(
                                        children: <Widget>[
                                          Expanded(
                                            child: Text(
                                              DriverStrings.customerDetails(
                                                locale,
                                              ),
                                              style: theme.textTheme.titleSmall
                                                  ?.copyWith(
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                          if (vm.customerPhone != null)
                                            FilledButton.tonalIcon(
                                              key: const Key(
                                                'call_customer_btn',
                                              ),
                                              onPressed: vm.callCustomer,
                                              icon: const Icon(
                                                Icons.phone_rounded,
                                                size: 18,
                                              ),
                                              label: Text(
                                                DriverStrings.callCustomer(
                                                  locale,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      if (vm.customerProfile != null) ...<Widget>[
                                        Text(
                                          vm.customerProfile!.fullName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        if (vm.customerProfile!.phone != null)
                                          Text(vm.customerProfile!.phone!),
                                        const SizedBox(height: 6),
                                      ],
                                      Text(
                                        [
                                          ?trip.vehicleSummary,
                                          if (trip.vehiclePlate != null)
                                            trip.vehiclePlate!,
                                          WenshyLabels.vehicleCategory(
                                            trip.vehicleCategory,
                                            locale: locale,
                                          ),
                                        ].join(' • '),
                                      ),
                                      if (trip.breakdownReason != null &&
                                          trip.breakdownReason!
                                              .trim()
                                              .isNotEmpty) ...<Widget>[
                                        const SizedBox(height: 6),
                                        Text(
                                          trip.breakdownReason!,
                                          style: TextStyle(
                                            color: theme
                                                .colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                      if (trip.breakdownNotes != null &&
                                          trip.breakdownNotes!
                                              .trim()
                                              .isNotEmpty) ...<Widget>[
                                        const SizedBox(height: 4),
                                        Text(trip.breakdownNotes!),
                                      ],
                                      if (vm.breakdownPhotoUrls
                                          .isNotEmpty) ...<Widget>[
                                        const SizedBox(height: 10),
                                        Text(
                                          DriverStrings.breakdownPhotos(locale),
                                          style: theme.textTheme.labelMedium
                                              ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        SizedBox(
                                          height: 76,
                                          child: ListView(
                                            scrollDirection: Axis.horizontal,
                                            children: vm
                                                .breakdownPhotoUrls.values
                                                .map(
                                                  (url) => Padding(
                                                    padding:
                                                        const EdgeInsetsDirectional
                                                            .only(end: 8),
                                                    child: ClipRRect(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                        10,
                                                      ),
                                                      child: Image.network(
                                                        url,
                                                        width: 76,
                                                        height: 76,
                                                        fit: BoxFit.cover,
                                                      ),
                                                    ),
                                                  ),
                                                )
                                                .toList(growable: false),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              if (vm.nextStage != null)
                                WenshyPrimaryButton(
                                  label: WenshyLabels.tripStageAction(
                                    vm.nextStage!,
                                    locale: locale,
                                  ),
                                  icon: vm.nextStage == TripStatus.delivered
                                      ? Icons.check_circle_rounded
                                      : Icons.arrow_forward_rounded,
                                  backgroundColor:
                                      vm.nextStage == TripStatus.delivered
                                          ? WenshyColors.emerald
                                          : WenshyColors.amber,
                                  foregroundColor:
                                      vm.nextStage == TripStatus.delivered
                                          ? Colors.white
                                          : WenshyColors.deepSlate,
                                  isLoading: vm.isUpdatingStage,
                                  onPressed: () => vm.advanceToNextStage(),
                                )
                              else
                                WenshyPrimaryButton(
                                  label: DriverStrings.t(
                                    locale,
                                    'العودة للرئيسية',
                                    'Back to Home',
                                  ),
                                  icon: Icons.home_outlined,
                                  onPressed: () => context.go('/home'),
                                ),
                              if (trip.status.isCancellable) ...<Widget>[
                                const SizedBox(height: 10),
                                OutlinedButton.icon(
                                  onPressed: vm.isUpdatingStage
                                      ? null
                                      : () => _confirmCancel(locale),
                                  icon: const Icon(Icons.cancel_outlined),
                                  label:
                                      Text(DriverStrings.cancelTrip(locale)),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: WenshyColors.red,
                                    side: const BorderSide(
                                      color: WenshyColors.red,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
        );
      },
    );
  }
}

class _TripStageTimeline extends StatelessWidget {
  const _TripStageTimeline({
    required this.currentStatus,
    required this.locale,
  });

  final TripStatus currentStatus;
  final String locale;

  @override
  Widget build(BuildContext context) {
    const steps = TripStatus.activeTimelineSteps;
    final activeIdx = steps.indexOf(currentStatus);

    return Column(
      children: <Widget>[
        for (var i = 0; i < steps.length; i++)
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(vertical: 4),
            child: Row(
              children: <Widget>[
                Icon(
                  i <= activeIdx
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  size: 18,
                  color: i < activeIdx
                      ? WenshyColors.emerald
                      : i == activeIdx
                          ? WenshyColors.amberDark
                          : WenshyColors.slateMuted,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    WenshyLabels.tripStatus(steps[i], locale: locale),
                    style: TextStyle(
                      fontWeight:
                          i == activeIdx ? FontWeight.w800 : FontWeight.w500,
                      color: i <= activeIdx
                          ? WenshyColors.deepSlate
                          : WenshyColors.slateMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _LocationBlock extends StatelessWidget {
  const _LocationBlock({
    required this.icon,
    required this.color,
    required this.title,
    required this.address,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String address;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                address,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
