import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

const Color kVoidBackground = Color(0xFF07070A);
const Color kVoidAccent = Color(0xFF8B5CF6);
const Color kVoidGoalComplete = Color(0xFF34D399);
const int kVoidFocusCalendarDays = 30;

const _kCompletedSessions = 'completedSessions';
const _kTotalFocusSeconds = 'totalFocusSeconds';
const _kTotalFocusMinutes = 'totalFocusMinutes';
const _kFocusDataUsesSeconds = 'focus_data_uses_seconds';
const _kCurrentStreak = 'currentStreak';
const _kBestStreak = 'bestStreak';
const _kLastActiveDate = 'last_active_date';
const _kDailyActivity = 'daily_activity';
const _kTodaySessionsDate = 'todaySessionsDate';
const _kTodaySessions = 'todaySessions';
const _kTotalDistractions = 'totalDistractions';
const _kSessionDistractionsHistory = 'session_distractions_history';
const _kPreventedDistractionMinutes = 'prevented_distraction_minutes';
const _kSessionHistory = 'session_history';
const _kSessionFocusSecondsHistory = 'session_focus_seconds_history';
const _kSessionHistoryManuallyCleared = 'session_history_manually_cleared';
const _kDailyGoalMinutes = 'daily_goal_minutes';
const _kDailyGoalAchieved = 'daily_goal_achieved';
const _kDefaultDailyGoalMinutes = 60;
const kVoidAppVersion = '1.0.0';
const kVoidRuStoreUrl = 'https://www.rustore.ru/catalog/app/ru.voidapp.focus';

const _kDayLabels = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
const _kMonthLabels = [
  'января',
  'февраля',
  'марта',
  'апреля',
  'мая',
  'июня',
  'июля',
  'августа',
  'сентября',
  'октября',
  'ноября',
  'декабря',
];

class VoidSessionRecord {
  const VoidSessionRecord({
    required this.completedAt,
    required this.focusSeconds,
    required this.distractions,
    required this.focusScore,
    required this.xp,
  });

  final DateTime completedAt;
  final int focusSeconds;
  final int distractions;
  final int focusScore;
  final int xp;

  Map<String, dynamic> toJson() => {
        'completedAt': completedAt.toIso8601String(),
        'focusSeconds': focusSeconds,
        'distractions': distractions,
        'focusScore': focusScore,
        'xp': xp,
      };

  factory VoidSessionRecord.fromJson(Map<String, dynamic> json) {
    final distractions = json['distractions'] as int? ?? 0;
    return VoidSessionRecord(
      completedAt: DateTime.parse(json['completedAt'] as String),
      focusSeconds: json['focusSeconds'] as int? ?? 0,
      distractions: distractions,
      focusScore: computeFocusScore(distractions),
      xp: json['xp'] as int? ?? 0,
    );
  }
}

String formatSessionDateTime(DateTime dateTime) {
  final day = dateTime.day.toString().padLeft(2, '0');
  final month = dateTime.month.toString().padLeft(2, '0');
  final year = dateTime.year;
  final hour = dateTime.hour.toString().padLeft(2, '0');
  final minute = dateTime.minute.toString().padLeft(2, '0');
  return '$day.$month.$year · $hour:$minute';
}

enum VoidFocusDayStatus { none, partial, completed }

VoidFocusDayStatus resolveFocusDayStatus({
  required int focusSeconds,
  required int goalMinutes,
}) {
  if (focusSeconds <= 0) return VoidFocusDayStatus.none;
  if (focusSeconds >= goalMinutes * 60) return VoidFocusDayStatus.completed;
  return VoidFocusDayStatus.partial;
}

Color focusDayStatusColor(VoidFocusDayStatus status) {
  switch (status) {
    case VoidFocusDayStatus.completed:
      return kVoidGoalComplete;
    case VoidFocusDayStatus.partial:
      return kVoidAccent;
    case VoidFocusDayStatus.none:
      return Colors.white.withValues(alpha: 0.14);
  }
}

class VoidDayActivity {
  const VoidDayActivity({
    required this.date,
    required this.focusSeconds,
    this.sessionsCount = 0,
    this.distractions = 0,
    this.averageFocusScore = 0,
    this.xpEarned = 0,
  });

  final DateTime date;
  final int focusSeconds;
  final int sessionsCount;
  final int distractions;
  final double averageFocusScore;
  final int xpEarned;

  String get dayLabel => _kDayLabels[date.weekday - 1];

  bool get hasActivity => focusSeconds > 0 || sessionsCount > 0;

  VoidFocusDayStatus status(int goalMinutes) => resolveFocusDayStatus(
        focusSeconds: focusSeconds,
        goalMinutes: goalMinutes,
      );
}

class VoidCalendarMonthStats {
  const VoidCalendarMonthStats({
    required this.activeDays,
    required this.totalFocusSeconds,
    required this.longestStreak,
  });

  final int activeDays;
  final int totalFocusSeconds;
  final int longestStreak;

  factory VoidCalendarMonthStats.fromDays(List<VoidDayActivity> days) {
    return VoidCalendarMonthStats(
      activeDays: days.where((day) => day.hasActivity).length,
      totalFocusSeconds: days.fold<int>(
        0,
        (sum, day) => sum + day.focusSeconds,
      ),
      longestStreak: computeLongestActiveStreak(days),
    );
  }
}

int computeLongestActiveStreak(List<VoidDayActivity> days) {
  var longest = 0;
  var current = 0;
  for (final day in days) {
    if (day.hasActivity) {
      current++;
      if (current > longest) {
        longest = current;
      }
    } else {
      current = 0;
    }
  }
  return longest;
}

DateTime normalizeActivityDate(DateTime date) =>
    DateTime(date.year, date.month, date.day);

Set<DateTime> activeDatesFromActivity(Map<String, int> activity) {
  return activity.entries
      .where((entry) => entry.value > 0)
      .map((entry) => normalizeActivityDate(_parseDateKey(entry.key)))
      .toSet();
}

int computeCurrentStreakFromActivity(Map<String, int> activity) {
  final activeDates = activeDatesFromActivity(activity);
  if (activeDates.isEmpty) return 0;

  final today = normalizeActivityDate(DateTime.now());
  final yesterday = today.subtract(const Duration(days: 1));

  if (!activeDates.contains(today) && !activeDates.contains(yesterday)) {
    return 0;
  }

  var cursor = activeDates.contains(today) ? today : yesterday;
  var streak = 0;
  while (activeDates.contains(cursor)) {
    streak++;
    cursor = cursor.subtract(const Duration(days: 1));
  }
  return streak;
}

int computeBestStreakFromActivity(Map<String, int> activity) {
  final dates = activeDatesFromActivity(activity).toList()..sort();
  if (dates.isEmpty) return 0;
  if (dates.length == 1) return 1;

  var best = 1;
  var current = 1;
  for (var index = 1; index < dates.length; index++) {
    final gap = dates[index].difference(dates[index - 1]).inDays;
    if (gap == 1) {
      current++;
      if (current > best) best = current;
    } else {
      current = 1;
    }
  }
  return best;
}

Map<String, VoidDayActivity> aggregateDayActivityFromSessions(
  List<VoidSessionRecord> history,
) {
  final aggregates = <String, _VoidDaySessionAggregate>{};
  for (final session in history) {
    final key = StatsService.dateKey(session.completedAt);
    final aggregate = aggregates.putIfAbsent(
      key,
      () => const _VoidDaySessionAggregate(),
    );
    aggregates[key] = aggregate.copyWith(
      sessionsCount: aggregate.sessionsCount + 1,
      focusSeconds: aggregate.focusSeconds + session.focusSeconds,
      distractions: aggregate.distractions + session.distractions,
      focusScoreSum: aggregate.focusScoreSum + session.focusScore,
      xpEarned: aggregate.xpEarned + session.xp,
    );
  }

  return aggregates.map(
    (key, aggregate) => MapEntry(
      key,
      VoidDayActivity(
        date: _parseDateKey(key),
        focusSeconds: aggregate.focusSeconds,
        sessionsCount: aggregate.sessionsCount,
        distractions: aggregate.distractions,
        averageFocusScore: aggregate.sessionsCount == 0
            ? 0
            : aggregate.focusScoreSum / aggregate.sessionsCount,
        xpEarned: aggregate.xpEarned,
      ),
    ),
  );
}

DateTime _parseDateKey(String key) {
  final parts = key.split('-');
  if (parts.length != 3) {
    return DateTime.now();
  }
  return DateTime(
    int.parse(parts[0]),
    int.parse(parts[1]),
    int.parse(parts[2]),
  );
}

class _VoidDaySessionAggregate {
  const _VoidDaySessionAggregate({
    this.sessionsCount = 0,
    this.focusSeconds = 0,
    this.distractions = 0,
    this.focusScoreSum = 0,
    this.xpEarned = 0,
  });

  final int sessionsCount;
  final int focusSeconds;
  final int distractions;
  final int focusScoreSum;
  final int xpEarned;

  _VoidDaySessionAggregate copyWith({
    int? sessionsCount,
    int? focusSeconds,
    int? distractions,
    int? focusScoreSum,
    int? xpEarned,
  }) {
    return _VoidDaySessionAggregate(
      sessionsCount: sessionsCount ?? this.sessionsCount,
      focusSeconds: focusSeconds ?? this.focusSeconds,
      distractions: distractions ?? this.distractions,
      focusScoreSum: focusScoreSum ?? this.focusScoreSum,
      xpEarned: xpEarned ?? this.xpEarned,
    );
  }
}

String formatCalendarDayTitle(DateTime date) {
  return '${date.day} ${_kMonthLabels[date.month - 1]}';
}

class VoidAchievement {
  const VoidAchievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.isUnlocked,
  });

  final String id;
  final String title;
  final String description;
  final IconData icon;
  final bool isUnlocked;
}

List<VoidAchievement> buildAchievements({
  required int completedSessions,
  required int totalFocusSeconds,
  required int currentStreak,
  required int preventedDistractionMinutes,
  required bool dailyGoalAchieved,
}) {
  return [
    VoidAchievement(
      id: 'first_session',
      title: 'Первая сессия',
      description: 'Завершите первую фокус-сессию',
      icon: Icons.flag_rounded,
      isUnlocked: completedSessions >= 1,
    ),
    VoidAchievement(
      id: 'focus_10_minutes',
      title: '10 минут фокуса',
      description: 'Накопите 10 минут фокуса',
      icon: Icons.timer_outlined,
      isUnlocked: totalFocusSeconds >= 600,
    ),
    VoidAchievement(
      id: 'focus_1_hour',
      title: '1 час фокуса',
      description: 'Накопите 1 час фокуса',
      icon: Icons.hourglass_top_rounded,
      isUnlocked: totalFocusSeconds >= 3600,
    ),
    VoidAchievement(
      id: 'sessions_10',
      title: '10 сессий',
      description: 'Завершите 10 фокус-сессий',
      icon: Icons.layers_rounded,
      isUnlocked: completedSessions >= 10,
    ),
    VoidAchievement(
      id: 'prevented_100',
      title: '100 отвлечений предотвращено',
      description: '100 минут фокуса без отвлечений',
      icon: Icons.shield_moon_rounded,
      isUnlocked: preventedDistractionMinutes >= 100,
    ),
    VoidAchievement(
      id: 'streak_7_days',
      title: '7 дней подряд',
      description: 'Поддерживайте серию 7 дней',
      icon: Icons.local_fire_department_rounded,
      isUnlocked: currentStreak >= 7,
    ),
    VoidAchievement(
      id: 'daily_goal',
      title: 'Цель дня выполнена',
      description: 'Накопите 60 минут фокуса за день',
      icon: Icons.track_changes_rounded,
      isUnlocked: dailyGoalAchieved,
    ),
  ];
}

class StatsData {
  const StatsData({
    required this.completedSessions,
    required this.totalFocusSeconds,
    required this.currentStreak,
    required this.bestStreak,
    required this.todaySessions,
    required this.distractions,
    required this.averageDistractionsPerSession,
    required this.preventedDistractionMinutes,
    required this.achievements,
    required this.sessionHistory,
    required this.todayFocusSeconds,
    required this.dailyGoalMinutes,
    required this.averageFocusScore,
    required this.last7Days,
    required this.last30Days,
  });

  final int completedSessions;
  final int totalFocusSeconds;
  final int currentStreak;
  final int bestStreak;
  final int todaySessions;
  final int distractions;
  final double averageDistractionsPerSession;
  final int preventedDistractionMinutes;
  final List<VoidAchievement> achievements;
  final List<VoidSessionRecord> sessionHistory;
  final int todayFocusSeconds;
  final int dailyGoalMinutes;
  final double averageFocusScore;
  final List<VoidDayActivity> last7Days;
  final List<VoidDayActivity> last30Days;

  int get todayFocusMinutes => todayFocusSeconds ~/ 60;

  double get dailyGoalProgress => dailyGoalMinutes <= 0
      ? 0
      : (todayFocusSeconds / (dailyGoalMinutes * 60)).clamp(0.0, 1.0);

  bool get isDailyGoalCompleted =>
      todayFocusSeconds >= dailyGoalMinutes * 60;

  int get unlockedAchievementsCount =>
      achievements.where((achievement) => achievement.isUnlocked).length;

  int get totalXp => computeTotalXp(totalFocusSeconds);

  int get level => computeLevel(totalXp);

  int get xpInCurrentLevel => computeXpInCurrentLevel(totalXp);

  double get levelProgress => computeLevelProgress(totalXp);

