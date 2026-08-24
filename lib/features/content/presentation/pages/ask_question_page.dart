import 'package:farm_tracker/core/analytics/analytics_service.dart';
import 'package:farm_tracker/core/widgets/feedback/app_snackbar.dart';
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
    context.read<QuestionBloc>().add(SubmitQuestionEvent(text));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ask Us')),
      body: BlocConsumer<QuestionBloc, QuestionState>(
        listener: (context, state) {
          if (state is QuestionLoaded && state.successMessage != null) {
            _controller.clear();
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(AppSnackBar.success(state.successMessage!));
          } else if (state is QuestionError) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(AppSnackBar.error(state.message));
          }
        },
        builder: (context, state) {
          final isSubmitting = state is QuestionLoading;
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
                  onPressed: isSubmitting ? null : _submit,
                  child: isSubmitting
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
            if (question.isAnswered && question.answerText != null) ...[
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
