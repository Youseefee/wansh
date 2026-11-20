import 'package:flutter/material.dart';
import 'package:wenshy_core/wenshy_core.dart';

import '../../../core/app_dependencies.dart';
import '../../../core/app_strings.dart';
import '../../../core/language_toggle_button.dart';
import '../view_models/vehicles_view_model.dart';

/// Saved customer vehicles CRUD screen (`public.customer_vehicles`).
class VehiclesView extends StatefulWidget {
  const VehiclesView({super.key});

  @override
  State<VehiclesView> createState() => _VehiclesViewState();
}

class _VehiclesViewState extends State<VehiclesView> {
  VehiclesViewModel? _vm;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final deps = AppDependenciesScope.of(context);
    final vm = VehiclesViewModel(repository: deps.vehicleRepository);
    _vm = vm;
    _reload();
  }

  Future<void> _reload() async {
    final deps = AppDependenciesScope.of(context);
    final customerId = deps.authViewModel.currentUserId;
    if (customerId == null) return;
    await _vm?.loadVehicles(
      customerId,
      locale: deps.localeController.languageCode,
    );
  }

  @override
  void dispose() {
    _vm?.dispose();
    super.dispose();
  }

  Future<void> _openVehicleSheet({CustomerVehicle? existing}) async {
    final vm = _vm;
    if (vm == null) return;
    final deps = AppDependenciesScope.of(context);
    final customerId = deps.authViewModel.currentUserId;
    if (customerId == null) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return _VehicleEditorSheet(
          existing: existing,
          viewModel: vm,
          customerId: customerId,
          localeCode: deps.localeController.languageCode,
        );
      },
    );
  }

  Future<void> _confirmDelete(CustomerVehicle vehicle) async {
    final vm = _vm;
    if (vm == null) return;
    final deps = AppDependenciesScope.of(context);
    final customerId = deps.authViewModel.currentUserId;
    if (customerId == null) return;
    final strings = AppStrings.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(strings.delete),
        content: Text(
          '${strings.confirmDeleteVehicle}\n${vehicle.make} ${vehicle.model} (${vehicle.plateNumber})',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(strings.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: WenshyColors.red),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(strings.delete),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await vm.deleteVehicle(
        customerId: customerId,
        vehicleId: vehicle.id,
        locale: deps.localeController.languageCode,
      );
    }
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
        title: Text(strings.myVehiclesTitle),
        actions: <Widget>[
          const LanguageToggleButton(),
          IconButton(
            tooltip: strings.addVehicleTitle,
            onPressed: () => _openVehicleSheet(),
            icon: const Icon(Icons.add_circle_outline_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openVehicleSheet(),
        icon: const Icon(Icons.directions_car_filled_rounded),
        label: Text(strings.addVehicleTitle),
      ),
      body: ListenableBuilder(
        listenable: vm,
        builder: (context, _) {
          if (vm.isLoading && vm.vehicles.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 96),
              children: <Widget>[
                if (vm.errorMessage != null) ...<Widget>[
                  Container(
                    padding: const EdgeInsetsDirectional.all(12),
                    decoration: BoxDecoration(
                      color: WenshyColors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      vm.errorMessage!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: WenshyColors.red,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (vm.vehicles.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsetsDirectional.all(24),
                      child: Column(
                        children: <Widget>[
                          const Icon(
                            Icons.directions_car_outlined,
                            size: 56,
                            color: WenshyColors.slateMuted,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            strings.noVehiclesEmpty,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyLarge,
                          ),
                          const SizedBox(height: 16),
                          WenshyPrimaryButton(
                            label: strings.addVehicleTitle,
                            icon: Icons.add_rounded,
                            onPressed: () => _openVehicleSheet(),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  for (final vehicle in vm.vehicles) ...<Widget>[
                    Card(
                      child: Padding(
                        padding: const EdgeInsetsDirectional.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                CircleAvatar(
                                  backgroundColor: WenshyColors.amberSoft,
                                  child: const Icon(
                                    Icons.directions_car_rounded,
                                    color: WenshyColors.deepSlate,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Row(
                                        children: <Widget>[
                                          Expanded(
                                            child: Text(
                                              [
                                                vehicle.make,
                                                vehicle.model,
                                                if (vehicle.year != null)
                                                  vehicle.year.toString(),
                                              ].join(' '),
                                              style: theme.textTheme.titleMedium
                                                  ?.copyWith(
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                          if (vehicle.isDefault)
                                            Container(
                                              padding:
                                                  const EdgeInsetsDirectional
                                                      .symmetric(
                                                horizontal: 8,
                                                vertical: 3,
                                              ),
                                              decoration: BoxDecoration(
                                                color: WenshyColors.emerald
                                                    .withValues(alpha: 0.14),
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                              child: Text(
                                                strings.defaultBadge,
                                                style: const TextStyle(
                                                  color: WenshyColors.emerald,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        [
                                          vehicle.plateNumber,
                                          WenshyLabels.vehicleCategory(
                                            vehicle.vehicleCategory,
                                            locale: localeCode,
                                          ),
                                          if (vehicle.color != null &&
                                              vehicle.color!.isNotEmpty)
                                            vehicle.color!,
                                        ].join(' • '),
                                        style: theme.textTheme.bodySmall,
                                      ),
                                      if (vehicle.notes != null &&
                                          vehicle.notes!.isNotEmpty) ...<Widget>[
                                        const SizedBox(height: 4),
                                        Text(
                                          vehicle.notes!,
                                          style:
                                              theme.textTheme.bodySmall?.copyWith(
                                            color: WenshyColors.slateMuted,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            const Divider(height: 1),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: <Widget>[
                                if (!vehicle.isDefault)
                                  TextButton.icon(
                                    onPressed: vm.isSaving
                                        ? null
                                        : () {
                                            final uid = deps
                                                .authViewModel.currentUserId;
                                            if (uid == null) return;
                                            vm.setDefault(
                                              customerId: uid,
                                              vehicleId: vehicle.id,
                                              locale: localeCode,
                                            );
                                          },
                                    icon: const Icon(
                                      Icons.star_outline_rounded,
                                      size: 18,
                                    ),
                                    label: Text(strings.setAsDefault),
                                  ),
                                TextButton.icon(
                                  onPressed: vm.isSaving
                                      ? null
                                      : () => _openVehicleSheet(existing: vehicle),
                                  icon: const Icon(Icons.edit_outlined, size: 18),
                                  label: Text(strings.edit),
                                ),
                                TextButton.icon(
                                  onPressed: vm.isSaving
                                      ? null
                                      : () => _confirmDelete(vehicle),
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                    size: 18,
                                    color: WenshyColors.red,
                                  ),
                                  label: Text(
                                    strings.delete,
                                    style:
                                        const TextStyle(color: WenshyColors.red),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _VehicleEditorSheet extends StatefulWidget {
  const _VehicleEditorSheet({
    required this.existing,
    required this.viewModel,
    required this.customerId,
    required this.localeCode,
  });

  final CustomerVehicle? existing;
  final VehiclesViewModel viewModel;
  final String customerId;
  final String localeCode;

  @override
  State<_VehicleEditorSheet> createState() => _VehicleEditorSheetState();
}

class _VehicleEditorSheetState extends State<_VehicleEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _makeController;
  late final TextEditingController _modelController;
  late final TextEditingController _yearController;
  late final TextEditingController _colorController;
  late final TextEditingController _plateController;
  late final TextEditingController _notesController;
  late VehicleCategory _category;
  late bool _isDefault;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _makeController = TextEditingController(text: e?.make ?? '');
    _modelController = TextEditingController(text: e?.model ?? '');
    _yearController = TextEditingController(text: e?.year?.toString() ?? '');
    _colorController = TextEditingController(text: e?.color ?? '');
    _plateController = TextEditingController(text: e?.plateNumber ?? '');
    _notesController = TextEditingController(text: e?.notes ?? '');
    _category = e?.vehicleCategory ?? VehicleCategory.sedan;
    _isDefault = e?.isDefault ?? false;
  }

  @override
  void dispose() {
    _makeController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    _colorController.dispose();
    _plateController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final ok = await widget.viewModel.saveVehicle(
      editingId: widget.existing?.id,
      customerId: widget.customerId,
      make: _makeController.text,
      model: _modelController.text,
      year: int.tryParse(_yearController.text.trim()),
      color: _colorController.text,
      plateNumber: _plateController.text,
      category: _category,
      notes: _notesController.text,
      isDefault: _isDefault,
      locale: widget.localeCode,
    );

    if (ok && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(16, 4, 16, 16 + bottomInset),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: ListenableBuilder(
            listenable: widget.viewModel,
            builder: (context, _) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    widget.existing == null
                        ? strings.addVehicleTitle
                        : strings.editVehicleTitle,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: TextFormField(
                          controller: _makeController,
                          decoration:
                              InputDecoration(labelText: strings.vehicleMake),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? strings.requiredField
                              : null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _modelController,
                          decoration:
                              InputDecoration(labelText: strings.vehicleModel),
                          validator: (v) => (v == null || v.trim().isEmpty)
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
                          controller: _yearController,
                          keyboardType: TextInputType.number,
                          decoration:
                              InputDecoration(labelText: strings.vehicleYear),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _colorController,
                          decoration:
                              InputDecoration(labelText: strings.vehicleColor),
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
                          decoration:
                              InputDecoration(labelText: strings.vehiclePlate),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? strings.requiredField
                              : null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<VehicleCategory>(
                          initialValue: _category,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: strings.vehicleCategory,
                          ),
                          items: VehicleCategory.values
                              .map(
                                (cat) => DropdownMenuItem<VehicleCategory>(
                                  value: cat,
                                  child: Text(
                                    WenshyLabels.vehicleCategory(
                                      cat,
                                      locale: widget.localeCode,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (cat) {
                            if (cat != null) {
                              setState(() => _category = cat);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _notesController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: strings.breakdownNotes,
                    ),
                  ),
                  const SizedBox(height: 6),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: _isDefault,
                    onChanged: (val) => setState(() => _isDefault = val),
                    title: Text(strings.setAsDefault),
                  ),
                  if (widget.viewModel.errorMessage != null) ...<Widget>[
                    Text(
                      widget.viewModel.errorMessage!,
                      style: const TextStyle(color: WenshyColors.red),
                    ),
                    const SizedBox(height: 8),
                  ],
                  const SizedBox(height: 8),
                  WenshyPrimaryButton(
                    label: strings.save,
                    isLoading: widget.viewModel.isSaving,
                    onPressed: widget.viewModel.isSaving ? null : _save,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
