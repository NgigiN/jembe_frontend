import 'package:farm_tracker/core/theme/app_typography.dart';
import 'package:farm_tracker/core/theme/console_colors.dart';
import 'package:farm_tracker/core/theme/console_metrics.dart';
import 'package:farm_tracker/core/utils/kes.dart';
import 'package:farm_tracker/features/farm/domain/entities/season.dart';
import 'package:farm_tracker/features/web_console/data/console_log_service.dart';
import 'package:farm_tracker/features/web_console/presentation/widgets/console_form.dart';
import 'package:farm_tracker/features/web_console/presentation/widgets/console_page.dart';
import 'package:farm_tracker/features/web_console/presentation/widgets/console_skeleton.dart';
import 'package:flutter/material.dart';

/// What is being logged. Each kind is a different shape of form, not a
/// flag on one shared one — a sale has a unit price and a harvest has a
/// unit, and pretending otherwise makes every field optional.
enum LogEntryKind {
  activity,
  input,
  revenue,
  harvest,
  herdActivity,
  land,
  plant,
  animalType,
  season,
  herd;

  String get title => switch (this) {
    LogEntryKind.activity => 'Log an activity',
    LogEntryKind.input => 'Log an input',
    LogEntryKind.revenue => 'Log a sale',
    LogEntryKind.harvest => 'Log a harvest',
    LogEntryKind.herdActivity => 'Log a herd event',
    LogEntryKind.land => 'Add a plot',
    LogEntryKind.plant => 'Add a crop',
    LogEntryKind.animalType => 'Add an animal type',
    LogEntryKind.season => 'Start a season',
    LogEntryKind.herd => 'Add a herd',
  };

  String get submitLabel => switch (this) {
    LogEntryKind.activity => 'Log activity',
    LogEntryKind.input => 'Log input',
    LogEntryKind.revenue => 'Log sale',
    LogEntryKind.harvest => 'Log harvest',
    LogEntryKind.herdActivity => 'Log event',
    LogEntryKind.land => 'Add plot',
    LogEntryKind.plant => 'Add crop',
    LogEntryKind.animalType => 'Add type',
    LogEntryKind.season => 'Start season',
    LogEntryKind.herd => 'Add herd',
  };

  String get blurb => switch (this) {
    LogEntryKind.activity =>
      'Work done on a season or a herd — weeding, spraying, vaccination.',
    LogEntryKind.input =>
      'Something bought and applied — fertiliser, feed, veterinary supplies.',
    LogEntryKind.revenue => 'A sale: what went out, and what it brought in.',
    LogEntryKind.harvest => 'What came off a season, and how much of it.',
    LogEntryKind.herdActivity => 'A birth or a loss in one of your herds.',
    LogEntryKind.land =>
      'A field or paddock. Seasons and herds are set up against it.',
    LogEntryKind.plant => 'Something you grow. A season plants one of these.',
    LogEntryKind.animalType => 'A kind of animal. A herd is made of one.',
    LogEntryKind.season =>
      'One crop on one plot, over a stretch of time. Work and inputs are '
          'logged against it.',
    LogEntryKind.herd => 'A group of animals kept together.',
  };

  /// Whether the user picks between a season and a herd. A harvest is
  /// always a season's and a herd event is always a herd's; the other
  /// three can be either.
  bool get choosesSource =>
      this == LogEntryKind.activity ||
      this == LogEntryKind.input ||
      this == LogEntryKind.revenue;

  /// The setup records stand on their own; only the logging kinds are
  /// recorded against a season or a herd.
  bool get needsSource => switch (this) {
    LogEntryKind.land ||
    LogEntryKind.plant ||
    LogEntryKind.animalType ||
    LogEntryKind.season ||
    LogEntryKind.herd => false,
    _ => true,
  };
}

/// Opens the log form for [kind]. Resolves to true when something was
/// created, so the caller can refresh what it is showing.
Future<bool?> showLogEntryDialog(
  BuildContext context, {
  required LogEntryKind kind,
  required LogWriter service,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => LogEntryDialog(kind: kind, service: service),
  );
}

