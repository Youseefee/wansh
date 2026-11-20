import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:wenshy_core/wenshy_core.dart';

import '../../../core/driver_strings.dart';
import '../../../core/locale_controller.dart';
import '../../../core/widgets/driver_widgets.dart';
import '../view_models/complaints_view_model.dart';

/// Driver complaints & evidence submission screen (`complaints` +
/// `complaint-evidence` bucket).
class ComplaintsView extends StatefulWidget {
  const ComplaintsView({
    super.key,
    required this.viewModel,
    required this.localeController,
  });

  final ComplaintsViewModel viewModel;
  final LocaleController localeController;

  @override
  State<ComplaintsView> createState() => _ComplaintsViewState();
}

class _ComplaintsViewState extends State<ComplaintsView> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _descriptionController = TextEditingController();

  ComplaintCategory _category = ComplaintCategory.customerBehavior;
  String? _selectedTripId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.viewModel.loadComplaints();
    });
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    RescueRequest? trip;
    for (final item in widget.viewModel.driverTrips) {
      if (item.id == _selectedTripId) {
        trip = item;
        break;
      }
    }

    final ok = await widget.viewModel.submitComplaint(
      category: _category,
      subject: _subjectController.text,
      description: _descriptionController.text,
      relatedTrip: trip,
    );

    if (ok && mounted) {
      _subjectController.clear();
      _descriptionController.clear();
      setState(() => _selectedTripId = null);
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

        return Scaffold(
          appBar: AppBar(
            title: Text(DriverStrings.navComplaints(locale)),
            actions: <Widget>[
              LocaleToggleButton(localeController: widget.localeController),
            ],
          ),
          body: vm.isLoading && vm.complaints.isEmpty
              ? const WenshyLoadingView()
              : RefreshIndicator(
                  onRefresh: vm.loadComplaints,
                  child: ListView(
                    padding: const EdgeInsetsDirectional.all(16),
                    children: <Widget>[
                      Card(
                        child: Padding(
                          padding: const EdgeInsetsDirectional.all(16),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: <Widget>[
                                Text(
                                  DriverStrings.newComplaint(locale),
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 12),
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
                                if (vm.successMessage != null) ...<Widget>[
                                  Text(
                                    vm.successMessage!,
                                    style: const TextStyle(
                                      color: WenshyColors.emerald,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                ],
                                DropdownButtonFormField<ComplaintCategory>(
                                  initialValue: _category,
                                  decoration: InputDecoration(
                                    labelText: DriverStrings.t(
                                      locale,
                                      'تصنيف الشكوى',
                                      'Complaint Category',
                                    ),
                                  ),
                                  items: ComplaintCategory.values
                                      .map(
                                        (cat) =>
                                            DropdownMenuItem<ComplaintCategory>(
                                          value: cat,
                                          child: Text(
                                            WenshyLabels.complaintCategory(
                                              cat,
                                              locale: locale,
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(growable: false),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() => _category = val);
                                    }
                                  },
                                ),
                                if (vm.driverTrips.isNotEmpty) ...<Widget>[
                                  const SizedBox(height: 12),
                                  DropdownButtonFormField<String?>(
                                    initialValue: _selectedTripId,
                                    decoration: InputDecoration(
                                      labelText: DriverStrings.t(
                                        locale,
                                        'الرحلة المرتبطة (اختياري)',
                                        'Related Trip (optional)',
                                      ),
                                    ),
                                    items: <DropdownMenuItem<String?>>[
                                      DropdownMenuItem<String?>(
                                        value: null,
                                        child: Text(
                                          DriverStrings.t(
                                            locale,
                                            'بدون رحلة محددة',
                                            'General / No specific trip',
                                          ),
                                        ),
                                      ),
                                      ...vm.driverTrips.map(
                                        (trip) => DropdownMenuItem<String?>(
                                          value: trip.id,
                                          child: Text(
                                            '${trip.requestCode} • ${trip.pickupAddress}',
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                    ],
                                    onChanged: (val) =>
                                        setState(() => _selectedTripId = val),
                                  ),
                                ],
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _subjectController,
                                  decoration: InputDecoration(
                                    labelText:
                                        DriverStrings.complaintSubject(locale),
                                  ),
                                  validator: (v) => (v?.trim().isEmpty ?? true)
                                      ? DriverStrings.t(
                                          locale,
                                          'أدخل عنوان الشكوى',
                                          'Enter a subject',
                                        )
                                      : null,
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _descriptionController,
                                  maxLines: 3,
                                  decoration: InputDecoration(
                                    labelText: DriverStrings.complaintDescription(
                                      locale,
                                    ),
                                  ),
                                  validator: (v) => (v?.trim().isEmpty ?? true)
                                      ? DriverStrings.t(
                                          locale,
                                          'أدخل تفاصيل المشكلة',
                                          'Describe the issue',
                                        )
                                      : null,
                                ),
                                const SizedBox(height: 12),
                                OutlinedButton.icon(
                                  onPressed: () => vm.pickEvidence(
                                    source: ImageSource.gallery,
                                  ),
                                  icon: const Icon(Icons.attach_file_rounded),
                                  label: Text(
                                    '${DriverStrings.attachEvidence(locale)} (${vm.stagedEvidence.length})',
                                  ),
                                ),
                                if (vm.stagedEvidence.isNotEmpty) ...<Widget>[
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 6,
                                    children: <Widget>[
                                      for (var i = 0;
                                          i < vm.stagedEvidence.length;
                                          i++)
                                        Chip(
                                          label: Text(
                                            vm.stagedEvidence[i].fileName,
                                          ),
                                          onDeleted: () =>
                                              vm.removeEvidenceAt(i),
                                        ),
                                    ],
                                  ),
                                ],
                                const SizedBox(height: 16),
                                WenshyPrimaryButton(
                                  label:
                                      DriverStrings.submitComplaintBtn(locale),
                                  icon: Icons.send_rounded,
                                  isLoading: vm.isSubmitting,
                                  onPressed: _submit,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        DriverStrings.t(
                          locale,
                          'الشكاوى السابقة',
                          'Previous Complaints',
                        ),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (vm.complaints.isEmpty)
                        Card(
                          child: Padding(
                            padding: const EdgeInsetsDirectional.all(20),
                            child: Center(
                              child: Text(
                                DriverStrings.noComplaintsYet(locale),
                              ),
                            ),
                          ),
                        )
                      else
                        for (final complaint in vm.complaints) ...<Widget>[
                          Card(
                            child: Padding(
                              padding: const EdgeInsetsDirectional.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Row(
                                    children: <Widget>[
                                      Expanded(
                                        child: Text(
                                          '${complaint.complaintCode} • ${complaint.subject}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                      WenshyStatusBadge.complaint(
                                        complaint.status,
                                        locale: locale,
                                        compact: true,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(complaint.description),
                                  if (complaint.adminNotes?.trim().isNotEmpty ==
                                      true) ...<Widget>[
                                    const SizedBox(height: 8),
                                    Text(
                                      '${DriverStrings.t(locale, 'رد الإدارة:', 'Admin Notes:')} ${complaint.adminNotes}',
                                      style: const TextStyle(
                                        color: WenshyColors.info,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                    ],
                  ),
                ),
        );
      },
    );
  }
}
