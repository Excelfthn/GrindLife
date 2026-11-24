import 'package:flutter/material.dart';

import '../models.dart';
import '../state.dart';
import '../theme.dart';

Future<void> showEditor(BuildContext context, {Schedule? existing, DateTime? initialDay}) {
  return showDialog<void>(
    context: context,
    barrierColor: const Color(0xB808070C),
    builder: (_) => _EditorDialog(existing: existing, initialDay: dateOnly(initialDay ?? DateTime.now())),
  );
}

const _repeatLabels = ['Once', 'Daily', 'Weekly', 'Monthly'];
const _repeatValues = ['once', 'daily', 'weekly', 'monthly'];
const _endLabels = ['Never', 'On date', 'After N times'];
const _endValues = ['never', 'date', 'count'];
const _reminderLabels = ['At start', '5 min before', '10 min before', '15 min before', '30 min before', '1 hour before'];
const _reminderValues = [0, 5, 10, 15, 30, 60];

class _EditorDialog extends StatefulWidget {
  const _EditorDialog({this.existing, required this.initialDay});
  final Schedule? existing;
  final DateTime initialDay;
  @override
  State<_EditorDialog> createState() => _EditorDialogState();
}

class _EditorDialogState extends State<_EditorDialog> {
  late final TextEditingController _title;
  final _newTask = TextEditingController();
  late int _start;
  late int _end;
  late Recurrence _rec;
  late String _attr;
  late bool _attrManual;
  late int _reminder;
  late List<TaskItem> _tasks;
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?.title ?? '');
    _start = e?.startMin ?? 9 * 60;
    _end = e?.endMin ?? 10 * 60;
    _rec = e?.rec.copy() ?? Recurrence(type: 'weekly', weekdays: [widget.initialDay.weekday], start: widget.initialDay, monthDay: widget.initialDay.day);
    _attr = e?.attr ?? 'INT';
    _attrManual = e?.attrManual ?? false;
    _reminder = e?.reminder ?? 10;
    _tasks = e?.tasks.map((t) => TaskItem(id: t.id, title: t.title, weight: t.weight)).toList() ?? [];
  }

  @override
  void dispose() {
    _title.dispose();
    _newTask.dispose();
    super.dispose();
  }

  String get _effectiveAttr => _attrManual ? _attr : guessAttr(_title.text);
  int get _duration => (_end - _start).clamp(0, 24 * 60).toInt();
  String get _calc => guessCalcType(_title.text, _duration);
  int get _pool => _calc == 'none' ? 0 : (_duration * 0.5).round();

  int _xpFor(TaskItem t) {
    final sum = _tasks.fold<int>(0, (a, b) => a + b.weight);
    return sum == 0 ? 0 : (_pool * t.weight / sum).round();
  }

  void _setRepeat(String type) {
    setState(() {
      _rec.type = type;
      if (type == 'daily') _rec.weekdays = [1, 2, 3, 4, 5, 6, 7];
      if (type == 'weekly' && (_rec.weekdays.isEmpty || _rec.weekdays.length == 7)) {
        _rec.weekdays = [_rec.start.weekday];
      }
      if (type == 'monthly') _rec.monthDay = _rec.start.day;
    });
  }

  Future<void> _pickTime(bool start) async {
    final cur = start ? _start : _end;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: (cur ~/ 60) % 24, minute: cur % 60),
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      final m = picked.hour * 60 + picked.minute;
      if (start) {
        final d = _duration == 0 ? 60 : _duration;
        _start = m;
        _end = (m + d).clamp(0, 24 * 60).toInt();
      } else {
        _end = m == 0 ? 24 * 60 : m;
      }
    });
  }

  Future<DateTime?> _pickDate(DateTime initial) {
    return showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
  }

  void _addTask() {
    final t = _newTask.text.trim();
    if (t.isEmpty) return;
    setState(() {
      _tasks.add(TaskItem(id: newId(), title: t, weight: 2));
      _newTask.clear();
    });
  }

  void _save() {
    final title = _title.text.trim();
    if (title.isEmpty) return setState(() => _error = 'Give the activity a name.');
    if (_end <= _start) return setState(() => _error = 'End time must be after start time.');
    if ((_rec.type == 'daily' || _rec.type == 'weekly') && _rec.weekdays.isEmpty) {
      return setState(() => _error = 'Pick at least one day.');
    }
    final e = widget.existing;
    final s = Schedule(
      id: e?.id ?? newId(),
      title: title,
      startMin: _start,
      endMin: _end,
      rec: _rec,
      attr: _effectiveAttr,
      attrManual: _attrManual,
      location: e?.location ?? '',
      notes: e?.notes ?? '',
      reminder: _reminder,
      tasks: _tasks,
      occ: e?.occ,
    );
    appState.upsert(s);
    Navigator.pop(context);
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.sheet,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete schedule?'),
        content: const Text('This removes the schedule and all its repeats. XP you already earned stays.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: C.muted))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: C.coral))),
        ],
      ),
    );
    if (ok == true && widget.existing != null) {
      appState.delete(widget.existing!);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final calc = _calc;
    final attr = _effectiveAttr;
    final xpInfo = calc == 'duration'
        ? 'XP from focus time + completion bonus'
        : (calc == 'checklist' ? 'Fixed XP when checked' : 'Leisure activity, no XP');
    return Dialog(
      backgroundColor: C.sheet,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: const BorderSide(color: C.line)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 680),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: C.grid))),
              child: Row(
                children: [
                  Expanded(child: Text(widget.existing == null ? 'New schedule' : 'Edit schedule', style: pixel(20))),
                  if (widget.existing != null)
                    IconButton(tooltip: 'Delete', onPressed: _delete, icon: const Icon(Icons.delete_outline, color: C.coral)),
                  IconButton(tooltip: 'Close', onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: C.text)),
                ],
              ),
            ),
            Flexible(
              child: Scrollbar(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const FieldLabel('Activity name'),
                      TextField(
                        controller: _title,
                        onChanged: (_) => setState(() {}),
                        textCapitalization: TextCapitalization.sentences,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                        decoration: fieldDecoration(hint: 'e.g. Morning jog'),
                      ),
                      const SizedBox(height: 14),
                      _GroupBox(children: [
                        _SettingRow(
                          icon: Icons.repeat,
                          label: 'Repeat',
                          child: _MenuValue(
                            text: _repeatLabels[_repeatValues.indexOf(_rec.type)],
                            onPick: (ctx) async {
                              final v = await showRoundMenu<String>(ctx, _repeatLabels, _repeatValues, _rec.type);
                              if (v != null) _setRepeat(v);
                            },
                          ),
                        ),
                        if (_rec.type != 'once')
                          _SettingRow(
                            icon: Icons.flag_outlined,
                            label: 'Ends',
                            child: _MenuValue(
                              text: _endLabels[_endValues.indexOf(_rec.endMode)],
                              onPick: (ctx) async {
                                final v = await showRoundMenu<String>(ctx, _endLabels, _endValues, _rec.endMode);
                                if (v != null) {
                                  setState(() {
                                    _rec.endMode = v;
                                    if (v == 'date') _rec.until ??= DateTime(_rec.start.year, _rec.start.month + 3, _rec.start.day);
                                  });
                                }
                              },
                            ),
                          ),
                        if (_rec.type != 'once' && _rec.endMode == 'date')
                          _SettingRow(
                            label: 'End date',
                            child: _Pill(
                              text: niceDate(_rec.until ?? _rec.start),
                              onTap: () async {
                                final d = await _pickDate(_rec.until ?? _rec.start);
                                if (d != null) setState(() => _rec.until = d);
                              },
                            ),
                          ),
                        if (_rec.type != 'once' && _rec.endMode == 'count')
                          _SettingRow(
                            label: 'Count',
                            child: _Stepper(
                              text: '${_rec.count} times',
                              onMinus: () => setState(() => _rec.count = (_rec.count - 1).clamp(2, 365).toInt()),
                              onPlus: () => setState(() => _rec.count = (_rec.count + 1).clamp(2, 365).toInt()),
                            ),
                          ),
                      ]),
                      const SizedBox(height: 14),
                      if (_rec.type == 'once') ...[
                        _GroupBox(children: [
                          _SettingRow(
                            icon: Icons.event_outlined,
                            label: 'Date',
                            child: _Pill(
                              text: niceDate(_rec.start),
                              onTap: () async {
                                final d = await _pickDate(_rec.start);
                                if (d != null) setState(() => _rec.start = d);
                              },
                            ),
                          ),
                        ]),
                        const SizedBox(height: 14),
                      ],
                      if (_rec.type == 'daily' || _rec.type == 'weekly') ...[
                        const FieldLabel('Days (pick one or more)'),
                        Row(
                          children: [
                            for (var wd = 1; wd <= 7; wd++)
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 2),
                                  child: _Chip(
                                    label: weekdayShort[wd - 1],
                                    on: _rec.weekdays.contains(wd),
                                    onTap: () => setState(() {
                                      if (_rec.weekdays.contains(wd)) {
                                        if (_rec.weekdays.length > 1) _rec.weekdays.remove(wd);
                                      } else {
                                        _rec.weekdays.add(wd);
                                        _rec.weekdays.sort();
                                      }
                                    }),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 14),
                      ],
                      if (_rec.type == 'monthly') ...[
                        _GroupBox(children: [
                          _SettingRow(
                            icon: Icons.calendar_today_outlined,
                            label: 'Every month on day',
                            labelWidth: 130,
                            child: _Stepper(
                              text: '${_rec.monthDay}',
                              onMinus: () => setState(() => _rec.monthDay = _rec.monthDay <= 1 ? 31 : _rec.monthDay - 1),
                              onPlus: () => setState(() => _rec.monthDay = _rec.monthDay >= 31 ? 1 : _rec.monthDay + 1),
                            ),
                          ),
                        ]),
                        if (_rec.monthDay > 28)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text('Months without day ${_rec.monthDay} use their last day.',
                                style: const TextStyle(fontSize: 11.5, color: C.muted)),
                          ),
                        const SizedBox(height: 14),
                      ],
                      _GroupBox(children: [
                        _SettingRow(
                          icon: Icons.schedule,
                          label: 'Time',
                          labelWidth: 44,
                          child: Row(
                            children: [
                              Expanded(child: _Pill(text: hhmm(_start), onTap: () => _pickTime(true), expand: true)),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 6),
                                child: Icon(Icons.arrow_forward, size: 16, color: C.faint),
                              ),
                              Expanded(child: _Pill(text: _end == 24 * 60 ? '24:00' : hhmm(_end), onTap: () => _pickTime(false), expand: true)),
                            ],
                          ),
                        ),
                        _SettingRow(
                          icon: Icons.notifications_none,
                          label: 'Reminder',
                          child: _MenuValue(
                            text: _reminderLabels[_reminderValues.indexOf(_reminder)],
                            onPick: (ctx) async {
                              final v = await showRoundMenu<int>(ctx, _reminderLabels, _reminderValues, _reminder);
                              if (v != null) setState(() => _reminder = v);
                            },
                          ),
                        ),
                      ]),
                      const SizedBox(height: 14),
                      FieldLabel('Attribute gained · ${_attrManual ? 'set manually' : 'guessed from name'}'),
                      Row(
                        children: [
                          for (final a in attrCodes)
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 3),
                                child: _AttrChip(
                                  code: a,
                                  on: attr == a,
                                  onTap: () => setState(() {
                                    _attr = a;
                                    _attrManual = true;
                                  }),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: box(color: C.surface, border: C.surface, radius: 10),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, size: 16, color: C.gold),
                            const SizedBox(width: 8),
                            Expanded(child: Text(xpInfo, style: const TextStyle(fontSize: 12.5, color: Color(0xFFD6D1E2)))),
                            if (_rec.type != 'once' && calc != 'none')
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(color: const Color(0xFF3A2A27), borderRadius: BorderRadius.circular(6)),
                                child: const Text('Streak on', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: C.coral)),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: Text('Tasks (${_tasks.length})', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
                          Text('Pool $_pool XP', style: const TextStyle(fontSize: 12, color: C.muted)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      for (final t in _tasks)
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
                          decoration: box(radius: 12),
                          child: Row(
                            children: [
                              Expanded(child: Text(t.title, style: const TextStyle(fontSize: 14))),
                              _WeightChip(
                                weight: t.weight,
                                onTap: () => setState(() => t.weight = t.weight == 1 ? 2 : (t.weight == 2 ? 4 : 1)),
                              ),
                              SizedBox(
                                width: 40,
                                child: Text('+${_xpFor(t)}', textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: C.gold)),
                              ),
                              IconButton(
                                tooltip: 'Remove ${t.title}',
                                onPressed: () => setState(() => _tasks.remove(t)),
                                icon: const Icon(Icons.close, size: 18, color: C.faint),
                              ),
                            ],
                          ),
                        ),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _newTask,
                              onSubmitted: (_) => _addTask(),
                              decoration: fieldDecoration(hint: 'Add task'),
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Material(
                            color: C.surface2,
                            borderRadius: BorderRadius.circular(10),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: _addTask,
                              child: const SizedBox(width: 46, height: 46, child: Icon(Icons.add, color: C.text)),
                            ),
                          ),
                        ],
                      ),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(_error!, style: const TextStyle(color: C.coral, fontSize: 13)),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: C.grid))),
              child: SizedBox(width: double.infinity, child: GoldButton(label: 'Save schedule', onTap: _save, height: 48)),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------- Small building blocks (also used by the detail popup) ----------

