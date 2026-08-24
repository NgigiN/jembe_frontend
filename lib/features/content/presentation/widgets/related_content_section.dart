import 'package:farm_tracker/core/analytics/analytics_service.dart';
import 'package:farm_tracker/core/navigation/app_router.dart';
import 'package:farm_tracker/features/content/domain/content_relevance_matcher.dart';
import 'package:farm_tracker/features/content/presentation/bloc/content_bloc.dart';
import 'package:farm_tracker/features/content/presentation/widgets/content_card.dart';
import 'package:farm_tracker/injection_container.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

enum ContentMatchKind { animal, crop }

const _matcher = ContentRelevanceMatcher();

class RelatedContentSection extends StatelessWidget {
  const RelatedContentSection({
    required this.matchNames,
    required this.kind,
    super.key,
  });

  final List<String> matchNames;
  final ContentMatchKind kind;

  @override
  Widget build(BuildContext context) {
    final allContent = context.watch<ContentBloc>().state.items;
    if (matchNames.isEmpty || allContent.isEmpty) {
      return const SizedBox.shrink();
    }

    final matches = kind == ContentMatchKind.animal
        ? _matcher.forAnimalTypeNames(allContent, matchNames)
        : _matcher.forPlantNames(allContent, matchNames);
    final visible = matches.take(3).toList();
    if (visible.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tips for you', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final item in visible)
            ContentCard(
              item: item,
              onTap: () {
                sl<AnalyticsService>().track(
                  'content_view',
                  metadata: {'content_id': item.id},
                );
                context.push(AppRoutePath.contentDetailFor(item.id));
              },
            ),
          TextButton(
            onPressed: () {
              sl<AnalyticsService>().track('content_list_opened');
              context.push(AppRoutePath.contentTips);
            },
            child: const Text('View all tips'),
          ),
        ],
      ),
    );
  }
}