  static const empty = StatsData(
    completedSessions: 0,
    totalFocusSeconds: 0,
    currentStreak: 0,
    bestStreak: 0,
    todaySessions: 0,
    distractions: 0,
    averageDistractionsPerSession: 0,
    preventedDistractionMinutes: 0,
    achievements: [],
    sessionHistory: [],
    todayFocusSeconds: 0,
    dailyGoalMinutes: _kDefaultDailyGoalMinutes,
    averageFocusScore: 0,
    last7Days: [],
    last30Days: [],
  );
}

String formatDailyGoalTime(int seconds) {
  if (seconds <= 0) return '0с';
  final minutes = seconds ~/ 60;
  final remainingSeconds = seconds % 60;
  if (minutes > 0 && remainingSeconds > 0) {
    return '${minutes}м ${remainingSeconds}с';
  }
  if (minutes > 0) return '${minutes}м';
  return '${remainingSeconds}с';
}

String formatDailyGoalTarget(int goalMinutes) => '${goalMinutes}м';

String formatDailyGoalProgress(int todayFocusSeconds, int goalMinutes) {
  return '${formatDailyGoalTime(todayFocusSeconds)} / '
      '${formatDailyGoalTarget(goalMinutes)}';
}

int formatDailyGoalPercent(double progress) =>
    (progress * 100).round().clamp(0, 100);

String formatAverageDistractions(double value) {
  if (value <= 0) return '0';
  final rounded = (value * 10).round() / 10;
  if ((rounded - rounded.round()).abs() < 0.01) {
    return rounded.round().toString();
  }
  return rounded.toStringAsFixed(1).replaceAll('.', ',');
}

String formatFocusDuration(int totalSeconds) {
  if (totalSeconds <= 0) return '0 сек';
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;
  if (hours > 0) {
    final parts = <String>['${hours}ч'];
    if (minutes > 0) parts.add('${minutes}м');
    if (seconds > 0) parts.add('${seconds}с');
    return parts.join(' ');
  }
  if (minutes > 0) {
    if (seconds > 0) return '${minutes}м ${seconds}с';
    return '${minutes}м';
  }
  return '${seconds}с';
}

int computeActualFocusSeconds({
  required int totalSessionSeconds,
  required int remainingSeconds,
}) {
  if (remainingSeconds <= 0) {
    return totalSessionSeconds;
  }
  return totalSessionSeconds - remainingSeconds;
}

int computeSessionXp(int elapsedSeconds, int distractions) {
  return elapsedSeconds ~/ 60;
}

int computeTotalXp(int totalFocusSeconds) => totalFocusSeconds ~/ 60;

int computeLevel(int totalXp) => 1 + totalXp ~/ 100;

int computeXpInCurrentLevel(int totalXp) => totalXp % 100;

double computeLevelProgress(int totalXp) =>
    computeXpInCurrentLevel(totalXp) / 100;

String formatLevelXpProgress(int xpInLevel) => '$xpInLevel / 100 XP';

int computeFocusScore(int distractions) {
  return (100 - distractions * 3).clamp(0, 100);
}

String formatFocusScore(num score) {
  if (score == score.roundToDouble()) {
    return score.round().toString();
  }
  return score.toStringAsFixed(1).replaceAll('.', ',');
}

String buildVoidFeedbackBody(String intro) {
  return '$intro\n\n'
      '---\n'
      'VOID v$kVoidAppVersion\n'
      'Платформа: ${defaultTargetPlatform.name}';
}

void showVoidSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      backgroundColor: const Color(0xFF12121A),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: kVoidAccent.withValues(alpha: 0.25)),
      ),
      content: Text(
        message,
        style: TextStyle(color: Colors.white.withValues(alpha: 0.9)),
      ),
    ),
  );
}

Future<void> launchVoidExternalUri(
  BuildContext context,
  Uri uri, {
  String? clipboardFallback,
  required String failureMessage,
  String? clipboardSuccessMessage,
}) async {
  try {
    if (await canLaunchUrl(uri)) {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (launched) return;
    }
  } catch (_) {}

  if (clipboardFallback != null) {
    try {
      await Clipboard.setData(ClipboardData(text: clipboardFallback));
      if (context.mounted) {
        showVoidSnackBar(
          context,
          clipboardSuccessMessage ?? 'Текст скопирован в буфер обмена',
        );
      }
      return;
    } catch (_) {}
  }

  if (context.mounted) {
    showVoidSnackBar(context, failureMessage);
  }
}

Future<void> launchVoidMailFeedback(
  BuildContext context, {
  required String subject,
  required String body,
}) {
  final uri = Uri(
    scheme: 'mailto',
    queryParameters: <String, String>{
      'subject': subject,
      'body': body,
    },
  );

  return launchVoidExternalUri(
    context,
    uri,
    clipboardFallback: '[$subject]\n$body',
    failureMessage: 'Не удалось открыть почтовое приложение',
    clipboardSuccessMessage: 'Шаблон письма скопирован в буфер обмена',
  );
}

Future<void> launchVoidStoreListing(BuildContext context) {
  return launchVoidExternalUri(
    context,
    Uri.parse(kVoidRuStoreUrl),
    failureMessage: 'Не удалось открыть RuStore',
  );
}

class StatsService extends ChangeNotifier {
  StatsService._();

  static final StatsService instance = StatsService._();

  StatsData data = StatsData.empty;
  bool isLoading = false;
  Future<void>? _loadFuture;
  SharedPreferences? _prefs;
  Future<void>? _initFuture;

  bool get hasData => data.completedSessions > 0;
  bool get isInitialized => _prefs != null;

  Future<void> initialize({bool force = false}) {
    if (force) {
      _prefs = null;
      _initFuture = null;
    }
    if (_prefs != null) {
      return Future.value();
    }
    return _initFuture ??= _initializePrefs();
  }

  Future<void> _initializePrefs() async {
    try {
      _prefs = await SharedPreferences.getInstance();
    } catch (_) {
      _prefs = null;
      _initFuture = null;
    }
  }

  Future<SharedPreferences?> _requirePrefs() async {
    try {
      await initialize();
      return _prefs;
    } catch (_) {
      return null;
    }
  }

  static StatsData _emptyData() => StatsData(
        completedSessions: 0,
        totalFocusSeconds: 0,
        currentStreak: 0,
        bestStreak: 0,
        todaySessions: 0,
        distractions: 0,
        averageDistractionsPerSession: 0,
        preventedDistractionMinutes: 0,
        achievements: buildAchievements(
          completedSessions: 0,
          totalFocusSeconds: 0,
          currentStreak: 0,
          preventedDistractionMinutes: 0,
          dailyGoalAchieved: false,
        ),
        sessionHistory: [],
        todayFocusSeconds: 0,
        dailyGoalMinutes: _kDefaultDailyGoalMinutes,
        averageFocusScore: 0,
        last7Days: _buildLast7Days({}),
        last30Days: _buildLast30Days({}),
      );

  static double _computeAverageFocusScore({
    required List<VoidSessionRecord> history,
    required List<int> distractionsHistory,
  }) {
    if (history.isNotEmpty) {
      final total = history.fold<int>(
        0,
        (sum, record) => sum + computeFocusScore(record.distractions),
      );
      return total / history.length;
    }
    if (distractionsHistory.isNotEmpty) {
      final total = distractionsHistory.fold<int>(
        0,
        (sum, distractions) => sum + computeFocusScore(distractions),
      );
      return total / distractionsHistory.length;
    }
    return 0;
  }

  static List<VoidSessionRecord> _readSessionHistoryRaw(SharedPreferences prefs) {
    final raw = prefs.getString(_kSessionHistory);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map(
            (entry) => VoidSessionRecord.fromJson(
              entry.map((key, value) => MapEntry(key.toString(), value)),
            ),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  static List<int> _readSessionFocusSecondsHistory(SharedPreferences prefs) {
    return _parseIntList(prefs.getString(_kSessionFocusSecondsHistory));
  }

  static List<VoidSessionRecord> _buildFullSessionHistory(
    SharedPreferences prefs,
  ) {
    final completedSessions = _readCompletedSessions(prefs);
    if (completedSessions == 0) return [];

    final distractions = _readSessionDistractionsHistory(prefs);
    final focusSecondsList = _readSessionFocusSecondsHistory(prefs);
    final existing = _readSessionHistoryRaw(prefs);
    existing.sort((a, b) => b.completedAt.compareTo(a.completedAt));
    final totalFocus = _readTotalFocusSeconds(prefs);

    final knownFocusTotal = focusSecondsList.fold<int>(0, (sum, value) => sum + value);
    final legacySessionCount = completedSessions - focusSecondsList.length;
    final remainingFocus = (totalFocus - knownFocusTotal).clamp(0, totalFocus);
    final legacyFocusEstimate = legacySessionCount > 0
        ? remainingFocus ~/ legacySessionCount
        : 0;

    final records = <VoidSessionRecord>[];

    for (var i = 0; i < completedSessions; i++) {
      final distractionsValue = i < distractions.length ? distractions[i] : 0;

      int focusSecondsValue;
      if (i < focusSecondsList.length) {
        focusSecondsValue = focusSecondsList[i];
      } else {
        focusSecondsValue = legacyFocusEstimate;
      }

      final newestIndex = completedSessions - 1 - i;
      DateTime completedAt;
      if (newestIndex < existing.length) {
        final existingRecord = existing[newestIndex];
        completedAt = existingRecord.completedAt;
        if (existingRecord.focusSeconds > 0 &&
            i >= focusSecondsList.length) {
          focusSecondsValue = existingRecord.focusSeconds;
        }
      } else {
        completedAt = DateTime.now().subtract(
          Duration(days: completedSessions - 1 - i, minutes: i * 7),
        );
      }

      records.add(
        VoidSessionRecord(
          completedAt: completedAt,
          focusSeconds: focusSecondsValue,
          distractions: distractionsValue,
          focusScore: computeFocusScore(distractionsValue),
          xp: computeSessionXp(focusSecondsValue, distractionsValue),
        ),
      );
    }

    records.sort((a, b) => b.completedAt.compareTo(a.completedAt));
    return records;
  }

  static Future<List<VoidSessionRecord>> _syncSessionHistory(
    SharedPreferences prefs,
  ) async {
    if (prefs.getBool(_kSessionHistoryManuallyCleared) == true) {
      return [];
    }
    final rebuilt = _buildFullSessionHistory(prefs);
    await prefs.setString(
      _kSessionHistory,
      jsonEncode(rebuilt.map((record) => record.toJson()).toList()),
    );
    return rebuilt;
  }

  static List<VoidSessionRecord> _readSessionHistory(SharedPreferences prefs) {
    final history = _readSessionHistoryRaw(prefs);
    history.sort((a, b) => b.completedAt.compareTo(a.completedAt));
    return history;
  }

  static List<int> _parseIntList(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .map((value) => value is num ? value.toInt() : int.tryParse('$value') ?? 0)
          .toList();
    } catch (_) {
      return [];
    }
  }

  static List<int> _readSessionDistractionsHistory(SharedPreferences prefs) {
    return _parseIntList(prefs.getString(_kSessionDistractionsHistory));
  }

  static double _computeAverageDistractions({
    required List<int> history,
    required int completedSessions,
    required int totalDistractions,
  }) {
    if (completedSessions == 0) return 0;
    if (history.isNotEmpty) {
      return history.fold<int>(0, (sum, value) => sum + value) / history.length;
    }
    return totalDistractions / completedSessions;
  }

  int _readTodaySessions(SharedPreferences prefs) {
    final today = _dateKey(DateTime.now());
    final storedDate = prefs.getString(_kTodaySessionsDate);
    if (storedDate != today) return 0;
    return prefs.getInt(_kTodaySessions) ?? 0;
  }

  static String dateKey(DateTime date) => _dateKey(date);

  static String _dateKey(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static List<VoidDayActivity> _buildLast7Days(
    Map<String, int> activity, [
    List<VoidSessionRecord> sessionHistory = const [],
  ]) {
    return _buildLastDays(activity, 7, sessionHistory);
  }

  static List<VoidDayActivity> _buildLast30Days(
    Map<String, int> activity, [
    List<VoidSessionRecord> sessionHistory = const [],
  ]) {
    return _buildLastDays(activity, kVoidFocusCalendarDays, sessionHistory);
  }

  static List<VoidDayActivity> _buildLastDays(
    Map<String, int> activity,
    int dayCount,
    List<VoidSessionRecord> sessionHistory,
  ) {
    final sessionDays = aggregateDayActivityFromSessions(sessionHistory);
    final today = DateTime.now();
    return List<VoidDayActivity>.generate(dayCount, (index) {
      final date = DateTime(today.year, today.month, today.day)
          .subtract(Duration(days: dayCount - 1 - index));
      final key = _dateKey(date);
      final sessionDay = sessionDays[key];
      final focusSeconds = activity[key] ?? sessionDay?.focusSeconds ?? 0;
      final sessionsCount = sessionDay?.sessionsCount ?? 0;
      final xpEarned = sessionDay != null && sessionsCount > 0
          ? sessionDay.xpEarned
          : focusSeconds > 0
              ? focusSeconds ~/ 60
              : 0;
      return VoidDayActivity(
        date: date,
        focusSeconds: focusSeconds,
        sessionsCount: sessionsCount,
        distractions: sessionDay?.distractions ?? 0,
        averageFocusScore: sessionDay?.averageFocusScore ?? 0,
        xpEarned: xpEarned,
      );
    });
  }

  static Map<String, int> _parseActivity(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      return decoded.map(
        (key, value) => MapEntry(
          key.toString(),
          value is num ? value.toInt() : int.tryParse('$value') ?? 0,
        ),
      );
    } catch (_) {
      return {};
    }
  }

  Future<void> load({bool force = false}) {
    if (force) {
      _loadFuture = null;
    }
    return _loadFuture ??= _loadInternal().whenComplete(() {
      _loadFuture = null;
    });
  }

  void scheduleLoad({bool force = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(load(force: force));
    });
  }

