import 'package:farm_tracker/features/feed/presentation/bloc/feed_bloc.dart';
import 'package:farm_tracker/features/feed/presentation/bloc/feed_event.dart';
import 'package:farm_tracker/features/feed/presentation/bloc/feed_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class FeedPage extends StatefulWidget {
  const FeedPage({super.key});
  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  @override
  void initState() {
    super.initState();
    context.read<FeedBloc>().add(LoadFeed());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Feed')),
      body: BlocBuilder<FeedBloc, FeedState>(
        builder: (context, state) {
          if (state is FeedLoading || state is FeedInitial) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is FeedError) {
            return Center(child: Text(state.message));
          }
          final loaded = state as FeedLoaded;
          return ListView.builder(
            itemCount: loaded.entries.length + (loaded.hasMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == loaded.entries.length) {
                context.read<FeedBloc>().add(LoadMoreFeed());
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final entry = loaded.entries[index];
              final loggedBy = entry.loggedByFirstName == null
                  ? 'Former member'
                  : '${entry.loggedByFirstName} ${entry.loggedByLastName}';
              return ListTile(
                title: Text(entry.summary),
                subtitle: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(loggedBy),
                    const Text(' · '),
                    Text('${entry.createdAt.toLocal()}'),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
