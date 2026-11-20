import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:wenshy_core/wenshy_core.dart';

import '../../../core/driver_strings.dart';
import '../../../core/locale_controller.dart';
import '../../../core/widgets/driver_widgets.dart';
import '../view_models/trips_history_view_model.dart';

/// Trips History & Earnings dashboard showing `total_trips`, `total_earnings`,
/// `avg_rating`, past rescue trips, and customer ratings.
class TripsHistoryView extends StatefulWidget {
  const TripsHistoryView({
    super.key,
    required this.viewModel,
    required this.localeController,
  });

  final TripsHistoryViewModel viewModel;
  final LocaleController localeController;

  @override
  State<TripsHistoryView> createState() => _TripsHistoryViewState();
}

class _TripsHistoryViewState extends State<TripsHistoryView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.viewModel.loadHistory();
    });
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

        return Scaffold(
          appBar: AppBar(
            title: Text(DriverStrings.navHistory(locale)),
            actions: <Widget>[
              LocaleToggleButton(localeController: widget.localeController),
            ],
          ),
          body: vm.isLoading && vm.trips.isEmpty
              ? const WenshyLoadingView()
              : vm.errorMessage != null && vm.trips.isEmpty
                  ? WenshyErrorView(
                      message: vm.errorMessage!,
                      onRetry: () => vm.loadHistory(refreshSession: true),
                    )
                  : RefreshIndicator(
                      onRefresh: () => vm.loadHistory(refreshSession: true),
                      child: ListView(
                        padding: const EdgeInsetsDirectional.all(16),
                        children: <Widget>[
                          _EarningsSummaryRow(
                            totalTrips: vm.totalTrips,
                            totalEarnings: vm.totalEarnings,
                            avgRating: vm.avgRating,
                            locale: locale,
                          ),
                          const SizedBox(height: 20),
                          Text(
                            DriverStrings.t(
                              locale,
                              'سجل رحلات الإنقاذ',
                              'Rescue Trips History',
                            ),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 10),
                          if (vm.trips.isEmpty)
                            Card(
                              child: Padding(
                                padding: const EdgeInsetsDirectional.all(24),
                                child: Center(
                                  child: Text(DriverStrings.noTripsYet(locale)),
                                ),
                              ),
                            )
                          else
                            for (final trip in vm.trips) ...<Widget>[
                              Card(
                                child: ListTile(
                                  contentPadding:
                                      const EdgeInsetsDirectional.all(14),
                                  onTap: () => context.push('/trip/${trip.id}'),
                                  title: Row(
                                    children: <Widget>[
                                      Expanded(
                                        child: Text(
                                          trip.requestCode,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                      WenshyStatusBadge.trip(
                                        trip.status,
                                        locale: locale,
                                        compact: true,
                                      ),
                                    ],
                                  ),
                                  subtitle: Padding(
                                    padding:
                                        const EdgeInsetsDirectional.only(top: 8),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Text(
                                          '${trip.pickupAddress} → ${trip.dropoffAddress}',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: <Widget>[
                                            Text(
                                              WenshyLabels.formatDateTime(
                                                trip.createdAt,
                                              ),
                                              style: theme.textTheme.bodySmall,
                                            ),
                                            Text(
                                              WenshyLabels.formatPrice(
                                                trip.displayPrice,
                                                currency: trip.currency,
                                                locale: locale,
                                              ),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                                color: WenshyColors.emerald,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                            ],
                          if (vm.ratings.isNotEmpty) ...<Widget>[
                            const SizedBox(height: 12),
                            Text(
                              DriverStrings.t(
                                locale,
                                'تقييمات العملاء',
                                'Customer Ratings',
                              ),
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 10),
                            for (final rating in vm.ratings) ...<Widget>[
                              Card(
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: WenshyColors.amberSoft,
                                    child: Text(
                                      '${rating.score}★',
                                      style: const TextStyle(
                                        color: WenshyColors.amberDark,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    rating.comment?.trim().isNotEmpty == true
                                        ? rating.comment!
                                        : DriverStrings.t(
                                            locale,
                                            'تقييم ${rating.score} من 5',
                                            'Rated ${rating.score} out of 5',
                                          ),
                                  ),
                                  subtitle: Text(
                                    WenshyLabels.formatDateTime(
                                      rating.createdAt,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                          ],
                        ],
                      ),
                    ),
        );
      },
    );
  }
}

class _EarningsSummaryRow extends StatelessWidget {
  const _EarningsSummaryRow({
    required this.totalTrips,
    required this.totalEarnings,
    required this.avgRating,
    required this.locale,
  });

  final int totalTrips;
  final double totalEarnings;
  final double avgRating;
  final String locale;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: _MetricTile(
            label: DriverStrings.totalTripsLabel(locale),
            value: '$totalTrips',
            icon: Icons.local_shipping_outlined,
            color: WenshyColors.info,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MetricTile(
            label: DriverStrings.totalEarningsLabel(locale),
            value: WenshyLabels.formatPrice(totalEarnings, locale: locale),
            icon: Icons.account_balance_wallet_outlined,
            color: WenshyColors.emerald,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MetricTile(
            label: DriverStrings.avgRatingLabel(locale),
            value: avgRating.toStringAsFixed(2),
            icon: Icons.star_rate_rounded,
            color: WenshyColors.amberDark,
          ),
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 8),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