  static int _readCompletedSessions(SharedPreferences prefs) {
    return prefs.getInt(_kCompletedSessions) ??
        prefs.getInt('total_sessions') ??
        0;
  }

  Future<void> _migrateToSecondsIfNeeded(SharedPreferences prefs) async {
    if (prefs.getBool(_kFocusDataUsesSeconds) == true) return;

    if (!prefs.containsKey(_kTotalFocusSeconds)) {
      if (prefs.containsKey(_kTotalFocusMinutes)) {
        await prefs.setInt(
          _kTotalFocusSeconds,
          (prefs.getInt(_kTotalFocusMinutes) ?? 0) * 60,
        );
        final activity = _parseActivity(prefs.getString(_kDailyActivity));
        if (activity.isNotEmpty) {
          final migrated =
              activity.map((key, value) => MapEntry(key, value * 60));
          await prefs.setString(_kDailyActivity, jsonEncode(migrated));
        }
      } else {
        await prefs.setInt(
          _kTotalFocusSeconds,
          prefs.getInt('total_focus_seconds') ?? 0,
        );
      }
    }

    await prefs.setBool(_kFocusDataUsesSeconds, true);
  }

  static int _readTotalFocusSeconds(SharedPreferences prefs) {
    return prefs.getInt(_kTotalFocusSeconds) ?? 0;
  }

  int _readCurrentStreak(SharedPreferences prefs) {
    return prefs.getInt(_kCurrentStreak) ??
        prefs.getInt('current_streak') ??
        0;
  }

  int _readBestStreak(SharedPreferences prefs) {
    return prefs.getInt(_kBestStreak) ?? 0;
  }

  static Future<({int current, int best})> _syncStreakFromActivity(
    SharedPreferences prefs,
    Map<String, int> activity,
  ) async {
    final current = computeCurrentStreakFromActivity(activity);
    final computedBest = computeBestStreakFromActivity(activity);
    final storedBest = prefs.getInt(_kBestStreak) ?? 0;
    final best = computedBest > storedBest ? computedBest : storedBest;

    if (prefs.getInt(_kCurrentStreak) != current) {
      await prefs.setInt(_kCurrentStreak, current);
    }
    if (best != storedBest) {
      await prefs.setInt(_kBestStreak, best);
    }

    final today = _dateKey(DateTime.now());
    if (activity[today] != null && activity[today]! > 0) {
      await prefs.setString(_kLastActiveDate, today);
    }

    return (current: current, best: best);
  }

  int _readTodayFocusSeconds(
    SharedPreferences prefs,
    Map<String, int> activity,
  ) {
    return activity[_dateKey(DateTime.now())] ?? 0;
  }

  int _readDailyGoalMinutes(SharedPreferences prefs) {
    return prefs.getInt(_kDailyGoalMinutes) ?? _kDefaultDailyGoalMinutes;
  }

  static bool _readDailyGoalAchieved(SharedPreferences prefs) {
    return prefs.getBool(_kDailyGoalAchieved) ?? false;
  }

  static bool _activityContainsDailyGoal(
    Map<String, int> activity,
    int goalMinutes,
  ) {
    final threshold = goalMinutes * 60;
    return activity.values.any((seconds) => seconds >= threshold);
  }

  Future<void> _syncDailyGoalAchieved(
    SharedPreferences prefs,
    Map<String, int> activity,
    int goalMinutes,
  ) async {
    if (_readDailyGoalAchieved(prefs)) return;
    if (_activityContainsDailyGoal(activity, goalMinutes)) {
      await prefs.setBool(_kDailyGoalAchieved, true);
    }
  }

  Future<void> _loadInternal() async {
    isLoading = true;
    notifyListeners();

    try {
      await initialize();
      final prefs = await _requirePrefs();
      if (prefs == null) {
        data = _emptyData();
        return;
      }

      await _migrateToSecondsIfNeeded(prefs);

      final activity = _parseActivity(prefs.getString(_kDailyActivity));
      final completedSessions = _readCompletedSessions(prefs);
      final totalFocusSeconds = _readTotalFocusSeconds(prefs);
      final streak = await _syncStreakFromActivity(prefs, activity);
      final currentStreak = streak.current;
      final bestStreak = streak.best;
      final todaySessions = _readTodaySessions(prefs);
      final distractions = prefs.getInt(_kTotalDistractions) ?? 0;
      final sessionDistractionsHistory =
          _readSessionDistractionsHistory(prefs);
      final averageDistractionsPerSession = _computeAverageDistractions(
        history: sessionDistractionsHistory,
        completedSessions: completedSessions,
        totalDistractions: distractions,
      );
      final preventedDistractionMinutes =
          prefs.getInt(_kPreventedDistractionMinutes) ?? 0;
      final dailyGoalMinutes = _readDailyGoalMinutes(prefs);
      await _syncDailyGoalAchieved(prefs, activity, dailyGoalMinutes);
      final dailyGoalAchieved = _readDailyGoalAchieved(prefs);
      final achievements = buildAchievements(
        completedSessions: completedSessions,
        totalFocusSeconds: totalFocusSeconds,
        currentStreak: currentStreak,
        preventedDistractionMinutes: preventedDistractionMinutes,
        dailyGoalAchieved: dailyGoalAchieved,
      );
      final sessionHistory = await _syncSessionHistory(prefs);
      final todayFocusSeconds = _readTodayFocusSeconds(prefs, activity);
      final averageFocusScore = _computeAverageFocusScore(
        history: sessionHistory,
        distractionsHistory: sessionDistractionsHistory,
      );

      data = StatsData(
        completedSessions: completedSessions,
        totalFocusSeconds: totalFocusSeconds,
        currentStreak: currentStreak,
        bestStreak: bestStreak,
        todaySessions: todaySessions,
        distractions: distractions,
        averageDistractionsPerSession: averageDistractionsPerSession,
        preventedDistractionMinutes: preventedDistractionMinutes,
        achievements: achievements,
        sessionHistory: sessionHistory,
        todayFocusSeconds: todayFocusSeconds,
        dailyGoalMinutes: dailyGoalMinutes,
        averageFocusScore: averageFocusScore,
        last7Days: _buildLast7Days(activity, sessionHistory),
        last30Days: _buildLast30Days(activity, sessionHistory),
      );

    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> completeSession({
    required int focusSeconds,
    int sessionDistractions = 0,
  }) async {
    await initialize();
    final prefs = await _requirePrefs();
    if (prefs == null) {
      return false;
    }

    try {
      await _migrateToSecondsIfNeeded(prefs);

      final today = _dateKey(DateTime.now());
      final yesterday =
          _dateKey(DateTime.now().subtract(const Duration(days: 1)));

      final completedSessions = _readCompletedSessions(prefs) + 1;
      final totalFocusSeconds =
          _readTotalFocusSeconds(prefs) + focusSeconds;

      final activity = _parseActivity(prefs.getString(_kDailyActivity));
      activity[today] = (activity[today] ?? 0) + focusSeconds;

      final todaySessions = _readTodaySessions(prefs) + 1;
      final totalDistractions =
          (prefs.getInt(_kTotalDistractions) ?? 0) + sessionDistractions;
      final sessionDistractionsHistory =
          _readSessionDistractionsHistory(prefs)..add(sessionDistractions);
      final sessionFocusSecondsHistory =
          _readSessionFocusSecondsHistory(prefs)..add(focusSeconds);

      await prefs.setInt(_kCompletedSessions, completedSessions);
      await prefs.setInt(_kTotalFocusSeconds, totalFocusSeconds);
      await prefs.setString(_kDailyActivity, jsonEncode(activity));
      await _syncStreakFromActivity(prefs, activity);
      await prefs.setString(_kTodaySessionsDate, today);
      await prefs.setInt(_kTodaySessions, todaySessions);
      await prefs.setInt(_kTotalDistractions, totalDistractions);
      await prefs.setString(
        _kSessionDistractionsHistory,
        jsonEncode(sessionDistractionsHistory),
      );
      await prefs.setString(
        _kSessionFocusSecondsHistory,
        jsonEncode(sessionFocusSecondsHistory),
      );
      await prefs.setBool(_kSessionHistoryManuallyCleared, false);

      if (sessionDistractions == 0 && focusSeconds > 0) {
        final preventedMinutes =
            (prefs.getInt(_kPreventedDistractionMinutes) ?? 0) +
                focusSeconds ~/ 60;
        await prefs.setInt(_kPreventedDistractionMinutes, preventedMinutes);
      }

      await _syncSessionHistory(prefs);

      final dailyGoalMinutes = _readDailyGoalMinutes(prefs);
      if ((activity[today] ?? 0) >= dailyGoalMinutes * 60) {
        await prefs.setBool(_kDailyGoalAchieved, true);
      }
    } catch (_) {
      return false;
    }

    _loadFuture = null;
    await _loadInternal();
    return true;
  }

  Future<bool> resetAllStats() async {
    await initialize();
    final prefs = await _requirePrefs();
    if (prefs == null) {
      return false;
    }

    try {
      await prefs.setInt(_kCompletedSessions, 0);
      await prefs.setInt(_kTotalFocusSeconds, 0);
      await prefs.setInt(_kCurrentStreak, 0);
      await prefs.setInt(_kBestStreak, 0);
      await prefs.remove(_kLastActiveDate);
      await prefs.setString(_kDailyActivity, jsonEncode({}));
      await prefs.remove(_kTodaySessionsDate);
      await prefs.setInt(_kTodaySessions, 0);
      await prefs.setInt(_kTotalDistractions, 0);
      await prefs.setString(_kSessionDistractionsHistory, jsonEncode([]));
      await prefs.setInt(_kPreventedDistractionMinutes, 0);
      await prefs.setString(_kSessionHistory, jsonEncode([]));
      await prefs.setString(_kSessionFocusSecondsHistory, jsonEncode([]));
      await prefs.setBool(_kSessionHistoryManuallyCleared, false);
      await prefs.setBool(_kDailyGoalAchieved, false);
    } catch (_) {
      return false;
    }

    _loadFuture = null;
    await _loadInternal();
    return true;
  }

  Future<bool> clearSessionHistory() async {
    await initialize();
    final prefs = await _requirePrefs();
    if (prefs == null) {
      return false;
    }

    try {
      await prefs.setString(_kSessionHistory, jsonEncode([]));
      await prefs.setString(_kSessionDistractionsHistory, jsonEncode([]));
      await prefs.setString(_kSessionFocusSecondsHistory, jsonEncode([]));
      await prefs.setBool(_kSessionHistoryManuallyCleared, true);
    } catch (_) {
      return false;
    }

    _loadFuture = null;
    await _loadInternal();
    return true;
  }

  Future<String> exportData() async {
    await load();
    final stats = data;
    final export = {
      'exportedAt': DateTime.now().toIso8601String(),
      'appVersion': kVoidAppVersion,
      'completedSessions': stats.completedSessions,
      'totalFocusSeconds': stats.totalFocusSeconds,
      'currentStreak': stats.currentStreak,
      'bestStreak': stats.bestStreak,
      'todaySessions': stats.todaySessions,
      'totalDistractions': stats.distractions,
      'averageDistractionsPerSession': stats.averageDistractionsPerSession,
      'preventedDistractionMinutes': stats.preventedDistractionMinutes,
      'todayFocusSeconds': stats.todayFocusSeconds,
      'dailyGoalMinutes': stats.dailyGoalMinutes,
      'averageFocusScore': stats.averageFocusScore,
      'totalXp': stats.totalXp,
      'level': stats.level,
      'xpInCurrentLevel': stats.xpInCurrentLevel,
      'unlockedAchievementsCount': stats.unlockedAchievementsCount,
      'last7Days': stats.last7Days
          .map(
            (day) => {
              'date': _dateKey(day.date),
              'focusSeconds': day.focusSeconds,
            },
          )
          .toList(),
      'last30Days': stats.last30Days
          .map(
            (day) => {
              'date': _dateKey(day.date),
              'focusSeconds': day.focusSeconds,
              'status': resolveFocusDayStatus(
                focusSeconds: day.focusSeconds,
                goalMinutes: stats.dailyGoalMinutes,
              ).name,
            },
          )
          .toList(),
      'sessionHistory':
          stats.sessionHistory.map((session) => session.toJson()).toList(),
      'achievements': stats.achievements
          .map(
            (achievement) => {
              'id': achievement.id,
              'title': achievement.title,
              'isUnlocked': achievement.isUnlocked,
            },
          )
          .toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(export);
  }
}

class VoidMetrics {
  VoidMetrics._({
    required this.paddingH,
    required this.gapS,
    required this.gapM,
    required this.gapL,
    required this.buttonHeight,
    required this.buttonRadius,
    required this.logoSize,
    required this.brandTitleSize,
    required this.brandLetterSpacing,
    required this.welcomeTitleSize,
    required this.sessionTitleSize,
    required this.subtitleSize,
    required this.timerSize,
    required this.timerFontSize,
    required this.statValueSize,
    required this.cardValueLarge,
    required this.cardValueMedium,
    required this.isCompact,
  });

  final double paddingH;
  final double gapS;
  final double gapM;
  final double gapL;
  final double buttonHeight;
  final double buttonRadius;
  final double logoSize;
  final double brandTitleSize;
  final double brandLetterSpacing;
  final double welcomeTitleSize;
  final double sessionTitleSize;
  final double subtitleSize;
  final double timerSize;
  final double timerFontSize;
  final double statValueSize;
  final double cardValueLarge;
  final double cardValueMedium;
  final bool isCompact;

  factory VoidMetrics.of(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final width = size.width;
    final height = size.height;
    final scale = (width / 390).clamp(0.82, 1.12);
    final heightScale = (height / 780).clamp(0.78, 1.08);
    final compact = height < 680;

    return VoidMetrics._(
      paddingH: (width * 0.055).clamp(16, 22),
      gapS: compact ? 12 : 16,
      gapM: compact ? 16 : 20,
      gapL: compact ? 20 : 28,
      buttonHeight: (46 * scale).clamp(44, 50),
      buttonRadius: 12,
      logoSize: (60 * scale).clamp(52, 68),
      brandTitleSize: (width * 0.17).clamp(48, 64),
      brandLetterSpacing: (width * 0.045).clamp(10, 18),
      welcomeTitleSize: (24 * scale).clamp(22, 28),
      sessionTitleSize: (20 * scale).clamp(18, 22),
      subtitleSize: (14 * scale).clamp(13, 15),
      timerSize: (width * 0.68).clamp(200, 260) * heightScale.clamp(0.9, 1.0),
      timerFontSize: (width * 0.13).clamp(40, 52),
      statValueSize: (22 * scale).clamp(20, 24),
      cardValueLarge: (40 * scale).clamp(36, 46),
      cardValueMedium: (28 * scale).clamp(26, 32),
      isCompact: compact,
    );
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await StatsService.instance.initialize().catchError((_) {});
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: kVoidBackground,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const VoidApp());
}

class VoidApp extends StatelessWidget {
  const VoidApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VOID',
      locale: const Locale('ru'),
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: kVoidBackground,
        colorScheme: const ColorScheme.dark(
          surface: kVoidBackground,
          primary: kVoidAccent,
        ),
      ),
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            textScaler: media.textScaler.clamp(maxScaleFactor: 1.15),
          ),
          child: child!,
        );
      },
      home: const VoidOnboardingScreen(),
    );
  }
}

