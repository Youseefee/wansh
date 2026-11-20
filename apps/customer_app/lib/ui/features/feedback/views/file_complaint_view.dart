import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:wenshy_core/wenshy_core.dart';

import '../../../../data/repositories/models.dart';
import '../../../core/app_dependencies.dart';
import '../../../core/app_strings.dart';
import '../../../core/language_toggle_button.dart';
import '../view_models/complaints_view_model.dart';

/// Form for filing a new complaint (`public.complaints`) and attaching evidence
/// photos to the `complaint-evidence` Supabase Storage bucket.
class FileComplaintView extends StatefulWidget {
  const FileComplaintView({
    super.key,
    this.requestId,
    this.reportedUserId,
  });

  final String? requestId;
  final String? reportedUserId;

  @override
  State<FileComplaintView> createState() => _FileComplaintViewState();
}

class _FileComplaintViewState extends State<FileComplaintView> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _descriptionController = TextEditingController();

  ComplaintsViewModel? _vm;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final deps = AppDependenciesScope.of(context);
    _vm = ComplaintsViewModel(repository: deps.feedbackRepository);
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _descriptionController.dispose();
    _vm?.dispose();
    super.dispose();
  }

  Future<void> _pickCamera() async {
    final deps = AppDependenciesScope.of(context);
    final photo = await deps.photoPicker.pickFromCamera();
    if (photo != null) {
      _vm?.addEvidenceFiles(<SelectedPhotoBytes>[photo]);
    }
  }

  Future<void> _pickGallery() async {
    final deps = AppDependenciesScope.of(context);
    final photos = await deps.photoPicker.pickMultipleFromGallery();
    if (photos.isNotEmpty) {
      _vm?.addEvidenceFiles(photos);
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final vm = _vm;
    if (vm == null) return;
    final deps = AppDependenciesScope.of(context);
    final reporterId = deps.authViewModel.currentUserId;
    if (reporterId == null) return;

    final created = await vm.submitComplaint(
      reporterId: reporterId,
      requestId: widget.requestId,
      reportedUserId: widget.reportedUserId,
      subject: _subjectController.text,
      description: _descriptionController.text,
      locale: deps.localeController.languageCode,
    );

    if (created != null && mounted) {
      final strings = AppStrings.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.complaintSubmitted)),
      );
      context.pop(created);
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
        title: Text(strings.fileComplaintTitle),
        actions: const <Widget>[
          LanguageToggleButton(),
        ],
      ),
      body: ListenableBuilder(
        listenable: vm,
        builder: (context, _) {
          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 32),
              children: <Widget>[
                DropdownButtonFormField<ComplaintCategory>(
                  initialValue: vm.category,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: strings.complaintCategoryLabel,
                  ),
                  items: ComplaintCategory.values
                      .map(
                        (cat) => DropdownMenuItem<ComplaintCategory>(
                          value: cat,
                          child: Text(
                            WenshyLabels.complaintCategory(
                              cat,
                              locale: localeCode,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (cat) {
                    if (cat != null) vm.setCategory(cat);
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _subjectController,
                  decoration: InputDecoration(
                    labelText: strings.complaintSubjectLabel,
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? strings.requiredField
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: strings.complaintDescriptionLabel,
                    alignLabelWithHint: true,
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? strings.requiredField
                      : null,
                ),
                const SizedBox(height: 16),
                Text(
                  strings.evidencePhotosLabel,
                  style: theme.textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    OutlinedButton.icon(
                      onPressed: vm.isSubmitting ? null : _pickCamera,
                      icon: const Icon(Icons.camera_alt_outlined),
                      label: Text(strings.camera),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed: vm.isSubmitting ? null : _pickGallery,
                      icon: const Icon(Icons.photo_library_outlined),
                      label: Text(strings.gallery),
                    ),
                  ],
                ),
                if (vm.evidenceFiles.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 84,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: vm.evidenceFiles.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final photo = vm.evidenceFiles[index];
                        return Stack(
                          children: <Widget>[
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.memory(
                                photo.bytes,
                                width: 84,
                                height: 84,
                                fit: BoxFit.cover,
                              ),
                            ),
                            PositionedDirectional(
                              top: 2,
                              end: 2,
                              child: GestureDetector(
                                onTap: () => vm.removeEvidenceAt(index),
                                child: const CircleAvatar(
                                  radius: 11,
                                  backgroundColor: Colors.black87,
                                  child: Icon(
                                    Icons.close,
                                    size: 14,
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
                if (vm.errorMessage != null) ...<Widget>[
                  const SizedBox(height: 12),
                  Text(
                    vm.errorMessage!,
                    style: const TextStyle(color: WenshyColors.red),
                  ),
                ],
                const SizedBox(height: 22),
                WenshyPrimaryButton(
                  label: strings.submitComplaintBtn,
                  icon: Icons.send_rounded,
                  isLoading: vm.isSubmitting,
                  onPressed: vm.isSubmitting ? null : _submit,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
