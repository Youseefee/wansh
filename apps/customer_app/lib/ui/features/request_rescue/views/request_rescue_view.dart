import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:wenshy_core/wenshy_core.dart';

import '../../../../data/repositories/models.dart';
import '../../../core/app_dependencies.dart';
import '../../../core/app_strings.dart';
import '../view_models/request_rescue_view_model.dart';

/// Rescue Request & Live Server Quotation screen.
class RequestRescueView extends StatefulWidget {
  const RequestRescueView({
    super.key,
    required this.routeSelection,
  });

  final RouteSelection routeSelection;

  @override
  State<RequestRescueView> createState() => _RequestRescueViewState();
}

class _RequestRescueViewState extends State<RequestRescueView> {
  final _formKey = GlobalKey<FormState>();
  final _makeController = TextEditingController();
  final _modelController = TextEditingController();
  final _yearController = TextEditingController();
  final _colorController = TextEditingController();
  final _plateController = TextEditingController();
  final _reasonController = TextEditingController();
  final _notesController = TextEditingController();

  RequestRescueViewModel? _vm;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final deps = AppDependenciesScope.of(context);
    final vm = RequestRescueViewModel(
      route: widget.routeSelection,
      mapRepository: deps.mapRepository,
      vehicleRepository: deps.vehicleRepository,
      rescueRepository: deps.rescueRepository,
    );
    _vm = vm;
    final customerId = deps.authViewModel.currentUserId;
    if (customerId != null) {
      vm.initialize(
        customerId: customerId,
        locale: deps.localeController.languageCode,
      );
    }
  }

  @override
  void dispose() {
    _makeController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    _colorController.dispose();
    _plateController.dispose();
    _reasonController.dispose();
    _notesController.dispose();
    _vm?.dispose();
    super.dispose();
  }

  Future<void> _pickCamera() async {
    final deps = AppDependenciesScope.of(context);
    final photo = await deps.photoPicker.pickFromCamera();
    if (photo != null) {
      _vm?.addPhotos(<SelectedPhotoBytes>[photo]);
    }
  }

  Future<void> _pickGallery() async {
    final deps = AppDependenciesScope.of(context);
    final photos = await deps.photoPicker.pickMultipleFromGallery();
    if (photos.isNotEmpty) {
      _vm?.addPhotos(photos);
    }
  }

  Future<void> _submit() async {
    final vm = _vm;
    if (vm == null) return;
    if (vm.useManualVehicle && !(_formKey.currentState?.validate() ?? true)) {
      return;
    }
    final deps = AppDependenciesScope.of(context);
    final customerId = deps.authViewModel.currentUserId;
    if (customerId == null) return;

    vm.updateManualVehicle(
      make: _makeController.text,
      model: _modelController.text,
      year: int.tryParse(_yearController.text.trim()),
      color: _colorController.text,
      plate: _plateController.text,
    );
    vm.setBreakdownReason(_reasonController.text);
    vm.setBreakdownNotes(_notesController.text);

    final result = await vm.submitRequest(
      customerId: customerId,
      locale: deps.localeController.languageCode,
    );
    if (result != null && mounted) {
      context.go('/trip/${result.request.id}', extra: result);
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
      appBar: AppBar(title: Text(strings.requestRescueTitle)),
      body: ListenableBuilder(
        listenable: vm,
        builder: (context, _) {
          if (vm.isInitializing) {
            return WenshyLoadingView(message: strings.loading);
          }

          return SingleChildScrollView(
            padding: const EdgeInsetsDirectional.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  // 1. Route Summary
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
                          _RouteRow(
                            icon: Icons.car_crash_rounded,
                            color: WenshyColors.amberDark,
                            title: strings.pickupPointLabel,
                            address: vm.route.pickupAddress,
                          ),
                          const Divider(height: 18),
                          _RouteRow(
                            icon: Icons.flag_rounded,
                            color: WenshyColors.emerald,
                            title: strings.dropoffPointLabel,
                            address: vm.route.dropoffAddress,
                          ),
                          if (vm.route.routeDistanceKm != null) ...<Widget>[
                            const Divider(height: 18),
                            Row(
                              children: <Widget>[
                                const Icon(
                                  Icons.alt_route_rounded,
                                  size: 18,
                                  color: WenshyColors.info,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  [
                                    WenshyLabels.formatDistanceKm(
                                      vm.route.routeDistanceKm!,
                                      locale: localeCode,
                                    ),
                                    if (vm.route.routeDurationMinutes != null)
                                      WenshyLabels.formatEtaMinutes(
                                        vm.route.routeDurationMinutes!,
                                        locale: localeCode,
                                      ),
                                  ].join(' • '),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: WenshyColors.info,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 2. Winch Type Selector
                  Text(
                    strings.selectWinchType,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final type in vm.winchTypes)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(bottom: 8),
                      child: Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(
                            color: vm.selectedWinchType?.id == type.id
                                ? WenshyColors.amber
                                : theme.colorScheme.outline,
                            width:
                                vm.selectedWinchType?.id == type.id ? 2 : 1,
                          ),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => vm.selectWinchType(
                            type,
                            locale: localeCode,
                          ),
                          child: Padding(
                            padding: const EdgeInsetsDirectional.all(12),
                            child: Row(
                              children: <Widget>[
                                Icon(
                                  vm.selectedWinchType?.id == type.id
                                      ? Icons.radio_button_checked
                                      : Icons.radio_button_off,
                                  color: vm.selectedWinchType?.id == type.id
                                      ? WenshyColors.amberDark
                                      : theme.colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        type.localizedName(localeCode),
                                        style: theme.textTheme.titleSmall
                                            ?.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      if (type.localizedDescription(
                                              localeCode) !=
                                          null)
                                        Text(
                                          type.localizedDescription(localeCode)!,
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                            color: theme
                                                .colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: <Widget>[
                                    Text(
                                      WenshyLabels.formatPrice(
                                        type.baseFare,
                                        locale: localeCode,
                                      ),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: WenshyColors.amberDark,
                                      ),
                                    ),
                                    Text(
                                      '+ ${WenshyLabels.formatPrice(type.pricePerKm, locale: localeCode)}/km',
                                      style: theme.textTheme.labelSmall,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),

                  // 3. Vehicle Selection (Saved or Manual)
                  Card(
                    child: Padding(
                      padding: const EdgeInsetsDirectional.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Text(
                            strings.vehicleSelection,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 10),
                          if (vm.savedVehicles.isNotEmpty) ...<Widget>[
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: <Widget>[
                                for (final vehicle in vm.savedVehicles)
                                  ChoiceChip(
                                    selected: !vm.useManualVehicle &&
                                        vm.selectedVehicle?.id == vehicle.id,
                                    label: Text(
                                      '${vehicle.displayLabel} • ${vehicle.plateNumber}',
                                    ),
                                    onSelected: (_) =>
                                        vm.selectSavedVehicle(vehicle),
                                  ),
                                ChoiceChip(
                                  selected: vm.useManualVehicle,
                                  label: Text(strings.enterVehicleManually),
                                  onSelected: (_) => vm.enableManualVehicle(),
                                ),
                              ],
                            ),
                          ],
                          if (vm.useManualVehicle) ...<Widget>[
                            const SizedBox(height: 12),
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: TextFormField(
                                    controller: _makeController,
                                    decoration: InputDecoration(
                                      labelText: strings.vehicleMake,
                                    ),
                                    validator: (v) =>
                                        vm.useManualVehicle &&
                                                (v == null || v.trim().isEmpty)
                                            ? strings.requiredField
                                            : null,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextFormField(
                                    controller: _modelController,
                                    decoration: InputDecoration(
                                      labelText: strings.vehicleModel,
                                    ),
                                    validator: (v) =>
                                        vm.useManualVehicle &&
                                                (v == null || v.trim().isEmpty)
                                            ? strings.requiredField
                                            : null,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: TextFormField(
                                    controller: _plateController,
                                    decoration: InputDecoration(
                                      labelText: strings.vehiclePlate,
                                    ),
                                    validator: (v) =>
                                        vm.useManualVehicle &&
                                                (v == null || v.trim().isEmpty)
                                            ? strings.requiredField
                                            : null,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextFormField(
                                    controller: _yearController,
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      labelText: strings.vehicleYear,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: TextFormField(
                                    controller: _colorController,
                                    decoration: InputDecoration(
                                      labelText: strings.vehicleColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: DropdownButtonFormField<VehicleCategory>(
                                    initialValue: vm.manualCategory,
                                    isExpanded: true,
                                    decoration: InputDecoration(
                                      labelText: strings.vehicleCategory,
                                    ),
                                    items: VehicleCategory.values
                                        .map(
                                          (cat) => DropdownMenuItem(
                                            value: cat,
                                            child: Text(
                                              WenshyLabels.vehicleCategory(
                                                cat,
                                                locale: localeCode,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (cat) {
                                      if (cat != null) {
                                        vm.updateManualVehicle(category: cat);
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 4. Breakdown Info & Photos
                  Card(
                    child: Padding(
                      padding: const EdgeInsetsDirectional.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Text(
                            strings.breakdownDetails,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _reasonController,
                            decoration: InputDecoration(
                              labelText: strings.breakdownReason,
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _notesController,
                            maxLines: 2,
                            decoration: InputDecoration(
                              labelText: strings.breakdownNotes,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            strings.addPhotos,
                            style: theme.textTheme.labelLarge,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: <Widget>[
                              OutlinedButton.icon(
                                onPressed: _pickCamera,
                                icon: const Icon(Icons.camera_alt_outlined),
                                label: Text(strings.camera),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                onPressed: _pickGallery,
                                icon: const Icon(Icons.photo_library_outlined),
                                label: Text(strings.gallery),
                              ),
                            ],
                          ),
                          if (vm.photos.isNotEmpty) ...<Widget>[
                            const SizedBox(height: 10),
                            SizedBox(
                              height: 78,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: vm.photos.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(width: 8),
                                itemBuilder: (context, index) {
                                  final p = vm.photos[index];
                                  return Stack(
                                    children: <Widget>[
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: Image.memory(
                                          p.bytes,
                                          width: 78,
                                          height: 78,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                      PositionedDirectional(
                                        top: 2,
                                        end: 2,
                                        child: InkWell(
                                          onTap: () => vm.removePhotoAt(index),
                                          child: const CircleAvatar(
                                            radius: 11,
                                            backgroundColor: Colors.black87,
                                            child: Icon(
                                              Icons.close,
                                              size: 13,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 5. Payment Method
                  Card(
                    child: Padding(
                      padding: const EdgeInsetsDirectional.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            strings.paymentMethodLabel,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: PaymentMethod.values
                                .map(
                                  (method) => ChoiceChip(
                                    selected: vm.paymentMethod == method,
                                    label: Text(
                                      WenshyLabels.paymentMethod(
                                        method,
                                        locale: localeCode,
                                      ),
                                    ),
                                    onSelected: (_) =>
                                        vm.setPaymentMethod(method),
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 6. Live Server Quotation Card
                  Card(
                    color: WenshyColors.deepSlate,
                    child: Padding(
                      padding: const EdgeInsetsDirectional.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: <Widget>[
                              Text(
                                strings.liveQuoteTitle,
                                style: const TextStyle(
                                  color: WenshyColors.amber,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                              if (vm.isCalculatingQuote)
                                const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: WenshyColors.amber,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (vm.quote != null) ...<Widget>[
                            _QuoteLine(
                              label: strings.estimatedDistance,
                              value: WenshyLabels.formatDistanceKm(
                                vm.quote!.estimatedDistanceKm,
                                locale: localeCode,
                              ),
                            ),
                            _QuoteLine(
                              label: strings.estimatedDuration,
                              value: WenshyLabels.formatEtaMinutes(
                                vm.quote!.estimatedDurationMin,
                                locale: localeCode,
                              ),
                            ),
                            _QuoteLine(
                              label: strings.baseFare,
                              value: WenshyLabels.formatPrice(
                                vm.quote!.baseFare,
                                currency: vm.quote!.currency,
                                locale: localeCode,
                              ),
                            ),
                            _QuoteLine(
                              label: strings.perKm,
                              value: WenshyLabels.formatPrice(
                                vm.quote!.pricePerKm,
                                currency: vm.quote!.currency,
                                locale: localeCode,
                              ),
                            ),
                            _QuoteLine(
                              label: strings.priceRange,
                              value:
                                  '${WenshyLabels.formatPrice(vm.quote!.minPriceRange, currency: vm.quote!.currency, locale: localeCode)} - ${WenshyLabels.formatPrice(vm.quote!.maxPriceRange, currency: vm.quote!.currency, locale: localeCode)}',
                            ),
                            const Divider(color: Colors.white24, height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: <Widget>[
                                Text(
                                  strings.estimatedTotal,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  WenshyLabels.formatPrice(
                                    vm.quote!.estimatedPrice,
                                    currency: vm.quote!.currency,
                                    locale: localeCode,
                                  ),
                                  style: const TextStyle(
                                    color: WenshyColors.amber,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ] else
                            Text(
                              strings.calculatingQuote,
                              style: const TextStyle(color: Colors.white70),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

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

                  WenshyPrimaryButton(
                    label: strings.confirmRequestBtn,
                    icon: Icons.send_rounded,
                    isLoading: vm.isSubmitting,
                    onPressed: vm.isCalculatingQuote ? null : _submit,
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RouteRow extends StatelessWidget {
  const _RouteRow({
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
      children: <Widget>[
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
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

class _QuoteLine extends StatelessWidget {
  const _QuoteLine({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 13.5,
            ),
          ),
        ],
      ),
    );
  }
}