class VoidOnboardingScreen extends StatefulWidget {
  const VoidOnboardingScreen({super.key});

  @override
  State<VoidOnboardingScreen> createState() => _VoidOnboardingScreenState();
}

class _VoidOnboardingScreenState extends State<VoidOnboardingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fade = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  void _openHome() {
    HapticFeedback.lightImpact();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute<void>(builder: (_) => const VoidShell()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = VoidMetrics.of(context);

    return Scaffold(
      backgroundColor: kVoidBackground,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const VoidAmbientGlow(),
          SafeArea(
            minimum: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
            child: FadeTransition(
              opacity: _fade,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: m.paddingH),
                child: Column(
                  children: [
                    Spacer(flex: m.isCompact ? 2 : 3),
                    Container(
                      width: m.logoSize,
                      height: m.logoSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: kVoidAccent.withValues(alpha: 0.4),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: kVoidAccent.withValues(alpha: 0.3),
                            blurRadius: 20,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Container(
                          width: m.logoSize * 0.16,
                          height: m.logoSize * 0.16,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: kVoidAccent,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: m.gapM),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'VOID',
                        style: TextStyle(
                          fontSize: m.brandTitleSize,
                          fontWeight: FontWeight.w200,
                          letterSpacing: m.brandLetterSpacing,
                          color: Colors.white.withValues(alpha: 0.95),
                          shadows: [
                            Shadow(
                              color: kVoidAccent.withValues(alpha: 0.5),
                              blurRadius: 24,
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: m.gapS),
                    Text(
                      'Контролируй своё внимание',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: m.subtitleSize,
                        letterSpacing: 0.8,
                        color: Colors.white.withValues(alpha: 0.45),
                      ),
                    ),
                    Spacer(flex: m.isCompact ? 3 : 4),
                    SizedBox(
                      width: double.infinity,
                      height: m.buttonHeight,
                      child: FilledButton(
                        onPressed: _openHome,
                        style: FilledButton.styleFrom(
                          backgroundColor: kVoidAccent,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(m.buttonRadius),
                          ),
                        ),
                        child: const Text(
                          'Начать фокус',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: m.gapM),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class VoidShell extends StatefulWidget {
  const VoidShell({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<VoidShell> createState() => _VoidShellState();
}

class _VoidShellState extends State<VoidShell> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    StatsService.instance.scheduleLoad(force: true);
  }

  void _onTabSelected(int index) {
    if (index == _currentIndex) return;
    HapticFeedback.selectionClick();
    setState(() => _currentIndex = index);
    StatsService.instance.load(force: true);
  }

  void _openFocusTab() {
    HapticFeedback.lightImpact();
    setState(() => _currentIndex = 1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kVoidBackground,
      body: IndexedStack(
        index: _currentIndex,
        children: [
          VoidHomeTab(onStartSession: _openFocusTab),
          const VoidFocusTab(),
          const VoidAnalyticsTab(),
          const VoidProfileTab(),
        ],
      ),
      bottomNavigationBar: VoidBottomNav(
        currentIndex: _currentIndex,
        onTap: _onTabSelected,
      ),
    );
  }
}

class VoidBottomNav extends StatelessWidget {
  const VoidBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0F),
        border: Border(
          top: BorderSide(color: kVoidAccent.withValues(alpha: 0.12)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: BottomNavigationBar(
          currentIndex: currentIndex,
          onTap: onTap,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: kVoidAccent,
          unselectedItemColor: Colors.white.withValues(alpha: 0.38),
          selectedFontSize: 11,
          unselectedFontSize: 11,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w400),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined, size: 22),
              activeIcon: Icon(Icons.home_rounded, size: 22),
              label: 'Главная',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.timer_outlined, size: 22),
              activeIcon: Icon(Icons.timer_rounded, size: 22),
              label: 'Фокус',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.insights_outlined, size: 22),
              activeIcon: Icon(Icons.insights_rounded, size: 22),
              label: 'Аналитика',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline_rounded, size: 22),
              activeIcon: Icon(Icons.person_rounded, size: 22),
              label: 'Профиль',
            ),
          ],
        ),
      ),
    );
  }
}

class VoidTabScaffold extends StatelessWidget {
  const VoidTabScaffold({
    super.key,
    required this.child,
    this.glowCenter = const Alignment(0, -0.3),
  });

  final Widget child;
  final Alignment glowCenter;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        VoidAmbientGlow(center: glowCenter),
        child,
      ],
    );
  }
}

class VoidHomeTab extends StatefulWidget {
  const VoidHomeTab({super.key, required this.onStartSession});

  final VoidCallback onStartSession;

  @override
  State<VoidHomeTab> createState() => _VoidHomeTabState();
}

class _VoidHomeTabState extends State<VoidHomeTab> {
  @override
  void initState() {
    super.initState();
    StatsService.instance.scheduleLoad(force: true);
  }

  @override
  Widget build(BuildContext context) {
    final m = VoidMetrics.of(context);

    return VoidTabScaffold(
      glowCenter: const Alignment(0, -0.6),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: m.paddingH),
          child: ListenableBuilder(
            listenable: StatsService.instance,
            builder: (context, _) {
              final analytics = StatsService.instance.data;

              return Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: m.gapS),
                          Text(
                            'Добро пожаловать',
                            style: TextStyle(
                              fontSize: m.welcomeTitleSize,
                              fontWeight: FontWeight.w300,
                              color: Colors.white.withValues(alpha: 0.95),
                            ),
                          ),
                          SizedBox(height: m.gapL),
                          VoidDailyGoalCard(
                            todayFocusSeconds: analytics.todayFocusSeconds,
                            goalMinutes: analytics.dailyGoalMinutes,
                            progress: analytics.dailyGoalProgress,
                          ),
                          SizedBox(height: m.gapM),
                          VoidStatCard(
                            label: 'Всего сессий',
                            value: '${analytics.completedSessions}',
                            prominent: true,
                          ),
                          SizedBox(height: m.gapM),
                          VoidStatCard(
                            label: 'Время фокуса',
                            value: formatFocusDuration(
                              analytics.totalFocusSeconds,
                            ),
                          ),
                          SizedBox(height: m.gapM),
                          VoidStreakCard(
                            currentStreak: analytics.currentStreak,
                            bestStreak: analytics.bestStreak,
                          ),
                          SizedBox(height: m.gapM),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(
                    width: double.infinity,
                    height: m.buttonHeight,
                    child: FilledButton(
                      onPressed: widget.onStartSession,
                      style: FilledButton.styleFrom(
                        backgroundColor: kVoidAccent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(m.buttonRadius),
                        ),
                      ),
                      child: const Text(
                        'Начать сессию',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: m.gapS),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class VoidAnalyticsTab extends StatefulWidget {
  const VoidAnalyticsTab({super.key});

  @override
  State<VoidAnalyticsTab> createState() => _VoidAnalyticsTabState();
}

class _VoidAnalyticsTabState extends State<VoidAnalyticsTab> {
  @override
  void initState() {
    super.initState();
    StatsService.instance.scheduleLoad(force: true);
  }

  @override
  Widget build(BuildContext context) {
    final m = VoidMetrics.of(context);

    return VoidTabScaffold(
      glowCenter: const Alignment(0, -0.5),
      child: SafeArea(
        child: ListenableBuilder(
          listenable: StatsService.instance,
          builder: (context, _) {
            final store = StatsService.instance;
            final analytics = store.data;

            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.symmetric(horizontal: m.paddingH),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: m.gapS),
                  Text(
                    'Аналитика',
                    style: TextStyle(
                      fontSize: m.welcomeTitleSize,
                      fontWeight: FontWeight.w300,
                      color: Colors.white.withValues(alpha: 0.95),
                    ),
                  ),
                  SizedBox(height: m.gapL),
                  if (store.isLoading)
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: m.gapL * 2),
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: kVoidAccent,
                          strokeWidth: 2,
                        ),
                      ),
                    )
                  else if (!store.hasData)
                    const _VoidAnalyticsEmptyState()
                  else ...[
                    VoidStatCard(
                      label: 'Всего сессий',
                      value: '${analytics.completedSessions}',
                      prominent: true,
                    ),
                    SizedBox(height: m.gapM),
                    VoidStatCard(
                      label: 'Всего часов фокуса',
                      value: formatFocusDuration(analytics.totalFocusSeconds),
                    ),
                    SizedBox(height: m.gapM),
                    VoidStreakCard(
                      currentStreak: analytics.currentStreak,
                      bestStreak: analytics.bestStreak,
                    ),
                    SizedBox(height: m.gapM),
                    VoidStatCard(
                      label: 'Всего отвлечений',
                      value: '${analytics.distractions}',
                    ),
                    SizedBox(height: m.gapM),
                    VoidStatCard(
                      label: 'Среднее отвлечений за сессию',
                      value: formatAverageDistractions(
                        analytics.averageDistractionsPerSession,
                      ),
                    ),
                    SizedBox(height: m.gapM),
                    VoidStatCard(
                      label: 'Фокус-счёт',
                      value: formatFocusScore(analytics.averageFocusScore),
                    ),
                    SizedBox(height: m.gapM),
                    VoidActivityChart(days: analytics.last7Days),
                    SizedBox(height: m.gapM),
                    VoidCalendarMonthStatsPanel(
                      stats: VoidCalendarMonthStats.fromDays(
                        analytics.last30Days,
                      ),
                    ),
                    SizedBox(height: m.gapM),
                    VoidFocusCalendar(
                      days: analytics.last30Days,
                      goalMinutes: analytics.dailyGoalMinutes,
                    ),
                    SizedBox(height: m.gapM),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _VoidAnalyticsEmptyState extends StatelessWidget {
  const _VoidAnalyticsEmptyState();

  @override
  Widget build(BuildContext context) {
    final m = VoidMetrics.of(context);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: 20,
        vertical: m.isCompact ? 28 : 36,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kVoidAccent.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.insights_outlined,
            size: 40,
            color: kVoidAccent.withValues(alpha: 0.6),
          ),
          SizedBox(height: m.gapM),
          Text(
            'Завершите первую фокус-сессию для просмотра статистики',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: m.subtitleSize,
              height: 1.5,
              color: Colors.white.withValues(alpha: 0.55),
            ),
          ),
        ],
      ),
    );
  }
}

class VoidActivityChart extends StatelessWidget {
  const VoidActivityChart({super.key, required this.days});

  final List<VoidDayActivity> days;

