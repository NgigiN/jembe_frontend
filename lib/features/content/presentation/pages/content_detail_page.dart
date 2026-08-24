import 'package:farm_tracker/features/content/presentation/bloc/content_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ContentDetailPage extends StatelessWidget {
  const ContentDetailPage({required this.contentId, super.key});

  final String contentId;

  @override
  Widget build(BuildContext context) {
    final items = context.watch<ContentBloc>().state.items;
    final item = items.where((i) => i.id == contentId).firstOrNull;

    return Scaffold(
      appBar: AppBar(title: Text(item?.title ?? 'Tip')),
      body: item == null
          ? const Center(child: Text('This tip is no longer available.'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Source: ${item.source}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(item.body, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
    );
  }
}
