import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:wenshy_core/wenshy_core.dart';

import '../../../core/app_dependencies.dart';
import '../../../core/app_strings.dart';
import '../../../core/language_toggle_button.dart';
import '../view_models/complaints_view_model.dart';

/// Lists complaints filed by the signed-in customer (`public.complaints`).
class ComplaintsView extends StatefulWidget {
  const ComplaintsView({super.key});

  @override
  State<ComplaintsView> createState() => _ComplaintsViewState();
}

class _ComplaintsViewState extends State<ComplaintsView> {
  ComplaintsViewModel? _vm;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final deps = AppDependenciesScope.of(context);
    final vm = ComplaintsViewModel(repository: deps.feedbackRepository);
    _vm = vm;
    _reload();
  }

  Future<void> _reload() async {
    final deps = AppDependenciesScope.of(context);
    final uid = deps.authViewModel.currentUserId;
    if (uid == null) return;
    await _vm?.loadComplaints(
      uid,
      locale: deps.localeController.languageCode,
    );
  }

  @override
  void dispose() {
    _vm?.dispose();
    super.dispose();
  }

  Future<void> _openNewComplaint() async {
    final created = await context.push<Complaint?>('/complaints/new');
    if (created != null && mounted) {
      await _reload();
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
        title: Text(strings.complaintsTitle),
        actions: <Widget>[
          const LanguageToggleButton(),
          IconButton(
            tooltip: strings.fileComplaintTitle,
            onPressed: _openNewComplaint,
            icon: const Icon(Icons.add_comment_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openNewComplaint,
        icon: const Icon(Icons.report_problem_outlined),
        label: Text(strings.fileComplaintCta),
      ),
      body: ListenableBuilder(
        listenable: vm,
        builder: (context, _) {
          if (vm.isLoading && vm.complaints.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 96),
              children: <Widget>[
                if (vm.errorMessage != null) ...<Widget>[
                  Text(
                    vm.errorMessage!,
                    style: const TextStyle(color: WenshyColors.red),
                  ),
                  const SizedBox(height: 10),
                ],
                if (vm.complaints.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsetsDirectional.all(24),
                      child: Column(
                        children: <Widget>[
                          const Icon(
                            Icons.support_agent_rounded,
                            size: 54,
                            color: WenshyColors.slateMuted,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            strings.noComplaintsEmpty,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyLarge,
                          ),
                          const SizedBox(height: 16),
                          WenshyPrimaryButton(
                            label: strings.fileComplaintTitle,
                            icon: Icons.add_rounded,
                            onPressed: _openNewComplaint,
                          ),
                        ],
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
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: <Widget>[
                                Text(
                                  complaint.complaintCode,
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                WenshyStatusBadge.complaint(
                                  complaint.status,
                                  locale: localeCode,
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              complaint.subject,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              WenshyLabels.complaintCategory(
                                complaint.category,
                                locale: localeCode,
                              ),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: WenshyColors.amberDark,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              complaint.description,
                              style: theme.textTheme.bodyMedium,
                            ),
                            if (complaint.adminNotes != null &&
                                complaint.adminNotes!.isNotEmpty) ...<Widget>[
                              const SizedBox(height: 10),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsetsDirectional.all(10),
                                decoration: BoxDecoration(
                                  color: WenshyColors.amberSoft,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      strings.adminResponseLabel,
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      complaint.adminNotes!,
                                      style: theme.textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 8),
                            Text(
                              DateFormat.yMMMd(localeCode)
                                  .add_jm()
                                  .format(complaint.createdAt.toLocal()),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: WenshyColors.slateMuted,
                              ),
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
