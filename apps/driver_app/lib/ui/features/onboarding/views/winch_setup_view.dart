import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:wenshy_core/wenshy_core.dart';

import '../../../core/driver_strings.dart';
import '../../../core/locale_controller.dart';
import '../../../core/widgets/driver_widgets.dart';
import '../view_models/onboarding_view_model.dart';

/// Screen for registering tow-trucks (`driver_winches`) and uploading winch
/// photos (`winch-photos` bucket).
class WinchSetupView extends StatefulWidget {
  const WinchSetupView({
    super.key,
    required this.viewModel,
    required this.localeController,
  });

  final OnboardingViewModel viewModel;
  final LocaleController localeController;

  @override
  State<WinchSetupView> createState() => _WinchSetupViewState();
}

class _WinchSetupViewState extends State<WinchSetupView> {
  final _formKey = GlobalKey<FormState>();
  final _plateController = TextEditingController();
  final _brandController = TextEditingController();
  final _modelController = TextEditingController();
  final _yearController = TextEditingController();
  final _colorController = TextEditingController();
  final _capacityController = TextEditingController();
  final _licenseController = TextEditingController();

  String? _selectedWinchTypeId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await widget.viewModel.loadOnboardingData();
      if (_selectedWinchTypeId == null &&
          widget.viewModel.winchTypes.isNotEmpty) {
        setState(() {
          _selectedWinchTypeId = widget.viewModel.winchTypes.first.id;
        });
      }
    });
  }

  @override
  void dispose() {
    _plateController.dispose();
    _brandController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    _colorController.dispose();
    _capacityController.dispose();
    _licenseController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final winchTypeId = _selectedWinchTypeId;
    if (winchTypeId == null) return;

    final ok = await widget.viewModel.registerWinch(
      winchTypeId: winchTypeId,
      plateNumber: _plateController.text,
      brand: _brandController.text,
      model: _modelController.text,
      year: int.tryParse(_yearController.text.trim()),
      color: _colorController.text,
      maxCapacityTons: double.tryParse(_capacityController.text.trim()),
      winchLicenseNumber: _licenseController.text,
    );

    if (ok && mounted) {
      _plateController.clear();
      _brandController.clear();
      _modelController.clear();
      _yearController.clear();
      _colorController.clear();
      _capacityController.clear();
      _licenseController.clear();
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
        final effectiveTypeId = _selectedWinchTypeId ??
            (vm.winchTypes.isNotEmpty ? vm.winchTypes.first.id : null);

        return Scaffold(
          appBar: AppBar(
            title: Text(DriverStrings.winchSetupTitle(locale)),
            actions: <Widget>[
              LocaleToggleButton(localeController: widget.localeController),
            ],
          ),
          body: vm.isLoading && vm.winchTypes.isEmpty
              ? const WenshyLoadingView()
              : SingleChildScrollView(
                  padding: const EdgeInsetsDirectional.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      if (vm.winches.isNotEmpty) ...<Widget>[
                        Text(
                          DriverStrings.t(
                            locale,
                            'الأوناش المسجلة',
                            'Registered Tow Trucks',
                          ),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 10),
                        for (final winch in vm.winches) ...<Widget>[
                          _RegisteredWinchCard(
                            winch: winch,
                            locale: locale,
                            photoUrlResolver: vm.winchPhotoUrl,
                          ),
                          const SizedBox(height: 10),
                        ],
                        const Divider(height: 28),
                      ],
                      Text(
                        DriverStrings.t(
                          locale,
                          'إضافة ونش جديد',
                          'Add New Tow Truck',
                        ),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (vm.errorMessage != null) ...<Widget>[
                        _StatusMessage(
                          message: vm.errorMessage!,
                          color: WenshyColors.red,
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (vm.successMessage != null) ...<Widget>[
                        _StatusMessage(
                          message: vm.successMessage!,
                          color: WenshyColors.emerald,
                        ),
                        const SizedBox(height: 12),
                      ],
                      Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            DropdownButtonFormField<String>(
                              initialValue: effectiveTypeId,
                              decoration: InputDecoration(
                                labelText: DriverStrings.t(
                                  locale,
                                  'فئة الونش',
                                  'Tow Truck Category',
                                ),
                                prefixIcon:
                                    const Icon(Icons.local_shipping_outlined),
                              ),
                              items: vm.winchTypes
                                  .map(
                                    (wt) => DropdownMenuItem<String>(
                                      value: wt.id,
                                      child: Text(wt.localizedName(locale)),
                                    ),
                                  )
                                  .toList(growable: false),
                              onChanged: (val) => setState(
                                () => _selectedWinchTypeId = val,
                              ),
                              validator: (v) => v == null
                                  ? DriverStrings.t(
                                      locale,
                                      'اختر فئة الونش',
                                      'Select a tow truck category',
                                    )
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _plateController,
                              decoration: InputDecoration(
                                labelText: DriverStrings.t(
                                  locale,
                                  'رقم اللوحة المعدنية',
                                  'Plate Number',
                                ),
                                prefixIcon:
                                    const Icon(Icons.confirmation_number_outlined),
                              ),
                              validator: (v) => (v?.trim().isEmpty ?? true)
                                  ? DriverStrings.t(
                                      locale,
                                      'رقم اللوحة مطلوب',
                                      'Plate number is required',
                                    )
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: TextFormField(
                                    controller: _brandController,
                                    decoration: InputDecoration(
                                      labelText: DriverStrings.t(
                                        locale,
                                        'الماركة (مثال: إيسوزو)',
                                        'Brand (e.g. Isuzu)',
                                      ),
                                    ),
                                    validator: (v) => (v?.trim().isEmpty ?? true)
                                        ? DriverStrings.t(
                                            locale,
                                            'مطلوب',
                                            'Required',
                                          )
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: _modelController,
                                    decoration: InputDecoration(
                                      labelText: DriverStrings.t(
                                        locale,
                                        'الموديل',
                                        'Model',
                                      ),
                                    ),
                                    validator: (v) => (v?.trim().isEmpty ?? true)
                                        ? DriverStrings.t(
                                            locale,
                                            'مطلوب',
                                            'Required',
                                          )
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: TextFormField(
                                    controller: _yearController,
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      labelText: DriverStrings.t(
                                        locale,
                                        'سنة الصنع',
                                        'Year',
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: _capacityController,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                    decoration: InputDecoration(
                                      labelText: DriverStrings.t(
                                        locale,
                                        'الحمولة (طن)',
                                        'Capacity (Tons)',
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _colorController,
                              decoration: InputDecoration(
                                labelText: DriverStrings.t(
                                  locale,
                                  'اللون (اختياري)',
                                  'Color (optional)',
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _licenseController,
                              decoration: InputDecoration(
                                labelText: DriverStrings.t(
                                  locale,
                                  'رقم رخصة تسيير الونش',
                                  'Winch License Number',
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              DriverStrings.t(
                                locale,
                                'صور الونش (${vm.stagedWinchPhotos.length})',
                                'Tow Truck Photos (${vm.stagedWinchPhotos.length})',
                              ),
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => vm.pickWinchPhoto(
                                      source: ImageSource.camera,
                                    ),
                                    icon: const Icon(Icons.camera_alt_outlined),
                                    label: Text(
                                      DriverStrings.pickFromCamera(locale),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => vm.pickWinchPhoto(
                                      source: ImageSource.gallery,
                                    ),
                                    icon:
                                        const Icon(Icons.photo_library_outlined),
                                    label: Text(
                                      DriverStrings.pickFromGallery(locale),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (vm.stagedWinchPhotos.isNotEmpty) ...<Widget>[
                              const SizedBox(height: 10),
                              SizedBox(
                                height: 84,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: vm.stagedWinchPhotos.length,
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(width: 8),
                                  itemBuilder: (context, idx) {
                                    final item = vm.stagedWinchPhotos[idx];
                                    return Stack(
                                      children: <Widget>[
                                        ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          child: Image.memory(
                                            item.bytes,
                                            width: 84,
                                            height: 84,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                        PositionedDirectional(
                                          top: 2,
                                          end: 2,
                                          child: CircleAvatar(
                                            radius: 12,
                                            backgroundColor: Colors.black54,
                                            child: IconButton(
                                              padding: EdgeInsets.zero,
                                              icon: const Icon(
                                                Icons.close,
                                                size: 14,
                                                color: Colors.white,
                                              ),
                                              onPressed: () =>
                                                  vm.removeStagedWinchPhoto(
                                                idx,
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
                            const SizedBox(height: 22),
                            WenshyPrimaryButton(
                              label: DriverStrings.t(
                                locale,
                                'حفظ بيانات الونش',
                                'Save Tow Truck',
                              ),
                              icon: Icons.save_outlined,
                              isLoading: vm.isSubmitting,
                              onPressed: _submit,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }
}

class _RegisteredWinchCard extends StatelessWidget {
  const _RegisteredWinchCard({
    required this.winch,
    required this.locale,
    required this.photoUrlResolver,
  });

  final DriverWinch winch;
  final String locale;
  final String Function(String path) photoUrlResolver;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    winch.displayLabel,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                WenshyStatusBadge(
                  label: winch.isVerified
                      ? DriverStrings.t(locale, 'موثق', 'Verified')
                      : DriverStrings.t(locale, 'قيد التوثيق', 'Pending Verify'),
                  color: winch.isVerified
                      ? WenshyColors.emerald
                      : WenshyColors.amberDark,
                  compact: true,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${winch.plateNumber}'
              '${winch.winchType != null ? ' • ${winch.winchType!.localizedName(locale)}' : ''}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (winch.photoPaths.isNotEmpty) ...<Widget>[
              const SizedBox(height: 10),
              SizedBox(
                height: 64,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: winch.photoPaths.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, idx) {
                    final url = photoUrlResolver(winch.photoPaths[idx]);
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        url,
                        width: 64,
                        height: 64,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          width: 64,
                          height: 64,
                          color: theme.colorScheme.surfaceContainer,
                          child: const Icon(Icons.local_shipping_outlined),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusMessage extends StatelessWidget {
  const _StatusMessage({
    required this.message,
    required this.color,
  });

  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        message,
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
