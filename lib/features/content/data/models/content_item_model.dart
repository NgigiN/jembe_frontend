import 'package:farm_tracker/features/content/domain/entities/content_item.dart';

class ContentItemModel extends ContentItem {
  const ContentItemModel({
    required super.id,
    required super.title,
    required super.summary,
    required super.body,
    required super.language,
    required super.source,
    required super.animalTypeTags,
    required super.cropTags,
    required super.publishedAt,
  });

  factory ContentItemModel.fromJson(Map<String, dynamic> json) {
    final source = (json['source'] as String?)?.trim() ?? '';
    if (source.isEmpty) {
      throw FormatException(
        'Content item ${json['id']} is missing a required source citation',
      );
    }

    return ContentItemModel(
      id: json['id'] as String,
      title: json['title'] as String,
      summary: json['summary'] as String,
      body: json['body'] as String,
      language: json['language'] as String,
      source: source,
      animalTypeTags: (json['animalTypeTags'] as List<dynamic>? ?? [])
          .map((e) => e as String)
          .toList(),
      cropTags: (json['cropTags'] as List<dynamic>? ?? [])
          .map((e) => e as String)
          .toList(),
      publishedAt: DateTime.parse(json['publishedAt'] as String),
    );
  }
}
