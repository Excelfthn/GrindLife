String dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime nextDay(DateTime d) => DateTime(d.year, d.month, d.day + 1);

String hhmm(int minutes) {
  final h = (minutes ~/ 60) % 24;
  final m = minutes % 60;
  return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
}

const weekdayShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const monthShort = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String niceDate(DateTime d) => '${weekdayShort[d.weekday - 1]} ${d.day} ${monthShort[d.month - 1]}';

class TaskItem {
  TaskItem({required this.id, required this.title, this.weight = 2});
  String id;
  String title;
  int weight; // 1 Easy, 2 Medium, 4 Hard

  String get weightLabel => weight == 1 ? 'Easy' : (weight == 4 ? 'Hard' : 'Medium');

  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'weight': weight};
  factory TaskItem.fromJson(Map<String, dynamic> j) =>
      TaskItem(id: j['id'] as String, title: j['title'] as String, weight: (j['weight'] as num?)?.toInt() ?? 2);
}

class Recurrence {
  Recurrence({
    this.type = 'weekly',
    List<int>? weekdays,
    this.monthDay = 1,
    required this.start,
    this.endMode = 'never',
    this.until,
    this.count = 12,
  }) : weekdays = weekdays ?? [DateTime.now().weekday];

  String type; // once, daily, weekly, monthly
  List<int> weekdays; // DateTime.weekday values, 1 = Monday
  int monthDay;
  DateTime start; // first day (also the date for "once")
  String endMode; // never, date, count
  DateTime? until;
  int count;

  bool _matches(DateTime d) {
    switch (type) {
      case 'once':
        return d == dateOnly(start);
      case 'daily':
      case 'weekly':
        return weekdays.contains(d.weekday);
      case 'monthly':
        final last = DateTime(d.year, d.month + 1, 0).day;
        return d.day == (monthDay > last ? last : monthDay);
    }
    return false;
  }

  bool occursOn(DateTime day) {
    final d = dateOnly(day);
    final s = dateOnly(start);
    if (d.isBefore(s)) return false;
    if (!_matches(d)) return false;
    if (type == 'once') return true;
    if (endMode == 'date' && until != null && d.isAfter(dateOnly(until!))) return false;
    if (endMode == 'count') {
      var n = 0;
      var cur = s;
      while (!cur.isAfter(d)) {
        if (_matches(cur)) n++;
        if (n > count) return false;
        cur = nextDay(cur);
      }
    }
    return true;
  }

  Map<String, dynamic> toJson() => {
        'type': type,
        'weekdays': weekdays,
        'monthDay': monthDay,
        'start': start.toIso8601String(),
        'endMode': endMode,
        'until': until?.toIso8601String(),
        'count': count,
      };

  factory Recurrence.fromJson(Map<String, dynamic> j) => Recurrence(
        type: j['type'] as String? ?? 'weekly',
        weekdays: ((j['weekdays'] as List?) ?? const []).map((e) => (e as num).toInt()).toList(),
        monthDay: (j['monthDay'] as num?)?.toInt() ?? 1,
        start: DateTime.parse(j['start'] as String),
        endMode: j['endMode'] as String? ?? 'never',
        until: j['until'] == null ? null : DateTime.parse(j['until'] as String),
        count: (j['count'] as num?)?.toInt() ?? 12,
      );

  Recurrence copy() => Recurrence.fromJson(toJson());
}

class OccState {
  OccState({List<String>? done, this.focusSec = 0, this.focusXp = 0}) : done = done ?? [];
  List<String> done; // task ids done (or '_self' for a schedule without tasks)
  int focusSec;
  int focusXp;

  Map<String, dynamic> toJson() => {'done': done, 'focusSec': focusSec, 'focusXp': focusXp};
  factory OccState.fromJson(Map<String, dynamic> j) => OccState(
        done: ((j['done'] as List?) ?? const []).map((e) => e as String).toList(),
        focusSec: (j['focusSec'] as num?)?.toInt() ?? 0,
        focusXp: (j['focusXp'] as num?)?.toInt() ?? 0,
      );
}

class Schedule {
  Schedule({
    required this.id,
    required this.title,
    required this.startMin,
    required this.endMin,
    required this.rec,
    this.attr = 'INT',
    this.attrManual = false,
    this.location = '',
    this.notes = '',
    this.reminder = 10,
    List<TaskItem>? tasks,
    Map<String, OccState>? occ,
  })  : tasks = tasks ?? [],
        occ = occ ?? {};

  String id;
  String title;
  int startMin;
  int endMin;
  Recurrence rec;
  String attr;
  bool attrManual;
  String location;
  String notes;
  int reminder; // minutes before start, 0 = at start
  List<TaskItem> tasks;
  Map<String, OccState> occ;

