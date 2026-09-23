import 'package:farm_tracker/core/theme/app_typography.dart';
import 'package:farm_tracker/core/theme/console_colors.dart';
import 'package:farm_tracker/core/theme/console_metrics.dart';
import 'package:farm_tracker/core/utils/console_dates.dart';
import 'package:farm_tracker/features/auth/data/models/user_storage_model.dart';
import 'package:farm_tracker/features/auth/data/services/user_storage_service.dart';
import 'package:farm_tracker/features/farms/domain/entities/farm_role.dart';
import 'package:farm_tracker/features/farms/presentation/bloc/farm_bloc.dart';
import 'package:farm_tracker/features/farms/presentation/bloc/farm_state.dart';
import 'package:farm_tracker/features/feed/domain/entities/feed_entry.dart';
import 'package:farm_tracker/features/feed/presentation/bloc/feed_bloc.dart';
import 'package:farm_tracker/features/feed/presentation/bloc/feed_event.dart';
import 'package:farm_tracker/features/feed/presentation/bloc/feed_state.dart';
import 'package:farm_tracker/features/web_console/presentation/utils/csv_download.dart';
import 'package:farm_tracker/features/web_console/presentation/widgets/console_card.dart';
import 'package:farm_tracker/features/web_console/presentation/widgets/console_controls.dart';
import 'package:farm_tracker/features/web_console/presentation/widgets/console_empty.dart';
import 'package:farm_tracker/features/web_console/presentation/widgets/console_identity.dart';
import 'package:farm_tracker/features/web_console/presentation/widgets/console_page.dart';
import 'package:farm_tracker/features/web_console/presentation/widgets/console_skeleton.dart';
import 'package:farm_tracker/features/web_console/presentation/widgets/console_table.dart';
import 'package:farm_tracker/features/web_console/presentation/widgets/console_text.dart';
import 'package:farm_tracker/features/web_console/presentation/widgets/feed_entry_look.dart';
import 'package:farm_tracker/features/web_console/presentation/widgets/log_on_android_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The Feed (DESIGN_SPEC §4, screens 03 and 10): everything logged on the
/// farm, newest first, grouped by day.
///
/// Staff and workers get meaningfully different pages rather than the same
/// page with things greyed out (§5): a worker's has no amounts, no search,
/// a mine-or-everyone filter instead of type chips, and a rail of quick-log
/// shortcuts where staff get the full table width.
class FeedPage extends StatefulWidget {
  const FeedPage({super.key});

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  final _search = TextEditingController();
  late final Future<UserStorageModel?> _user = UserStorageService.getUserData();
  int _typeFilter = 0;
  String _person = FeedView.everyone;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    context.read<FeedBloc>().add(LoadFeed());
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final feed = context.watch<FeedBloc>().state;
    final farmState = context.watch<FarmBloc>().state;
    final role = farmState is FarmLoaded ? farmState.currentRole : null;

    return FutureBuilder<UserStorageModel?>(
      future: _user,
      builder: (context, snapshot) {
        return FeedView(
          farmName: _farmName(farmState),
          role: role,
          currentUserName: snapshot.data?.name ?? '',
          entries: feed is FeedLoaded ? feed.entries : null,
          hasMore: feed is FeedLoaded && feed.hasMore,
          errorMessage: feed is FeedError ? feed.message : null,
          typeFilterIndex: _typeFilter,
          person: _person,
          searchController: _search,
          page: _page,
          onTypeFilterChanged: (index) => setState(() {
            _typeFilter = index;
            _page = 0;
          }),
          onPersonChanged: (value) => setState(() {
            _person = value ?? FeedView.everyone;
            _page = 0;
          }),
          onSearchChanged: (_) => setState(() => _page = 0),
          onPageChanged: (page) => setState(() => _page = page),
          onLoadMore: () => context.read<FeedBloc>().add(LoadMoreFeed()),
          onRetry: () => context.read<FeedBloc>().add(LoadFeed()),
        );
      },
    );
  }

  String _farmName(FarmState state) {
    if (state is! FarmLoaded || state.currentFarmId == null) return 'Your farm';
    for (final farm in state.farms) {
      if (farm.id == state.currentFarmId) return farm.name;
    }
    return 'Your farm';
  }
}

/// The Feed's drawing, with no bloc in sight.
class FeedView extends StatelessWidget {
  const FeedView({
    required this.farmName,
    required this.entries,
    this.role,
    this.currentUserName = '',
    this.hasMore = false,
    this.errorMessage,
    this.typeFilterIndex = 0,
    this.person = everyone,
    this.searchController,
    this.page = 0,
    this.onTypeFilterChanged,
    this.onPersonChanged,
    this.onSearchChanged,
    this.onPageChanged,
    this.onLoadMore,
    this.onRetry,
    super.key,
  });

  static const everyone = 'Everyone';

  /// How many rows fill one page of the table.
  static const _pageSize = 12;

  final String farmName;
  final FarmRole? role;

  /// Who is signed in, so a worker's "Mine" filter has something to match.
  final String currentUserName;

  /// Null while loading.
  final List<FeedEntry>? entries;

