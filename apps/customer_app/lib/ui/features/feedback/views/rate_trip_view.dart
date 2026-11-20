import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:wenshy_core/wenshy_core.dart';

import '../../../core/app_dependencies.dart';
import '../../../core/app_strings.dart';
import '../../../core/language_toggle_button.dart';
import '../view_models/rate_trip_view_model.dart';

/// Post-delivery star rating & feedback tags screen (`public.ratings`).
class RateTripView extends StatefulWidget {
  const RateTripView({
    super.key,
    required this.requestId,
  });

  final String requestId;

  @override
  State<RateTripView> createState() => _RateTripViewState();
}

class _RateTripViewState extends State<RateTripView> {
  final _commentController = TextEditingController();
  RateTripViewModel? _vm;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final deps = AppDependenciesScope.of(context);
    final vm = RateTripViewModel(
      requestId: widget.requestId,
      rescueRepository: deps.rescueRepository,
      feedbackRepository: deps.feedbackRepository,
    );
    _vm = vm;
    vm.initialize(locale: deps.localeController.languageCode);
  }

  @override
  void dispose() {
    _commentController.dispose();
    _vm?.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final vm = _vm;
    if (vm == null) return;
    final deps = AppDependenciesScope.of(context);
    final customerId = deps.authViewModel.currentUserId;
    if (customerId == null) return;

    vm.setComment(_commentController.text);
    final created = await vm.submit(
      customerId: customerId,
      locale: deps.localeController.languageCode,
    );

    if (created != null && mounted) {
      final strings = AppStrings.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.ratingSubmitted)),
      );
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = _vm!;
    final strings = AppStrings.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.rateTripTitle),
        actions: const <Widget>[
          LanguageToggleButton(),
        ],
      ),
      body: ListenableBuilder(
        listenable: vm,
        builder: (context, _) {
          if (vm.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final existing = vm.existingRating;
          if (existing != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsetsDirectional.all(24),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsetsDirectional.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Icon(
                          Icons.check_circle_rounded,
                          color: WenshyColors.emerald,
                          size: 48,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          strings.alreadyRatedTitle,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List<Widget>.generate(
                            5,
                            (i) => Icon(
                              i < existing.score
                                  ? Icons.star_rounded
                                  : Icons.star_border_rounded,
                              color: WenshyColors.amber,
                              size: 32,
                            ),
                          ),
                        ),
                        if (existing.tags.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            alignment: WrapAlignment.center,
                            children: existing.tags
                                .map((t) => Chip(label: Text(t)))
                                .toList(),
                          ),
                        ],
                        if (existing.comment != null &&
                            existing.comment!.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 10),
                          Text(existing.comment!, textAlign: TextAlign.center),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsetsDirectional.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Card(
                  child: Padding(
                    padding: const EdgeInsetsDirectional.all(18),
                    child: Column(
                      children: <Widget>[
                        if (vm.request != null) ...<Widget>[
                          Text(
                            vm.request!.requestCode,
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: WenshyColors.slateMuted,
                            ),
                          ),
                          const SizedBox(height: 6),
                        ],
                        Text(
                          strings.howWasService,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List<Widget>.generate(5, (i) {
                            final star = i + 1;
                            final selected = star <= vm.score;
                            return IconButton(
                              key: Key('rate_star_$star'),
                              iconSize: 40,
                              onPressed: () => vm.setScore(star),
                              icon: Icon(
                                selected
                                    ? Icons.star_rounded
                                    : Icons.star_border_rounded,
                                color: selected
                                    ? WenshyColors.amber
                                    : WenshyColors.slateMuted,
                              ),
                            );
                          }),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: strings.ratingTags.map((tag) {
                    final active = vm.selectedTags.contains(tag);
                    return FilterChip(
                      label: Text(tag),
                      selected: active,
                      onSelected: (_) => vm.toggleTag(tag),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _commentController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: strings.ratingCommentHint,
                  ),
                ),
                if (vm.errorMessage != null) ...<Widget>[
                  const SizedBox(height: 12),
                  Text(
                    vm.errorMessage!,
                    style: const TextStyle(color: WenshyColors.red),
                  ),
                ],
                const SizedBox(height: 20),
                WenshyPrimaryButton(
                  label: strings.submitRatingBtn,
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