  /// True when the schedule ends after midnight (end time earlier than start).
  bool get overnight => endMin < startMin;
  int get duration => overnight ? endMin + 24 * 60 - startMin : (endMin - startMin).clamp(0, 24 * 60).toInt();
  String get calcType => guessCalcType(title, duration);
  int get pool => calcType == 'none' ? 0 : (duration * 0.5).round();

  int taskXp(TaskItem t) {
    final sum = tasks.fold<int>(0, (a, b) => a + b.weight);
    if (sum == 0) return 0;
    return (pool * t.weight / sum).round();
  }

  /// XP for marking a schedule without tasks as done.
  int get selfXp => calcType == 'none' ? 0 : (pool < 10 ? 10 : pool);

  OccState occFor(DateTime d) => occ.putIfAbsent(dateKey(d), () => OccState());
  OccState? peekOcc(DateTime d) => occ[dateKey(d)];

  bool doneOn(DateTime d) {
    final o = peekOcc(d);
    if (o == null) return false;
    if (tasks.isEmpty) return o.done.contains('_self');
    return tasks.every((t) => o.done.contains(t.id));
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'startMin': startMin,
        'endMin': endMin,
        'rec': rec.toJson(),
        'attr': attr,
        'attrManual': attrManual,
        'location': location,
        'notes': notes,
        'reminder': reminder,
        'tasks': tasks.map((t) => t.toJson()).toList(),
        'occ': occ.map((k, v) => MapEntry(k, v.toJson())),
      };

  factory Schedule.fromJson(Map<String, dynamic> j) => Schedule(
        id: j['id'] as String,
        title: j['title'] as String,
        startMin: (j['startMin'] as num).toInt(),
        endMin: (j['endMin'] as num).toInt(),
        rec: Recurrence.fromJson(Map<String, dynamic>.from(j['rec'] as Map)),
        attr: j['attr'] as String? ?? 'INT',
        attrManual: j['attrManual'] as bool? ?? false,
        location: j['location'] as String? ?? '',
        notes: j['notes'] as String? ?? '',
        reminder: (j['reminder'] as num?)?.toInt() ?? 10,
        tasks: ((j['tasks'] as List?) ?? const [])
            .map((e) => TaskItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        occ: ((j['occ'] as Map?) ?? const {}).map(
          (k, v) => MapEntry(k as String, OccState.fromJson(Map<String, dynamic>.from(v as Map))),
        ),
      );
}

// ---------- Lightweight classifiers (keyword layer) ----------

bool _hasWord(String text, String word) {
  final t = ' ${text.toLowerCase().replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')} ';
  return t.contains(' $word ') || t.contains(' $word');
}

const _checklistWords = ['send', 'pay', 'submit', 'buy', 'email', 'register', 'kirim', 'bayar', 'beli', 'daftar'];
const _noXpWords = ['eat', 'lunch', 'dinner', 'breakfast', 'relax', 'chill', 'movie', 'makan', 'istirahat', 'santai', 'nonton'];

/// 'duration', 'checklist' or 'none'.
String guessCalcType(String title, int durationMin) {
  if (_noXpWords.any((w) => _hasWord(title, w))) return 'none';
  if (_checklistWords.any((w) => _hasWord(title, w))) return 'checklist';
  return durationMin >= 15 ? 'duration' : 'checklist';
}

const _attrWords = {
  'STR': ['jog', 'run', 'gym', 'workout', 'exercise', 'swim', 'cycling', 'bike', 'football', 'futsal', 'badminton', 'tennis', 'hiking', 'yoga', 'pushup', 'stretch', 'lari', 'olahraga', 'renang', 'sepeda', 'senam'],
  'CHA': ['meet', 'meeting', 'call', 'networking', 'hangout', 'interview', 'presentation', 'pitch', 'family', 'friend', 'date', 'event', 'ketemu', 'rapat', 'nongkrong', 'organisasi', 'presentasi', 'keluarga', 'teman'],
  'WIS': ['sleep', 'nap', 'meditate', 'meditation', 'pray', 'journal', 'reflect', 'review', 'rest', 'tidur', 'meditasi', 'sholat', 'ibadah', 'jurnal', 'refleksi', 'ngaji'],
  'INT': ['study', 'learn', 'class', 'lecture', 'thesis', 'read', 'homework', 'exam', 'code', 'coding', 'research', 'report', 'course', 'belajar', 'kuliah', 'skripsi', 'baca', 'tugas', 'ngoding', 'riset', 'laporan'],
};

String guessAttr(String title) {
  for (final entry in _attrWords.entries) {
    if (entry.value.any((w) => _hasWord(title, w))) return entry.key;
  }
  return 'INT';
}
