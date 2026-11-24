import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

class LevelInfo {
  const LevelInfo(this.level, this.into, this.need);
  final int level;
  final int into;
  final int need;
  double get progress => need == 0 ? 0 : into / need;
}

class AppState extends ChangeNotifier {
  static const _key = 'life_rpg_state_v1';

  final List<Schedule> schedules = [];
  int totalXp = 0;
  Map<String, int> attrXp = {'INT': 0, 'STR': 0, 'CHA': 0, 'WIS': 0};
  Set<String> activeDays = {};
  int tasksDone = 0;
  int focusSecTotal = 0;
  bool loaded = false;

  SharedPreferences? _prefs;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs!.getString(_key);
    if (raw != null) {
      try {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        schedules
          ..clear()
          ..addAll(((j['schedules'] as List?) ?? const [])
              .map((e) => Schedule.fromJson(Map<String, dynamic>.from(e as Map))));
        totalXp = (j['totalXp'] as num?)?.toInt() ?? 0;
        final ax = (j['attrXp'] as Map?) ?? const {};
        attrXp = {for (final k in ['INT', 'STR', 'CHA', 'WIS']) k: (ax[k] as num?)?.toInt() ?? 0};
        activeDays = ((j['activeDays'] as List?) ?? const []).map((e) => e as String).toSet();
        tasksDone = (j['tasksDone'] as num?)?.toInt() ?? 0;
        focusSecTotal = (j['focusSecTotal'] as num?)?.toInt() ?? 0;
      } catch (_) {
        // Corrupt data: start fresh rather than crash.
      }
    }
    loaded = true;
    notifyListeners();
  }

  Future<void> _save() async {
    final data = jsonEncode({
      'schedules': schedules.map((s) => s.toJson()).toList(),
      'totalXp': totalXp,
      'attrXp': attrXp,
      'activeDays': activeDays.toList(),
      'tasksDone': tasksDone,
      'focusSecTotal': focusSecTotal,
    });
    await _prefs?.setString(_key, data);
  }

  void _changed() {
    notifyListeners();
    _save();
  }

  // ---------- Level ----------

  static int xpForLevel(int l) => (100 * pow(l, 1.5)).round();

  LevelInfo get levelInfo {
    var l = 1;
    var rem = totalXp;
    while (rem >= xpForLevel(l)) {
      rem -= xpForLevel(l);
      l++;
    }
    return LevelInfo(l, rem, xpForLevel(l));
  }

  int get streak {
    var day = dateOnly(DateTime.now());
    if (!activeDays.contains(dateKey(day))) day = DateTime(day.year, day.month, day.day - 1);
    var n = 0;
    while (activeDays.contains(dateKey(day))) {
      n++;
      day = DateTime(day.year, day.month, day.day - 1);
    }
    return n;
  }

  // ---------- Schedules ----------

  List<Schedule> schedulesOn(DateTime day) {
    final list = schedules.where((s) => s.rec.occursOn(day)).toList();
    list.sort((a, b) => a.startMin.compareTo(b.startMin));
    return list;
  }

  void upsert(Schedule s) {
    final i = schedules.indexWhere((e) => e.id == s.id);
    if (i >= 0) {
      schedules[i] = s;
    } else {
      schedules.add(s);
    }
    _changed();
  }

  void delete(Schedule s) {
    schedules.removeWhere((e) => e.id == s.id);
    _changed();
  }

  void touch() => _changed();

  void _addXp(Schedule s, int xp) {
    totalXp = max(0, totalXp + xp);
    attrXp[s.attr] = max(0, (attrXp[s.attr] ?? 0) + xp);
  }

  /// Toggle a task (or '_self' for a schedule without tasks) on a given date.
  /// Returns the XP gained (negative when unchecked).
  int toggleTask(Schedule s, DateTime day, String taskId) {
    final o = s.occFor(day);
    int xp;
    if (taskId == '_self') {
      xp = s.selfXp;
    } else {
      final t = s.tasks.firstWhere((t) => t.id == taskId);
      xp = s.taskXp(t);
    }
    if (o.done.contains(taskId)) {
      o.done.remove(taskId);
      tasksDone = max(0, tasksDone - 1);
      _addXp(s, -xp);
      xp = -xp;
    } else {
      o.done.add(taskId);
      tasksDone++;
      _addXp(s, xp);
      activeDays.add(dateKey(DateTime.now()));
    }
    _changed();
    return xp;
  }

  /// Called every second while a focus session runs. Returns XP gained (0 or 1).
  int addFocusSecond(Schedule s, DateTime day) {
    final o = s.occFor(day);
    o.focusSec++;
    focusSecTotal++;
    var gained = 0;
    final capMin = (s.duration * 1.2).round();
    if (o.focusSec % 60 == 0 && s.calcType == 'duration' && o.focusXp < capMin) {
      o.focusXp++;
      _addXp(s, 1);
      gained = 1;
    }
    if (o.focusSec >= 5 * 60) activeDays.add(dateKey(DateTime.now()));
    notifyListeners();
    if (o.focusSec % 15 == 0) _save();
    return gained;
  }

  int tasksTotalOn(DateTime day) {
    var n = 0;
    for (final s in schedulesOn(day)) {
      n += s.tasks.isEmpty ? 1 : s.tasks.length;
    }
    return n;
  }

  int tasksDoneOn(DateTime day) {
    var n = 0;
    for (final s in schedulesOn(day)) {
      final o = s.peekOcc(day);
      if (o != null) n += o.done.length;
    }
    return n;
  }

  int focusMinOn(DateTime day) {
    var sec = 0;
    for (final s in schedulesOn(day)) {
      sec += s.peekOcc(day)?.focusSec ?? 0;
    }
    return sec ~/ 60;
  }

  Future<void> resetAll() async {
    schedules.clear();
    totalXp = 0;
    attrXp = {'INT': 0, 'STR': 0, 'CHA': 0, 'WIS': 0};
    activeDays = {};
    tasksDone = 0;
    focusSecTotal = 0;
    _changed();
  }
}

final appState = AppState();

String newId() => '${DateTime.now().microsecondsSinceEpoch}${Random().nextInt(9999)}';