  @override
  Widget build(BuildContext context) {
    final m = VoidMetrics.of(context);
    final maxSeconds = days.fold<int>(
      0,
      (max, day) => day.focusSeconds > max ? day.focusSeconds : max,
    );

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: m.isCompact ? 16 : 20,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kVoidAccent.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Последние 7 дней активности',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.45),
            ),
          ),
          SizedBox(height: m.gapM),
          Builder(
            builder: (context) {
              final chartHeight = m.isCompact ? 92.0 : 112.0;
              const labelArea = 20.0;
              final maxBarHeight = chartHeight - labelArea;

              return SizedBox(
                height: chartHeight,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final day in days)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Container(
                                height: _barHeight(
                                  day.focusSeconds,
                                  maxSeconds,
                                  maxBarHeight,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(6),
                                  gradient: day.focusSeconds > 0
                                  ? LinearGradient(
                                      begin: Alignment.bottomCenter,
                                      end: Alignment.topCenter,
                                      colors: [
                                        kVoidAccent.withValues(alpha: 0.7),
                                        kVoidAccent,
                                      ],
                                    )
                                  : null,
                              color: day.focusSeconds == 0
                                  ? Colors.white.withValues(alpha: 0.06)
                                  : null,
                              boxShadow: day.focusSeconds > 0
                                  ? [
                                      BoxShadow(
                                        color:
                                            kVoidAccent.withValues(alpha: 0.25),
                                        blurRadius: 8,
                                      ),
                                    ]
                                  : null,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                day.dayLabel,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.white.withValues(alpha: 0.4),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  double _barHeight(int seconds, int maxSeconds, double maxBarHeight) {
    const minHeight = 4.0;
    if (seconds <= 0 || maxSeconds <= 0) return minHeight;
    return minHeight + (seconds / maxSeconds) * (maxBarHeight - minHeight);
  }
}

class VoidFocusCalendarScreen extends StatefulWidget {
  const VoidFocusCalendarScreen({super.key});

  @override
  State<VoidFocusCalendarScreen> createState() =>
      _VoidFocusCalendarScreenState();
}

class _VoidFocusCalendarScreenState extends State<VoidFocusCalendarScreen> {
  @override
  void initState() {
    super.initState();
    StatsService.instance.scheduleLoad(force: true);
  }

  @override
  Widget build(BuildContext context) {
    final m = VoidMetrics.of(context);

    return Scaffold(
      backgroundColor: kVoidBackground,
      appBar: AppBar(
        backgroundColor: kVoidBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white.withValues(alpha: 0.8),
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Календарь фокуса',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w400,
            color: Colors.white.withValues(alpha: 0.95),
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          const VoidAmbientGlow(center: Alignment(0, -0.45)),
          SafeArea(
            child: ListenableBuilder(
              listenable: StatsService.instance,
              builder: (context, _) {
                final store = StatsService.instance;
                final stats = store.data;
                final goalMinutes = stats.dailyGoalMinutes;
                final days = stats.last30Days;
                final focusDays = days
                    .where((day) => day.focusSeconds > 0)
                    .length;
                final monthStats = VoidCalendarMonthStats.fromDays(days);

                if (store.isLoading && days.every((day) => day.focusSeconds == 0)) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: kVoidAccent,
                      strokeWidth: 2,
                    ),
                  );
                }

                return SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    m.paddingH,
                    m.gapM,
                    m.paddingH,
                    m.gapL,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Последние 30 дней',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.42),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        focusDays == 0
                            ? 'Завершите сессию, чтобы увидеть активность'
                            : 'Нажмите на день, чтобы увидеть детали',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                      ),
                      SizedBox(height: m.gapM),
                      VoidCalendarMonthStatsPanel(stats: monthStats),
                      SizedBox(height: m.gapM),
                      VoidFocusCalendar(
                        days: days,
                        goalMinutes: goalMinutes,
                        showHeader: false,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  static String _focusDaysLabel(int count) {
    final mod10 = count % 10;
    final mod100 = count % 100;
    if (mod100 >= 11 && mod100 <= 14) return 'дней';
    if (mod10 == 1) return 'день';
    if (mod10 >= 2 && mod10 <= 4) return 'дня';
    return 'дней';
  }

}

void showVoidDayDetailSheet(
  BuildContext context, {
  required VoidDayActivity day,
  required int goalMinutes,
}) {
  final isToday = day.date ==
      DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
      );
  final status = day.status(goalMinutes);

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF12121A),
    shape: RoundedRectangleBorder(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      side: BorderSide(color: kVoidAccent.withValues(alpha: 0.28)),
    ),
    builder: (sheetContext) {
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: focusDayStatusColor(status),
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: status == VoidFocusDayStatus.completed
                          ? [
                              BoxShadow(
                                color:
                                    kVoidGoalComplete.withValues(alpha: 0.45),
                                blurRadius: 10,
                              ),
                            ]
                          : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      formatCalendarDayTitle(day.date),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.95),
                      ),
                    ),
                  ),
                  if (isToday)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.35),
                        ),
                        color: Colors.white.withValues(alpha: 0.06),
                      ),
                      child: Text(
                        'Сегодня',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.white.withValues(alpha: 0.72),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${day.dayLabel} · ${status == VoidFocusDayStatus.completed ? 'Цель выполнена' : status == VoidFocusDayStatus.partial ? 'Был фокус' : 'Нет фокуса'}',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.42),
                ),
              ),
              const SizedBox(height: 18),
              if (!day.hasActivity) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 28,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: kVoidAccent.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Text(
                    'В этот день не было фокус-сессий',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: Colors.white.withValues(alpha: 0.55),
                    ),
                  ),
                ),
              ] else ...[
                _VoidDayDetailMetric(
                  label: 'Всего фокуса',
                  value: formatFocusDuration(day.focusSeconds),
                ),
                const SizedBox(height: 10),
                _VoidDayDetailMetric(
                  label: 'Сессий завершено',
                  value: '${day.sessionsCount}',
                ),
                const SizedBox(height: 10),
                _VoidDayDetailMetric(
                  label: 'Средний фокус-счёт',
                  value: day.sessionsCount > 0
                      ? formatFocusScore(day.averageFocusScore)
                      : '—',
                ),
                const SizedBox(height: 10),
                _VoidDayDetailMetric(
                  label: 'Всего отвлечений',
                  value: '${day.distractions}',
                ),
                const SizedBox(height: 10),
                _VoidDayDetailMetric(
                  label: 'Заработано XP',
                  value: '+${day.xpEarned} XP',
                  accent: true,
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}

class _VoidDayDetailMetric extends StatelessWidget {
  const _VoidDayDetailMetric({
    required this.label,
    required this.value,
    this.accent = false,
  });

  final String label;
  final String value;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: accent
              ? kVoidAccent.withValues(alpha: 0.28)
              : kVoidAccent.withValues(alpha: 0.16),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.48),
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: accent
                  ? kVoidAccent.withValues(alpha: 0.95)
                  : Colors.white.withValues(alpha: 0.92),
            ),
          ),
        ],
      ),
    );
  }
}

class VoidCalendarMonthStatsPanel extends StatelessWidget {
  const VoidCalendarMonthStatsPanel({super.key, required this.stats});

  final VoidCalendarMonthStats stats;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kVoidAccent.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _VoidCalendarMonthStatItem(
              label: 'Активные дни',
              value: '${stats.activeDays}',
            ),
          ),
          Container(
            width: 1,
            height: 34,
            color: Colors.white.withValues(alpha: 0.08),
          ),
          Expanded(
            child: _VoidCalendarMonthStatItem(
              label: 'Всего фокуса',
              value: formatFocusDuration(stats.totalFocusSeconds),
            ),
          ),
          Container(
            width: 1,
            height: 34,
            color: Colors.white.withValues(alpha: 0.08),
          ),
          Expanded(
            child: _VoidCalendarMonthStatItem(
              label: 'Серия (30 дн.)',
              value: '${stats.longestStreak}',
            ),
          ),
        ],
      ),
    );
  }
}

class _VoidCalendarMonthStatItem extends StatelessWidget {
  const _VoidCalendarMonthStatItem({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        children: [
          Text(
            value,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.92),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 9,
              color: Colors.white.withValues(alpha: 0.38),
            ),
          ),
        ],
      ),
    );
  }
}

class VoidFocusCalendar extends StatelessWidget {
  const VoidFocusCalendar({
    super.key,
    required this.days,
    required this.goalMinutes,
    this.showHeader = true,
  });

  final List<VoidDayActivity> days;
  final int goalMinutes;
  final bool showHeader;

  @override
  Widget build(BuildContext context) {
    final m = VoidMetrics.of(context);
    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: m.isCompact ? 16 : 20,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kVoidAccent.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showHeader) ...[
            Text(
              'Календарь фокуса',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.45),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Последние 30 дней',
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.28),
              ),
            ),
            SizedBox(height: m.gapM),
          ],
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: days.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 6,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.82,
            ),
            itemBuilder: (context, index) {
              final day = days[index];
              final status = day.status(goalMinutes);
              final isToday = day.date == today;
              final dayKey = StatsService.dateKey(day.date);

              return GestureDetector(
                key: Key('calendar-day-$dayKey'),
                behavior: HitTestBehavior.opaque,
                onTap: () => showVoidDayDetailSheet(
                  context,
                  day: day,
                  goalMinutes: goalMinutes,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: double.infinity,
                      height: m.isCompact ? 24 : 28,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(7),
                        color: focusDayStatusColor(status),
                        border: isToday
                            ? Border.all(
                                color: Colors.white.withValues(alpha: 0.9),
                                width: 1.5,
                              )
                            : null,
                        boxShadow: [
                          if (isToday) ...[
                            BoxShadow(
                              color: Colors.white.withValues(alpha: 0.42),
                              blurRadius: 10,
                              spreadRadius: 0.5,
                            ),
                            BoxShadow(
                              color: kVoidAccent.withValues(alpha: 0.28),
                              blurRadius: 14,
                            ),
                          ],
                          if (status == VoidFocusDayStatus.completed) ...[
                            BoxShadow(
                              color: kVoidGoalComplete.withValues(alpha: 0.5),
                              blurRadius: 12,
                              spreadRadius: 0.5,
                            ),
                            BoxShadow(
                              color: kVoidGoalComplete.withValues(alpha: 0.22),
                              blurRadius: 18,
                            ),
                          ] else if (status == VoidFocusDayStatus.partial) ...[
                            BoxShadow(
                              color: kVoidAccent.withValues(alpha: 0.18),
                              blurRadius: 6,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${day.date.day}',
                      style: TextStyle(
                        fontSize: 9,
                        color: isToday
                            ? Colors.white.withValues(alpha: 0.9)
                            : Colors.white.withValues(alpha: 0.32),
                        fontWeight:
                            isToday ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          SizedBox(height: m.gapM),
          const _VoidFocusCalendarLegend(),
        ],
      ),
    );
  }
}

class _VoidFocusCalendarLegend extends StatelessWidget {
  const _VoidFocusCalendarLegend();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 14,
      runSpacing: 8,
      children: const [
        _VoidFocusCalendarLegendItem(
          color: kVoidGoalComplete,
          label: 'Цель выполнена',
        ),
        _VoidFocusCalendarLegendItem(
          color: kVoidAccent,
          label: 'Был фокус',
        ),
        _VoidFocusCalendarLegendItem(
          color: Color(0x24FFFFFF),
          label: 'Нет фокуса',
        ),
      ],
    );
  }
}

class _VoidFocusCalendarLegendItem extends StatelessWidget {
  const _VoidFocusCalendarLegendItem({
    required this.color,
    required this.label,
  });

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.white.withValues(alpha: 0.42),
          ),
        ),
      ],
    );
  }
}

class VoidProfileTab extends StatefulWidget {
  const VoidProfileTab({super.key});

  @override
  State<VoidProfileTab> createState() => _VoidProfileTabState();
}

class _VoidProfileTabState extends State<VoidProfileTab> {
  @override
  void initState() {
    super.initState();
    StatsService.instance.scheduleLoad(force: true);
  }

  @override
  Widget build(BuildContext context) {
    final m = VoidMetrics.of(context);

    return VoidTabScaffold(
      glowCenter: const Alignment(0, -0.4),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: m.paddingH),
          child: ListenableBuilder(
            listenable: StatsService.instance,
            builder: (context, _) {
              final stats = StatsService.instance.data;

              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    SizedBox(height: m.gapL),
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: kVoidAccent.withValues(alpha: 0.35),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: kVoidAccent.withValues(alpha: 0.2),
                            blurRadius: 20,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.person_rounded,
                        size: 36,
                        color: kVoidAccent.withValues(alpha: 0.8),
                      ),
                    ),
                    SizedBox(height: m.gapM),
                    Text(
                      'Профиль',
                      style: TextStyle(
                        fontSize: m.welcomeTitleSize,
                        fontWeight: FontWeight.w300,
                        color: Colors.white.withValues(alpha: 0.95),
                      ),
                    ),
                    SizedBox(height: m.gapS),
                    Text(
                      'Пользователь VOID',
                      style: TextStyle(
                        fontSize: m.subtitleSize,
                        color: Colors.white.withValues(alpha: 0.45),
                      ),
                    ),
                    SizedBox(height: m.gapL),
                    VoidLevelCard(
                      level: stats.level,
                      totalXp: stats.totalXp,
                      xpInLevel: stats.xpInCurrentLevel,
                      progress: stats.levelProgress,
                    ),
                    SizedBox(height: m.gapM),
                    VoidStatCard(
                      label: 'Всего сессий',
                      value: '${stats.completedSessions}',
                    ),
                    SizedBox(height: m.gapM),
                    VoidStatCard(
                      label: 'Время фокуса',
                      value: formatFocusDuration(stats.totalFocusSeconds),
                    ),
                    SizedBox(height: m.gapM),
                    VoidStreakCard(
                      currentStreak: stats.currentStreak,
                      bestStreak: stats.bestStreak,
                    ),
                    SizedBox(height: m.gapL),
                    VoidHistoryAccessCard(
                      sessionCount: stats.completedSessions,
                      onTap: () {
                        Navigator.push<void>(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => const VoidSessionHistoryScreen(),
                          ),
                        );
                      },
                    ),
                    SizedBox(height: m.gapM),
                    VoidCalendarAccessCard(
                      days: stats.last30Days,
                      goalMinutes: stats.dailyGoalMinutes,
                      onTap: () {
                        Navigator.push<void>(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => const VoidFocusCalendarScreen(),
                          ),
                        );
                      },
                    ),
                    SizedBox(height: m.gapM),
                    VoidAchievementsSection(
                      achievements: stats.achievements,
                      unlockedCount: stats.unlockedAchievementsCount,
                    ),
                    SizedBox(height: m.gapM),
                    VoidSettingsAccessCard(
                      onTap: () {
                        Navigator.push<void>(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => const VoidSettingsScreen(),
                          ),
                        );
                      },
                    ),
                    SizedBox(height: m.gapM),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class VoidHistoryAccessCard extends StatelessWidget {
  const VoidHistoryAccessCard({
    super.key,
    required this.sessionCount,
    required this.onTap,
  });

  final int sessionCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: kVoidAccent.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: kVoidAccent.withValues(alpha: 0.16),
                  border: Border.all(color: kVoidAccent.withValues(alpha: 0.35)),
                ),
                child: Icon(
                  Icons.history_rounded,
                  size: 20,
                  color: kVoidAccent.withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'История сессий',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.92),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      sessionCount == 0
                          ? 'Пока нет завершённых сессий'
                          : '$sessionCount ${_sessionCountLabel(sessionCount)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.45),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: kVoidAccent.withValues(alpha: 0.75),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _sessionCountLabel(int count) {
    final mod10 = count % 10;
    final mod100 = count % 100;
    if (mod100 >= 11 && mod100 <= 14) return 'сессий';
    if (mod10 == 1) return 'сессия';
    if (mod10 >= 2 && mod10 <= 4) return 'сессии';
    return 'сессий';
  }
}

