import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../models.dart';
import '../state.dart';
import '../theme.dart';
import 'editor.dart';

Future<void> showDetail(BuildContext context, Schedule s, DateTime day) {
  return showDialog<void>(
    context: context,
    barrierColor: const Color(0xB808070C),
    builder: (_) => _DetailDialog(schedule: s, day: dateOnly(day)),
  );
}

const _reminderLabels = ['At start', '5 min before', '10 min before', '15 min before', '30 min before', '1 hour before'];
const _reminderValues = [0, 5, 10, 15, 30, 60];

class _DetailDialog extends StatefulWidget {
  const _DetailDialog({required this.schedule, required this.day});
  final Schedule schedule;
  final DateTime day;
  @override
  State<_DetailDialog> createState() => _DetailDialogState();
}

class _DetailDialogState extends State<_DetailDialog> {
  late final TextEditingController _loc;
  late final TextEditingController _notes;
  bool _timerView = false;
  int _sessMin = 25;
  bool _focusPhase = true;
  int _round = 1;
  int _left = 25 * 60;
  bool _running = false;
  Timer? _ticker;
  String? _toast;
  Timer? _toastTimer;

  Schedule get s => widget.schedule;

  @override
  void initState() {
    super.initState();
    _loc = TextEditingController(text: s.location);
    _notes = TextEditingController(text: s.notes);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _toastTimer?.cancel();
    _loc.dispose();
    _notes.dispose();
    Future.microtask(appState.touch);
    super.dispose();
  }

