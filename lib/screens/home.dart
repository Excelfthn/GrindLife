import 'dart:async';

import 'package:flutter/material.dart';

import '../models.dart';
import '../state.dart';
import '../theme.dart';
import 'detail.dart';
import 'editor.dart';

const _firstHour = 0;
const _lastHour = 23;
const _hourH = 52.0;
const _timeCol = 34.0;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _weekOffset = 0;
  final _scroll = ScrollController();
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final h = DateTime.now().hour - _firstHour - 1;
      if (_scroll.hasClients && h > 0) {
        _scroll.jumpTo((h * _hourH).clamp(0.0, _scroll.position.maxScrollExtent).toDouble());
      }
    });
    _clock = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  DateTime get _weekStart {
    final today = dateOnly(DateTime.now());
    final monday = DateTime(today.year, today.month, today.day - (today.weekday - 1));
    return DateTime(monday.year, monday.month, monday.day + 7 * _weekOffset);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final days = List.generate(7, (i) => DateTime(_weekStart.year, _weekStart.month, _weekStart.day + i));
        final today = dateOnly(DateTime.now());
        return Stack(
          children: [
            Column(
              children: [
                _Header(today: today),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _weekOffset == 0 ? 'This week' : '${days.first.day} ${monthShort[days.first.month - 1]} to ${days.last.day} ${monthShort[days.last.month - 1]}',
                          style: pixel(22),
                        ),
                      ),
                      _SquareButton(icon: Icons.chevron_left, label: 'Previous week', onTap: () => setState(() => _weekOffset--)),
                      const SizedBox(width: 6),
                      _SquareButton(icon: Icons.chevron_right, label: 'Next week', onTap: () => setState(() => _weekOffset++)),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      const SizedBox(width: _timeCol),
                      for (final d in days)
                        Expanded(
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 1),
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            decoration: BoxDecoration(
                              color: d == today ? C.gold : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              children: [
                                Text(weekdayShort[d.weekday - 1],
                                    style: TextStyle(fontSize: 11, color: d == today ? C.bg : C.muted, fontWeight: d == today ? FontWeight.w700 : FontWeight.w400)),
                                Text('${d.day}',
                                    style: TextStyle(fontSize: 11, color: d == today ? C.bg : C.muted, fontWeight: d == today ? FontWeight.w700 : FontWeight.w400)),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: SingleChildScrollView(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                    child: LayoutBuilder(
                      builder: (context, constraints) => _WeekGrid(
                        days: days,
                        today: today,
                        width: constraints.maxWidth,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Positioned(
              right: 16,
              bottom: 16,
              child: Row(
                children: [
                  Tooltip(
                    message: 'Create schedule with AI',
                    child: Material(
                      color: C.surface2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: C.line2)),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => showComingSoon(context, 'AI input coming soon', 'Soon you can type or say your plans and the app turns them into schedules.'),
                        child: const SizedBox(width: 48, height: 48, child: Icon(Icons.auto_awesome, color: C.purpleLight, size: 20)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 128,
                    child: GoldButton(
                      label: 'Schedule',
                      icon: Icons.add,
                      height: 50,
                      onTap: () => showEditor(context, initialDay: _weekOffset == 0 ? today : days.first),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SquareButton extends StatelessWidget {
  const _SquareButton({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Material(
        color: C.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: C.line)),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: SizedBox(width: 44, height: 36, child: Icon(icon, size: 20, color: C.text)),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.today});
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final lv = appState.levelInfo;
    final done = appState.tasksDoneOn(today);
    final total = appState.tasksTotalOn(today);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: box(color: C.surface2, border: C.gold, radius: 12, borderWidth: 2),
                child: const Center(child: PixelArt(sprite: Sprites.avatar, size: 34)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(child: Text('Hi, Adventurer', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
                        Text('Lv ${lv.level}', style: pixel(16, color: C.gold, weight: FontWeight.w500)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: LinearProgressIndicator(value: lv.progress, minHeight: 10, backgroundColor: C.surface2, color: C.gold),
                    ),
                    const SizedBox(height: 4),
                    Text('${lv.into} / ${lv.need} XP to level ${lv.level + 1}', style: const TextStyle(fontSize: 12, color: C.muted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _Stat(label: 'Today', value: '$done / $total done'),
              const SizedBox(width: 8),
              _Stat(label: 'Streak', value: '${appState.streak} days', color: C.coral),
              const SizedBox(width: 8),
              _Stat(label: 'Focus', value: '${appState.focusMinOn(today)} min', color: C.purpleLight),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.color = C.text});
  final String label;
  final String value;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: box(radius: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, color: C.muted)),
            const SizedBox(height: 2),
            Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }
}

class _WeekGrid extends StatelessWidget {
  const _WeekGrid({required this.days, required this.today, required this.width});
  final List<DateTime> days;
  final DateTime today;
  final double width;

  @override
  Widget build(BuildContext context) {
    const hours = _lastHour - _firstHour;
    final colW = (width - _timeCol) / 7;
    double y(int minutes) => ((minutes - _firstHour * 60) / 60 * _hourH).clamp(0, hours * _hourH).toDouble();

    final children = <Widget>[];
    for (var h = 0; h <= hours; h++) {
      children.add(Positioned(
        top: h * _hourH,
        left: _timeCol - 4,
        right: 0,
        child: Container(height: 1, color: C.grid),
      ));
      children.add(Positioned(
        top: h * _hourH - 7,
        left: 0,
        width: _timeCol - 8,
        child: Text(
          (h + _firstHour).toString().padLeft(2, '0'),
          textAlign: TextAlign.right,
          maxLines: 1,
          style: const TextStyle(fontSize: 10.5, height: 1.2, color: C.faint),
        ),
      ));
    }
    final todayIndex = days.indexOf(today);
    if (todayIndex >= 0) {
      children.add(Positioned(
        top: 0,
        bottom: 0,
        left: _timeCol + colW * todayIndex,
        width: colW,
        child: Container(color: const Color(0x12F2B544)),
      ));
    }
    for (var i = 0; i < 7; i++) {
      final day = days[i];
      for (final s in appState.schedulesOn(day)) {
        final top = y(s.startMin);
        final h = ((s.overnight ? hours * _hourH : y(s.endMin)) - top).clamp(22.0, 9999.0).toDouble();
        final color = attrColors[s.attr] ?? C.gold;
        final done = s.doneOn(day);
        children.add(Positioned(
          top: top + 1,
          left: _timeCol + colW * i + 1,
          width: colW - 3,
          height: h - 2,
          child: Material(
            color: done ? color.withAlpha(110) : color,
            borderRadius: BorderRadius.circular(6),
            child: InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: () => showDetail(context, s, day),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Text(
                  done ? '✓ ${s.title}' : s.title,
                  maxLines: (h / 14).floor().clamp(1, 8).toInt(),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10.5, height: 1.2, fontWeight: FontWeight.w600, color: C.bg),
                ),
              ),
            ),
          ),
        ));
      }
    }
    for (var i = 0; i < 7; i++) {
      final day = days[i];
      final prev = DateTime(day.year, day.month, day.day - 1);
      for (final s in appState.overnightInto(day)) {
        final h = y(s.endMin).clamp(22.0, 9999.0).toDouble();
        final color = attrColors[s.attr] ?? C.gold;
        children.add(Positioned(
          top: 1,
          left: _timeCol + colW * i + 1,
          width: colW - 3,
          height: h - 2,
          child: Material(
            color: color.withAlpha(s.doneOn(prev) ? 90 : 170),
            borderRadius: BorderRadius.circular(6),
            child: InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: () => showDetail(context, s, prev),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Text(
                  '↳ ${s.title}',
                  maxLines: (h / 14).floor().clamp(1, 8).toInt(),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10.5, height: 1.2, fontWeight: FontWeight.w600, color: C.bg),
                ),
              ),
            ),
          ),
        ));
      }
    }
    if (todayIndex >= 0) {
      final now = DateTime.now();
      final ny = y(now.hour * 60 + now.minute);
      children.add(Positioned(top: ny - 1, left: _timeCol - 4, right: 0, child: Container(height: 2, color: C.coral)));
      children.add(Positioned(
        top: ny - 5,
        left: _timeCol - 8,
        child: Container(width: 10, height: 10, decoration: const BoxDecoration(color: C.coral, shape: BoxShape.circle)),
      ));
    }
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: SizedBox(height: hours * _hourH, width: width, child: Stack(clipBehavior: Clip.none, children: children)),
    );
  }
}