class VoidCalendarAccessCard extends StatelessWidget {
  const VoidCalendarAccessCard({
    super.key,
    required this.days,
    required this.goalMinutes,
    required this.onTap,
  });

  final List<VoidDayActivity> days;
  final int goalMinutes;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final focusDays = days.where((day) => day.focusSeconds > 0).length;
    final goalDays = days
        .where(
          (day) => day.status(goalMinutes) == VoidFocusDayStatus.completed,
        )
        .length;
    final subtitle = focusDays == 0
        ? 'Последние 30 дней'
        : goalDays > 0
            ? '$goalDays ${_goalDaysLabel(goalDays)} · $focusDays с фокусом'
            : '$focusDays ${_focusDaysLabel(focusDays)} с фокусом';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: kVoidAccent.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: kVoidGoalComplete.withValues(alpha: 0.12),
                  border: Border.all(
                    color: kVoidGoalComplete.withValues(alpha: 0.35),
                  ),
                ),
                child: Icon(
                  Icons.calendar_month_rounded,
                  size: 20,
                  color: kVoidGoalComplete.withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Календарь фокуса',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.92),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.45),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: kVoidAccent.withValues(alpha: 0.75),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _focusDaysLabel(int count) {
    final mod10 = count % 10;
    final mod100 = count % 100;
    if (mod100 >= 11 && mod100 <= 14) return 'дней';
    if (mod10 == 1) return 'день';
    if (mod10 >= 2 && mod10 <= 4) return 'дня';
    return 'дней';
  }

  static String _goalDaysLabel(int count) {
    final mod10 = count % 10;
    final mod100 = count % 100;
    if (mod100 >= 11 && mod100 <= 14) return 'целей';
    if (mod10 == 1) return 'цель';
    if (mod10 >= 2 && mod10 <= 4) return 'цели';
    return 'целей';
  }
}

