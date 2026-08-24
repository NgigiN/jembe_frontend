import 'package:farm_tracker/core/analytics/analytics_service.dart';
import 'package:farm_tracker/core/widgets/crud/entity_error_view.dart';
import 'package:farm_tracker/core/widgets/feedback/app_snackbar.dart';
import 'package:farm_tracker/core/widgets/loading/skeleton_entity_list.dart';
import 'package:farm_tracker/features/content/domain/entities/question.dart';
import 'package:farm_tracker/features/content/presentation/bloc/question_bloc.dart';
import 'package:farm_tracker/features/content/presentation/bloc/question_event.dart';
import 'package:farm_tracker/features/content/presentation/bloc/question_state.dart';
import 'package:farm_tracker/injection_container.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AskQuestionPage extends StatefulWidget {
  const AskQuestionPage({super.key});

  @override
  State<AskQuestionPage> createState() => _AskQuestionPageState();
}

class _AskQuestionPageState extends State<AskQuestionPage> {
  final _controller = TextEditingController();

  // Tracked locally rather than derived from `state is QuestionLoading`,
  // because that state also covers the initial GetQuestionsEvent list-load
  // triggered from initState, not just an in-flight submission.
  bool _isSubmitting = false;

  // True once the first GetQuestionsEvent has settled (QuestionLoaded or
  // QuestionError). Needed because QuestionBloc threads the *current*
  // questions list through every subsequent QuestionLoading/QuestionError
  // it emits, including a from-zero-questions submit's - so for a user
  // with no existing questions, a submit failure looks structurally
  // identical (empty questions list) to a genuine first-load failure.
  // Safe to gate the skeleton branch on `!_hasLoadedOnce` directly: a
  // QuestionLoading transition never itself mutates this flag (only
  // QuestionLoaded/QuestionError do, in the listener below), so the value
  // the builder reads for a Loading state was always settled by a prior,
  // separate transition - no ordering hazard there.
  bool _hasLoadedOnce = false;

  // Whether the very first settle (QuestionLoaded or QuestionError) was an
  // error. Deliberately NOT re-derived from `_hasLoadedOnce` in the
  // builder: flutter_bloc's BlocConsumer runs the listener (and its
  // setState) to completion for a given state *before* the builder
  // evaluates that same state, so by the time the builder ran for a
  // genuine first-ever QuestionError, `_hasLoadedOnce` would already have
  // flipped to `true` in that same listener call - making a
  // `state is QuestionError && !_hasLoadedOnce` builder check always false
  // for exactly the case it's meant to catch. Instead, the listener
  // computes and stores this decision once, using the pre-mutation value,
  // and the builder reads the stored decision directly.
  bool _isFirstLoadError = false;

  @override
  void initState() {
    super.initState();
    context.read<QuestionBloc>().add(GetQuestionsEvent());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    sl<AnalyticsService>().track('question_submitted');
    setState(() => _isSubmitting = true);
    context.read<QuestionBloc>().add(SubmitQuestionEvent(text));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ask Us')),
      body: BlocConsumer<QuestionBloc, QuestionState>(
        listener: (context, state) {
          // Captured before any mutation below: true only if an earlier
          // GetQuestionsEvent already settled. Used both to decide (once,
          // for the transition that first settles the load) whether this
          // is a first-load failure, and to tell a genuine first-load
          // failure (no snackbar - EntityErrorView handles it inline)
          // apart from a later failure that also happens to carry an
          // empty questions list, e.g. a from-zero-questions submit (which
          // must still notify via snackbar, since the form stays on
          // screen instead of EntityErrorView).
          final wasLoadedOnce = _hasLoadedOnce;
          if (state is QuestionLoaded) {
            setState(() {
              if (!wasLoadedOnce) {
                _isFirstLoadError = false;
                _hasLoadedOnce = true;
              }
              if (_isSubmitting) _isSubmitting = false;
            });
            if (state.successMessage != null) {
              _controller.clear();
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(AppSnackBar.success(state.successMessage!));
            }
          } else if (state is QuestionError) {
            setState(() {
              if (!wasLoadedOnce) {
                _isFirstLoadError = true;
                _hasLoadedOnce = true;
              }
              if (_isSubmitting) _isSubmitting = false;
            });
            if (state.questions.isNotEmpty || wasLoadedOnce) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(AppSnackBar.error(state.message));
            }
          }
        },
        builder: (context, state) {
          if (state is QuestionLoading && !_hasLoadedOnce) {
            return const SkeletonEntityList(icon: Icons.question_answer);
          }

          if (state is QuestionError && _isFirstLoadError) {
            return EntityErrorView(
              message: state.message,
              onRetry: () =>
                  context.read<QuestionBloc>().add(GetQuestionsEvent()),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Have a question about your farm? Ask us directly - '
                'we read every question and answer here.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _controller,
                maxLines: 4,
                maxLength: 1000,
                decoration: const InputDecoration(
                  hintText: 'Type your question...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Submit'),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Your questions',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (state.questions.isEmpty)
                const Text('No questions yet.')
              else
                for (final q in state.questions) _QuestionTile(question: q),
            ],
          );
        },
      ),
    );
  }
}

class _QuestionTile extends StatelessWidget {
  const _QuestionTile({required this.question});
  final Question question;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              question.questionText,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            if (question.answerText != null &&
                question.answerText!.trim().isNotEmpty) ...[
              const Divider(),
              Text(question.answerText!),
            ] else
              Text(
                'Awaiting a reply',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
              ),
          ],
        ),
      ),
    );
  }
}
