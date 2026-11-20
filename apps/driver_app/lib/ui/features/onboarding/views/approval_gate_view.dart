import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:wenshy_core/wenshy_core.dart';

import '../../../core/driver_session_controller.dart';
import '../../../core/driver_strings.dart';
import '../../../core/locale_controller.dart';
import '../../../core/widgets/driver_widgets.dart';
import '../../notifications/view_models/notifications_view_model.dart';
import '../view_models/onboarding_view_model.dart';

/// Approval Gate Screen displayed while `driverProfile.approvalStatus != approved`.
/// Covers `pending`, `under_review`, `rejected` (with `rejection_reason` and
/// re-upload CTA), and `suspended`.
class ApprovalGateView extends StatefulWidget {
  const ApprovalGateView({
    super.key,
    required this.viewModel,
    required this.sessionController,
    required this.localeController,
    this.notificationsController,
  });

  final OnboardingViewModel viewModel;
  final DriverSessionController sessionController;
  final LocaleController localeController;
  final DriverNotificationsController? notificationsController;

  @override
  State<ApprovalGateView> createState() => _ApprovalGateViewState();
}

class _ApprovalGateViewState extends State<ApprovalGateView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.viewModel.loadOnboardingData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[
        widget.viewModel,
        widget.sessionController,
        widget.localeController,
      ]),
      builder: (context, _) {
        final locale = widget.localeController.localeCode;
        final theme = Theme.of(context);
        final driver = widget.sessionController.driverProfile;
        final profile = widget.sessionController.userProfile;
        final status = driver?.approvalStatus ?? DriverApprovalStatus.pending;
        final vm = widget.viewModel;

        return Scaffold(
          appBar: AppBar(
            title: Text(DriverStrings.approvalGateTitle(locale)),
            actions: <Widget>[
              if (widget.notificationsController != null)
                NotificationsBellButton(
                  notificationsController: widget.notificationsController!,
                  localeController: widget.localeController,
                ),
              LocaleToggleButton(localeController: widget.localeController),
              IconButton(
                tooltip: DriverStrings.signOut(locale),
                icon: const Icon(Icons.logout_rounded),
                onPressed: widget.sessionController.signOut,
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: () => vm.loadOnboardingData(refreshSession: true),
            child: ListView(
              padding: const EdgeInsetsDirectional.all(20),
              children: <Widget>[
                Card(
                  child: Padding(
                    padding: const EdgeInsetsDirectional.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                profile?.fullName.isNotEmpty == true
                                    ? profile!.fullName
                                    : DriverStrings.t(
                                        locale,
                                        'كابتن ونشي',
                                        'Wenshy Driver',
                                      ),
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            WenshyStatusBadge.driverApproval(
                              status,
                              locale: locale,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          WenshyLabels.driverApprovalDescription(
                            status,
                            locale: locale,
                          ),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (status == DriverApprovalStatus.rejected ||
                            status == DriverApprovalStatus.suspended) ...<Widget>[
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsetsDirectional.all(14),
                            decoration: BoxDecoration(
                              color: WenshyColors.red.withValues(alpha: 0.09),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: WenshyColors.red.withValues(alpha: 0.35),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  DriverStrings.rejectionReasonLabel(locale),
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    color: WenshyColors.red,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  driver?.rejectionReason?.trim().isNotEmpty ==
                                          true
                                      ? driver!.rejectionReason!
                                      : DriverStrings.t(
                                          locale,
                                          'يرجى مراجعة المستندات المرفوعة والتأكد من وضوح الصور وصلاحيتها.',
                                          'Please inspect your uploaded documents and make sure images are clear and valid.',
                                        ),
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: WenshyColors.deepSlate,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (vm.isLoading)
                  const Padding(
                    padding: EdgeInsetsDirectional.symmetric(vertical: 24),
                    child: WenshyLoadingView(),
                  )
                else ...<Widget>[
                  _OnboardingStepCard(
                    title: DriverStrings.setupWinchStep(locale),
                    subtitle: vm.hasRegisteredWinch
                        ? DriverStrings.t(
                            locale,
                            'تم تسجيل ${vm.winches.length} ونش',
                            '${vm.winches.length} tow truck(s) registered',
                          )
                        : DriverStrings.t(
                            locale,
                            'أضف بيانات الونش ورقم اللوحة والصور',
                            'Add your tow truck specs, plate number, and photos',
                          ),
                    icon: Icons.local_shipping_outlined,
                    completed: vm.hasRegisteredWinch,
                    enabled: status.canEditDocuments,
                    actionLabel: vm.hasRegisteredWinch
                        ? DriverStrings.t(locale, 'عرض / إضافة', 'View / Add')
                        : DriverStrings.t(locale, 'إعداد الآن', 'Set Up'),
                    onTap: () => context.push('/onboarding/winch'),
                  ),
                  const SizedBox(height: 12),
                  _OnboardingStepCard(
                    title: DriverStrings.uploadKycStep(locale),
                    subtitle: DriverStrings.t(
                      locale,
                      'تم رفع ${vm.uploadedDocumentsCount} من ${OnboardingViewModel.requiredDocuments.length} مستندات'
                      '${vm.rejectedDocumentsCount > 0 ? ' (${vm.rejectedDocumentsCount} مرفوض)' : ''}',
                      '${vm.uploadedDocumentsCount} of ${OnboardingViewModel.requiredDocuments.length} documents uploaded'
                      '${vm.rejectedDocumentsCount > 0 ? ' (${vm.rejectedDocumentsCount} rejected)' : ''}',
                    ),
                    icon: Icons.verified_user_outlined,
                    completed: vm.uploadedDocumentsCount ==
                            OnboardingViewModel.requiredDocuments.length &&
                        vm.rejectedDocumentsCount == 0,
                    hasWarning: vm.rejectedDocumentsCount > 0 ||
                        status == DriverApprovalStatus.rejected,
                    enabled: status.canEditDocuments,
                    actionLabel: status == DriverApprovalStatus.rejected ||
                            vm.rejectedDocumentsCount > 0
                        ? DriverStrings.reuploadDoc(locale)
                        : DriverStrings.t(locale, 'إدارة المستندات', 'Manage Docs'),
                    onTap: () => context.push('/onboarding/kyc'),
                  ),
                ],
                const SizedBox(height: 24),
                if (status == DriverApprovalStatus.rejected)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(bottom: 12),
                    child: WenshyPrimaryButton(
                      label: DriverStrings.t(
                        locale,
                        'إعادة رفع المستندات المرفوضة',
                        'Re-upload Rejected Documents',
                      ),
                      icon: Icons.upload_file_rounded,
                      backgroundColor: WenshyColors.red,
                      foregroundColor: Colors.white,
                      onPressed: () => context.push('/onboarding/kyc'),
                    ),
                  ),
                OutlinedButton.icon(
                  onPressed: vm.isLoading
                      ? null
                      : () => vm.loadOnboardingData(refreshSession: true),
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(DriverStrings.refreshStatus(locale)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _OnboardingStepCard extends StatelessWidget {
  const _OnboardingStepCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.completed,
    required this.enabled,
    required this.actionLabel,
    required this.onTap,
    this.hasWarning = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool completed;
  final bool enabled;
  final String actionLabel;
  final VoidCallback onTap;
  final bool hasWarning;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = hasWarning
        ? WenshyColors.red
        : completed
            ? WenshyColors.emerald
            : WenshyColors.amberDark;

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsetsDirectional.symmetric(
          horizontal: 16,
          vertical: 10,
        ),
        leading: CircleAvatar(
          backgroundColor: accent.withValues(alpha: 0.14),
          child: Icon(
            hasWarning
                ? Icons.warning_amber_rounded
                : completed
                    ? Icons.check_circle_outline
                    : icon,
            color: accent,
          ),
        ),
        title: Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsetsDirectional.only(top: 4),
          child: Text(subtitle),
        ),
        trailing: enabled
            ? FilledButton.tonal(
                onPressed: onTap,
                child: Text(actionLabel),
              )
            : null,
      ),
    );
  }
}
