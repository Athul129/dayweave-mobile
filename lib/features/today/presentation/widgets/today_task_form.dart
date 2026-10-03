import 'package:flutter/material.dart';

import '../../../../core/date_time/dayweave_date_time.dart';
import '../../../../core/theme/dayweave_theme.dart';
import '../../../../models/task.dart';
import '../../application/today_state.dart';

const defaultTaskNote = 'A small, clear next step.';

TodayTaskDraft defaultTodayTaskDraft(LocalDate date, {String title = ''}) =>
    TodayTaskDraft(
      title: title,
      note: defaultTaskNote,
      time: '16:00',
      minutes: 30,
      energy: TaskEnergy.light,
      section: TaskSection.afternoon,
      date: date,
    );

Future<Task?> showTodayTaskFormSheet({
  required BuildContext context,
  required LocalDate today,
  TodayTaskDraft? initial,
  Task? editing,
  required Future<Task?> Function(TodayTaskDraft draft) onSave,
  Future<void> Function()? onDelete,
}) =>
    showModalBottomSheet<Task?>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: DayweaveColors.paper,
      builder: (context) => TodayTaskForm(
        today: today,
        initial: initial ?? _draftFromTask(editing!),
        editing: editing,
        onSave: onSave,
        onDelete: onDelete,
      ),
    );

TodayTaskDraft _draftFromTask(Task task) => TodayTaskDraft(
      title: task.title,
      note: task.note,
      time: task.time,
      minutes: task.minutes,
      energy: task.energy,
      section: task.section,
      date: LocalDate.parse(task.date),
    );

class TodayTaskForm extends StatefulWidget {
  const TodayTaskForm({
    required this.today,
    required this.initial,
    required this.onSave,
    this.editing,
    this.onDelete,
    super.key,
  });

  final LocalDate today;
  final TodayTaskDraft initial;
  final Task? editing;
  final Future<Task?> Function(TodayTaskDraft draft) onSave;
  final Future<void> Function()? onDelete;

  @override
  State<TodayTaskForm> createState() => _TodayTaskFormState();
}

class _TodayTaskFormState extends State<TodayTaskForm> {
  late final TextEditingController _title;
  late final TextEditingController _note;
  late final TextEditingController _time;
  late final TextEditingController _minutes;
  late LocalDate _date;
  late TaskEnergy _energy;
  late TaskSection _section;
  bool _saving = false;
  bool _deleting = false;
  String? _formError;
  Map<String, String> _errors = const {};

