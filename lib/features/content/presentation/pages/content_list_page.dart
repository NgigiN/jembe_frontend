import 'package:farm_tracker/core/analytics/analytics_service.dart';
import 'package:farm_tracker/core/navigation/app_router.dart';
import 'package:farm_tracker/features/content/presentation/bloc/content_bloc.dart';
import 'package:farm_tracker/features/content/presentation/bloc/content_event.dart';
import 'package:farm_tracker/features/content/presentation/widgets/content_card.dart';
import 'package:farm_tracker/injection_container.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class ContentListPage extends StatefulWidget {
  const ContentListPage({super.key});

  @override
  State<ContentListPage> createState() => _ContentListPageState();
}

class _ContentListPageState extends State<ContentListPage> {
  String _query = '';

  @override
  void initState() {
    super.initState();
    context.read<ContentBloc>().add(GetAllContentEvent());
  }

  @override
  Widget build(BuildContext context) {
    final items = context.watch<ContentBloc>().state.items;
    final query = _query.trim().toLowerCase();
    final visible = query.isEmpty
        ? items
        : items
              .where(
                (i) =>
                    i.title.toLowerCase().contains(query) ||
                    i.summary.toLowerCase().contains(query),
              )
              .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Farming Tips')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search tips...',
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          Expanded(
            child: visible.isEmpty
                ? const Center(child: Text('No tips found'))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: visible.length,
                    itemBuilder: (context, index) {
                      final item = visible[index];
                      return ContentCard(
                        item: item,
                        onTap: () {
                          sl<AnalyticsService>().track(
                            'content_view',
                            metadata: {'content_id': item.id},
                          );
                          context.push(AppRoutePath.contentDetailFor(item.id));
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
