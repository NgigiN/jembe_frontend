import 'package:farm_tracker/core/analytics/analytics_service.dart';
import 'package:farm_tracker/core/widgets/crud/entity_error_view.dart';
import 'package:farm_tracker/core/widgets/feedback/app_snackbar.dart';
import 'package:farm_tracker/features/content/domain/entities/question.dart';
import 'package:farm_tracker/features/content/presentation/bloc/question_bloc.dart';
import 'package:farm_tracker/features/content/presentation/bloc/question_event.dart';
import 'package:farm_tracker/features/content/presentation/bloc/question_state.dart';
import 'package:farm_tracker/injection_container.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Ask Us: a composite page - a persistent question-input form on top of a
/// "Your questions" list.
///
/// Unlike a pure list page (e.g. LandPage), this page must NOT swap its whole
/// body out for a skeleton or an error view while the list loads or fails:
/// doing so takes away a form the user may be halfway through typing into, and
/// offers a "Try Again" button that cannot recover their draft. Loading, error
/// and empty treatment is therefore confined to [_QuestionsSection] below the
/// form, and the form itself renders unconditionally in every bloc state.
class AskQuestionPage extends StatefulWidget {
  const AskQuestionPage({super.key});

  @override
  State<AskQuestionPage> createState() => _AskQuestionPageState();
}

class _AskQuestionPageState extends State<AskQuestionPage> {
  final _controller = TextEditingController();

  /// True only while a [SubmitQuestionEvent] dispatched by this page is still
  /// in flight. Deliberately not derived from `state is QuestionLoading`,
  /// which also covers the initial list load from [initState] and any later
  /// background refresh - neither should disable the Submit button.
  ///
  /// Nothing about *which content the page renders* depends on this flag: it
  /// only drives the button's enabled/spinner state and the choice of error
  /// feedback. So, unlike the flag schemes this replaced, it can never hide
  /// the form or the user's questions no matter when it is read or written.
  bool _isSubmitting = false;

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
    // Guards a rapid double-tap whose second tap lands before the setState
    // below has rebuilt the button in its disabled state.
    if (_isSubmitting) return;
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
          // Captured before the reset below, so a terminal state can tell a
          // failed submission apart from a failed list load.
          final wasSubmitting = _isSubmitting;
          if (state is QuestionLoaded) {
            if (_isSubmitting) setState(() => _isSubmitting = false);
            // Only a successful submit clears the draft - never an error, and
            // never a plain list reload.
            if (state.successMessage != null) {
              _controller.clear();
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(AppSnackBar.success(state.successMessage!));
            }
          } else if (state is QuestionError) {
            if (_isSubmitting) setState(() => _isSubmitting = false);
            // A failed submit always gets a snackbar: the form stays on
            // screen, and the questions section below it may well be scrolled
            // out of view behind the keyboard, so it is not reliable feedback
            // for an action the user just took. A failure that arrives with
            // questions already loaded also gets one, since the section keeps
            // showing that (now stale) list. The only silent case is a list
            // load that failed with nothing to show, where the inline
            // EntityErrorView in the questions section *is* the feedback.
            if (wasSubmitting || state.questions.isNotEmpty) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(AppSnackBar.error(state.message));
            }
          }
        },
        builder: (context, state) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Everything down to the Submit button is state-independent:
              // there is no branch above this that can replace it.
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
              _QuestionsSection(state: state),
            ],
          );
        },
      ),
    );
  }
}

/// The "Your questions" section - the only part of the page that varies with
/// bloc state.
///
/// Every branch is bounded and renders inline, below the form: none of them
/// expands to fill the page or scrolls on its own, so whatever this section
/// shows, the form above it stays visible and usable.
class _QuestionsSection extends StatelessWidget {
  const _QuestionsSection({required this.state});

  final QuestionState state;

  @override
  Widget build(BuildContext context) {
    // Local binding so the `is` checks below promote.
    final state = this.state;

    // Data first, whatever the state class is. QuestionBloc threads the
    // current questions through the QuestionLoading it emits for a background
    // refresh or a submit, and through a QuestionError for a failed one; all
    // of those mean "we still have the previous list", so keep showing it
    // rather than replacing it with a spinner or an error view.
    final questions = state.questions;
    if (questions.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final question in questions) _QuestionTile(question: question),
        ],
      );
    }

    // Nothing to show, and the last thing that happened failed. Retrying is
    // always a list reload: if the failure came from a submit instead, the
    // draft is still sitting in the field above, so the user can simply submit
    // again. Note this needs no "was this the first load?" bookkeeping - it is
    // a plain read of the current state, so it cannot latch on and hide a list
    // that a later, unrelated error arrives on top of (that list is non-empty,
    // and so was already returned above).
    if (state is QuestionError) {
      return EntityErrorView(
        message: state.message,
        onRetry: () => context.read<QuestionBloc>().add(GetQuestionsEvent()),
      );
    }

    // The load succeeded and there is genuinely nothing to show yet.
    if (state is QuestionLoaded) {
      return const Text('No questions yet.');
    }

    // QuestionInitial, or a QuestionLoading with no data behind it yet. This
    // also catches the Loading of a from-zero-questions submit, which is a
    // purely cosmetic overlap: a spinner instead of "No questions yet." for a
    // moment, in a section that is about to be replaced by the new question
    // anyway. Nothing is hidden either way.
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Center(child: CircularProgressIndicator()),
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
            // Answer visibility depends on answerText alone, never on
            // status/isAnswered: an answer that has been written must show
            // even if the status field lags behind.
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
