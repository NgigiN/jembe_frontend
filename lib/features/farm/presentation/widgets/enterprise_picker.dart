import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

enum EnterpriseKind { season, herd }

/// A season or a herd, represented uniformly so cost-reporting screens can
/// filter by "which enterprise" without caring which one it is.
class Enterprise extends Equatable {
  const Enterprise({
    required this.id,
    required this.kind,
    required this.name,
    required this.startDate,
    this.endDate,
  });

  final String id;
  final EnterpriseKind kind;
  final String name;
  final DateTime startDate;
  final DateTime? endDate;

  bool get isActive => endDate == null || endDate!.isAfter(DateTime.now());

  @override
  List<Object?> get props => [id, kind, name, startDate, endDate];
}

/// Tappable selector that opens a searchable, Active/Completed-grouped sheet
/// of [Enterprise] entries. `selected == null` means "All Active".
class EnterprisePicker extends StatelessWidget {
  const EnterprisePicker({
    required this.enterprises,
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final List<Enterprise> enterprises;
  final Enterprise? selected;
  final ValueChanged<Enterprise?> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _openSheet(context),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.filter_list),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                selected?.name ?? 'All Active Seasons/Herds',
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }

  void _openSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _EnterprisePickerSheet(
        enterprises: enterprises,
        selected: selected,
        onSelected: (enterprise) {
          onChanged(enterprise);
          Navigator.pop(sheetContext);
        },
      ),
    );
  }
}

class _EnterprisePickerSheet extends StatefulWidget {
  const _EnterprisePickerSheet({
    required this.enterprises,
    required this.selected,
    required this.onSelected,
  });

  final List<Enterprise> enterprises;
  final Enterprise? selected;
  final ValueChanged<Enterprise?> onSelected;

  @override
  State<_EnterprisePickerSheet> createState() =>
      _EnterprisePickerSheetState();
}

class _EnterprisePickerSheetState extends State<_EnterprisePickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final matches = query.isEmpty
        ? widget.enterprises
        : widget.enterprises
            .where((e) => e.name.toLowerCase().contains(query))
            .toList();
    final active = matches.where((e) => e.isActive).toList();
    final completed = matches.where((e) => !e.isActive).toList();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search seasons/herds...',
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: RadioGroup<String?>(
                groupValue: widget.selected?.id,
                onChanged: (value) {
                  final match = value == null
                      ? null
                      : widget.enterprises
                          .where((e) => e.id == value)
                          .firstOrNull;
                  widget.onSelected(match);
                },
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    const RadioListTile<String?>(
                      value: null,
                      title: Text('All Active'),
                    ),
                    if (active.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          'ACTIVE',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      for (final enterprise in active)
                        RadioListTile<String?>(
                          value: enterprise.id,
                          title: Text(enterprise.name),
                          subtitle: Text(
                            enterprise.kind == EnterpriseKind.season
                                ? 'Season'
                                : 'Herd',
                          ),
                        ),
                    ],
                    if (completed.isNotEmpty)
                      ExpansionTile(
                        title: Text('COMPLETED (${completed.length})'),
                        children: [
                          for (final enterprise in completed)
                            RadioListTile<String?>(
                              value: enterprise.id,
                              title: Text(enterprise.name),
                              subtitle: Text(
                                enterprise.kind == EnterpriseKind.season
                                    ? 'Season'
                                    : 'Herd',
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