  final bool hasMore;
  final String? errorMessage;
  final int typeFilterIndex;
  final String person;
  final TextEditingController? searchController;
  final int page;
  final ValueChanged<int>? onTypeFilterChanged;
  final ValueChanged<String?>? onPersonChanged;
  final ValueChanged<String>? onSearchChanged;
  final ValueChanged<int>? onPageChanged;
  final VoidCallback? onLoadMore;
  final VoidCallback? onRetry;

  static const _typeFilters = [
    'All',
    'Activities',
    'Harvests',
    'Inputs',
    'Revenue',
  ];
  static const _typeValues = [null, 'activity', 'harvest', 'input', 'revenue'];

  /// Workers do not see money (DESIGN_SPEC §5).
  bool get _isStaff => role == null || role!.isStaff;

  @override
  Widget build(BuildContext context) {
    if (errorMessage != null && entries == null) {
      return ConsoleErrorState(
        farmName: farmName,
        subtitle: 'Feed',
        detail: errorMessage!,
        onRetry: onRetry,
      );
    }

    final all = entries ?? const <FeedEntry>[];
    final filtered = _filter(all);

    return ConsolePage(
      title: 'Feed',
      subtitle: _isStaff
          ? 'Everything logged on $farmName, newest first'
          : '$farmName · what you and the team have logged',
      actions: [
        if (_isStaff)
          ConsoleButton.outlined(
            label: 'Export CSV',
            icon: Icons.download_outlined,
            onPressed: filtered.isEmpty ? null : () => _exportCsv(filtered),
          ),
        const LogOnAndroidButton(
          label: 'Log entry',
          variant: LogButton.filled,
          icon: Icons.add,
        ),
      ],
      // Staff get the full table width — the Feed is the one page whose
      // whole job is the table (screen 03). A worker's narrower table
      // leaves room for the quick-log rail (screen 10).
      rail: _isStaff ? null : _workerRail(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _toolbar(context, all),
          const SizedBox(height: 12),
          ConsoleCard(
            padding: const EdgeInsets.fromLTRB(6, 10, 6, 12),
            child: _table(context, filtered),
          ),
        ],
      ),
    );
  }

  Widget _toolbar(BuildContext context, List<FeedEntry> all) {
    if (!_isStaff) {
      // A worker filters by whose work it is, not by what kind it is.
      return Row(
        children: [
          ConsoleChips(
            labels: const [everyone, 'Mine'],
            selectedIndex: person == everyone ? 0 : 1,
            onSelected: (index) =>
                onPersonChanged?.call(index == 0 ? everyone : currentUserName),
          ),
        ],
      );
    }

    final people = {for (final entry in all) loggedByName(entry)}.toList()
      ..sort();

    return Row(
      children: [
        Expanded(
          child: ConsoleChips(
            labels: _typeFilters,
            selectedIndex: typeFilterIndex,
            onSelected: onTypeFilterChanged ?? (_) {},
          ),
        ),
        const SizedBox(width: 10),
        ConsoleSelect<String>(
          value: people.contains(person) ? person : everyone,
          items: [everyone, ...people],
          labelBuilder: (value) => value,
          icon: Icons.person_outline,
          onChanged: onPersonChanged ?? (_) {},
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 200,
          height: ConsoleMetrics.buttonHeight,
          child: TextField(
            controller: searchController,
            onChanged: onSearchChanged,
            style: AppTypography.bodyDense,
            decoration: InputDecoration(
              hintText: 'Search entries',
              prefixIcon: Icon(
                Icons.search,
                size: 18,
                color: context.console.muted,
              ),
              prefixIconConstraints: const BoxConstraints.tightFor(
                width: 32,
                height: 20,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _workerRail(BuildContext context) {
    return const ConsoleRail(
      children: [
        ConsoleCard(
          kicker: 'Quick log',
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _QuickLogTile(
                      label: 'Activity',
                      icon: Icons.grass_outlined,
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: _QuickLogTile(
                      label: 'Harvest',
                      icon: Icons.agriculture_outlined,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _QuickLogTile(
                      label: 'Herd activity',
                      icon: Icons.pets_outlined,
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: _QuickLogTile(
                      label: 'Input',
                      icon: Icons.inventory_2_outlined,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        _WorkerLockCard(),
      ],
    );
  }

  List<FeedEntry> _filter(List<FeedEntry> all) {
    final type = _isStaff ? _typeValues[typeFilterIndex] : null;
    final query = _isStaff
        ? (searchController?.text.trim().toLowerCase() ?? '')
        : '';
    return all.where((entry) {
      if (type != null && entry.entityType != type) return false;
      if (person != everyone && loggedByName(entry) != person) return false;
      if (query.isNotEmpty && !entry.summary.toLowerCase().contains(query)) {
        return false;
      }
      return true;
    }).toList();
  }

  Widget _table(BuildContext context, List<FeedEntry> filtered) {
    if (entries == null) return const SkeletonRows(count: 8);

    if (filtered.isEmpty) {
      return ConsoleEmptyBlock(
        icon: Icons.dynamic_feed_outlined,
        title: entries!.isEmpty ? 'Nothing logged yet' : 'No entries match',
        body: entries!.isEmpty
            ? 'Work logged on the Android app shows up here within seconds of '
                  'the phone syncing.'
            : 'Try a different filter or search.',
      );
    }

    // The feed API is cursor-paged, so there is no total to number pages
    // against. Pages are cut from what has been loaded, and stepping past
    // the last one asks the server for more — which is what keeps the
    // numbered pager from lying about how much there is.
    final pageCount = (filtered.length / _pageSize).ceil();
    final current = page.clamp(0, pageCount - 1);
    final rows = filtered.skip(current * _pageSize).take(_pageSize).toList();
    final now = DateTime.now();

    String? lastGroup;
    final tableRows = <ConsoleRow>[];
    for (final entry in rows) {
      final group = dayGroupLabel(entry.createdAt.toLocal(), now);
      if (group != lastGroup) {
        tableRows.add(ConsoleRow.group(group));
        lastGroup = group;
      }
      tableRows.add(_row(context, entry));
    }

    return ConsoleTable(
      columns: [
        const ConsoleColumn('Time', width: 72),
        const ConsoleColumn('Entry', flex: 5),
        const ConsoleColumn('Type', flex: 2),
        const ConsoleColumn('Detail', flex: 2),
        const ConsoleColumn('Logged by', flex: 3),
        if (_isStaff) const ConsoleColumn('Amount', flex: 2, alignEnd: true),
      ],
      rows: tableRows,
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ConsolePager(
            summary:
                '${rows.length} of ${filtered.length}${hasMore ? '+' : ''} '
                '${filtered.length == 1 ? 'entry' : 'entries'}',
            pageCount: hasMore ? pageCount + 1 : pageCount,
            currentPage: current,
            onPageChanged: (next) {
              if (next >= pageCount && hasMore) {
                onLoadMore?.call();
                return;
              }
              onPageChanged?.call(next);
            },
          ),
          if (!_isStaff) ...[
            const SizedBox(height: 10),
            Text(
              'Amounts on inputs and sales are shown to owners and managers '
              'only.',
              style: AppTypography.meta.copyWith(color: context.console.muted),
            ),
          ],
        ],
      ),
    );
  }

  ConsoleRow _row(BuildContext context, FeedEntry entry) {
    final look = lookOf(entry.entityType);
    final name = loggedByName(entry);
    final console = context.console;

    // The feed endpoint carries entity type, summary, who and when — not
    // the amount or the per-entry detail the mockups show. Rather than
    // invent either, both cells say "n/a" the way §3 prescribes, except a
    // worker's Detail, which reads "Hidden" where money would have been.
    final hiddenForWorker =
        !_isStaff &&
        (entry.entityType == 'input' || entry.entityType == 'revenue');

    return ConsoleRow([
      Text(
        formatTime(entry.createdAt.toLocal()),
        style: AppTypography.cell.copyWith(color: console.muted),
      ),
      EntryCell(icon: look.icon, label: entry.summary, category: look.category),
      Text(
        look.type,
        style: AppTypography.cell.copyWith(color: console.onSurface2),
      ),
      Text(
        hiddenForWorker ? 'Hidden' : '—',
        style: AppTypography.cell.copyWith(color: console.muted),
      ),
      LoggedByCell(name, avatar: InitialsAvatar(name)),
      if (_isStaff) const MoneyText.none(),
    ]);
  }

  void _exportCsv(List<FeedEntry> rows) {
    final buffer = StringBuffer('Date,Time,Type,Entry,Logged by\n');
    for (final entry in rows) {
      final local = entry.createdAt.toLocal();
      buffer.writeln(
        [
          formatDayMonth(local),
          formatTime(local),
          lookOf(entry.entityType).type,
          _csvField(entry.summary),
          _csvField(loggedByName(entry)),
        ].join(','),
      );
    }
    downloadCsv('${farmName.toLowerCase()}-feed.csv', buffer.toString());
  }

  static String _csvField(String value) =>
      value.contains(',') || value.contains('"')
      ? '"${value.replaceAll('"', '""')}"'
      : value;
}

/// One of the worker rail's four shortcuts (DESIGN_SPEC §4, screen 10).
class _QuickLogTile extends StatelessWidget {
  const _QuickLogTile({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final console = context.console;
    return Material(
      color: console.surfaceLow,
      borderRadius: BorderRadius.circular(ConsoleMetrics.radiusTile),
      child: InkWell(
        onTap: () => showLogOnAndroidDialog(context),
        borderRadius: BorderRadius.circular(ConsoleMetrics.radiusTile),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 14),
              Text(
                label,
                style: AppTypography.bodyDense.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkerLockCard extends StatelessWidget {
  const _WorkerLockCard();

  @override
  Widget build(BuildContext context) {
    final console = context.console;
    return ConsoleCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_outline, size: 20, color: console.muted),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "You're a worker here",
                  style: AppTypography.bodyDense.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Reports and totals are for owners and managers. Ask the '
                  'farm owner if you need access.',
                  style: AppTypography.meta.copyWith(
                    color: console.muted,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
