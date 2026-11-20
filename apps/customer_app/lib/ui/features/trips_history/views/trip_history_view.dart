import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:wenshy_core/wenshy_core.dart';

import '../../../core/app_dependencies.dart';
import '../../../core/app_strings.dart';
import '../../../core/language_toggle_button.dart';
import '../view_models/trips_history_view_model.dart';

/// Filterable list of customer rescue requests, routing active trips to the
/// live tracker and finished trips to full trip details.
class TripHistoryView extends StatefulWidget {
  const TripHistoryView({super.key});

  @override
  State<TripHistoryView> createState() => _TripHistoryViewState();
}

class _TripHistoryViewState extends State<TripHistoryView> {
  TripsHistoryViewModel? _vm;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final deps = AppDependenciesScope.of(context);
    final vm = TripsHistoryViewModel(repository: deps.rescueRepository);
    _vm = vm;
    _reload();
  }

  Future<void> _reload() async {
    final deps = AppDependenciesScope.of(context);
    final customerId = deps.authViewModel.currentUserId;
    if (customerId == null) return;
    await _vm?.loadTrips(
      customerId,
      locale: deps.localeController.languageCode,
    );
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
        title: Text(strings.tripsHistoryTitle),
        actions: const <Widget>[
          LanguageToggleButton(),
        ],
      ),
      body: ListenableBuilder(
        listenable: vm,
        builder: (context, _) {
          return Column(
            children: <Widget>[
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Row(
                  children: <Widget>[
                    _FilterChipItem(
                      label: strings.filterAll,
                      selected: vm.filter == TripHistoryFilter.all,
                      onSelected: () => vm.setFilter(TripHistoryFilter.all),
                    ),
                    const SizedBox(width: 8),
                    _FilterChipItem(
                      label: strings.filterActive,
                      selected: vm.filter == TripHistoryFilter.active,
                      onSelected: () => vm.setFilter(TripHistoryFilter.active),
                    ),
                    const SizedBox(width: 8),
                    _FilterChipItem(
                      label: strings.filterCompleted,
                      selected: vm.filter == TripHistoryFilter.completed,
                      onSelected: () =>
                          vm.setFilter(TripHistoryFilter.completed),
                    ),
                    const SizedBox(width: 8),
                    _FilterChipItem(
                      label: strings.filterCancelled,
                      selected: vm.filter == TripHistoryFilter.cancelled,
                      onSelected: () =>
                          vm.setFilter(TripHistoryFilter.cancelled),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: vm.isLoading && vm.allTrips.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : RefreshIndicator(
                        onRefresh: _reload,
                        child: vm.filteredTrips.isEmpty
                            ? ListView(
                                padding: const EdgeInsetsDirectional.all(24),
                                children: <Widget>[
                                  if (vm.errorMessage != null) ...<Widget>[
                                    Text(
                                      vm.errorMessage!,
                                      style: const TextStyle(
                                        color: WenshyColors.red,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                  ],
                                  Card(
                                    child: Padding(
                                      padding:
                                          const EdgeInsetsDirectional.all(24),
                                      child: Column(
                                        children: <Widget>[
                                          const Icon(
                                            Icons.history_rounded,
                                            size: 52,
                                            color: WenshyColors.slateMuted,
                                          ),
                                          const SizedBox(height: 10),
                                          Text(
                                            strings.noTripsEmpty,
                                            textAlign: TextAlign.center,
                                            style: theme.textTheme.bodyLarge,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : ListView.separated(
                                padding: const EdgeInsetsDirectional.fromSTEB(
                                  16,
                                  4,
                                  16,
                                  24,
                                ),
                                itemCount: vm.filteredTrips.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  final trip = vm.filteredTrips[index];
                                  return _TripHistoryCard(
                                    trip: trip,
                                    localeCode: localeCode,
                                    onTap: () {
                                      if (!trip.status.isTerminal) {
                                        context.push(
                                          '/trip/${trip.id}',
                                          extra: trip,
                                        );
                                      } else {
                                        context.push('/trip/${trip.id}/details');
                                      }
                                    },
                                  );
                                },
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

class _FilterChipItem extends StatelessWidget {
  const _FilterChipItem({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
    );
  }
}

class _TripHistoryCard extends StatelessWidget {
  const _TripHistoryCard({
    required this.trip,
    required this.localeCode,
    required this.onTap,
  });

  final RescueRequest trip;
  final String localeCode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vehicleSummary = <String>[
      if (trip.vehicleMake != null && trip.vehicleMake!.isNotEmpty)
        trip.vehicleMake!,
      if (trip.vehicleModel != null && trip.vehicleModel!.isNotEmpty)
        trip.vehicleModel!,
      if (trip.vehiclePlate != null && trip.vehiclePlate!.isNotEmpty)
        '(${trip.vehiclePlate!})',
    ].join(' ');

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsetsDirectional.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(
                    trip.requestCode,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  WenshyStatusBadge.trip(
                    trip.status,
                    locale: localeCode,
                    short: true,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  const Icon(
                    Icons.my_location_rounded,
                    size: 16,
                    color: WenshyColors.amberDark,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      trip.pickupAddress,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: <Widget>[
                  const Icon(
                    Icons.flag_rounded,
                    size: 16,
                    color: WenshyColors.emerald,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      trip.dropoffAddress,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Expanded(
                    child: Text(
                      vehicleSummary.isEmpty
                          ? DateFormat.yMMMd(localeCode)
                              .add_jm()
                              .format(trip.createdAt.toLocal())
                          : '$vehicleSummary • ${DateFormat.yMMMd(localeCode).add_jm().format(trip.createdAt.toLocal())}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: WenshyColors.slateMuted,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    WenshyLabels.formatPrice(
                      trip.displayPrice,
                      currency: trip.currency,
                      locale: localeCode,
                    ),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: WenshyColors.amberDark,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
