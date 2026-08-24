import 'package:flutter_test/flutter_test.dart';
import 'package:farm_tracker/features/content/data/models/question_model.dart';

void main() {
  group('QuestionModel', () {
    test('fromJson parses an unanswered question', () {
      final json = {
        'ID': 5,
        'question_text': 'How often should I deworm my goats?',
        'status': 'unanswered',
        'answer_text': null,
        'answered_at': null,
        'CreatedAt': '2026-08-01T00:00:00Z',
      };

      final model = QuestionModel.fromJson(json);

      expect(model.id, '5');
      expect(model.status, 'unanswered');
      expect(model.isAnswered, isFalse);
      expect(model.answerText, isNull);
      expect(model.answeredAt, isNull);
    });

    test('fromJson parses an answered question', () {
      final json = {
        'ID': 6,
        'question_text': 'x',
        'status': 'answered',
        'answer_text':
            'Every 3 months is a common schedule - check with your vet.',
        'answered_at': '2026-08-10T00:00:00Z',
        'CreatedAt': '2026-08-01T00:00:00Z',
      };

      final model = QuestionModel.fromJson(json);

      expect(model.isAnswered, isTrue);
      expect(
        model.answerText,
        'Every 3 months is a common schedule - check with your vet.',
      );
      expect(model.answeredAt, DateTime.parse('2026-08-10T00:00:00Z'));
    });
  });
}
