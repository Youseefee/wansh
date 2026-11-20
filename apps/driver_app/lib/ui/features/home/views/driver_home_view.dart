import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:wenshy_core/wenshy_core.dart';

import '../../../core/driver_strings.dart';
import '../../../core/locale_controller.dart';
import '../../../core/widgets/driver_widgets.dart';
import '../../notifications/view_models/notifications_view_model.dart';
import '../view_models/driver_home_view_model.dart';
import 'incoming_offer_sheet.dart';

/// Main approved-driver dispatch screen: online/offline toggle, Presence status,
/// live map, active trip resume banner, and incoming offer listener card.
class DriverHomeView extends StatefulWidget {
  const DriverHomeView({
    super.key,
    required this.viewModel,
    required this.localeController,
    this.notificationsController,
    this.showMapTiles = true,
  });

  final DriverHomeViewModel viewModel;
  final LocaleController localeController;
  final DriverNotificationsController? notificationsController;
  final bool showMapTiles;

  @override
  State<DriverHomeView> createState() => _DriverHomeViewState();
}

class _DriverHomeViewState extends State<DriverHomeView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.viewModel.initialize();
    });
  }

  Future<void> _onAcceptOffer() async {
    final requestId = await widget.viewModel.acceptCurrentOffer();
    if (requestId != null && mounted) {
      context.push('/trip/$requestId');
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
        final driver = vm.driverProfile;
        final pos = vm.currentPosition;
        final driverLatLng =
            pos != null ? LatLng(pos.lat, pos.lng) : DriverRouteMap.defaultCenter;

        return Scaffold(
          appBar: AppBar(
            title: Text(DriverStrings.appTitle(locale)),
            actions: <Widget>[
              if (widget.notificationsController != null)
                NotificationsBellButton(
                  notificationsController: widget.notificationsController!,
                  localeController: widget.localeController,
                ),
              LocaleToggleButton(localeController: widget.localeController),
            ],
          ),
          body: vm.isInitializing
              ? const WenshyLoadingView()
              : Stack(
                  children: <Widget>[
                    Positioned.fill(
                      child: DriverRouteMap(
                        driverPoint: driverLatLng,
                        pickupPoint: vm.activeOffer?.rescueRequest != null
                            ? LatLng(
                                vm.activeOffer!.rescueRequest!.pickupLat,
                                vm.activeOffer!.rescueRequest!.pickupLng,
                              )
                            : null,
                        dropoffPoint: vm.activeOffer?.rescueRequest != null
                            ? LatLng(
                                vm.activeOffer!.rescueRequest!.dropoffLat,
                                vm.activeOffer!.rescueRequest!.dropoffLng,
                              )
                            : null,
                        showTileLayer: widget.showMapTiles,
                      ),
                    ),
                    PositionedDirectional(
                      top: 12,
                      start: 16,
                      end: 16,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          _OnlineStatusCard(
                            isOnline: vm.isOnline,
                            isToggling: vm.isTogglingOnline,
                            driver: driver,
                            locale: locale,
                            onToggle: vm.toggleOnline,
                          ),
                          if (vm.activeTripId != null) ...<Widget>[
                            const SizedBox(height: 10),
                            _ActiveTripResumeCard(
                              locale: locale,
                              onResume: () =>
                                  context.push('/trip/${vm.activeTripId}'),
                            ),
                          ],
                          if (vm.errorMessage != null) ...<Widget>[
                            const SizedBox(height: 10),
                            _DismissibleNoticeCard(
                              message: vm.errorMessage!,
                              color: WenshyColors.red,
                              onDismiss: vm.clearMessages,
                            ),
                          ] else if (vm.statusMessage != null) ...<Widget>[
                            const SizedBox(height: 10),
                            _DismissibleNoticeCard(
                              message: vm.statusMessage!,
                              color: WenshyColors.amberDark,
                              onDismiss: vm.clearMessages,
                            ),
                          ],
                        ],
                      ),
                    ),
                    PositionedDirectional(
                      bottom: 16,
                      start: 16,
                      end: 16,
                      child: vm.activeOffer != null
                          ? IncomingOfferCard(
                              offer: vm.activeOffer!,
                              remaining: vm.offerRemaining,
                              locale: locale,
                              isBusy: vm.isRespondingToOffer,
                              onAccept: _onAcceptOffer,
                              onReject: () => vm.rejectCurrentOffer(),
                            )
                          : Card(
                              child: Padding(
                                padding: const EdgeInsetsDirectional.all(16),
                                child: Row(
                                  children: <Widget>[
                                    Icon(
                                      vm.isOnline
                                          ? Icons.radar_rounded
                                          : Icons.power_settings_new_rounded,
                                      color: vm.isOnline
                                          ? WenshyColors.emerald
                                          : WenshyColors.slateMuted,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        vm.isOnline
                                            ? DriverStrings.waitingForOffers(
                                                locale,
                                              )
                                            : DriverStrings.goOnlinePrompt(
                                                locale,
                                              ),
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}

class _OnlineStatusCard extends StatelessWidget {
  const _OnlineStatusCard({
    required this.isOnline,
    required this.isToggling,
    required this.driver,
    required this.locale,
    required this.onToggle,
  });

  final bool isOnline;
  final bool isToggling;
  final DriverProfile? driver;
  final String locale;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: isOnline ? WenshyColors.deepSlate : Colors.white,
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: isOnline ? WenshyColors.emerald : WenshyColors.slateMuted,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    isOnline
                        ? DriverStrings.onlineLabel(locale)
                        : DriverStrings.offlineLabel(locale),
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: isOnline ? Colors.white : WenshyColors.deepSlate,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (driver != null)
                    Text(
                      '${WenshyLabels.formatPrice(driver!.totalEarnings, locale: locale)} • ${driver!.totalTrips} ${DriverStrings.t(locale, 'رحلة', 'trips')}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isOnline
                            ? const Color(0xFFCBD5E1)
                            : WenshyColors.slateMuted,
                      ),
                    ),
                ],
              ),
            ),
            if (isToggling)
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              )
            else
              Switch(
                value: isOnline,
                activeThumbColor: WenshyColors.emerald,
                onChanged: onToggle,
              ),
          ],
        ),
      ),
    );
  }
}

class _ActiveTripResumeCard extends StatelessWidget {
  const _ActiveTripResumeCard({
    required this.locale,
    required this.onResume,
  });

  final String locale;
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: WenshyColors.amberSoft,
      child: ListTile(
        leading: const Icon(
          Icons.local_shipping_rounded,
          color: WenshyColors.amberDark,
        ),
        title: Text(
          DriverStrings.activeTripBanner(locale),
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            color: WenshyColors.deepSlate,
          ),
        ),
        trailing: FilledButton(
          onPressed: onResume,
          child: Text(DriverStrings.resumeTrip(locale)),
        ),
      ),
    );
  }
}

class _DismissibleNoticeCard extends StatelessWidget {
  const _DismissibleNoticeCard({
    required this.message,
    required this.color,
    required this.onDismiss,
  });

  final String message;
  final Color color;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: color),
      ),
      child: ListTile(
        dense: true,
        leading: Icon(Icons.info_outline, color: color),
        title: Text(
          message,
          style: TextStyle(color: color, fontWeight: FontWeight.w600),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.close, size: 18),
          onPressed: onDismiss,
        ),
      ),
    );
  }
}