class _GroupBox extends StatelessWidget {
  const _GroupBox({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: box(color: C.bg, border: C.line2, radius: 10),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(height: 1, thickness: 1, color: C.grid),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({this.icon, required this.label, required this.child, this.labelWidth = 72});
  final IconData? icon;
  final String label;
  final Widget child;
  final double labelWidth;
  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 46),
      child: Padding(
        padding: EdgeInsets.only(left: icon == null ? 38 : 10, right: 10),
        child: Row(
          children: [
            if (icon != null) ...[Icon(icon, size: 18, color: C.muted), const SizedBox(width: 10)],
            SizedBox(width: labelWidth, child: Text(label, style: const TextStyle(fontSize: 12, color: C.muted))),
            const SizedBox(width: 6),
            Expanded(child: Align(alignment: Alignment.centerRight, child: child)),
          ],
        ),
      ),
    );
  }
}

class _MenuValue extends StatelessWidget {
  const _MenuValue({required this.text, required this.onPick});
  final String text;
  final void Function(BuildContext anchor) onPick;
  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (anchor) => InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => onPick(anchor),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          child: Text(text, style: const TextStyle(fontSize: 14)),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.onTap, this.expand = false});
  final String text;
  final VoidCallback onTap;
  final bool expand;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: C.surface,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          alignment: Alignment.center,
          width: expand ? double.infinity : null,
          child: Text(text, style: const TextStyle(fontSize: 14)),
        ),
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({required this.text, required this.onMinus, required this.onPlus});
  final String text;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  @override
  Widget build(BuildContext context) {
    Widget btn(IconData i, VoidCallback f, String tip) => Tooltip(
          message: tip,
          child: Material(
            color: C.surface,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: f,
              child: SizedBox(width: 34, height: 34, child: Icon(i, size: 18, color: C.text)),
            ),
          ),
        );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        btn(Icons.remove, onMinus, 'Decrease'),
        SizedBox(width: 64, child: Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
        btn(Icons.add, onPlus, 'Increase'),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.on, required this.onTap});
  final String label;
  final bool on;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: on ? C.gold : C.bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: on ? C.gold : C.line2)),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: SizedBox(
          height: 44,
          child: Center(
            child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: on ? C.bg : C.text)),
          ),
        ),
      ),
    );
  }
}

class _AttrChip extends StatelessWidget {
  const _AttrChip({required this.code, required this.on, required this.onTap});
  final String code;
  final bool on;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final c = attrColors[code]!;
    return Material(
      color: on ? c : C.bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: on ? c : C.line2)),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: SizedBox(
          height: 52,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(code, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: on ? C.bg : C.text)),
              Text(attrNames[code]!, style: TextStyle(fontSize: 10.5, color: on ? C.bg : C.muted)),
            ],
          ),
        ),
      ),
    );
  }
}

class _WeightChip extends StatelessWidget {
  const _WeightChip({required this.weight, required this.onTap});
  final int weight;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final label = weight == 1 ? 'Easy' : (weight == 4 ? 'Hard' : 'Medium');
    final bg = weight == 1 ? const Color(0xFF1E3A39) : (weight == 4 ? const Color(0xFF3A2A27) : C.surface2);
    final fg = weight == 1 ? C.teal : (weight == 4 ? C.coral : C.purpleLight);
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fg)),
        ),
      ),
    );
  }
}
