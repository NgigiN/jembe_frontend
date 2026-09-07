import 'package:farm_tracker/core/widgets/crud/entity_empty_view.dart';
import 'package:farm_tracker/core/widgets/crud/entity_error_view.dart';
import 'package:farm_tracker/core/widgets/feedback/app_snackbar.dart';
import 'package:farm_tracker/core/widgets/loading/skeleton_entity_list.dart';
import 'package:farm_tracker/features/farm/data/models/trash_item_model.dart'
    show trashEntities;
import 'package:farm_tracker/features/farm/domain/entities/trash_item.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/trash_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/trash_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/trash_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// "Recently deleted" — a pragmatic restore utility (Phase 8 B2), not 12
/// typed CRUD views: every soft-deleted row across the 12 restorable
/// entities (`GET /api/v1/trash`, A2), grouped by entity, each with a
/// Restore button (`POST /api/v1/<entity>/:id/restore`, A3).
///
/// **Online-only** — there is no offline mirror of the trash list or of a
/// restore action (`TrashRepositoryImpl` always talks straight to the
/// network; `DeletionsDataSource` hard-deletes the local mirror row on a
/// tombstone, so there's nothing local left to un-delete). Reached only
/// from Settings ("Recently deleted" tile) — a new top-level `GoRoute`
/// outside the `ShellRoute`.
class TrashPage extends StatefulWidget {
  const TrashPage({super.key});

  @override
  State<TrashPage> createState() => _TrashPageState();
}

class _TrashPageState extends State<TrashPage> {
  /// "`<entity>:<id>`" of the item currently being restored, or null. Guards
  /// a row's Restore button against a double-tap and drives its spinner;
  /// cleared whenever a fresh `TrashLoaded`/`TrashError` arrives — a
  /// restore's outcome always produces one of those.
  String? _restoringKey;

  @override
  void initState() {
    super.initState();
    final bloc = context.read<TrashBloc>();
    if (bloc.state is! TrashLoaded) {
      bloc.add(LoadTrashEvent());
    }
  }

  void _onRestore(TrashItem item) {
    if (_restoringKey != null) return;
    setState(() => _restoringKey = '${item.entity}:${item.id}');
    context.read<TrashBloc>().add(
      RestoreItemEvent(entity: item.entity, id: item.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recently Deleted')),
      body: BlocConsumer<TrashBloc, TrashState>(
        listener: (context, state) {
          if ((state is TrashLoaded || state is TrashError) &&
              _restoringKey != null) {
            setState(() => _restoringKey = null);
          }
          if (state is TrashLoaded && state.successMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              AppSnackBar.success(context, state.successMessage!),
            );
          } else if (state is TrashLoaded && state.conflictMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              AppSnackBar.error(context, state.conflictMessage!),
            );
          } else if (state is TrashError && state.items.isNotEmpty) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(AppSnackBar.error(context, state.message));
          }
        },
        builder: (context, state) {
          final isLoading = state is TrashLoading;

          // The skeleton only makes sense when there's nothing to show yet
          // (first load). Once we have items — from a prior TrashLoaded, or
          // carried through a refresh/error — keep rendering them instead
          // of blanking the screen.
          if (isLoading && state.items.isEmpty) {
            return const SkeletonEntityList(icon: Icons.delete_outline);
          }

          if (state is TrashError && state.items.isEmpty) {
            return _scrollableCenter(
              EntityErrorView(
                message: state.message,
                onRetry: () =>
                    context.read<TrashBloc>().add(LoadTrashEvent()),
              ),
            );
          }

          final grouped = state.groupedByEntity;

          if (grouped.isEmpty && !isLoading) {
            return _scrollableCenter(
              const EntityEmptyView(
                icon: Icons.delete_outline,
                title: 'Nothing in the trash',
                subtitle:
                    'Deleted lands, plants, animals and other records '
                    'show up here for 30 days before they are gone for '
                    'good.',
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              final bloc = context.read<TrashBloc>()..add(LoadTrashEvent());
              await bloc.stream.firstWhere(
                (s) => s is TrashLoaded || s is TrashError,
              );
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                for (final entity in trashEntities)
                  if (grouped[entity] != null)
                    _EntitySection(
                      entity: entity,
                      items: grouped[entity]!,
                      restoringKey: _restoringKey,
                      onRestore: _onRestore,
                    ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _scrollableCenter(Widget child) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: child,
        ),
      ),
    );
  }
}

class _EntitySection extends StatelessWidget {
  const _EntitySection({
    required this.entity,
    required this.items,
    required this.restoringKey,
    required this.onRestore,
  });

  final String entity;
  final List<TrashItem> items;
  final String? restoringKey;
  final ValueChanged<TrashItem> onRestore;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Text(
            _sectionTitle(entity),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Card(
          elevation: 1,
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                _TrashItemTile(
                  item: items[i],
                  isRestoring:
                      restoringKey == '${items[i].entity}:${items[i].id}',
                  onRestore: () => onRestore(items[i]),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

const _sectionTitles = {
  'land': 'Lands',
  'plant': 'Plants',
  'season': 'Seasons',
  'activity': 'Activities',
  'input': 'Inputs',
  'harvest': 'Harvests',
  'animal_type': 'Animal Types',
  'herd': 'Herds',
  'animal': 'Animals',
  'infrastructure': 'Infrastructure',
  'cost_category': 'Cost Categories',
  'revenue': 'Revenue',
};

String _sectionTitle(String entity) => _sectionTitles[entity] ?? entity;

class _TrashItemTile extends StatelessWidget {
  const _TrashItemTile({
    required this.item,
    required this.isRestoring,
    required this.onRestore,
  });

  final TrashItem item;
  final bool isRestoring;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(item.label),
      subtitle: item.deletedAt != null
          ? Text('Deleted ${_formatDate(item.deletedAt!)}')
          : null,
      trailing: isRestoring
          ? const SizedBox(
              width: 20,
              height: 20,
              child: Padding(
                padding: EdgeInsets.all(2),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          : TextButton.icon(
              onPressed: onRestore,
              icon: const Icon(Icons.restore, size: 18),
              label: const Text('Restore'),
            ),
    );
  }
}

String _formatDate(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
