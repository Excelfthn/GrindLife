import 'dart:math';

import 'package:flutter/material.dart';

import '../models.dart';
import '../state.dart';
import '../theme.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final lv = appState.levelInfo;
        final maxAttr = max(1, appState.attrXp.values.fold<int>(0, max));
        final lowest = attrCodes.reduce((a, b) => (appState.attrXp[a] ?? 0) <= (appState.attrXp[b] ?? 0) ? a : b);
        final today = dateOnly(DateTime.now());
        final weekStart = DateTime(today.year, today.month, today.day - (today.weekday - 1));
        var weekDone = 0;
        var weekTotal = 0;
        for (var i = 0; i < 7; i++) {
          final d = DateTime(weekStart.year, weekStart.month, weekStart.day + i);
          weekDone += appState.tasksDoneOn(d);
          weekTotal += appState.tasksTotalOn(d);
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            Center(child: Text('Character', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
            const SizedBox(height: 16),
            Center(
              child: Container(
                width: 150,
                height: 150,
                decoration: box(color: C.surface, border: C.gold, radius: 24, borderWidth: 3),
                alignment: Alignment.bottomCenter,
                child: const PixelArt(sprite: Sprites.avatar, size: 128),
              ),
            ),
            const SizedBox(height: 12),
            Center(child: Text('Adventurer', style: pixel(26))),
            const SizedBox(height: 4),
            Center(
              child: Text('Level ${lv.level} · ${appState.totalXp} XP total',
                  style: const TextStyle(fontSize: 13, color: C.muted)),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(value: lv.progress, minHeight: 12, backgroundColor: C.surface2, color: C.gold),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(child: Text('${lv.into} / ${lv.need} XP', style: const TextStyle(fontSize: 12, color: C.muted))),
                Text('${lv.need - lv.into} XP to go', style: const TextStyle(fontSize: 12, color: C.muted)),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: box(radius: 16),
              child: GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 14,
                crossAxisSpacing: 16,
                childAspectRatio: 2.6,
                children: [
                  for (final a in attrCodes)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text(a, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: attrColors[a]))),
                            Text('${appState.attrXp[a] ?? 0}', style: const TextStyle(fontSize: 13)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: (appState.attrXp[a] ?? 0) / maxAttr,
                            minHeight: 8,
                            backgroundColor: C.surface2,
                            color: attrColors[a],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          appState.totalXp > 0 && a == lowest ? '${attrNames[a]}, needs attention' : attrNames[a]!,
                          style: TextStyle(fontSize: 11.5, color: appState.totalXp > 0 && a == lowest ? C.coral : C.muted),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _StatBox(label: 'Tasks done', value: '${appState.tasksDone}'),
                const SizedBox(width: 8),
                _StatBox(label: 'Focus time', value: '${appState.focusSecTotal ~/ 60} min'),
                const SizedBox(width: 8),
                _StatBox(label: 'Streak', value: '${appState.streak} days'),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: box(color: C.surface2, border: C.surface2, radius: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('WEEKLY REVIEW', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: C.purpleLight)),
                  const SizedBox(height: 6),
                  Text(
                    weekTotal == 0
                        ? 'No schedules this week yet. Add one from the Schedule tab to start earning XP.'
                        : '$weekDone of $weekTotal tasks done this week.',
                    style: const TextStyle(fontSize: 14, height: 1.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: TextButton(
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: C.sheet,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      title: const Text('Reset all data?'),
                      content: const Text('This deletes every schedule, task, XP and streak on this phone. It cannot be undone.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: C.muted))),
                        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Reset', style: TextStyle(color: C.coral))),
                      ],
                    ),
                  );
                  if (ok == true) await appState.resetAll();
                },
                child: const Text('Reset all data', style: TextStyle(color: C.faint)),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({required this.label, required this.value});
  final String label;
  final String value;
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
            Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
