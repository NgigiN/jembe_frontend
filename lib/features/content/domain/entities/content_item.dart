import 'package:equatable/equatable.dart';

class ContentItem extends Equatable {
  const ContentItem({
    required this.id,
    required this.title,
    required this.summary,
    required this.body,
    required this.language,
    required this.source,
    required this.animalTypeTags,
    required this.cropTags,
    required this.publishedAt,
  });

  final String id;
  final String title;
  final String summary;
  final String body;
  final String language;
  final String source;
  final List<String> animalTypeTags;
  final List<String> cropTags;
  final DateTime publishedAt;

  @override
  List<Object?> get props => [
    id,
    title,
    summary,
    body,
    language,
    source,
    animalTypeTags,
    cropTags,
    publishedAt,
  ];
}
