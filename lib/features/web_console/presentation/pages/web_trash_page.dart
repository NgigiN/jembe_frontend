import 'package:farm_tracker/core/theme/app_typography.dart';
import 'package:farm_tracker/core/theme/console_colors.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/trash_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/trash_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/trash_state.dart';
import 'package:farm_tracker/features/web_console/presentation/widgets/console_card.dart';
import 'package:farm_tracker/features/web_console/presentation/widgets/console_page.dart';
import 'package:farm_tracker/features/web_console/presentation/widgets/console_skeleton.dart';
import 'package:farm_tracker/features/web_console/presentation/widgets/console_table.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Deleted records, grouped by what they are, with a Restore on each row.
///
/// It reuses the mobile [TrashBloc] unchanged — the trash feature was
/// already live-HTTP only, so nothing about it needed splitting for web.
class WebTrashPage extends StatefulWidget {
  const WebTrashPage({super.key});

  @override
  State<WebTrashPage> createState() => _WebTrashPageState();
}

class _WebTrashPageState extends State<WebTrashPage> {
  @override
  void initState() {
    super.initState();
    context.read<TrashBloc>().add(LoadTrashEvent());
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<TrashBloc, TrashState>(
      listenWhen: (_, state) =>
          state is TrashLoaded &&
          (state.successMessage != null || state.conflictMessage != null),
      listener: (context, state) {
        if (state is! TrashLoaded) return;
        final message = state.successMessage ?? state.conflictMessage;
        if (message == null) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
      },
      builder: (context, state) {
        return ConsolePage(
          title: 'Trash',
          subtitle: 'Records you deleted. Restoring one puts it back where '
              'it was.',
          rail: ConsoleRail(
            children: [
              ConsoleCard(
                kicker: 'About the trash',
                color: context.console.surfaceLow,
                child: Text(
                  'Deleting a record on Android or here moves it to the '
                  'trash rather than removing it. Restoring brings back the '
                  'record and anything that hung off it.',
                  style: AppTypography.bodyDense.copyWith(
                    color: context.console.onSurface2,
                  ),
                ),
              ),
            ],
          ),
          child: ConsoleCard(
            padding: const EdgeInsets.fromLTRB(6, 10, 6, 10),
            child: _body(context, state),
          ),
        );
      },
    );
  }

  Widget _body(BuildContext context, TrashState state) {
    if (state is TrashLoading && state.items.isEmpty) {
      return const SkeletonRows(count: 5);
    }
    if (state is TrashError && state.items.isEmpty) {
      return _Message(
        icon: Icons.cloud_off,
        title: "Couldn't load the trash",
        body: state.message,
        onRetry: () => context.read<TrashBloc>().add(LoadTrashEvent()),
      );
    }
    if (state.items.isEmpty) {
      return const _Message(
        icon: Icons.delete_outline,
        title: 'Nothing in the trash',
        body: 'Deleted records show up here so you can put them back.',
      );
    }

    final grouped = state.groupedByEntity;
    return ConsoleTable(
      columns: const [
        ConsoleColumn('Record', flex: 4),
        ConsoleColumn('Deleted', flex: 2, dropBelow: 560),
        ConsoleColumn('', width: 110, alignEnd: true),
      ],
      rows: [
        for (final entry in grouped.entries) ...[
          ConsoleRow.group(_entityLabel(entry.key)),
          for (final item in entry.value)
            ConsoleRow([
              EntryCell(icon: Icons.history, label: item.label),
              Text(
                item.deletedAt == null
                    ? '—'
                    : _formatDate(item.deletedAt!),
                style: AppTypography.cell.copyWith(
                  color: context.console.muted,
                ),
              ),
              OutlinedButton(
                onPressed: () => context.read<TrashBloc>().add(
                  RestoreItemEvent(entity: item.entity, id: item.id),
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 31),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                child: const Text('Restore'),
              ),
            ]),
        ],
      ],
    );
  }
}

/// `land` → "Lands". The trash groups by the backend's snake_case entity
/// key; this is the only place the console has to say them out loud.
String _entityLabel(String entity) {
  const labels = {
    'land': 'Lands',
    'plant': 'Plants',
    'season': 'Seasons',
    'activity': 'Activities',
    'input': 'Inputs',
    'harvest': 'Harvests',
    'animal_type': 'Animal types',
    'herd': 'Herds',
    'animal': 'Animals',
    'infrastructure': 'Infrastructure',
    'cost_category': 'Cost categories',
    'revenue': 'Revenue',
  };
  return labels[entity] ?? entity.replaceAll('_', ' ');
}

String _formatDate(DateTime date) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${date.day} ${months[date.month - 1]}';
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    required this.body,
    this.onRetry,
  });

  final IconData icon;
  final String title;
  final String body;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final console = context.console;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 44, horizontal: 20),
      child: Column(
        children: [
          Icon(icon, size: 30, color: console.muted),
          const SizedBox(height: 12),
          Text(title, style: AppTypography.cardTitle),
          const SizedBox(height: 6),
          Text(
            body,
            textAlign: TextAlign.center,
            style: AppTypography.bodyDense.copyWith(color: console.muted),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            ConsoleButton.outlined(label: 'Try again', onPressed: onRetry),
          ],
        ],
      ),
    );
  }
}