class VoidSettingsAccessCard extends StatelessWidget {
  const VoidSettingsAccessCard({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: kVoidAccent.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: kVoidAccent.withValues(alpha: 0.16),
                  border: Border.all(color: kVoidAccent.withValues(alpha: 0.35)),
                ),
                child: Icon(
                  Icons.settings_rounded,
                  size: 20,
                  color: kVoidAccent.withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Настройки',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.92),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Данные, экспорт и информация',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.45),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: kVoidAccent.withValues(alpha: 0.75),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class VoidSettingsScreen extends StatelessWidget {
  const VoidSettingsScreen({super.key});

  Future<void> _confirmAction({
    required BuildContext context,
    required String title,
    required String message,
    required String confirmLabel,
    required Future<bool> Function() onConfirm,
    required String successMessage,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF12121A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: kVoidAccent.withValues(alpha: 0.3)),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.95),
            fontWeight: FontWeight.w500,
          ),
        ),
        content: Text(
          message,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.65),
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              'Отмена',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.55)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              confirmLabel,
              style: const TextStyle(color: kVoidAccent),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final success = await onConfirm();
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF12121A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: kVoidAccent.withValues(alpha: 0.25)),
        ),
        content: Text(
          success ? successMessage : 'Не удалось выполнить действие',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.9)),
        ),
      ),
    );
  }

  Future<void> _exportData(BuildContext context) async {
    final json = await StatsService.instance.exportData();
    try {
      await Clipboard.setData(ClipboardData(text: json));
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF12121A),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: kVoidAccent.withValues(alpha: 0.25)),
          ),
          content: Text(
            'Не удалось скопировать данные',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.9)),
          ),
        ),
      );
      return;
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF12121A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: kVoidAccent.withValues(alpha: 0.25)),
        ),
        content: Text(
          'Данные скопированы в буфер обмена',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.9)),
        ),
      ),
    );
  }

  Future<void> _reportBug(BuildContext context) {
    return launchVoidMailFeedback(
      context,
      subject: 'VOID — сообщение об ошибке',
      body: buildVoidFeedbackBody(
        'Опишите ошибку:\n'
        '1. Что вы делали\n'
        '2. Что произошло\n'
        '3. Как должно работать',
      ),
    );
  }

  Future<void> _suggestFeature(BuildContext context) {
    return launchVoidMailFeedback(
      context,
      subject: 'VOID — предложение функции',
      body: buildVoidFeedbackBody(
        'Опишите идею:\n'
        '1. Какую функцию хотите\n'
        '2. Зачем она нужна\n'
        '3. Как вы будете её использовать',
      ),
    );
  }

  Future<void> _rateApp(BuildContext context) {
    return launchVoidStoreListing(context);
  }

  Future<void> _showAboutDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF12121A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: kVoidAccent.withValues(alpha: 0.3)),
        ),
        title: Column(
          children: [
            Text(
              'VOID',
              style: TextStyle(
                color: kVoidAccent,
                fontWeight: FontWeight.w300,
                letterSpacing: 8,
                fontSize: 28,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'v$kVoidAppVersion',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        content: Text(
          'Приложение для глубокого фокуса и контроля внимания. '
          'Отслеживайте сессии, серии и прогресс без лишнего шума.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.65),
            height: 1.5,
          ),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text(
              'Закрыть',
              style: TextStyle(color: kVoidAccent),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = VoidMetrics.of(context);

    return Scaffold(
      backgroundColor: kVoidBackground,
      appBar: AppBar(
        backgroundColor: kVoidBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white.withValues(alpha: 0.8),
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Настройки',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w400,
            color: Colors.white.withValues(alpha: 0.95),
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          const VoidAmbientGlow(center: Alignment(0, -0.55)),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: m.paddingH),
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.only(top: m.gapS, bottom: m.gapL),
                children: [
                  VoidSettingsOptionTile(
                    icon: Icons.restart_alt_rounded,
                    title: 'Сбросить статистику',
                    subtitle: 'Обнулить сессии, фокус, серию и достижения',
                    onTap: () => _confirmAction(
                      context: context,
                      title: 'Сбросить статистику?',
                      message:
                          'Все данные статистики будут удалены без возможности восстановления. '
                          'Цель дня останется без изменений.',
                      confirmLabel: 'Сбросить',
                      onConfirm: StatsService.instance.resetAllStats,
                      successMessage: 'Статистика сброшена',
                    ),
                  ),
                  SizedBox(height: m.gapS),
                  VoidSettingsOptionTile(
                    icon: Icons.delete_outline_rounded,
                    title: 'Очистить историю сессий',
                    subtitle: 'Удалить записи истории, сохранив общие показатели',
                    onTap: () => _confirmAction(
                      context: context,
                      title: 'Очистить историю?',
                      message:
                          'Список завершённых сессий будет удалён. '
                          'Общая статистика и достижения сохранятся.',
                      confirmLabel: 'Очистить',
                      onConfirm: StatsService.instance.clearSessionHistory,
                      successMessage: 'История сессий очищена',
                    ),
                  ),
                  SizedBox(height: m.gapS),
                  VoidSettingsOptionTile(
                    icon: Icons.upload_rounded,
                    title: 'Экспорт данных',
                    subtitle: 'Скопировать статистику в буфер обмена (JSON)',
                    onTap: () => _exportData(context),
                  ),
                  SizedBox(height: m.gapL),
                  const VoidSettingsSectionHeader(title: 'Обратная связь'),
                  SizedBox(height: m.gapS),
                  VoidSettingsOptionTile(
                    icon: Icons.bug_report_outlined,
                    title: 'Сообщить об ошибке',
                    subtitle: 'Отправить отчёт через почтовое приложение',
                    onTap: () => _reportBug(context),
                  ),
                  SizedBox(height: m.gapS),
                  VoidSettingsOptionTile(
                    icon: Icons.lightbulb_outline_rounded,
                    title: 'Предложить функцию',
                    subtitle: 'Поделиться идеей для следующих версий',
                    onTap: () => _suggestFeature(context),
                  ),
                  SizedBox(height: m.gapS),
                  VoidSettingsOptionTile(
                    icon: Icons.star_outline_rounded,
                    title: 'Оценить приложение',
                    subtitle: 'Открыть страницу VOID в RuStore',
                    onTap: () => _rateApp(context),
                  ),
                  SizedBox(height: m.gapL),
                  VoidSettingsOptionTile(
                    icon: Icons.info_outline_rounded,
                    title: 'О приложении',
                    subtitle: 'VOID v$kVoidAppVersion',
                    onTap: () => _showAboutDialog(context),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class VoidSettingsSectionHeader extends StatelessWidget {
  const VoidSettingsSectionHeader({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          letterSpacing: 1.2,
          fontWeight: FontWeight.w500,
          color: Colors.white.withValues(alpha: 0.38),
        ),
      ),
    );
  }
}

class VoidSettingsOptionTile extends StatelessWidget {
  const VoidSettingsOptionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: kVoidAccent.withValues(alpha: 0.18)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: kVoidAccent.withValues(alpha: 0.12),
                  border: Border.all(color: kVoidAccent.withValues(alpha: 0.28)),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: kVoidAccent.withValues(alpha: 0.85),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.92),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.3,
                        color: Colors.white.withValues(alpha: 0.45),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: kVoidAccent.withValues(alpha: 0.55),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class VoidSessionHistoryScreen extends StatefulWidget {
  const VoidSessionHistoryScreen({super.key});

  @override
  State<VoidSessionHistoryScreen> createState() => _VoidSessionHistoryScreenState();
}

class _VoidSessionHistoryScreenState extends State<VoidSessionHistoryScreen> {
  @override
  void initState() {
    super.initState();
    StatsService.instance.scheduleLoad(force: true);
  }

  @override
  Widget build(BuildContext context) {
    final m = VoidMetrics.of(context);

    return Scaffold(
      backgroundColor: kVoidBackground,
      appBar: AppBar(
        backgroundColor: kVoidBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white.withValues(alpha: 0.8),
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'История сессий',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w400,
            color: Colors.white.withValues(alpha: 0.95),
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          const VoidAmbientGlow(center: Alignment(0, -0.55)),
          SafeArea(
            child: ListenableBuilder(
              listenable: StatsService.instance,
              builder: (context, _) {
                final store = StatsService.instance;
                final history = store.data.sessionHistory;

                if (store.isLoading && history.isEmpty) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: kVoidAccent,
                      strokeWidth: 2,
                    ),
                  );
                }

                if (history.isEmpty) {
                  return Padding(
                    padding: EdgeInsets.symmetric(horizontal: m.paddingH),
                    child: Center(
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: m.isCompact ? 28 : 36,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: kVoidAccent.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.history_rounded,
                              size: 40,
                              color: kVoidAccent.withValues(alpha: 0.6),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'История пуста',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w400,
                                color: Colors.white.withValues(alpha: 0.85),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Завершите первую сессию, чтобы увидеть историю',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.4,
                                color: Colors.white.withValues(alpha: 0.45),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    m.paddingH,
                    m.gapS,
                    m.paddingH,
                    m.gapL,
                  ),
                  itemCount: history.length,
                  separatorBuilder: (_, __) => SizedBox(height: m.gapS),
                  itemBuilder: (context, index) {
                    return VoidSessionHistoryCard(session: history[index]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class VoidSessionHistoryCard extends StatelessWidget {
  const VoidSessionHistoryCard({super.key, required this.session});

  final VoidSessionRecord session;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kVoidAccent.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            formatSessionDateTime(session.completedAt),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _SessionHistoryMetric(
                  label: 'Длительность',
                  value: formatFocusDuration(session.focusSeconds),
                ),
              ),
              Expanded(
                child: _SessionHistoryMetric(
                  label: 'Отвлечения',
                  value: '${session.distractions}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _SessionHistoryMetric(
                  label: 'Фокус-счёт',
                  value: '${session.focusScore}',
                ),
              ),
              Expanded(
                child: _SessionHistoryMetric(
                  label: 'XP',
                  value: '+${session.xp}',
                  accent: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SessionHistoryMetric extends StatelessWidget {
  const _SessionHistoryMetric({
    required this.label,
    required this.value,
    this.accent = false,
  });

  final String label;
  final String value;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.white.withValues(alpha: 0.4),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: accent
                ? kVoidAccent
                : Colors.white.withValues(alpha: 0.88),
          ),
        ),
      ],
    );
  }
}

class VoidFocusTab extends StatefulWidget {
  const VoidFocusTab({super.key});

  @override
  State<VoidFocusTab> createState() => _VoidFocusTabState();
}

class _VoidFocusTabState extends State<VoidFocusTab> {
  static const int _sessionMinutes = 25;
  static const int _totalSeconds = _sessionMinutes * 60;

  int _remainingSeconds = _totalSeconds;
  int _sessionDistractions = 0;
  int _distractionFeedbackTick = 0;
  int _distractionCooldownSeconds = 0;
  bool _isRunning = false;
  bool _isPaused = false;
  bool _isCompleted = false;
  bool _sessionSaved = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    if (!_isRunning || _isPaused || _isCompleted || _sessionSaved) return;
    if (_distractionCooldownSeconds > 0) {
      _distractionCooldownSeconds--;
    }
    if (_remainingSeconds <= 1) {
      unawaited(_finishSession(
        remainingAtFinish: 0,
        naturalCompletion: true,
      ));
    } else {
      setState(() => _remainingSeconds--);
    }
  }

  Future<void> _finishSession({
    int? remainingAtFinish,
    bool naturalCompletion = false,
  }) async {
    if (_sessionSaved) return;
    _sessionSaved = true;

    final remaining = remainingAtFinish ?? _remainingSeconds;
    final elapsedSeconds = _totalSeconds - remaining;
    final focusSeconds = computeActualFocusSeconds(
      totalSessionSeconds: _totalSeconds,
      remainingSeconds: remaining,
    );
    final distractions = _sessionDistractions;
    final xp = computeSessionXp(elapsedSeconds, distractions);

    _timer?.cancel();
    setState(() {
      _isRunning = false;
      _isPaused = false;
      _isCompleted = true;
      _remainingSeconds = 0;
    });
    HapticFeedback.mediumImpact();

    await StatsService.instance.completeSession(
      focusSeconds: focusSeconds,
      sessionDistractions: distractions,
    );

    if (mounted) {
      await _showCompletionDialog(
        elapsedSeconds: elapsedSeconds,
        distractions: distractions,
        xp: xp,
        focusScore: computeFocusScore(distractions),
      );
    }
  }

  void _recordDistraction() {
    if (!_isRunning || _isCompleted || _distractionCooldownSeconds > 0) return;

    _distractionCooldownSeconds = 3;
    HapticFeedback.selectionClick();
    setState(() {
      _sessionDistractions++;
      _distractionFeedbackTick++;
    });
  }

  void _startSession() {
    if (_isRunning || _isCompleted) return;
    HapticFeedback.lightImpact();
    setState(() => _isRunning = true);
    _startTimer();
  }

  void _togglePause() {
    if (!_isRunning || _isCompleted) return;
    HapticFeedback.lightImpact();
    setState(() => _isPaused = !_isPaused);
  }

  void _resetSession() {
    HapticFeedback.lightImpact();
    _timer?.cancel();
    setState(() {
      _remainingSeconds = _totalSeconds;
      _sessionDistractions = 0;
      _distractionFeedbackTick = 0;
      _distractionCooldownSeconds = 0;
      _isRunning = false;
      _isPaused = false;
      _isCompleted = false;
      _sessionSaved = false;
    });
  }

  Future<void> _showCompletionDialog({
    required int elapsedSeconds,
    required int distractions,
    required int xp,
    required int focusScore,
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF12121A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: kVoidAccent.withValues(alpha: 0.3)),
        ),
        title: Text(
          'Сессия завершена',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.95),
            fontWeight: FontWeight.w500,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _CompletionSummaryRow(
              label: 'Длительность',
              value: formatFocusDuration(elapsedSeconds),
            ),
            const SizedBox(height: 12),
            _CompletionSummaryRow(
              label: 'Отвлечения',
              value: '$distractions',
            ),
            const SizedBox(height: 12),
            _CompletionSummaryRow(
              label: 'Получено XP',
              value: '+$xp',
              accent: true,
            ),
            const SizedBox(height: 12),
            _CompletionSummaryRow(
              label: 'Фокус-счёт',
              value: '$focusScore',
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _resetSession();
            },
            child: const Text(
              'Готово',
              style: TextStyle(color: kVoidAccent),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final m = VoidMetrics.of(context);
    final progress = _remainingSeconds / _totalSeconds;
    final innerRing = m.timerSize * 0.78;

    return VoidTabScaffold(
      glowCenter: const Alignment(0, 0.1),
      child: SafeArea(
        minimum: EdgeInsets.symmetric(vertical: m.gapS),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: m.paddingH),
          child: Column(
            children: [
              SizedBox(height: m.gapS),
              Text(
                'Глубокий фокус',
                style: TextStyle(
                  fontSize: m.sessionTitleSize,
                  fontWeight: FontWeight.w300,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
              Expanded(
                child: Center(
                  child: SizedBox(
                    width: m.timerSize,
                    height: m.timerSize,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox.expand(
                          child: CircularProgressIndicator(
                            value: progress,
                            strokeWidth: 3,
                            backgroundColor:
                                kVoidAccent.withValues(alpha: 0.12),
                            valueColor:
                                const AlwaysStoppedAnimation(kVoidAccent),
                            strokeCap: StrokeCap.round,
                          ),
                        ),
                        Container(
                          width: innerRing,
                          height: innerRing,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: kVoidAccent.withValues(alpha: 0.2),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: kVoidAccent.withValues(alpha: 0.15),
                                blurRadius: 32,
                              ),
                            ],
                          ),
                        ),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            _formatTime(_remainingSeconds),
                            style: TextStyle(
                              fontSize: m.timerFontSize,
                              fontWeight: FontWeight.w200,
                              letterSpacing: 2,
                              color: Colors.white.withValues(alpha: 0.95),
                              shadows: [
                                Shadow(
                                  color: kVoidAccent.withValues(alpha: 0.4),
                                  blurRadius: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              ListenableBuilder(
                listenable: StatsService.instance,
                builder: (context, _) {
                  final stats = StatsService.instance.data;
                  final sessionActive = _isRunning && !_isCompleted;

                  return Column(
                    children: [
                      _DistractionRecordedToast(
                        trigger: _distractionFeedbackTick,
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Expanded(
                            child: _SessionStat(
                              label: 'Сессий сегодня',
                              value: '${stats.todaySessions}',
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 28,
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                          Expanded(
                            child: _DistractionCounter(
                              count: _sessionDistractions,
                              isActive: sessionActive,
                              onTap: sessionActive ? _recordDistraction : null,
                            ),
                          ),
                        ],
                      ),
                      if (sessionActive) ...[
                        SizedBox(height: m.gapS),
                        Text(
                          'Отмечайте моменты, когда вы отвлеклись от задачи',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            height: 1.35,
                            color: Colors.white.withValues(alpha: 0.38),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
              SizedBox(height: m.gapL),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed:
                          _isRunning || _isCompleted ? null : _startSession,
                      style: FilledButton.styleFrom(
                        backgroundColor: kVoidAccent,
                        disabledBackgroundColor:
                            kVoidAccent.withValues(alpha: 0.25),
                        foregroundColor: Colors.white,
                        disabledForegroundColor:
                            Colors.white.withValues(alpha: 0.4),
                        elevation: 0,
                        minimumSize: Size.fromHeight(m.buttonHeight),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(m.buttonRadius),
                        ),
                      ),
                      child: const Text(
                        'Старт',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: m.gapS * 0.6),
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          _isRunning && !_isCompleted ? _togglePause : null,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white.withValues(alpha: 0.85),
                        disabledForegroundColor:
                            Colors.white.withValues(alpha: 0.25),
                        side: BorderSide(
                          color: kVoidAccent.withValues(alpha: 0.4),
                        ),
                        minimumSize: Size.fromHeight(m.buttonHeight),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(m.buttonRadius),
                        ),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          _isPaused ? 'Продолжить' : 'Пауза',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: m.gapS * 0.6),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _resetSession,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white.withValues(alpha: 0.6),
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.15),
                        ),
                        minimumSize: Size.fromHeight(m.buttonHeight),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(m.buttonRadius),
                        ),
                      ),
                      child: const Text(
                        'Сброс',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: m.gapS),
              SizedBox(
                width: double.infinity,
                height: m.buttonHeight,
                child: FilledButton(
                  onPressed: _isRunning && !_isCompleted
                      ? () => unawaited(_finishSession())
                      : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: kVoidAccent,
                    disabledBackgroundColor:
                        kVoidAccent.withValues(alpha: 0.2),
                    foregroundColor: Colors.white,
                    disabledForegroundColor:
                        Colors.white.withValues(alpha: 0.35),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(m.buttonRadius),
                    ),
                  ),
                  child: const Text(
                    'Завершить сессию',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DistractionRecordedToast extends StatefulWidget {
  const _DistractionRecordedToast({required this.trigger});

  final int trigger;

  @override
  State<_DistractionRecordedToast> createState() =>
      _DistractionRecordedToastState();
}

class _DistractionRecordedToastState extends State<_DistractionRecordedToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _opacity = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0, end: 1)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 20,
      ),
      TweenSequenceItem(tween: ConstantTween<double>(1), weight: 45),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1, end: 0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 35,
      ),
    ]).animate(_controller);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0, 0.35, curve: Curves.easeOutCubic),
      ),
    );
  }

  @override
  void didUpdateWidget(_DistractionRecordedToast oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger > oldWidget.trigger) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        if (_controller.value == 0) {
          return const SizedBox(height: 0);
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Opacity(
            opacity: _opacity.value,
            child: SlideTransition(
              position: _slide,
              child: child,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: kVoidAccent.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: kVoidAccent.withValues(alpha: 0.35)),
          boxShadow: [
            BoxShadow(
              color: kVoidAccent.withValues(alpha: 0.18),
              blurRadius: 12,
            ),
          ],
        ),
        child: Text(
          'Отвлечение зафиксировано',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.white.withValues(alpha: 0.88),
          ),
        ),
      ),
    );
  }
}

class _DistractionCounter extends StatefulWidget {
  const _DistractionCounter({
    required this.count,
    required this.isActive,
    this.onTap,
  });

  final int count;
  final bool isActive;
  final VoidCallback? onTap;

  @override
  State<_DistractionCounter> createState() => _DistractionCounterState();
}

class _DistractionCounterState extends State<_DistractionCounter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.14)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.14, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 65,
      ),
    ]).animate(_pulseController);
    _glowAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: const Interval(0, 0.5, curve: Curves.easeOut),
      ),
    );
  }

  @override
  void didUpdateWidget(_DistractionCounter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.count > oldWidget.count) {
      _pulseController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = VoidMetrics.of(context);

    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  if (_glowAnimation.value > 0)
                    BoxShadow(
                      color: kVoidAccent
                          .withValues(alpha: 0.22 * _glowAnimation.value),
                      blurRadius: 14 * _glowAnimation.value,
                      spreadRadius: 1 * _glowAnimation.value,
                    ),
                ],
              ),
              child: child,
            ),
          );
        },
        child: Column(
          children: [
            Text(
              'Отвлечений',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.4),
              ),
            ),
            if (widget.isActive) ...[
              const SizedBox(height: 2),
              Text(
                'Нажмите при потере концентрации',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 9,
                  color: kVoidAccent.withValues(alpha: 0.55),
                ),
              ),
            ],
            const SizedBox(height: 4),
            Text(
              '${widget.count}',
              style: TextStyle(
                fontSize: m.statValueSize,
                fontWeight: FontWeight.w300,
                color: widget.isActive
                    ? Colors.white.withValues(alpha: 0.95)
                    : Colors.white.withValues(alpha: 0.9),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionStat extends StatelessWidget {
  const _SessionStat({
    required this.label,
    required this.value,
    this.hint,
  });

  final String label;
  final String value;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final m = VoidMetrics.of(context);

    return Column(
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            color: Colors.white.withValues(alpha: 0.4),
          ),
        ),
        if (hint != null) ...[
          const SizedBox(height: 2),
          Text(
            hint!,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 9,
              color: kVoidAccent.withValues(alpha: 0.55),
            ),
          ),
        ],
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: m.statValueSize,
            fontWeight: FontWeight.w300,
            color: Colors.white.withValues(alpha: 0.9),
          ),
        ),
      ],
    );
  }
}

class _CompletionSummaryRow extends StatelessWidget {
  const _CompletionSummaryRow({
    required this.label,
    required this.value,
    this.accent = false,
  });

  final String label;
  final String value;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: accent
              ? kVoidAccent.withValues(alpha: 0.35)
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.55),
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: accent
                  ? kVoidAccent
                  : Colors.white.withValues(alpha: 0.92),
            ),
          ),
        ],
      ),
    );
  }
}

class VoidAmbientGlow extends StatelessWidget {
  const VoidAmbientGlow({super.key, this.center = const Alignment(0, -0.3)});

  final Alignment center;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: center,
          radius: 0.9,
          colors: [
            kVoidAccent.withValues(alpha: 0.12),
            kVoidBackground,
          ],
        ),
      ),
    );
  }
}

class VoidAchievementsSection extends StatelessWidget {
  const VoidAchievementsSection({
    super.key,
    required this.achievements,
    required this.unlockedCount,
  });

  final List<VoidAchievement> achievements;
  final int unlockedCount;

