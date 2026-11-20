import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:wenshy_core/wenshy_core.dart';

import '../../../core/driver_strings.dart';
import '../../../core/locale_controller.dart';
import '../../../core/widgets/driver_widgets.dart';
import '../view_models/onboarding_view_model.dart';

/// KYC compliance upload & re-upload screen backed by `driver-documents`
/// Storage bucket and `driver_documents` table (`upsert: true`).
class KycUploadView extends StatefulWidget {
  const KycUploadView({
    super.key,
    required this.viewModel,
    required this.localeController,
  });

  final OnboardingViewModel viewModel;
  final LocaleController localeController;

  @override
  State<KycUploadView> createState() => _KycUploadViewState();
}

class _KycUploadViewState extends State<KycUploadView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.viewModel.loadOnboardingData();
    });
  }

  Future<void> _chooseSourceAndUpload(
    DocumentType type,
    String locale,
  ) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheetCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsetsDirectional.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  WenshyLabels.documentType(type, locale: locale),
                  style: Theme.of(sheetCtx).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.camera_alt_outlined),
                  title: Text(DriverStrings.pickFromCamera(locale)),
                  onTap: () => Navigator.of(sheetCtx).pop(ImageSource.camera),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: Text(DriverStrings.pickFromGallery(locale)),
                  onTap: () => Navigator.of(sheetCtx).pop(ImageSource.gallery),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (source == null || !mounted) return;
    await widget.viewModel.pickAndUploadDocument(
      documentType: type,
      source: source,
    );
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
        final vm = widget.viewModel;
        final canEdit =
            vm.driverProfile?.approvalStatus.canEditDocuments ?? true;

        return Scaffold(
          appBar: AppBar(
            title: Text(DriverStrings.kycUploadTitle(locale)),
            actions: <Widget>[
              LocaleToggleButton(localeController: widget.localeController),
            ],
          ),
          body: vm.isLoading && vm.documents.isEmpty
              ? const WenshyLoadingView()
              : RefreshIndicator(
                  onRefresh: () => vm.loadOnboardingData(refreshSession: true),
                  child: ListView(
                    padding: const EdgeInsetsDirectional.all(16),
                    children: <Widget>[
                      if (vm.errorMessage != null) ...<Widget>[
                        _KycBanner(
                          message: vm.errorMessage!,
                          color: WenshyColors.red,
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (vm.successMessage != null) ...<Widget>[
                        _KycBanner(
                          message: vm.successMessage!,
                          color: WenshyColors.emerald,
                        ),
                        const SizedBox(height: 12),
                      ],
                      for (final docType
                          in OnboardingViewModel.requiredDocuments) ...<Widget>[
                        _KycDocumentTile(
                          docType: docType,
                          existing: vm.documentForType(docType),
                          isUploading: vm.uploadingDocType == docType,
                          canEdit: canEdit,
                          locale: locale,
                          onUploadTap: () =>
                              _chooseSourceAndUpload(docType, locale),
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

class _KycDocumentTile extends StatelessWidget {
  const _KycDocumentTile({
    required this.docType,
    required this.existing,
    required this.isUploading,
    required this.canEdit,
    required this.locale,
    required this.onUploadTap,
  });

  final DocumentType docType;
  final DriverDocument? existing;
  final bool isUploading;
  final bool canEdit;
  final String locale;
  final VoidCallback onUploadTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRejected =
        existing?.reviewStatus == DocumentReviewStatus.rejected;

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
                    WenshyLabels.documentType(docType, locale: locale),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (existing != null)
                  WenshyStatusBadge.documentReview(
                    existing!.reviewStatus,
                    locale: locale,
                    compact: true,
                  )
                else
                  WenshyStatusBadge(
                    label: DriverStrings.t(locale, 'غير مرفوع', 'Missing'),
                    color: WenshyColors.slateMuted,
                    compact: true,
                  ),
              ],
            ),
            if (isRejected &&
                existing?.rejectionReason?.trim().isNotEmpty == true) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                '${DriverStrings.rejectionReasonLabel(locale)} ${existing!.rejectionReason}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: WenshyColors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                if (isUploading)
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  )
                else if (canEdit)
                  FilledButton.tonalIcon(
                    onPressed: onUploadTap,
                    icon: Icon(
                      existing == null
                          ? Icons.upload_rounded
                          : Icons.refresh_rounded,
                    ),
                    label: Text(
                      existing == null
                          ? DriverStrings.uploadDoc(locale)
                          : DriverStrings.reuploadDoc(locale),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _KycBanner extends StatelessWidget {
  const _KycBanner({
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
