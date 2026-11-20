import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:wenshy_core/wenshy_core.dart';

import '../../../core/app_dependencies.dart';
import '../../../core/app_strings.dart';
import '../../../core/language_toggle_button.dart';
import '../view_models/trip_details_view_model.dart';

/// Complete summary view for a finished or past rescue request.
class TripDetailsView extends StatefulWidget {
  const TripDetailsView({
    super.key,
    required this.requestId,
  });

  final String requestId;

  @override
  State<TripDetailsView> createState() => _TripDetailsViewState();
}

class _TripDetailsViewState extends State<TripDetailsView> {
  TripDetailsViewModel? _vm;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final deps = AppDependenciesScope.of(context);
    final vm = TripDetailsViewModel(
      requestId: widget.requestId,
      rescueRepository: deps.rescueRepository,
      feedbackRepository: deps.feedbackRepository,
      winchCatalog: deps.winchCatalog,
    );
    _vm = vm;
    vm.load(locale: deps.localeController.languageCode);
  }

  @override
  void dispose() {
    _vm?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = _vm!;
    final deps = AppDependenciesScope.of(context);
    final strings = AppStrings.of(context);
    final localeCode = deps.localeController.languageCode;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.tripDetailsTitle),
        actions: const <Widget>[
          LanguageToggleButton(),
        ],
      ),
      body: ListenableBuilder(
        listenable: vm,
        builder: (context, _) {
          if (vm.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final req = vm.request;
          if (req == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsetsDirectional.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(vm.errorMessage ?? strings.unexpectedError),
                    const SizedBox(height: 12),
                    WenshyPrimaryButton(
                      label: strings.retry,
                      onPressed: () => vm.load(locale: localeCode),
                    ),
                  ],
                ),
              ),
            );
          }

          final vehicleParts = <String>[
            if (req.vehicleMake != null && req.vehicleMake!.isNotEmpty)
              req.vehicleMake!,
            if (req.vehicleModel != null && req.vehicleModel!.isNotEmpty)
              req.vehicleModel!,
            if (req.vehicleYear != null) req.vehicleYear.toString(),
            if (req.vehiclePlate != null && req.vehiclePlate!.isNotEmpty)
              req.vehiclePlate!,
          ];

          return RefreshIndicator(
            onRefresh: () => vm.load(locale: localeCode),
            child: ListView(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 32),
              children: <Widget>[
                // Header card
                Card(
                  child: Padding(
                    padding: const EdgeInsetsDirectional.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            Text(
                              req.requestCode,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            WenshyStatusBadge.trip(
                              req.status,
                              locale: localeCode,
                              short: false,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          DateFormat.yMMMd(localeCode)
                              .add_jm()
                              .format(req.createdAt.toLocal()),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: WenshyColors.slateMuted,
                          ),
                        ),
                        if (req.cancellationReason != null &&
                            req.cancellationReason!.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 8),
                          Text(
                            req.cancellationReason!,
                            style: const TextStyle(color: WenshyColors.red),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Route & Vehicle
                Card(
                  child: Padding(
                    padding: const EdgeInsetsDirectional.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          strings.routeSummary,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _DetailRow(
                          icon: Icons.my_location_rounded,
                          iconColor: WenshyColors.amberDark,
                          label: strings.pickupPointLabel,
                          value: req.pickupAddress,
                        ),
                        const SizedBox(height: 8),
                        _DetailRow(
                          icon: Icons.flag_rounded,
                          iconColor: WenshyColors.emerald,
                          label: strings.dropoffPointLabel,
                          value: req.dropoffAddress,
                        ),
                        if (vehicleParts.isNotEmpty) ...<Widget>[
                          const Divider(height: 20),
                          _DetailRow(
                            icon: Icons.directions_car_rounded,
                            iconColor: WenshyColors.deepSlate,
                            label: strings.vehicleSelection,
                            value: vehicleParts.join(' • '),
                          ),
                        ],
                        if (req.breakdownReason != null &&
                            req.breakdownReason!.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 8),
                          _DetailRow(
                            icon: Icons.build_circle_outlined,
                            iconColor: WenshyColors.slateMuted,
                            label: strings.breakdownReason,
                            value: req.breakdownReason!,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Price card
                Card(
                  child: Padding(
                    padding: const EdgeInsetsDirectional.all(14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              req.finalPrice != null
                                  ? strings.finalPriceLabel
                                  : strings.estimatedTotal,
                              style: theme.textTheme.titleSmall,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${WenshyLabels.paymentMethod(req.paymentMethod, locale: localeCode)} • ${WenshyLabels.paymentStatus(req.paymentStatus, locale: localeCode)}',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                        Text(
                          WenshyLabels.formatPrice(
                            req.displayPrice,
                            currency: req.currency,
                            locale: localeCode,
                          ),
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: WenshyColors.amberDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Driver & Winch
                if (vm.driver != null || vm.winch != null) ...<Widget>[
                  Card(
                    child: Padding(
                      padding: const EdgeInsetsDirectional.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            strings.driverAndWinchInfo,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (vm.driver != null)
                            Text(
                              '${vm.driver!.profile?.fullName ?? '—'} (★ ${vm.driver!.avgRating.toStringAsFixed(1)})',
                              style: theme.textTheme.titleSmall,
                            ),
                          if (vm.winch != null || vm.winchType != null) ...<Widget>[
                            const SizedBox(height: 4),
                            Text(
                              <String>[
                                if (vm.winchType != null)
                                  vm.winchType!.localizedName(localeCode),
                                if (vm.winch != null) vm.winch!.displayLabel,
                                if (vm.winch != null) vm.winch!.plateNumber,
                              ].join(' • '),
                              style: theme.textTheme.bodyMedium,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Breakdown Photos
                if (vm.photoUrls.isNotEmpty) ...<Widget>[
                  Card(
                    child: Padding(
                      padding: const EdgeInsetsDirectional.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            strings.breakdownPhotosTitle,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            height: 110,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: vm.photoUrls.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(width: 10),
                              itemBuilder: (context, index) {
                                final url = vm.photoUrls.values.elementAt(index);
                                return ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.network(
                                    url,
                                    width: 140,
                                    height: 110,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => Container(
                                      width: 140,
                                      color: Colors.black12,
                                      child: const Icon(
                                        Icons.broken_image_outlined,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Status Audit Logs
                if (vm.statusLogs.isNotEmpty) ...<Widget>[
                  Card(
                    child: Padding(
                      padding: const EdgeInsetsDirectional.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            strings.statusTimelineLog,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 10),
                          for (final log in vm.statusLogs) ...<Widget>[
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                const Icon(
                                  Icons.circle,
                                  size: 8,
                                  color: WenshyColors.amberDark,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        log.fromStatus != null
                                            ? '${WenshyLabels.tripStatus(log.fromStatus!, locale: localeCode)} → ${WenshyLabels.tripStatus(log.toStatus, locale: localeCode)}'
                                            : WenshyLabels.tripStatus(
                                                log.toStatus,
                                                locale: localeCode,
                                              ),
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      Text(
                                        DateFormat.yMMMd(localeCode)
                                            .add_jm()
                                            .format(log.createdAt.toLocal()),
                                        style:
                                            theme.textTheme.bodySmall?.copyWith(
                                          color: WenshyColors.slateMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Existing Rating or Action Buttons
                if (vm.existingRating != null) ...<Widget>[
                  Card(
                    color: WenshyColors.amberSoft,
                    child: Padding(
                      padding: const EdgeInsetsDirectional.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            '${strings.alreadyRatedTitle}: ${'★' * vm.existingRating!.score}',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (vm.existingRating!.comment != null &&
                              vm.existingRating!.comment!.isNotEmpty) ...<Widget>[
                            const SizedBox(height: 4),
                            Text(vm.existingRating!.comment!),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ] else if (req.status == TripStatus.delivered &&
                    req.driverId != null) ...<Widget>[
                  WenshyPrimaryButton(
                    label: strings.rateTripCta,
                    icon: Icons.star_rounded,
                    onPressed: () async {
                      await context.push('/trip/${req.id}/rate');
                      if (mounted) {
                        vm.load(locale: localeCode);
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                ],

                OutlinedButton.icon(
                  onPressed: () {
                    final query = <String, String>{
                      'requestId': req.id,
                      if (req.driverId != null) 'reportedUserId': req.driverId!,
                    };
                    final uri = Uri(
                      path: '/complaints/new',
                      queryParameters: query,
                    );
                    context.push(uri.toString());
                  },
                  icon: const Icon(Icons.report_problem_outlined),
                  label: Text(strings.fileComplaintCta),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: WenshyColors.slateMuted,
                ),
              ),
              Text(value, style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }
}