  @override
  Widget build(BuildContext context) {
    final m = VoidMetrics.of(context);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: m.isCompact ? 16 : 18,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kVoidAccent.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Достижения',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ),
              Text(
                '$unlockedCount/${achievements.length}',
                style: TextStyle(
                  fontSize: 12,
                  color: kVoidAccent.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
          SizedBox(height: m.gapM),
          for (var index = 0; index < achievements.length; index++) ...[
            if (index > 0) SizedBox(height: m.gapS),
            VoidAchievementCard(achievement: achievements[index]),
          ],
        ],
      ),
    );
  }
}

class VoidAchievementCard extends StatelessWidget {
  const VoidAchievementCard({super.key, required this.achievement});

  final VoidAchievement achievement;

  @override
  Widget build(BuildContext context) {
    final unlocked = achievement.isUnlocked;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: unlocked
            ? kVoidAccent.withValues(alpha: 0.1)
            : Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: unlocked
              ? kVoidAccent.withValues(alpha: 0.35)
              : Colors.white.withValues(alpha: 0.08),
        ),
        boxShadow: unlocked
            ? [
                BoxShadow(
                  color: kVoidAccent.withValues(alpha: 0.12),
                  blurRadius: 10,
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: unlocked
                  ? kVoidAccent.withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.05),
              border: Border.all(
                color: unlocked
                    ? kVoidAccent.withValues(alpha: 0.45)
                    : Colors.white.withValues(alpha: 0.1),
              ),
            ),
            child: Icon(
              unlocked ? achievement.icon : Icons.lock_outline_rounded,
              size: 20,
              color: unlocked
                  ? kVoidAccent
                  : Colors.white.withValues(alpha: 0.28),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  achievement.title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: unlocked
                        ? Colors.white.withValues(alpha: 0.92)
                        : Colors.white.withValues(alpha: 0.45),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  achievement.description,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.3,
                    color: unlocked
                        ? Colors.white.withValues(alpha: 0.5)
                        : Colors.white.withValues(alpha: 0.28),
                  ),
                ),
              ],
            ),
          ),
          if (unlocked)
            Icon(
              Icons.check_circle_rounded,
              size: 18,
              color: kVoidAccent.withValues(alpha: 0.85),
            ),
        ],
      ),
    );
  }
}

class VoidDailyGoalCard extends StatefulWidget {
  const VoidDailyGoalCard({
    super.key,
    required this.todayFocusSeconds,
    required this.goalMinutes,
    required this.progress,
  });

  final int todayFocusSeconds;
  final int goalMinutes;
  final double progress;

  int get _goalSeconds => goalMinutes * 60;

  @override
  State<VoidDailyGoalCard> createState() => _VoidDailyGoalCardState();
}

class _VoidDailyGoalCardState extends State<VoidDailyGoalCard>
    with TickerProviderStateMixin {
  late final AnimationController _celebrationController;
  late final AnimationController _progressController;
  late final AnimationController _shimmerController;
  late Animation<double> _progressAnimation;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _glowAnimation;
  late final Animation<double> _sparkleAnimation;
  bool _wasCompleted = false;

  @override
  void initState() {
    super.initState();
    _wasCompleted = widget.todayFocusSeconds >= widget._goalSeconds;
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _progressAnimation = Tween<double>(begin: 0, end: widget.progress).animate(
      CurvedAnimation(
        parent: _progressController,
        curve: Curves.easeOutCubic,
      ),
    );
    _progressController.forward();

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    if (!_wasCompleted && widget.progress > 0) {
      _shimmerController.forward();
    }

    _celebrationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.05)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.05, end: 0.985)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.985, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 60,
      ),
    ]).animate(_celebrationController);
    _glowAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0, end: 1)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1, end: 0.4)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 75,
      ),
    ]).animate(_celebrationController);
    _sparkleAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _celebrationController,
        curve: const Interval(0, 0.75, curve: Curves.easeOut),
      ),
    );
  }

  void _animateProgressTo(double target) {
    final begin = _progressAnimation.value;
    _progressAnimation = Tween<double>(begin: begin, end: target).animate(
      CurvedAnimation(
        parent: _progressController,
        curve: Curves.easeOutCubic,
      ),
    );
    _progressController.forward(from: 0);
  }

  @override
  void didUpdateWidget(VoidDailyGoalCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final completed = widget.todayFocusSeconds >= widget._goalSeconds;
    if ((oldWidget.progress - widget.progress).abs() > 0.001) {
      _animateProgressTo(widget.progress);
      if (!completed) {
        _shimmerController.forward(from: 0);
      }
    }
    if (completed && !_wasCompleted) {
      HapticFeedback.mediumImpact();
      _shimmerController.stop();
      _celebrationController.forward(from: 0);
    }
    _wasCompleted = completed;
  }

  @override
  void dispose() {
    _celebrationController.dispose();
    _progressController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final completed = widget.todayFocusSeconds >= widget._goalSeconds;
    final glowBoost = _glowAnimation.value;
    final accentColor = completed ? kVoidGoalComplete : kVoidAccent;

    return AnimatedBuilder(
      animation: Listenable.merge([
        _celebrationController,
        _progressController,
        _shimmerController,
      ]),
      builder: (context, child) {
        final animatedProgress = _progressAnimation.value.clamp(0.0, 1.0);
        final percent = formatDailyGoalPercent(animatedProgress);

        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                decoration: BoxDecoration(
                  color: completed
                      ? kVoidGoalComplete.withValues(alpha: 0.06)
                      : Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: accentColor.withValues(
                      alpha: completed
                          ? 0.45 + glowBoost * 0.3
                          : 0.22 + glowBoost * 0.15,
                    ),
                  ),
                  boxShadow: [
                    if (completed || glowBoost > 0)
                      BoxShadow(
                        color: accentColor
                            .withValues(alpha: 0.12 + glowBoost * 0.32),
                        blurRadius: 16 + glowBoost * 22,
                        spreadRadius: glowBoost * 2.5,
                      ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Сегодня',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.45),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '$percent%',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: accentColor.withValues(
                              alpha: 0.88 + glowBoost * 0.12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      formatDailyGoalProgress(
                        widget.todayFocusSeconds,
                        widget.goalMinutes,
                      ),
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w300,
                        color: completed
                            ? kVoidGoalComplete.withValues(alpha: 0.95)
                            : Colors.white.withValues(alpha: 0.95),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _VoidAnimatedDailyGoalBar(
                      progress: animatedProgress,
                      shimmerValue: completed ? 0 : _shimmerController.value,
                      accentColor: accentColor,
                      glowBoost: glowBoost,
                      completed: completed,
                    ),
                    if (completed) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            size: 16,
                            color: kVoidGoalComplete.withValues(
                              alpha: 0.9 + glowBoost * 0.1,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Цель дня выполнена',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: kVoidGoalComplete.withValues(
                                alpha: 0.9 + glowBoost * 0.1,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (_sparkleAnimation.value > 0)
                _DailyGoalSparkles(animation: _sparkleAnimation.value),
            ],
          ),
        );
      },
    );
  }
}

class _VoidAnimatedDailyGoalBar extends StatelessWidget {
  const _VoidAnimatedDailyGoalBar({
    required this.progress,
    required this.shimmerValue,
    required this.accentColor,
    required this.glowBoost,
    required this.completed,
  });

  final double progress;
  final double shimmerValue;
  final Color accentColor;
  final double glowBoost;
  final bool completed;

  @override
  Widget build(BuildContext context) {
    final shimmerOffset = -1.2 + shimmerValue * 2.4;

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: 10,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(
              color: accentColor.withValues(alpha: completed ? 0.16 : 0.12),
            ),
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: progress,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: completed
                      ? LinearGradient(
                          colors: [
                            accentColor.withValues(
                              alpha: 0.8 + glowBoost * 0.2,
                            ),
                            accentColor,
                          ],
                        )
                      : LinearGradient(
                          begin: Alignment(shimmerOffset - 0.5, 0),
                          end: Alignment(shimmerOffset + 0.5, 0),
                          colors: [
                            accentColor.withValues(alpha: 0.55),
                            accentColor,
                            accentColor.withValues(alpha: 0.7),
                            accentColor.withValues(alpha: 0.55),
                          ],
                          stops: const [0.0, 0.45, 0.55, 1.0],
                        ),
                  boxShadow: progress > 0
                      ? [
                          BoxShadow(
                            color: accentColor.withValues(
                              alpha: 0.35 + glowBoost * 0.45,
                            ),
                            blurRadius: 10 + glowBoost * 14,
                            spreadRadius: completed ? 0.5 : 0,
                          ),
                        ]
                      : null,
                ),
              ),
            ),
            if (progress > 0.04)
              FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: progress,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: 0.22),
                        Colors.white.withValues(alpha: 0.02),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DailyGoalSparkles extends StatelessWidget {
  const _DailyGoalSparkles({required this.animation});

  final double animation;

  static const _offsets = [
    Offset(-0.42, -0.55),
    Offset(0.48, -0.62),
    Offset(-0.55, 0.35),
    Offset(0.52, 0.42),
    Offset(0, -0.75),
    Offset(0.35, 0.55),
  ];

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final center = Offset(
              constraints.maxWidth / 2,
              constraints.maxHeight / 2,
            );
            final radius = constraints.maxWidth * 0.38 * animation;

            return Stack(
              clipBehavior: Clip.none,
              children: [
                for (var i = 0; i < _offsets.length; i++)
                  Positioned(
                    left: center.dx +
                        _offsets[i].dx * radius -
                        3 * (1 - animation),
                    top: center.dy +
                        _offsets[i].dy * radius -
                        3 * (1 - animation),
                    child: Opacity(
                      opacity: (1 - animation).clamp(0.0, 1.0),
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: kVoidGoalComplete.withValues(alpha: 0.85),
                          boxShadow: [
                            BoxShadow(
                              color: kVoidGoalComplete.withValues(alpha: 0.5),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class VoidLevelCard extends StatelessWidget {
  const VoidLevelCard({
    super.key,
    required this.level,
    required this.totalXp,
    required this.xpInLevel,
    required this.progress,
  });

  final int level;
  final int totalXp;
  final int xpInLevel;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kVoidAccent.withValues(alpha: 0.28)),
        boxShadow: [
          BoxShadow(
            color: kVoidAccent.withValues(alpha: 0.1),
            blurRadius: 16,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Уровень',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.45),
                  ),
                ),
              ),
              Text(
                '$totalXp XP',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: kVoidAccent.withValues(alpha: 0.75),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '$level',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w300,
              color: Colors.white.withValues(alpha: 0.95),
            ),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 8,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(
                    color: kVoidAccent.withValues(alpha: 0.12),
                  ),
                  FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: progress.clamp(0.0, 1.0),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            kVoidAccent.withValues(alpha: 0.75),
                            kVoidAccent,
                          ],
                        ),
                        boxShadow: progress > 0
                            ? [
                                BoxShadow(
                                  color: kVoidAccent.withValues(alpha: 0.35),
                                  blurRadius: 8,
                                ),
                              ]
                            : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            formatLevelXpProgress(xpInLevel),
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.55),
            ),
          ),
        ],
      ),
    );
  }
}

class VoidStreakCard extends StatelessWidget {
  const VoidStreakCard({
    super.key,
    required this.currentStreak,
    required this.bestStreak,
  });

  final int currentStreak;
  final int bestStreak;

  @override
  Widget build(BuildContext context) {
    final hasStreak = currentStreak > 0;
    final accent = hasStreak ? kVoidAccent : Colors.white;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasStreak
              ? kVoidAccent.withValues(alpha: 0.28)
              : kVoidAccent.withValues(alpha: 0.15),
        ),
        boxShadow: hasStreak
            ? [
                BoxShadow(
                  color: kVoidAccent.withValues(alpha: 0.1),
                  blurRadius: 14,
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: 0.12),
              border: Border.all(color: accent.withValues(alpha: 0.3)),
            ),
            child: Icon(
              Icons.local_fire_department_rounded,
              size: 22,
              color: accent.withValues(alpha: hasStreak ? 0.95 : 0.45),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: _VoidStreakMetric(
                    label: 'Текущая серия',
                    value: '$currentStreak',
                    highlight: hasStreak,
                  ),
                ),
                Container(
                  width: 1,
                  height: 34,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
                Expanded(
                  child: _VoidStreakMetric(
                    label: 'Лучшая серия',
                    value: '$bestStreak',
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

class _VoidStreakMetric extends StatelessWidget {
  const _VoidStreakMetric({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          Text(
            value,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: highlight
                  ? kVoidAccent.withValues(alpha: 0.95)
                  : Colors.white.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              color: Colors.white.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}

class VoidStatCard extends StatelessWidget {
  const VoidStatCard({
    super.key,
    required this.label,
    required this.value,
    this.prominent = false,
  });

  final String label;
  final String value;
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    final m = VoidMetrics.of(context);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: prominent ? (m.isCompact ? 18 : 22) : (m.isCompact ? 14 : 16),
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: kVoidAccent.withValues(alpha: prominent ? 0.35 : 0.15),
        ),
        boxShadow: prominent
            ? [
                BoxShadow(
                  color: kVoidAccent.withValues(alpha: 0.12),
                  blurRadius: 20,
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.45),
            ),
          ),
          SizedBox(height: prominent ? 10 : 6),
          Text(
            value,
            style: TextStyle(
              fontSize: prominent ? m.cardValueLarge : m.cardValueMedium,
              fontWeight: FontWeight.w200,
              color: prominent
                  ? kVoidAccent
                  : Colors.white.withValues(alpha: 0.95),
              shadows: prominent
                  ? [
                      Shadow(
                        color: kVoidAccent.withValues(alpha: 0.4),
                        blurRadius: 16,
                      ),
                    ]
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}
