import 'dart:convert';

import 'package:farm_tracker/features/content/data/models/content_item_model.dart';
import 'package:flutter/services.dart' show rootBundle;

abstract class ContentLocalDataSource {
  Future<List<ContentItemModel>> getAll();
}

class ContentLocalDataSourceImpl implements ContentLocalDataSource {
  List<ContentItemModel>? _cache;

  @override
  Future<List<ContentItemModel>> getAll() async {
    final cached = _cache;
    if (cached != null) return cached;

    final raw = await rootBundle.loadString('assets/content/tips.json');
    final decoded = json.decode(raw) as List<dynamic>;
    final items = decoded
        .map((e) => ContentItemModel.fromJson(e as Map<String, dynamic>))
        .toList();
    _cache = items;
    return items;
  }
}