/// The console's write form (one per [LogEntryKind]).
class LogEntryDialog extends StatefulWidget {
  const LogEntryDialog({required this.kind, required this.service, super.key});

  final LogEntryKind kind;
  final LogWriter service;

  @override
  State<LogEntryDialog> createState() => _LogEntryDialogState();
}

class _LogEntryDialogState extends State<LogEntryDialog> {
  final _formKey = GlobalKey<FormState>();
  final _type = TextEditingController();
  final _cost = TextEditingController();
  final _quantity = TextEditingController();
  final _unitPrice = TextEditingController();
  // 'kg' suits the harvest form, which is the only kind that arrives with
  // a sensible default unit; the plot form reuses this controller for soil
  // and clears it.
  late final _unit = TextEditingController(
    text: widget.kind == LogEntryKind.harvest ? 'kg' : '',
  );
  final _count = TextEditingController();
  final _details = TextEditingController();
  final _notes = TextEditingController();

  late Future<LogReference> _reference = widget.service.reference();

  /// 'plant' (a season) or 'animal' (a herd). A herd event is only ever a
  /// herd's; everything else starts on the plant side and may be switched.
  late String _source = widget.kind == LogEntryKind.herdActivity
      ? 'animal'
      : 'plant';
  String? _sourceId;

  /// Set once the user picks a side themselves, so the fallback above
  /// never overrides a deliberate choice.
  bool _sourceTouched = false;
  String _herdEvent = 'birth';
  String _tenure = 'owned';
  String? _plantId;
  String? _landId;
  String? _animalTypeId;
  DateTime? _endDate;
  DateTime _date = DateTime.now();
  bool _submitting = false;
  String? _failure;