  void _flash(String text) {
    setState(() => _toast = text);
    _toastTimer?.cancel();
    _toastTimer = Timer(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => _toast = null);
    });
  }

  void _toggle(String id) {
    final xp = appState.toggleTask(s, widget.day, id);
    if (xp > 0) _flash('Quest complete!  +$xp XP');
    setState(() {});
  }

  // ---------- Focus timer ----------

  void _start() {
    setState(() {
      _timerView = true;
      _focusPhase = true;
      _round = 1;
      _left = _sessMin * 60;
    });
    _run();
  }

  void _run() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_focusPhase) {
        appState.addFocusSecond(s, widget.day);
      }
      if (_left > 1) {
        setState(() => _left--);
      } else {
        _advance();
      }
    });
    setState(() => _running = true);
  }

  void _pause() {
    _ticker?.cancel();
    setState(() => _running = false);
  }

  void _advance() {
    if (_focusPhase) {
      _flash('Focus session complete!');
      if (_round >= 4) {
        _pause();
        setState(() {
          _round = 1;
          _left = _sessMin * 60;
        });
        return;
      }
      setState(() {
        _focusPhase = false;
        _left = 5 * 60;
      });
    } else {
      setState(() {
        _focusPhase = true;
        _round++;
        _left = _sessMin * 60;
      });
    }
  }

  void _stop() {
    _pause();
    setState(() => _timerView = false);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: C.sheet,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: const BorderSide(color: C.line)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 560),
        child: ListenableBuilder(
          listenable: appState,
          builder: (context, _) => Stack(
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _header(context),
                  Flexible(child: _timerView ? _timerBody() : _detailBody()),
                  if (!_timerView)
                    Container(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                      decoration: const BoxDecoration(border: Border(top: BorderSide(color: C.grid))),
                      child: SizedBox(
                        width: double.infinity,
                        child: GoldButton(label: 'Start focus session', icon: Icons.play_arrow_rounded, onTap: _start, height: 48),
                      ),
                    ),
                ],
              ),
              if (_toast != null)
                Positioned(
                  left: 12,
                  right: 12,
                  top: 70,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: C.text,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [BoxShadow(color: C.goldDark, offset: Offset(0, 4))],
                    ),
                    child: Text(_toast!, textAlign: TextAlign.center, style: const TextStyle(color: C.bg, fontWeight: FontWeight.w700)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    final end = s.endMin == 24 * 60 ? '24:00' : hhmm(s.endMin);
    return Container(
      color: C.gold,
      padding: const EdgeInsets.fromLTRB(14, 8, 4, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${niceDate(widget.day)}, ${hhmm(s.startMin)} to $end · +${s.attr}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xCC15131D))),
                const SizedBox(height: 2),
                Text(s.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: pixel(18, color: C.bg)),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Edit schedule',
            onPressed: () {
              final nav = Navigator.of(context);
              final rootContext = nav.context;
              nav.pop();
              showEditor(rootContext, existing: s, initialDay: widget.day);
            },
            icon: const Icon(Icons.edit_outlined, color: C.bg, size: 20),
          ),
          IconButton(tooltip: 'Close', onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: C.bg)),
        ],
      ),
    );
  }

  Widget _detailBody() {
    final o = s.peekOcc(widget.day);
    final done = o?.done ?? const <String>[];
    final earned = s.tasks.where((t) => done.contains(t.id)).fold<int>(0, (a, t) => a + s.taskXp(t)) +
        (s.tasks.isEmpty && done.contains('_self') ? s.selfXp : 0) +
        (o?.focusXp ?? 0);
    return Scrollbar(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              decoration: box(color: C.bg, border: C.line2, radius: 10),
              child: Column(
                children: [
                  _row(
                    Icons.place_outlined,
                    'Location',
                    TextField(
                      controller: _loc,
                      textAlign: TextAlign.right,
                      onChanged: (v) => s.location = v,
                      style: const TextStyle(fontSize: 14),
                      decoration: const InputDecoration(isDense: true, border: InputBorder.none, hintText: 'Add location', hintStyle: TextStyle(color: C.faint)),
                    ),
                  ),
                  const Divider(height: 1, color: C.grid),
                  _row(
                    Icons.notifications_none,
                    'Reminder',
                    Builder(
                      builder: (anchor) => InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () async {
                          final v = await showRoundMenu<int>(anchor, _reminderLabels, _reminderValues, s.reminder);
                          if (v != null) {
                            s.reminder = v;
                            appState.touch();
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                          child: Text(_reminderLabels[max(0, _reminderValues.indexOf(s.reminder))], style: const TextStyle(fontSize: 14)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const FieldLabel('Notes'),
            TextField(
              controller: _notes,
              minLines: 2,
              maxLines: 4,
              onChanged: (v) => s.notes = v,
              style: const TextStyle(fontSize: 14, height: 1.4),
              decoration: fieldDecoration(hint: 'Anything to remember'),
            ),
            const SizedBox(height: 12),
            const FieldLabel('Focus session'),
            Row(
              children: [
                for (final m in [25, 50, 90])
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Material(
                        color: _sessMin == m ? C.gold : C.bg,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(color: _sessMin == m ? C.gold : C.line2),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => setState(() => _sessMin = m),
                          child: SizedBox(
                            height: 44,
                            child: Center(
                              child: Text('$m min',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _sessMin == m ? C.bg : C.text)),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Text(
                    s.tasks.isEmpty ? 'Task' : 'Tasks (${s.tasks.where((t) => done.contains(t.id)).length}/${s.tasks.length})',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
                Text('+$earned XP', style: pixel(15, color: C.gold, weight: FontWeight.w500)),
              ],
            ),
            const SizedBox(height: 8),
            if (s.tasks.isEmpty)
              _taskTile('Mark as done', done.contains('_self'), s.selfXp, () => _toggle('_self'))
            else
              for (final t in s.tasks) _taskTile(t.title, done.contains(t.id), s.taskXp(t), () => _toggle(t.id)),
            if (s.calcType == 'none')
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text('Leisure activity: no XP, but it keeps your streak.', style: TextStyle(fontSize: 12, color: C.muted)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _row(IconData icon, String label, Widget child) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 46),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          children: [
            Icon(icon, size: 18, color: C.muted),
            const SizedBox(width: 10),
            SizedBox(width: 64, child: Text(label, style: const TextStyle(fontSize: 12, color: C.muted))),
            const SizedBox(width: 6),
            Expanded(child: Align(alignment: Alignment.centerRight, child: child)),
          ],
        ),
      ),
    );
  }

  Widget _taskTile(String title, bool done, int xp, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: done ? const Color(0xFF191723) : C.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: done ? C.grid : C.line)),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: done ? C.teal : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: done ? C.teal : const Color(0xFF6B6584), width: 2),
                  ),
                  child: done ? const Icon(Icons.check, size: 14, color: C.bg) : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      decoration: done ? TextDecoration.lineThrough : null,
                      color: done ? const Color(0x8CF4EFE4) : C.text,
                    ),
                  ),
                ),
                Text('+$xp', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: done ? C.teal : C.gold)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _timerBody() {
    final total = _focusPhase ? _sessMin * 60 : 5 * 60;
    final frac = _left / total;
    final mm = (_left ~/ 60).toString().padLeft(2, '0');
    final ss = (_left % 60).toString().padLeft(2, '0');
    final phaseColor = _focusPhase ? C.gold : C.teal;
    final o = s.peekOcc(widget.day);
    final done = o?.done ?? const <String>[];
    final next = s.tasks.where((t) => !done.contains(t.id)).toList();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: _focusPhase ? C.goldSoft : const Color(0xFF1E3A39),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(_focusPhase ? 'Focus' : 'Break', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: phaseColor)),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 170,
            height: 170,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(size: const Size.square(170), painter: _RingPainter(frac, phaseColor)),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('$mm:$ss', style: pixel(40)),
                    Text(_running ? (_focusPhase ? 'stay focused' : 'take a breather') : 'paused',
                        style: const TextStyle(fontSize: 12, color: C.muted)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var r = 1; r <= 4; r++)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: r == _round ? 28 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: r < _round ? C.teal : (r == _round ? phaseColor : C.line),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text('Session $_round of 4 · 5 min break', style: const TextStyle(fontSize: 12, color: C.muted)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _roundBtn(Icons.stop_rounded, 'Stop session', _stop, 52),
              const SizedBox(width: 16),
              Container(
                decoration: const BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: C.goldDark, offset: Offset(0, 5))]),
                child: Material(
                  color: C.gold,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _running ? _pause : _run,
                    child: SizedBox(
                      width: 60,
                      height: 60,
                      child: Icon(_running ? Icons.pause_rounded : Icons.play_arrow_rounded, color: C.bg, size: 30, semanticLabel: _running ? 'Pause' : 'Resume'),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              _roundBtn(Icons.skip_next_rounded, 'Skip to next phase', _advance, 52),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            decoration: box(radius: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Expanded(child: Text('Next task', style: TextStyle(fontSize: 12, color: C.muted))),
                    Text('+${o?.focusXp ?? 0} focus XP', style: const TextStyle(fontSize: 12, color: C.gold, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 4),
                if (s.tasks.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('No tasks in this schedule.', style: TextStyle(fontSize: 14, color: C.muted)),
                  )
                else if (next.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('All tasks done. Great work!', style: TextStyle(fontSize: 14, color: C.teal)),
                  )
                else
                  InkWell(
                    onTap: () => _toggle(next.first.id),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 44),
                      child: Row(
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFF6B6584), width: 2),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Text(next.first.title, style: const TextStyle(fontSize: 14))),
                          Text('+${s.taskXp(next.first)}', style: const TextStyle(fontSize: 12, color: C.muted)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _roundBtn(IconData icon, String tip, VoidCallback onTap, double size) {
    return Tooltip(
      message: tip,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(side: BorderSide(color: C.line2)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(width: size, height: size, child: Icon(icon, color: C.text)),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.frac, this.color);
  final double frac;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 13.0;
    final rect = Rect.fromLTWH(stroke / 2, stroke / 2, size.width - stroke, size.height - stroke);
    final bg = Paint()
      ..color = C.surface2
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    final fg = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, 2 * pi, false, bg);
    canvas.drawArc(rect, -pi / 2, 2 * pi * frac.clamp(0.0, 1.0).toDouble(), false, fg);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.frac != frac || old.color != color;
}