  bool get _editing => widget.editing != null;
  bool get _dateLocked =>
      _editing &&
      (widget.editing!.done ||
          widget.editing!.date.compareTo(widget.today.iso) < 0);

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.initial.title);
    _note = TextEditingController(text: widget.initial.note);
    _time = TextEditingController(text: widget.initial.time);
    _minutes = TextEditingController(text: widget.initial.minutes.toString());
    _date = widget.initial.date;
    _energy = widget.initial.energy;
    _section = widget.initial.section;
  }

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    _time.dispose();
    _minutes.dispose();
    super.dispose();
  }

  TodayTaskDraft get _draft => TodayTaskDraft(
        title: _title.text,
        note: _note.text,
        time: _time.text,
        minutes: int.tryParse(_minutes.text) ?? 0,
        energy: _energy,
        section: _section,
        date: _date,
      );

  Future<void> _submit() async {
    if (_saving || _deleting) return;
    final draft = _draft;
    final errors = validateTodayTaskDraft(draft, widget.today);
    if (_dateLocked && draft.date != widget.initial.date) {
      errors['date'] = widget.editing!.done
          ? 'Completed tasks cannot be moved.'
          : 'Existing past task dates remain locked.';
    }
    if (errors.isNotEmpty) {
      setState(() => _errors = errors);
      return;
    }
    setState(() {
      _saving = true;
      _formError = null;
      _errors = const {};
    });
    try {
      final result = await widget.onSave(draft);
      if (mounted && result != null) Navigator.of(context).pop(result);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _formError = _editing
              ? 'Task could not be updated. Please try again.'
              : 'Task could not be saved. Please try again.';
        });
      }
    }
  }

  Future<void> _delete() async {
    if (_saving || _deleting || widget.onDelete == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this task?'),
        content: const Text('This can’t be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() {
      _deleting = true;
      _formError = null;
    });
    try {
      await widget.onDelete!();
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() {
          _deleting = false;
          _formError = 'Task could not be deleted. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(DayweaveSpacing.xl,
            DayweaveSpacing.md, DayweaveSpacing.xl, DayweaveSpacing.xl),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Center(
              child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                      color: DayweaveColors.line,
                      borderRadius: BorderRadius.circular(4)))),
          const SizedBox(height: DayweaveSpacing.xl),
          Text(_editing ? 'Tune the details' : 'Give it a place',
              style: text.headlineSmall?.copyWith(fontSize: 30)),
          const SizedBox(height: DayweaveSpacing.xs),
          Text(
              _editing
                  ? 'Small adjustments keep the route honest.'
                  : 'Add just enough detail to make this easy to return to.',
              style: text.bodyLarge),
          const SizedBox(height: DayweaveSpacing.xl),
          _field('Title', _title,
              autofocus: !_editing, error: _errors['title']),
          const SizedBox(height: DayweaveSpacing.md),
          _field('Note', _note, maxLines: 3),
          const SizedBox(height: DayweaveSpacing.md),
          Row(children: [
            Expanded(
                child: _field('Time', _time,
                    keyboardType: TextInputType.datetime,
                    error: _errors['time'])),
            const SizedBox(width: DayweaveSpacing.md),
            Expanded(
                child: _field('Duration (minutes)', _minutes,
                    keyboardType: TextInputType.number,
                    error: _errors['minutes']))
          ]),
          const SizedBox(height: DayweaveSpacing.lg),
          _choiceGroup(
              'Energy',
              TaskEnergy.values,
              _energy,
              (value) => setState(() => _energy = value),
              (value) => value.name[0].toUpperCase() + value.name.substring(1)),
          const SizedBox(height: DayweaveSpacing.lg),
          _choiceGroup(
              'Section',
              TaskSection.values,
              _section,
              (value) => setState(() => _section = value),
              (value) => value.name[0].toUpperCase() + value.name.substring(1)),
          const SizedBox(height: DayweaveSpacing.lg),
          Text('Date', style: text.labelLarge),
          const SizedBox(height: DayweaveSpacing.xs),
          OutlinedButton.icon(
              onPressed: _dateLocked ? null : _pickDate,
              icon: const Icon(Icons.calendar_today_outlined, size: 18),
              label: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(MaterialLocalizations.of(context)
                      .formatFullDate(_date.asLocalDateTime)))),
          if (_dateLocked)
            Padding(
                padding: const EdgeInsets.only(top: DayweaveSpacing.xs),
                child: Text(
                    widget.editing!.done
                        ? 'Completed task dates are locked.'
                        : 'Past task dates are locked.',
                    style: text.bodySmall)),
          if (_errors['date'] != null)
            Text(_errors['date']!,
                style: text.bodySmall?.copyWith(color: DayweaveColors.coral)),
          if (_formError != null)
            Padding(
                padding: const EdgeInsets.only(top: DayweaveSpacing.md),
                child: Text(_formError!,
                    style: text.bodyMedium
                        ?.copyWith(color: DayweaveColors.coral))),
          const SizedBox(height: DayweaveSpacing.xl),
          Row(children: [
            if (_editing)
              TextButton(
                  onPressed: _saving || _deleting ? null : _delete,
                  child: const Text('Delete')),
            const Spacer(),
            TextButton(
                onPressed:
                    _saving || _deleting ? null : () => Navigator.pop(context),
                child: const Text('Cancel')),
            const SizedBox(width: DayweaveSpacing.sm),
            FilledButton(
                onPressed: _saving || _deleting ? null : _submit,
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(_editing ? 'Save changes' : 'Add to route'))
          ]),
        ]),
      ),
    );
  }

  Widget _field(String label, TextEditingController controller,
          {int maxLines = 1,
          TextInputType? keyboardType,
          String? error,
          bool autofocus = false}) =>
      TextField(
          controller: controller,
          autofocus: autofocus,
          keyboardType: keyboardType,
          maxLines: maxLines,
          decoration: InputDecoration(labelText: label, errorText: error));

  Widget _choiceGroup<T>(String label, Iterable<T> values, T selected,
          ValueChanged<T> onSelected, String Function(T) text) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: DayweaveSpacing.sm),
        Wrap(
            spacing: DayweaveSpacing.sm,
            runSpacing: DayweaveSpacing.sm,
            children: values
                .map((value) => ChoiceChip(
                    label: Text(text(value)),
                    selected: value == selected,
                    onSelected: (_) => onSelected(value),
                    selectedColor: DayweaveColors.sage))
                .toList())
      ]);

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
        context: context,
        initialDate: _date.asLocalDateTime,
        firstDate: widget.today.asLocalDateTime,
        lastDate: widget.today.asLocalDateTime.add(const Duration(days: 365)));
    if (picked != null) {
      setState(() => _date = LocalDate(picked.year, picked.month, picked.day));
    }
  }
}