  @override
  void dispose() {
    for (final controller in [
      _type,
      _cost,
      _quantity,
      _unitPrice,
      _unit,
      _count,
      _details,
      _notes,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final console = context.console;

    return AlertDialog(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.kind.title, style: AppTypography.cardTitle),
          const SizedBox(height: 4),
          Text(
            widget.kind.blurb,
            // Explicit weight: the dialog's titleTextStyle would otherwise
            // make this inherit the heading's 600.
            style: AppTypography.meta.copyWith(
              color: console.muted,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
      titleTextStyle: AppTypography.cardTitle.copyWith(
        color: Theme.of(context).colorScheme.onSurface,
      ),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      content: SizedBox(
        width: 460,
        child: FutureBuilder<LogReference>(
          future: _reference,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const _FormSkeleton();
            }
            if (snapshot.hasError) {
              return _Problem(
                text: "Couldn't load this farm's seasons and herds.",
                actionLabel: 'Try again',
                onAction: () => setState(() {
                  widget.service.invalidateReference();
                  // ignore() marks the error handled for the zone. The
                  // rebuild that attaches the FutureBuilder is a frame
                  // away, and a retry that fails in the gap would
                  // otherwise be reported as an unhandled async error;
                  // the builder still receives it and shows this block
                  // again.
                  _reference = widget.service.reference()..ignore();
                }),
              );
            }
            return _form(context, snapshot.data ?? const LogReference.empty());
          },
        ),
      ),
      actions: [
        ConsoleButton.outlined(
          label: 'Cancel',
          onPressed: _submitting ? null : () => Navigator.pop(context, false),
        ),
        FutureBuilder<LogReference>(
          future: _reference,
          builder: (context, snapshot) {
            final ready =
                snapshot.connectionState == ConnectionState.done &&
                !snapshot.hasError &&
                _blockedReason(snapshot.data ?? const LogReference.empty()) ==
                    null;
            return ConsoleButton.filled(
              label: _submitting ? 'Saving…' : widget.kind.submitLabel,
              onPressed: !ready || _submitting ? null : _submit,
            );
          },
        ),
      ],
    );
  }

  /// Why this form cannot be filled in yet, or null when it can.
  ///
  /// Both the body and the submit button read this, so a disabled button
  /// and the explanation above it can never disagree.
  String? _blockedReason(LogReference reference) {
    switch (widget.kind) {
      case LogEntryKind.season:
        if (reference.plants.isEmpty && reference.lands.isEmpty) {
          return 'A season is one crop on one plot, so it needs both first. '
              'Add a plot and a crop, then come back.';
        }
        if (reference.lands.isEmpty) return 'Add a plot first.';
        if (reference.plants.isEmpty) return 'Add a crop first.';
        return null;
      case LogEntryKind.herd:
        if (reference.animalTypes.isEmpty) {
          return 'Add an animal type first — a herd is made of one.';
        }
        return null;
      case LogEntryKind.land:
      case LogEntryKind.plant:
      case LogEntryKind.animalType:
        return null;
      case LogEntryKind.activity:
      case LogEntryKind.input:
      case LogEntryKind.revenue:
      case LogEntryKind.harvest:
      case LogEntryKind.herdActivity:
        final has = _source == 'plant'
            ? reference.hasPlantSource
            : reference.hasAnimalSource;
        if (has) return null;
        return _source == 'plant'
            ? 'Start a season first, then this form has something to log '
                  'against.'
            : 'Add a herd first, then this form has something to log '
                  'against.';
    }
  }

  Widget _form(BuildContext context, LogReference reference) {
    // A farm that keeps only animals should land on the herd form rather
    // than being told to start a season it will never have. Assigned here
    // rather than in a setState because the value is used by this same
    // build, and the reference it depends on only just arrived.
    if (widget.kind.choosesSource &&
        !_sourceTouched &&
        _source == 'plant' &&
        !reference.hasPlantSource &&
        reference.hasAnimalSource) {
      _source = 'animal';
    }

    // Say which thing is missing rather than showing a form whose first
    // field has no options.
    final blocked = _blockedReason(reference);
    if (blocked != null) return _Problem(text: blocked);

    final kind = widget.kind;
    // The picker's options and the held selection have to come from the
    // same side, or the dropdown is handed a value it has no item for.
    final sources = _source == 'plant'
        ? [for (final season in reference.seasons) season.id]
        : [for (final herd in reference.herds) herd.id];
    if (_sourceId == null || !sources.contains(_sourceId)) {
      _sourceId = sources.isEmpty ? null : sources.first;
    }

    return SingleChildScrollView(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (kind.choosesSource &&
                reference.hasPlantSource &&
                reference.hasAnimalSource) ...[
              ConsoleField(
                label: 'Logged against',
                child: ConsoleSegment<String>(
                  value: _source,
                  options: const [('plant', 'A season'), ('animal', 'A herd')],
                  onChanged: (value) => setState(() {
                    _source = value;
                    _sourceTouched = true;
                    _sourceId = null;
                  }),
                ),
              ),
              const SizedBox(height: 14),
            ],
            if (kind.needsSource) ...[
              _sourcePicker(reference),
              const SizedBox(height: 14),
            ],
            ..._kindFields(reference),
            if (kind.needsSource)
              ConsoleField(
                label: 'Notes',
                child: ConsoleTextField(
                  controller: _notes,
                  maxLines: 2,
                  hintText: 'Anything worth remembering (optional)',
                ),
              ),
            if (_failure != null) ...[
              const SizedBox(height: 14),
              _Problem(text: _failure!),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _sourcePicker(LogReference reference) {
    if (_source == 'plant') {
      return ConsoleField(
        label: 'Season',
        child: ConsoleFormDropdown<String>(
          value: _sourceId,
          items: [for (final season in reference.seasons) season.id],
          labelBuilder: (id) => _seasonLabel(reference, id),
          hintText: 'Pick a season',
          validator: (value) => value == null ? 'Pick a season.' : null,
          onChanged: (value) => setState(() => _sourceId = value),
        ),
      );
    }
    return ConsoleField(
      label: 'Herd',
      child: ConsoleFormDropdown<String>(
        value: _sourceId,
        items: [for (final herd in reference.herds) herd.id],
        labelBuilder: (id) => _herdLabel(reference, id),
        hintText: 'Pick a herd',
        validator: (value) => value == null ? 'Pick a herd.' : null,
        onChanged: (value) => setState(() => _sourceId = value),
      ),
    );
  }

  List<Widget> _kindFields(LogReference reference) {
    final dateField = ConsoleField(
      label: 'Date',
      child: ConsoleDateField(
        value: _date,
        onChanged: (value) => setState(() => _date = value),
      ),
    );

    switch (widget.kind) {
      case LogEntryKind.activity:
        return [
          ConsoleFieldRow(
            left: ConsoleField(
              label: 'Activity type',
              child: ConsoleSuggestField(
                controller: _type,
                suggestions: reference.typesFor(
                  category: 'activity',
                  source: _source,
                ),
                hintText: 'Weeding, spraying…',
                validator: (value) => requiredText(value, 'activity type'),
              ),
            ),
            right: dateField,
          ),
          const SizedBox(height: 14),
          ConsoleFieldRow(
            left: ConsoleField(
              label: 'Cost (KES)',
              child: ConsoleTextField.number(
                controller: _cost,
                hintText: '0',
                validator: (value) => requiredAmount(value, 'cost'),
              ),
            ),
            right: ConsoleField(
              label: 'Details',
              child: ConsoleTextField(
                controller: _details,
                hintText: '3 hrs, 2 workers (optional)',
              ),
            ),
          ),
          const SizedBox(height: 14),
        ];

      case LogEntryKind.input:
        return [
          ConsoleFieldRow(
            left: ConsoleField(
              label: 'Input type',
              child: ConsoleSuggestField(
                controller: _type,
                suggestions: reference.typesFor(
                  category: 'input',
                  source: _source,
                ),
                hintText: 'Fertiliser, feed…',
                validator: (value) => requiredText(value, 'input type'),
              ),
            ),
            right: dateField,
          ),
          const SizedBox(height: 14),
          ConsoleFieldRow(
            left: ConsoleField(
              label: 'Quantity',
              child: ConsoleTextField.number(
                controller: _quantity,
                hintText: '50 (optional)',
              ),
            ),
            right: ConsoleField(
              label: 'Cost (KES)',
              child: ConsoleTextField.number(
                controller: _cost,
                hintText: '0',
                validator: (value) => requiredAmount(value, 'cost'),
              ),
            ),
          ),
          const SizedBox(height: 14),
        ];

      case LogEntryKind.revenue:
        return [
          ConsoleFieldRow(
            left: ConsoleField(
              label: 'What was sold',
              child: ConsoleTextField(
                controller: _type,
                hintText: 'Milk, maize…',
                validator: (value) => requiredText(value, 'item sold'),
              ),
            ),
            right: dateField,
          ),
          const SizedBox(height: 14),
          ConsoleFieldRow(
            left: ConsoleField(
              label: 'Quantity',
              child: ConsoleTextField.number(
                controller: _quantity,
                hintText: '0',
                onChanged: (_) => setState(() {}),
                validator: (value) => requiredAmount(value, 'quantity'),
              ),
            ),
            right: ConsoleField(
              label: 'Unit price (KES)',
              child: ConsoleTextField.number(
                controller: _unitPrice,
                hintText: '0',
                onChanged: (_) => setState(() {}),
                validator: (value) => requiredAmount(value, 'unit price'),
              ),
            ),
          ),
          const SizedBox(height: 14),
          _TotalPreview(
            quantity: double.tryParse(_quantity.text.trim()) ?? 0,
            unitPrice: double.tryParse(_unitPrice.text.trim()) ?? 0,
          ),
          const SizedBox(height: 14),
        ];

      case LogEntryKind.harvest:
        return [
          ConsoleFieldRow(
            left: ConsoleField(
              label: 'Quantity',
              child: ConsoleTextField.number(
                controller: _quantity,
                hintText: '0',
                validator: (value) => requiredAmount(value, 'quantity'),
              ),
            ),
            right: ConsoleField(
              label: 'Unit',
              child: ConsoleTextField(
                controller: _unit,
                hintText: 'kg, bags, litres',
                validator: (value) => requiredText(value, 'unit'),
              ),
            ),
          ),
          const SizedBox(height: 14),
          dateField,
          const SizedBox(height: 14),
        ];

      case LogEntryKind.land:
        return [
          ConsoleField(
            label: 'Plot name',
            child: ConsoleTextField(
              controller: _type,
              autofocus: true,
              hintText: 'West Plot',
              validator: (value) => requiredText(value, 'plot name'),
            ),
          ),
          const SizedBox(height: 14),
          ConsoleFieldRow(
            left: ConsoleField(
              label: 'Size (hectares)',
              child: ConsoleTextField.number(
                controller: _quantity,
                hintText: '1.2 (optional)',
              ),
            ),
            right: ConsoleField(
              label: 'Where it is',
              child: ConsoleTextField(
                controller: _details,
                hintText: 'Nakuru (optional)',
              ),
            ),
          ),
          const SizedBox(height: 14),
          ConsoleFieldRow(
            left: ConsoleField(
              label: 'Soil',
              child: ConsoleTextField(
                controller: _unit,
                hintText: 'Loam (optional)',
              ),
            ),
            right: ConsoleField(
              label: 'Tenure',
              child: ConsoleSegment<String>(
                value: _tenure,
                options: const [('owned', 'Owned'), ('rented', 'Rented')],
                onChanged: (value) => setState(() => _tenure = value),
              ),
            ),
          ),
          const SizedBox(height: 14),
        ];

      case LogEntryKind.plant:
        return [
          ConsoleFieldRow(
            left: ConsoleField(
              label: 'Crop',
              child: ConsoleTextField(
                controller: _type,
                autofocus: true,
                hintText: 'Maize',
                validator: (value) => requiredText(value, 'crop name'),
              ),
            ),
            right: ConsoleField(
              label: 'Variety',
              child: ConsoleTextField(
                controller: _details,
                hintText: 'H614 (optional)',
              ),
            ),
          ),
          const SizedBox(height: 14),
        ];

      case LogEntryKind.animalType:
        return [
          ConsoleField(
            label: 'Animal type',
            child: ConsoleTextField(
              controller: _type,
              autofocus: true,
              hintText: 'Dairy cow, broiler',
              validator: (value) => requiredText(value, 'animal type'),
            ),
          ),
          const SizedBox(height: 14),
          ConsoleField(
            label: 'Notes',
            child: ConsoleTextField(
              controller: _details,
              hintText: 'Anything worth remembering (optional)',
            ),
          ),
          const SizedBox(height: 14),
        ];

      case LogEntryKind.season:
        return [
          ConsoleField(
            label: 'Season name',
            child: ConsoleTextField(
              controller: _type,
              autofocus: true,
              hintText: 'Long rains 2026',
              validator: (value) => requiredText(value, 'season name'),
            ),
          ),
          const SizedBox(height: 14),
          ConsoleFieldRow(
            left: ConsoleField(
              label: 'Crop',
              child: ConsoleFormDropdown<String>(
                value: _plantId,
                items: [for (final plant in reference.plants) plant.id],
                labelBuilder: (id) =>
                    reference.plants
                        .where((p) => p.id == id)
                        .firstOrNull
                        ?.name ??
                    'Unknown crop',
                hintText: 'Pick a crop',
                validator: (value) => value == null ? 'Pick a crop.' : null,
                onChanged: (value) => setState(() => _plantId = value),
              ),
            ),
            right: ConsoleField(
              label: 'Plot',
              child: ConsoleFormDropdown<String>(
                value: _landId,
                items: [for (final land in reference.lands) land.id],
                labelBuilder: (id) =>
                    reference.lands.where((l) => l.id == id).firstOrNull?.name ??
                    'Unknown plot',
                hintText: 'Pick a plot',
                validator: (value) => value == null ? 'Pick a plot.' : null,
                onChanged: (value) => setState(() => _landId = value),
              ),
            ),
          ),
          const SizedBox(height: 14),
          ConsoleFieldRow(
            left: ConsoleField(
              label: 'Starts',
              child: ConsoleDateField(
                value: _date,
                // A season can be planned ahead, unlike a logged entry.
                lastDate: DateTime.now().add(const Duration(days: 730)),
                onChanged: (value) => setState(() => _date = value),
              ),
            ),
            right: ConsoleField(
              label: 'Ends',
              hint: _endDate == null ? 'Leave it open if you do not know' : null,
              child: _endDate == null
                  ? ConsoleButton.outlined(
                      label: 'Set an end date',
                      onPressed: () => setState(
                        () => _endDate = _date.add(const Duration(days: 180)),
                      ),
                    )
                  : ConsoleDateField(
                      value: _endDate!,
                      firstDate: _date,
                      lastDate: DateTime.now().add(const Duration(days: 1095)),
                      onChanged: (value) => setState(() => _endDate = value),
                    ),
            ),
          ),
          const SizedBox(height: 14),
        ];

      case LogEntryKind.herd:
        return [
          ConsoleFieldRow(
            left: ConsoleField(
              label: 'Herd name',
              child: ConsoleTextField(
                controller: _type,
                autofocus: true,
                hintText: 'Dairy cows',
                validator: (value) => requiredText(value, 'herd name'),
              ),
            ),
            right: ConsoleField(
              label: 'Animal type',
              child: ConsoleFormDropdown<String>(
                value: _animalTypeId,
                items: [for (final type in reference.animalTypes) type.id],
                labelBuilder: (id) =>
                    reference.animalTypes
                        .where((t) => t.id == id)
                        .firstOrNull
                        ?.name ??
                    'Unknown type',
                hintText: 'Pick a type',
                validator: (value) =>
                    value == null ? 'Pick an animal type.' : null,
                onChanged: (value) => setState(() => _animalTypeId = value),
              ),
            ),
          ),
          const SizedBox(height: 14),
          ConsoleFieldRow(
            left: ConsoleField(
              label: 'Where it is kept',
              child: ConsoleTextField(
                controller: _details,
                hintText: 'Home paddock',
                validator: (value) => requiredText(value, 'location'),
              ),
            ),
            right: ConsoleField(
              label: 'How many animals',
              child: ConsoleTextField.number(
                controller: _count,
                hintText: '6',
                validator: (value) => requiredCount(value, 'head count'),
              ),
            ),
          ),
          const SizedBox(height: 14),
          ConsoleField(
            label: 'Kept since',
            child: ConsoleDateField(
              value: _date,
              onChanged: (value) => setState(() => _date = value),
            ),
          ),
          const SizedBox(height: 14),
        ];

      case LogEntryKind.herdActivity:
        return [
          ConsoleField(
            label: 'What happened',
            child: ConsoleSegment<String>(
              value: _herdEvent,
              options: const [('birth', 'A birth'), ('fatality', 'A loss')],
              onChanged: (value) => setState(() => _herdEvent = value),
            ),
          ),
          const SizedBox(height: 14),
          ConsoleFieldRow(
            left: ConsoleField(
              label: 'How many',
              child: ConsoleTextField.number(
                controller: _count,
                hintText: '1',
                validator: (value) => requiredCount(value, 'number'),
              ),
            ),
            right: dateField,
          ),
          const SizedBox(height: 14),
        ];
    }
  }

  String _seasonLabel(LogReference reference, String id) {
    final season = reference.seasons.firstWhere(
      (s) => s.id == id,
      orElse: () => _missingSeason,
    );
    final land = reference.lands.where((l) => l.id == season.landId).firstOrNull;
    return land == null ? season.name : '${season.name} — ${land.name}';
  }

  String _herdLabel(LogReference reference, String id) {
    final herd = reference.herds.where((h) => h.id == id).firstOrNull;
    if (herd == null) return 'Unknown herd';
    return herd.location.isEmpty
        ? herd.name
        : '${herd.name} (${herd.location})';
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    // A plot is logged against nothing, so a null selection is only a
    // problem for the kinds that need one.
    final sourceId = _sourceId;
    if (widget.kind.needsSource && sourceId == null) return;

    setState(() {
      _submitting = true;
      _failure = null;
    });

    final notes = _notes.text.trim().isEmpty ? null : _notes.text.trim();

    try {
      switch (widget.kind) {
        case LogEntryKind.activity:
          await widget.service.addActivity(
            sourceType: _source,
            sourceId: sourceId!,
            type: _type.text.trim(),
            cost: double.parse(_cost.text.trim()),
            date: _date,
            details: _details.text.trim().isEmpty ? null : _details.text.trim(),
            notes: notes,
          );
        case LogEntryKind.input:
          await widget.service.addInput(
            sourceType: _source,
            sourceId: sourceId!,
            type: _type.text.trim(),
            cost: double.parse(_cost.text.trim()),
            date: _date,
            quantity: double.tryParse(_quantity.text.trim()),
            notes: notes,
          );
        case LogEntryKind.revenue:
          await widget.service.addRevenue(
            source: _source,
            sourceId: sourceId!,
            type: _type.text.trim(),
            quantity: double.parse(_quantity.text.trim()),
            unitPrice: double.parse(_unitPrice.text.trim()),
            date: _date,
            notes: notes,
          );
        case LogEntryKind.harvest:
          await widget.service.addHarvest(
            seasonId: sourceId!,
            quantity: double.parse(_quantity.text.trim()),
            unit: _unit.text.trim(),
            date: _date,
            notes: notes,
          );
        case LogEntryKind.land:
          await widget.service.addLand(
            name: _type.text.trim(),
            size: double.tryParse(_quantity.text.trim()),
            location: _details.text.trim().isEmpty
                ? null
                : _details.text.trim(),
            soilType: _unit.text.trim().isEmpty ? null : _unit.text.trim(),
            tenureType: _tenure,
          );
        case LogEntryKind.plant:
          await widget.service.addPlant(
            name: _type.text.trim(),
            variety: _details.text.trim().isEmpty ? null : _details.text.trim(),
          );
        case LogEntryKind.animalType:
          await widget.service.addAnimalType(
            name: _type.text.trim(),
            notes: _details.text.trim().isEmpty ? null : _details.text.trim(),
          );
        case LogEntryKind.season:
          await widget.service.addSeason(
            name: _type.text.trim(),
            plantId: _plantId!,
            landId: _landId!,
            startDate: _date,
            endDate: _endDate,
          );
        case LogEntryKind.herd:
          await widget.service.addHerd(
            name: _type.text.trim(),
            animalTypeId: _animalTypeId!,
            location: _details.text.trim(),
            initialHeadCount: int.parse(_count.text.trim()),
            startDate: _date,
          );
        case LogEntryKind.herdActivity:
          await widget.service.addHerdActivity(
            herdId: sourceId!,
            activityType: _herdEvent,
            count: int.parse(_count.text.trim()),
            date: _date,
            notes: notes,
          );
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _failure =
            "That didn't save. Check the connection and try again — "
            'nothing was recorded.';
      });
    }
  }
}

/// Stands in for a season the reference list no longer has, so a stale
/// selection renders a label instead of throwing mid-build.
final _missingSeason = Season(
  id: '',
  userId: '',
  name: 'Unknown season',
  plantId: '',
  landId: '',
  startDate: DateTime(2000),
  createdAt: DateTime(2000),
  updatedAt: DateTime(2000),
);

class _TotalPreview extends StatelessWidget {
  const _TotalPreview({required this.quantity, required this.unitPrice});

  final double quantity;
  final double unitPrice;

  @override
  Widget build(BuildContext context) {
    final console = context.console;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: console.surfaceLow,
        borderRadius: BorderRadius.circular(ConsoleMetrics.radiusControl),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Total',
              style: AppTypography.bodyDense.copyWith(
                color: console.onSurface2,
              ),
            ),
          ),
          Text(
            formatKes(quantity * unitPrice),
            style: AppTypography.amount(18).copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _Problem extends StatelessWidget {
  const _Problem({required this.text, this.actionLabel, this.onAction});

  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final console = context.console;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: console.surfaceLow,
        borderRadius: BorderRadius.circular(ConsoleMetrics.radiusControl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            style: AppTypography.bodyDense.copyWith(
              color: console.onSurface2,
              height: 1.5,
            ),
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: 12),
            ConsoleButton.outlined(label: actionLabel!, onPressed: onAction),
          ],
        ],
      ),
    );
  }
}

class _FormSkeleton extends StatelessWidget {
  const _FormSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Skeleton(height: 40, radius: 10),
        SizedBox(height: 14),
        Skeleton(height: 40, radius: 10),
        SizedBox(height: 14),
        Skeleton(height: 40, radius: 10),
      ],
    );
  }
}
