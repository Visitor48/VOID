import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
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
const _kFirstLaunchFeedbackShown = 'first_launch_feedback_shown';
const _kVoidTasks = 'void_tasks';
const _kVoidProjects = 'void_projects';
const _kActiveTaskId = 'void_active_task_id';
const _kActiveTaskTitle = 'void_active_task_title';
const kDefaultTaskEstimatedSessions = 5;
const kDefaultProjectColorValue = 0xFF8B5CF6;
const kDefaultProjectIconName = 'study';

class VoidProjectTemplate {
  const VoidProjectTemplate({
    required this.id,
    required this.emoji,
    required this.defaultTitle,
    required this.colorValue,
  });

  final String id;
  final String emoji;
  final String defaultTitle;
  final int colorValue;
}

const List<VoidProjectTemplate> kVoidProjectTemplates = [
  VoidProjectTemplate(
    id: 'study',
    emoji: '📚',
    defaultTitle: 'Учёба',
    colorValue: 0xFF60A5FA,
  ),
  VoidProjectTemplate(
    id: 'work',
    emoji: '💼',
    defaultTitle: 'Работа',
    colorValue: 0xFF8B5CF6,
  ),
  VoidProjectTemplate(
    id: 'void',
    emoji: '🚀',
    defaultTitle: 'VOID',
    colorValue: 0xFF8B5CF6,
  ),
  VoidProjectTemplate(
    id: 'sport',
    emoji: '🏋️',
    defaultTitle: 'Спорт',
    colorValue: 0xFFF87171,
  ),
  VoidProjectTemplate(
    id: 'finance',
    emoji: '💰',
    defaultTitle: 'Финансы',
    colorValue: 0xFFFBBF24,
  ),
  VoidProjectTemplate(
    id: 'reading',
    emoji: '📖',
    defaultTitle: 'Чтение',
    colorValue: 0xFF34D399,
  ),
  VoidProjectTemplate(
    id: 'personal',
    emoji: '🎯',
    defaultTitle: 'Личное',
    colorValue: 0xFFF472B6,
  ),
  VoidProjectTemplate(
    id: 'health',
    emoji: '❤️',
    defaultTitle: 'Здоровье',
    colorValue: 0xFFF87171,
  ),
];

const List<int> kVoidProjectColorValues = [
  0xFF8B5CF6,
  0xFF34D399,
  0xFF60A5FA,
  0xFFF472B6,
  0xFFFBBF24,
  0xFFF87171,
];

VoidProjectTemplate? voidProjectTemplateById(String id) {
  for (final template in kVoidProjectTemplates) {
    if (template.id == id) return template;
  }
  return null;
}

String resolveVoidProjectEmoji(String iconName) =>
    voidProjectTemplateById(iconName)?.emoji ?? '📁';

Color resolveVoidProjectColor(int value) => Color(value);

String formatVoidTaskCountLabel(int count) {
  final mod10 = count % 10;
  final mod100 = count % 100;
  if (mod100 >= 11 && mod100 <= 14) return '$count задач';
  if (mod10 == 1) return '$count задача';
  if (mod10 >= 2 && mod10 <= 4) return '$count задачи';
  return '$count задач';
}

String formatVoidSessionCountWord(int count) {
  final mod10 = count % 10;
  final mod100 = count % 100;
  if (mod100 >= 11 && mod100 <= 14) return 'сессий';
  if (mod10 == 1) return 'сессия';
  if (mod10 >= 2 && mod10 <= 4) return 'сессии';
  return 'сессий';
}

String formatVoidSessionProgressLabel(int completed, int estimated) =>
    '$completed / $estimated ${formatVoidSessionCountWord(estimated)}';
const _kDeepWorkModeMinutes = 'deep_work_mode_minutes';
const _kFocusModeStats = 'focus_mode_stats';
const _kBonusXp = 'bonus_xp';
const _kWeeklyGoalsWeekKey = 'weekly_goals_week_key';
const _kWeeklyGoalsClaimed = 'weekly_goals_claimed';
const _kWeeklySessionsCount = 'weekly_sessions_count';
const kVoidWeeklyFocusTargetSeconds = 5 * 3600;
const kVoidWeeklySessionsTarget = 20;
const kVoidWeeklyStreakTarget = 3;
const kVoidWeeklyGoalFocusXp = 30;
const kVoidWeeklyGoalSessionsXp = 25;
const kVoidWeeklyGoalStreakXp = 20;
const _kDefaultDailyGoalMinutes = 60;
const _kDefaultDeepWorkModeMinutes = 25;
const kFirstLaunchFeedbackSessionThreshold = 3;
const kVoidAppVersion = '1.0.0';
const kVoidBackupFormatVersion = 1;
const kVoidRuStoreUrl = 'https://www.rustore.ru/catalog/app/ru.voidapp.focus';

const _kNotificationsEnabled = 'notifications_enabled';
const _kNotificationHour = 'notification_hour';
const _kNotificationMinute = 'notification_minute';
const kDefaultNotificationHour = 19;
const kDefaultNotificationMinute = 0;
const int kVoidNotificationDailyReminderId = 1001;
const int kVoidNotificationStreakWarningId = 1002;
const String kVoidNotificationChannelId = 'void_smart_reminders';

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
    this.taskId,
    this.taskTitle,
    this.focusModeMinutes,
  });

  final DateTime completedAt;
  final int focusSeconds;
  final int distractions;
  final int focusScore;
  final int xp;
  final String? taskId;
  final String? taskTitle;
  final int? focusModeMinutes;

  VoidSessionRecord copyWith({
    DateTime? completedAt,
    int? focusSeconds,
    int? distractions,
    int? focusScore,
    int? xp,
    String? taskId,
    String? taskTitle,
    int? focusModeMinutes,
  }) {
    return VoidSessionRecord(
      completedAt: completedAt ?? this.completedAt,
      focusSeconds: focusSeconds ?? this.focusSeconds,
      distractions: distractions ?? this.distractions,
      focusScore: focusScore ?? this.focusScore,
      xp: xp ?? this.xp,
      taskId: taskId ?? this.taskId,
      taskTitle: taskTitle ?? this.taskTitle,
      focusModeMinutes: focusModeMinutes ?? this.focusModeMinutes,
    );
  }

  Map<String, dynamic> toJson() => {
        'completedAt': completedAt.toIso8601String(),
        'focusSeconds': focusSeconds,
        'distractions': distractions,
        'focusScore': focusScore,
        'xp': xp,
        if (taskId != null) 'taskId': taskId,
        if (taskTitle != null) 'taskTitle': taskTitle,
        if (focusModeMinutes != null) 'focusModeMinutes': focusModeMinutes,
      };

  factory VoidSessionRecord.fromJson(Map<String, dynamic> json) {
    final distractions = json['distractions'] as int? ?? 0;
    return VoidSessionRecord(
      completedAt: DateTime.parse(json['completedAt'] as String),
      focusSeconds: json['focusSeconds'] as int? ?? 0,
      distractions: distractions,
      focusScore: computeFocusScore(distractions),
      xp: json['xp'] as int? ?? 0,
      taskId: json['taskId'] as String?,
      taskTitle: json['taskTitle'] as String?,
      focusModeMinutes: json['focusModeMinutes'] as int?,
    );
  }
}

class VoidProject {
  const VoidProject({
    required this.id,
    required this.title,
    required this.createdAt,
    this.colorValue = kDefaultProjectColorValue,
    this.iconName = kDefaultProjectIconName,
  });

  final String id;
  final String title;
  final DateTime createdAt;
  final int colorValue;
  final String iconName;

  Color get color => resolveVoidProjectColor(colorValue);

  String get emoji => resolveVoidProjectEmoji(iconName);

  VoidProject copyWith({
    String? id,
    String? title,
    DateTime? createdAt,
    int? colorValue,
    String? iconName,
  }) {
    return VoidProject(
      id: id ?? this.id,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      colorValue: colorValue ?? this.colorValue,
      iconName: iconName ?? this.iconName,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'createdAt': createdAt.toIso8601String(),
        'colorValue': colorValue,
        'iconName': iconName,
      };

  factory VoidProject.fromJson(Map<String, dynamic> json) {
    return VoidProject(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      createdAt: DateTime.parse(json['createdAt'] as String),
      colorValue: json['colorValue'] as int? ?? kDefaultProjectColorValue,
      iconName: json['iconName'] as String? ?? kDefaultProjectIconName,
    );
  }
}

class VoidProjectEditorResult {
  const VoidProjectEditorResult({
    required this.title,
    required this.colorValue,
    required this.iconName,
  });

  final String title;
  final int colorValue;
  final String iconName;
}

class VoidTask {
  const VoidTask({
    required this.id,
    required this.title,
    required this.description,
    required this.isCompleted,
    required this.estimatedSessions,
    required this.totalFocusSeconds,
    required this.completedSessions,
    required this.focusScoreSum,
    required this.bestFocusScore,
    required this.createdAt,
    this.projectId,
  });

  final String id;
  final String title;
  final String description;
  final bool isCompleted;
  final int estimatedSessions;
  final int totalFocusSeconds;
  final int completedSessions;
  final int focusScoreSum;
  final int bestFocusScore;
  final DateTime createdAt;
  final String? projectId;

  String get statusLabel => isCompleted ? 'Завершена' : 'Активна';

  double get averageFocusScore =>
      completedSessions == 0 ? 0 : focusScoreSum / completedSessions;

  double get sessionProgress => estimatedSessions <= 0
      ? 0
      : completedSessions / estimatedSessions;

  double get sessionProgressBarValue => sessionProgress.clamp(0.0, 1.0);

  int get sessionProgressPercent => estimatedSessions <= 0
      ? 0
      : (sessionProgress * 100).round();

  String get sessionProgressLabel =>
      formatVoidSessionProgressLabel(completedSessions, estimatedSessions);

  VoidTask copyWith({
    String? id,
    String? title,
    String? description,
    bool? isCompleted,
    int? estimatedSessions,
    int? totalFocusSeconds,
    int? completedSessions,
    int? focusScoreSum,
    int? bestFocusScore,
    DateTime? createdAt,
    String? projectId,
    bool clearProjectId = false,
  }) {
    return VoidTask(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      isCompleted: isCompleted ?? this.isCompleted,
      estimatedSessions: estimatedSessions ?? this.estimatedSessions,
      totalFocusSeconds: totalFocusSeconds ?? this.totalFocusSeconds,
      completedSessions: completedSessions ?? this.completedSessions,
      focusScoreSum: focusScoreSum ?? this.focusScoreSum,
      bestFocusScore: bestFocusScore ?? this.bestFocusScore,
      createdAt: createdAt ?? this.createdAt,
      projectId: clearProjectId ? null : (projectId ?? this.projectId),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'isCompleted': isCompleted,
        'estimatedSessions': estimatedSessions,
        'totalFocusSeconds': totalFocusSeconds,
        'completedSessions': completedSessions,
        'focusScoreSum': focusScoreSum,
        'bestFocusScore': bestFocusScore,
        'createdAt': createdAt.toIso8601String(),
        if (projectId != null) 'projectId': projectId,
      };

  factory VoidTask.fromJson(Map<String, dynamic> json) {
    return VoidTask(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      isCompleted: json['isCompleted'] as bool? ?? false,
      estimatedSessions: json['estimatedSessions'] as int? ??
          kDefaultTaskEstimatedSessions,
      totalFocusSeconds: json['totalFocusSeconds'] as int? ?? 0,
      completedSessions: json['completedSessions'] as int? ?? 0,
      focusScoreSum: json['focusScoreSum'] as int? ?? 0,
      bestFocusScore: json['bestFocusScore'] as int? ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String),
      projectId: json['projectId'] as String?,
    );
  }
}

class VoidTaskSessionProgressSection extends StatelessWidget {
  const VoidTaskSessionProgressSection({
    super.key,
    required this.task,
    required this.accent,
    this.showFocusTime = true,
  });

  final VoidTask task;
  final Color accent;
  final bool showFocusTime;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Прогресс',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.45),
              ),
            ),
            const Spacer(),
            Text(
              '${task.sessionProgressPercent}%',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: accent.withValues(alpha: 0.9),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          task.sessionProgressLabel,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Colors.white.withValues(alpha: 0.82),
          ),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: task.sessionProgressBarValue,
            minHeight: 6,
            backgroundColor: Colors.white.withValues(alpha: 0.08),
            valueColor: AlwaysStoppedAnimation(
              task.sessionProgress >= 1.0 ? kVoidGoalComplete : accent,
            ),
          ),
        ),
        if (showFocusTime) ...[
          const SizedBox(height: 8),
          Text(
            formatFocusDuration(task.totalFocusSeconds),
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.42),
            ),
          ),
        ],
      ],
    );
  }
}

class VoidFocusBreakdownEntry {
  const VoidFocusBreakdownEntry({
    required this.title,
    required this.focusSeconds,
    required this.sessionsCount,
  });

  final String title;
  final int focusSeconds;
  final int sessionsCount;
}

class VoidTaskEditorResult {
  const VoidTaskEditorResult({
    required this.title,
    required this.description,
    required this.isCompleted,
    required this.estimatedSessions,
    this.projectId,
  });

  final String title;
  final String description;
  final bool isCompleted;
  final int estimatedSessions;
  final String? projectId;
}

class VoidDeepWorkMode {
  const VoidDeepWorkMode({
    required this.minutes,
    required this.recommendation,
  });

  final int minutes;
  final String recommendation;

  static const light = VoidDeepWorkMode(
    minutes: 25,
    recommendation: 'Light Focus',
  );
  static const deep = VoidDeepWorkMode(
    minutes: 50,
    recommendation: 'Deep Focus',
  );
  static const elite = VoidDeepWorkMode(
    minutes: 90,
    recommendation: 'Elite Focus',
  );

  static const options = [light, deep, elite];

  static VoidDeepWorkMode? forMinutes(int minutes) {
    for (final mode in options) {
      if (mode.minutes == minutes) return mode;
    }
    return null;
  }

  static VoidDeepWorkMode resolve(int minutes) =>
      forMinutes(minutes) ?? light;

  String get durationLabel => '$minutes мин';
}

class VoidFocusModeStatEntry {
  const VoidFocusModeStatEntry({
    required this.minutes,
    required this.sessions,
    required this.focusSeconds,
  });

  final int minutes;
  final int sessions;
  final int focusSeconds;

  VoidDeepWorkMode get mode => VoidDeepWorkMode.resolve(minutes);
}

class VoidFocusModeStats {
  const VoidFocusModeStats({required this.entries});

  final List<VoidFocusModeStatEntry> entries;

  static const empty = VoidFocusModeStats(
    entries: [
      VoidFocusModeStatEntry(minutes: 25, sessions: 0, focusSeconds: 0),
      VoidFocusModeStatEntry(minutes: 50, sessions: 0, focusSeconds: 0),
      VoidFocusModeStatEntry(minutes: 90, sessions: 0, focusSeconds: 0),
    ],
  );

  VoidFocusModeStatEntry entryForMinutes(int minutes) {
    final resolved = VoidDeepWorkMode.resolve(minutes).minutes;
    return entries.firstWhere((entry) => entry.minutes == resolved);
  }
}

Map<String, dynamic> emptyFocusModeStatsMap() => {
      for (final mode in VoidDeepWorkMode.options)
        '${mode.minutes}': {'sessions': 0, 'focusSeconds': 0},
    };

VoidFocusModeStats parseFocusModeStatsMap(Map<String, dynamic> raw) {
  return VoidFocusModeStats(
    entries: VoidDeepWorkMode.options
        .map((mode) {
          final bucket = raw['${mode.minutes}'];
          if (bucket is! Map) {
            return VoidFocusModeStatEntry(
              minutes: mode.minutes,
              sessions: 0,
              focusSeconds: 0,
            );
          }
          return VoidFocusModeStatEntry(
            minutes: mode.minutes,
            sessions: bucket['sessions'] is num
                ? (bucket['sessions'] as num).toInt()
                : int.tryParse('${bucket['sessions']}') ?? 0,
            focusSeconds: bucket['focusSeconds'] is num
                ? (bucket['focusSeconds'] as num).toInt()
                : int.tryParse('${bucket['focusSeconds']}') ?? 0,
          );
        })
        .toList(),
  );
}

VoidFocusModeStats buildFocusModeStatsFromSessions(
  List<VoidSessionRecord> sessions,
) {
  final buckets = {
    for (final mode in VoidDeepWorkMode.options) mode.minutes: (sessions: 0, focus: 0),
  };

  for (final session in sessions) {
    if (session.focusSeconds <= 0) continue;
    final minutes =
        VoidDeepWorkMode.resolve(session.focusModeMinutes ?? 25).minutes;
    final current = buckets[minutes]!;
    buckets[minutes] = (
      sessions: current.sessions + 1,
      focus: current.focus + session.focusSeconds,
    );
  }

  return VoidFocusModeStats(
    entries: VoidDeepWorkMode.options
        .map(
          (mode) => VoidFocusModeStatEntry(
            minutes: mode.minutes,
            sessions: buckets[mode.minutes]!.sessions,
            focusSeconds: buckets[mode.minutes]!.focus,
          ),
        )
        .toList(),
  );
}

class VoidTaskSelection {
  const VoidTaskSelection({this.taskId, this.taskTitle});

  final String? taskId;
  final String? taskTitle;

  bool get hasTask => taskId != null && taskTitle != null;

  static const withoutTask = VoidTaskSelection();
}

String generateVoidTaskId() =>
    '${DateTime.now().microsecondsSinceEpoch}';

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

  VoidDayActivity copyWith({
    DateTime? date,
    int? focusSeconds,
    int? sessionsCount,
    int? distractions,
    double? averageFocusScore,
    int? xpEarned,
  }) {
    return VoidDayActivity(
      date: date ?? this.date,
      focusSeconds: focusSeconds ?? this.focusSeconds,
      sessionsCount: sessionsCount ?? this.sessionsCount,
      distractions: distractions ?? this.distractions,
      averageFocusScore: averageFocusScore ?? this.averageFocusScore,
      xpEarned: xpEarned ?? this.xpEarned,
    );
  }
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

Set<DateTime> activeDatesFromActivity(Map<String, VoidDayActivity> activity) {
  return activity.entries
      .where((entry) => entry.value.focusSeconds > 0)
      .map((entry) => normalizeActivityDate(entry.value.date))
      .toSet();
}

int computeCurrentStreakFromActivity(Map<String, VoidDayActivity> activity) {
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

int computeBestStreakFromActivity(Map<String, VoidDayActivity> activity) {
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

VoidDayActivity voidDayActivityFromJsonEntry(String key, Object? value) {
  final date = _parseDateKey(key);
  if (value is num) {
    return VoidDayActivity(date: date, focusSeconds: value.toInt());
  }
  if (value is Map) {
    return VoidDayActivity(
      date: date,
      focusSeconds: (value['focusSeconds'] as num?)?.toInt() ?? 0,
      sessionsCount: (value['sessionsCount'] as num?)?.toInt() ?? 0,
      distractions: (value['distractions'] as num?)?.toInt() ?? 0,
      averageFocusScore:
          (value['averageFocusScore'] as num?)?.toDouble() ?? 0,
      xpEarned: (value['xpEarned'] as num?)?.toInt() ?? 0,
    );
  }
  return VoidDayActivity(date: date, focusSeconds: 0);
}

Map<String, VoidDayActivity> parseDailyActivityMap(String? raw) {
  if (raw == null || raw.isEmpty) return {};
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return {};
    return decoded.map(
      (key, value) => MapEntry(
        key.toString(),
        voidDayActivityFromJsonEntry(key.toString(), value),
      ),
    );
  } catch (_) {
    return {};
  }
}

Map<String, VoidDayActivity> parseDailyActivityFromDynamicMap(
  Map<dynamic, dynamic> raw,
) {
  return raw.map(
    (key, value) => MapEntry(
      key.toString(),
      voidDayActivityFromJsonEntry(key.toString(), value),
    ),
  );
}

String encodeDailyActivityMap(Map<String, VoidDayActivity> activity) {
  return jsonEncode(exportDailyActivityJson(activity));
}

Map<String, dynamic> exportDailyActivityJson(
  Map<String, VoidDayActivity> activity,
) {
  return {
    for (final entry in activity.entries)
      entry.key: entry.value.focusSeconds,
  };
}

VoidDayActivity mergeDailyActivity({
  required String dayKey,
  VoidDayActivity? existing,
  required int addedFocusSeconds,
  int addedDistractions = 0,
  int addedFocusScore = 0,
  int addedXp = 0,
}) {
  final date = existing?.date ?? _parseDateKey(dayKey);
  final sessionsCount = (existing?.sessionsCount ?? 0) + 1;
  final totalFocus = (existing?.focusSeconds ?? 0) + addedFocusSeconds;
  final totalDistractions = (existing?.distractions ?? 0) + addedDistractions;
  final previousScoreSum =
      (existing?.averageFocusScore ?? 0) * (existing?.sessionsCount ?? 0);
  final averageFocusScore = sessionsCount == 0
      ? 0.0
      : (previousScoreSum + addedFocusScore) / sessionsCount;

  return VoidDayActivity(
    date: date,
    focusSeconds: totalFocus,
    sessionsCount: sessionsCount,
    distractions: totalDistractions,
    averageFocusScore: averageFocusScore,
    xpEarned: (existing?.xpEarned ?? 0) + addedXp,
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

class VoidPersonalRecords {
  const VoidPersonalRecords({
    required this.longestSessionSeconds,
    required this.bestFocusScore,
    required this.mostSessionsInDay,
    required this.longestStreak,
    required this.mostFocusTimeInDaySeconds,
  });

  final int longestSessionSeconds;
  final int bestFocusScore;
  final int mostSessionsInDay;
  final int longestStreak;
  final int mostFocusTimeInDaySeconds;

  static const empty = VoidPersonalRecords(
    longestSessionSeconds: 0,
    bestFocusScore: 0,
    mostSessionsInDay: 0,
    longestStreak: 0,
    mostFocusTimeInDaySeconds: 0,
  );

  bool get hasAnyRecord =>
      longestSessionSeconds > 0 ||
      bestFocusScore > 0 ||
      mostSessionsInDay > 0 ||
      longestStreak > 0 ||
      mostFocusTimeInDaySeconds > 0;
}

VoidPersonalRecords buildPersonalRecords({
  required List<VoidSessionRecord> sessionHistory,
  required Map<String, VoidDayActivity> activity,
  required int bestStreak,
}) {
  var longestSessionSeconds = 0;
  var bestFocusScore = 0;
  final sessionsByDay = <String, int>{};

  for (final session in sessionHistory) {
    if (session.focusSeconds > longestSessionSeconds) {
      longestSessionSeconds = session.focusSeconds;
    }
    if (session.focusScore > bestFocusScore) {
      bestFocusScore = session.focusScore;
    }
    final dayKey = StatsService.dateKey(
      normalizeActivityDate(session.completedAt),
    );
    sessionsByDay[dayKey] = (sessionsByDay[dayKey] ?? 0) + 1;
  }

  var mostSessionsInDay = 0;
  for (final count in sessionsByDay.values) {
    if (count > mostSessionsInDay) {
      mostSessionsInDay = count;
    }
  }

  var mostFocusTimeInDaySeconds = 0;
  for (final day in activity.values) {
    if (day.focusSeconds > mostFocusTimeInDaySeconds) {
      mostFocusTimeInDaySeconds = day.focusSeconds;
    }
  }

  return VoidPersonalRecords(
    longestSessionSeconds: longestSessionSeconds,
    bestFocusScore: bestFocusScore,
    mostSessionsInDay: mostSessionsInDay,
    longestStreak: bestStreak,
    mostFocusTimeInDaySeconds: mostFocusTimeInDaySeconds,
  );
}

String formatPersonalRecordDuration(int seconds) =>
    seconds > 0 ? formatFocusDuration(seconds) : '—';

String formatPersonalRecordCount(int value) => value > 0 ? '$value' : '—';

String formatPersonalRecordScore(int score) =>
    score > 0 ? formatFocusScore(score) : '—';

String formatCalendarDayTitle(DateTime date) {
  return '${date.day} ${_kMonthLabels[date.month - 1]}';
}

class VoidWeekBounds {
  const VoidWeekBounds({required this.start, required this.end});

  final DateTime start;
  final DateTime end;
}

VoidWeekBounds weekBoundsContaining(DateTime date) {
  final normalized = normalizeActivityDate(date);
  final start = normalized.subtract(Duration(days: normalized.weekday - 1));
  final end = start.add(const Duration(days: 6));
  return VoidWeekBounds(start: start, end: end);
}

bool isDateWithinWeek(DateTime date, VoidWeekBounds bounds) {
  final normalized = normalizeActivityDate(date);
  return !normalized.isBefore(bounds.start) && !normalized.isAfter(bounds.end);
}

String formatWeeklyReviewPeriod(VoidWeekBounds bounds) {
  final start = bounds.start;
  final end = bounds.end;
  if (start.month == end.month) {
    return '${start.day}–${end.day} ${_kMonthLabels[start.month - 1]}';
  }
  return '${start.day} ${_kMonthLabels[start.month - 1]} – '
      '${end.day} ${_kMonthLabels[end.month - 1]}';
}

class VoidWeeklyReviewStats {
  const VoidWeeklyReviewStats({
    required this.weekBounds,
    required this.sessionsCount,
    required this.totalFocusSeconds,
    required this.averageFocusScore,
    required this.totalDistractions,
    required this.bestDay,
    required this.bestDayFocusSeconds,
    required this.longestSessionSeconds,
  });

  final VoidWeekBounds weekBounds;
  final int sessionsCount;
  final int totalFocusSeconds;
  final double averageFocusScore;
  final int totalDistractions;
  final DateTime? bestDay;
  final int bestDayFocusSeconds;
  final int longestSessionSeconds;

  factory VoidWeeklyReviewStats.fromSessions({
    required List<VoidSessionRecord> sessions,
    required VoidWeekBounds weekBounds,
  }) {
    final weekSessions = sessions
        .where((session) => isDateWithinWeek(session.completedAt, weekBounds))
        .toList();

    if (weekSessions.isEmpty) {
      return VoidWeeklyReviewStats(
        weekBounds: weekBounds,
        sessionsCount: 0,
        totalFocusSeconds: 0,
        averageFocusScore: 0,
        totalDistractions: 0,
        bestDay: null,
        bestDayFocusSeconds: 0,
        longestSessionSeconds: 0,
      );
    }

    final totalFocusSeconds = weekSessions.fold<int>(
      0,
      (sum, session) => sum + session.focusSeconds,
    );
    final totalDistractions = weekSessions.fold<int>(
      0,
      (sum, session) => sum + session.distractions,
    );
    final scoreTotal = weekSessions.fold<int>(
      0,
      (sum, session) => sum + session.focusScore,
    );
    final longestSessionSeconds = weekSessions
        .map((session) => session.focusSeconds)
        .reduce((a, b) => a > b ? a : b);

    final focusByDay = <DateTime, int>{};
    for (final session in weekSessions) {
      final day = normalizeActivityDate(session.completedAt);
      focusByDay[day] = (focusByDay[day] ?? 0) + session.focusSeconds;
    }
    DateTime? bestDay;
    var bestDayFocusSeconds = 0;
    for (final entry in focusByDay.entries) {
      if (entry.value > bestDayFocusSeconds) {
        bestDay = entry.key;
        bestDayFocusSeconds = entry.value;
      }
    }

    return VoidWeeklyReviewStats(
      weekBounds: weekBounds,
      sessionsCount: weekSessions.length,
      totalFocusSeconds: totalFocusSeconds,
      averageFocusScore: scoreTotal / weekSessions.length,
      totalDistractions: totalDistractions,
      bestDay: bestDay,
      bestDayFocusSeconds: bestDayFocusSeconds,
      longestSessionSeconds: longestSessionSeconds,
    );
  }

  String get bestDayLabel {
    if (bestDay == null || bestDayFocusSeconds <= 0) return '—';
    final day = bestDay!;
    return '${formatCalendarDayTitle(day)} (${_kDayLabels[day.weekday - 1]})';
  }
}

class VoidWeeklyReviewData {
  const VoidWeeklyReviewData({
    required this.currentWeek,
    required this.previousWeek,
    required this.summary,
  });

  final VoidWeeklyReviewStats currentWeek;
  final VoidWeeklyReviewStats previousWeek;
  final String summary;
}

VoidWeeklyReviewData buildWeeklyReviewData({
  required List<VoidSessionRecord> sessionHistory,
  DateTime? referenceDate,
}) {
  final reference = referenceDate ?? DateTime.now();
  final currentBounds = weekBoundsContaining(reference);
  final previousReference = currentBounds.start.subtract(const Duration(days: 1));
  final previousBounds = weekBoundsContaining(previousReference);

  final currentWeek = VoidWeeklyReviewStats.fromSessions(
    sessions: sessionHistory,
    weekBounds: currentBounds,
  );
  final previousWeek = VoidWeeklyReviewStats.fromSessions(
    sessions: sessionHistory,
    weekBounds: previousBounds,
  );

  return VoidWeeklyReviewData(
    currentWeek: currentWeek,
    previousWeek: previousWeek,
    summary: buildWeeklyMotivationalSummary(
      current: currentWeek,
      previous: previousWeek,
    ),
  );
}

class VoidProductivityInsights {
  const VoidProductivityInsights({
    required this.mostFocusedProjectTitle,
    required this.mostFocusedProjectSeconds,
    required this.mostFocusedTaskTitle,
    required this.mostFocusedTaskSeconds,
    required this.averageSessionDurationSeconds,
    required this.bestFocusDay,
    required this.bestFocusDaySeconds,
    required this.bestFocusWeekBounds,
    required this.bestFocusWeekSeconds,
    required this.sessionsCount,
    required this.totalProjectFocusSeconds,
    required this.projectBreakdown,
    required this.taskBreakdown,
  });

  final String? mostFocusedProjectTitle;
  final int mostFocusedProjectSeconds;
  final String? mostFocusedTaskTitle;
  final int mostFocusedTaskSeconds;
  final int averageSessionDurationSeconds;
  final DateTime? bestFocusDay;
  final int bestFocusDaySeconds;
  final VoidWeekBounds? bestFocusWeekBounds;
  final int bestFocusWeekSeconds;
  final int sessionsCount;
  final int totalProjectFocusSeconds;
  final List<VoidFocusBreakdownEntry> projectBreakdown;
  final List<VoidFocusBreakdownEntry> taskBreakdown;

  bool get hasData => sessionsCount > 0;

  static const empty = VoidProductivityInsights(
    mostFocusedProjectTitle: null,
    mostFocusedProjectSeconds: 0,
    mostFocusedTaskTitle: null,
    mostFocusedTaskSeconds: 0,
    averageSessionDurationSeconds: 0,
    bestFocusDay: null,
    bestFocusDaySeconds: 0,
    bestFocusWeekBounds: null,
    bestFocusWeekSeconds: 0,
    sessionsCount: 0,
    totalProjectFocusSeconds: 0,
    projectBreakdown: [],
    taskBreakdown: [],
  );

  String get totalProjectFocusLabel => totalProjectFocusSeconds <= 0
      ? '—'
      : formatFocusDuration(totalProjectFocusSeconds);

  String get mostFocusedProjectLabel =>
      _formatInsightTitleDuration(
        mostFocusedProjectTitle,
        mostFocusedProjectSeconds,
      );

  String get mostFocusedTaskLabel =>
      _formatInsightTitleDuration(mostFocusedTaskTitle, mostFocusedTaskSeconds);

  String get averageSessionDurationLabel => sessionsCount == 0
      ? '—'
      : formatFocusDuration(averageSessionDurationSeconds);

  String get bestFocusDayLabel {
    if (bestFocusDay == null || bestFocusDaySeconds <= 0) return '—';
    final day = bestFocusDay!;
    return '${formatCalendarDayTitle(day)} (${_kDayLabels[day.weekday - 1]}) · '
        '${formatFocusDuration(bestFocusDaySeconds)}';
  }

  String get bestFocusWeekLabel {
    if (bestFocusWeekBounds == null || bestFocusWeekSeconds <= 0) return '—';
    return '${formatWeeklyReviewPeriod(bestFocusWeekBounds!)} · '
        '${formatFocusDuration(bestFocusWeekSeconds)}';
  }
}

String _formatInsightTitleDuration(String? title, int seconds) {
  if (title == null || title.isEmpty || seconds <= 0) return '—';
  return '$title · ${formatFocusDuration(seconds)}';
}

VoidProductivityInsights buildProductivityInsights({
  required List<VoidSessionRecord> sessionHistory,
  required List<VoidTask> tasks,
  required List<VoidProject> projects,
}) {
  if (sessionHistory.isEmpty) {
    return VoidProductivityInsights.empty;
  }

  VoidTask? taskById(String id) {
    for (final task in tasks) {
      if (task.id == id) return task;
    }
    return null;
  }

  VoidProject? projectById(String id) {
    for (final project in projects) {
      if (project.id == id) return project;
    }
    return null;
  }

  String? taskTitleForId(String taskId) {
    final task = taskById(taskId);
    if (task != null) return task.title;
    for (final session in sessionHistory) {
      if (session.taskId == taskId &&
          session.taskTitle != null &&
          session.taskTitle!.isNotEmpty) {
        return session.taskTitle;
      }
    }
    return null;
  }

  final focusByTask = <String, int>{};
  final focusByProject = <String, int>{};
  final sessionsByTask = <String, int>{};
  final sessionsByProject = <String, int>{};
  var totalFocusSeconds = 0;

  for (final session in sessionHistory) {
    totalFocusSeconds += session.focusSeconds;
    final taskId = session.taskId;
    if (taskId == null) continue;

    focusByTask[taskId] = (focusByTask[taskId] ?? 0) + session.focusSeconds;
    sessionsByTask[taskId] = (sessionsByTask[taskId] ?? 0) + 1;
    final projectId = taskById(taskId)?.projectId;
    if (projectId != null) {
      focusByProject[projectId] =
          (focusByProject[projectId] ?? 0) + session.focusSeconds;
      sessionsByProject[projectId] =
          (sessionsByProject[projectId] ?? 0) + 1;
    }
  }

  String? topTaskId;
  var topTaskSeconds = 0;
  for (final entry in focusByTask.entries) {
    if (entry.value > topTaskSeconds) {
      topTaskId = entry.key;
      topTaskSeconds = entry.value;
    }
  }

  String? topProjectId;
  var topProjectSeconds = 0;
  for (final entry in focusByProject.entries) {
    if (entry.value > topProjectSeconds) {
      topProjectId = entry.key;
      topProjectSeconds = entry.value;
    }
  }

  final dayActivity = aggregateDayActivityFromSessions(sessionHistory);
  DateTime? bestFocusDay;
  var bestFocusDaySeconds = 0;
  for (final activity in dayActivity.values) {
    if (activity.focusSeconds > bestFocusDaySeconds) {
      bestFocusDay = activity.date;
      bestFocusDaySeconds = activity.focusSeconds;
    }
  }

  final focusByWeekStart = <DateTime, int>{};
  for (final session in sessionHistory) {
    final weekStart = weekBoundsContaining(session.completedAt).start;
    focusByWeekStart[weekStart] =
        (focusByWeekStart[weekStart] ?? 0) + session.focusSeconds;
  }

  DateTime? bestWeekStart;
  var bestFocusWeekSeconds = 0;
  for (final entry in focusByWeekStart.entries) {
    if (entry.value > bestFocusWeekSeconds) {
      bestWeekStart = entry.key;
      bestFocusWeekSeconds = entry.value;
    }
  }

  final projectBreakdown = focusByProject.entries
      .map(
        (entry) => VoidFocusBreakdownEntry(
          title: projectById(entry.key)?.title ?? 'Проект',
          focusSeconds: entry.value,
          sessionsCount: sessionsByProject[entry.key] ?? 0,
        ),
      )
      .toList()
    ..sort((a, b) => b.focusSeconds.compareTo(a.focusSeconds));

  final taskBreakdown = focusByTask.entries
      .map(
        (entry) => VoidFocusBreakdownEntry(
          title: taskTitleForId(entry.key) ?? 'Задача',
          focusSeconds: entry.value,
          sessionsCount: sessionsByTask[entry.key] ?? 0,
        ),
      )
      .toList()
    ..sort((a, b) => b.focusSeconds.compareTo(a.focusSeconds));

  return VoidProductivityInsights(
    mostFocusedProjectTitle:
        topProjectId == null ? null : projectById(topProjectId)?.title,
    mostFocusedProjectSeconds: topProjectSeconds,
    mostFocusedTaskTitle:
        topTaskId == null ? null : taskTitleForId(topTaskId),
    mostFocusedTaskSeconds: topTaskSeconds,
    averageSessionDurationSeconds:
        totalFocusSeconds ~/ sessionHistory.length,
    bestFocusDay: bestFocusDay,
    bestFocusDaySeconds: bestFocusDaySeconds,
    bestFocusWeekBounds: bestWeekStart == null
        ? null
        : weekBoundsContaining(bestWeekStart),
    bestFocusWeekSeconds: bestFocusWeekSeconds,
    sessionsCount: sessionHistory.length,
    totalProjectFocusSeconds: focusByProject.values.fold<int>(
      0,
      (sum, seconds) => sum + seconds,
    ),
    projectBreakdown: projectBreakdown,
    taskBreakdown: taskBreakdown,
  );
}

String buildWeeklyMotivationalSummary({
  required VoidWeeklyReviewStats current,
  required VoidWeeklyReviewStats previous,
}) {
  if (current.sessionsCount == 0) {
    return 'Начните неделю с первой фокус-сессии';
  }

  final focusLine =
      'На этой неделе вы провели ${formatFocusDuration(current.totalFocusSeconds)} в глубоком фокусе';

  if (previous.sessionsCount > 0 &&
      previous.averageFocusScore > 0 &&
      current.averageFocusScore > previous.averageFocusScore) {
    final improvement = ((current.averageFocusScore - previous.averageFocusScore) /
            previous.averageFocusScore *
            100)
        .round();
    if (improvement >= 5) {
      return 'Отличная неделя! Вы улучшили концентрацию на $improvement%';
    }
  }

  if (current.totalFocusSeconds >= 3600 || current.sessionsCount >= 5) {
    return 'Отличная неделя! $focusLine';
  }

  return focusLine;
}

const String kVoidWeeklyGoalFocusId = 'focus_5h';
const String kVoidWeeklyGoalSessionsId = 'sessions_20';
const String kVoidWeeklyGoalStreakId = 'streak_3d';

class VoidWeeklyGoalProgress {
  const VoidWeeklyGoalProgress({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.current,
    required this.target,
    required this.xpReward,
    required this.isRewardClaimed,
  });

  final String id;
  final String title;
  final String subtitle;
  final int current;
  final int target;
  final int xpReward;
  final bool isRewardClaimed;

  double get progress =>
      target <= 0 ? 0 : (current / target).clamp(0.0, 1.0);

  bool get isCompleted => current >= target;

  String get progressLabel => formatWeeklyGoalProgressLabel(this);
}

class VoidWeeklyGoalsData {
  const VoidWeeklyGoalsData({
    required this.weekBounds,
    required this.goals,
    required this.completedCount,
  });

  final VoidWeekBounds weekBounds;
  final List<VoidWeeklyGoalProgress> goals;
  final int completedCount;
}

int computeWeekFocusSeconds(
  Map<String, VoidDayActivity> activity,
  VoidWeekBounds bounds,
) {
  var total = 0;
  for (var index = 0; index < 7; index++) {
    final day = bounds.start.add(Duration(days: index));
    total += activity[StatsService.dateKey(day)]?.focusSeconds ?? 0;
  }
  return total;
}

int computeWeekMaxStreakDays(
  Map<String, VoidDayActivity> activity,
  VoidWeekBounds bounds,
) {
  var best = 0;
  var current = 0;
  for (var index = 0; index < 7; index++) {
    final day = bounds.start.add(Duration(days: index));
    final key = StatsService.dateKey(day);
    if ((activity[key]?.focusSeconds ?? 0) > 0) {
      current++;
      if (current > best) {
        best = current;
      }
    } else {
      current = 0;
    }
  }
  return best;
}

List<VoidWeeklyGoalProgress> buildWeeklyGoalsProgress({
  required List<VoidSessionRecord> sessionHistory,
  required Map<String, VoidDayActivity> activity,
  required Set<String> claimedIds,
  DateTime? referenceDate,
  int? weeklySessionsCount,
}) {
  final bounds = weekBoundsContaining(referenceDate ?? DateTime.now());
  final weekStats = VoidWeeklyReviewStats.fromSessions(
    sessions: sessionHistory,
    weekBounds: bounds,
  );
  final weekFocusSeconds = computeWeekFocusSeconds(activity, bounds);
  final sessionsCount = weeklySessionsCount ?? weekStats.sessionsCount;
  final streakDays = computeWeekMaxStreakDays(activity, bounds);

  return [
    VoidWeeklyGoalProgress(
      id: kVoidWeeklyGoalFocusId,
      title: '5 часов фокуса',
      subtitle: 'Наберите 5 ч за неделю',
      current: weekFocusSeconds,
      target: kVoidWeeklyFocusTargetSeconds,
      xpReward: kVoidWeeklyGoalFocusXp,
      isRewardClaimed: claimedIds.contains(kVoidWeeklyGoalFocusId),
    ),
    VoidWeeklyGoalProgress(
      id: kVoidWeeklyGoalSessionsId,
      title: '20 сессий',
      subtitle: 'Завершите 20 сессий за неделю',
      current: sessionsCount,
      target: kVoidWeeklySessionsTarget,
      xpReward: kVoidWeeklyGoalSessionsXp,
      isRewardClaimed: claimedIds.contains(kVoidWeeklyGoalSessionsId),
    ),
    VoidWeeklyGoalProgress(
      id: kVoidWeeklyGoalStreakId,
      title: '3 дня серии',
      subtitle: 'Серия из 3 дней подряд за неделю',
      current: streakDays,
      target: kVoidWeeklyStreakTarget,
      xpReward: kVoidWeeklyGoalStreakXp,
      isRewardClaimed: claimedIds.contains(kVoidWeeklyGoalStreakId),
    ),
  ];
}

VoidWeeklyGoalsData buildWeeklyGoalsData({
  required List<VoidSessionRecord> sessionHistory,
  required Map<String, VoidDayActivity> activity,
  required Set<String> claimedIds,
  DateTime? referenceDate,
  int? weeklySessionsCount,
}) {
  final bounds = weekBoundsContaining(referenceDate ?? DateTime.now());
  final goals = buildWeeklyGoalsProgress(
    sessionHistory: sessionHistory,
    activity: activity,
    claimedIds: claimedIds,
    referenceDate: referenceDate,
    weeklySessionsCount: weeklySessionsCount,
  );

  return VoidWeeklyGoalsData(
    weekBounds: bounds,
    goals: goals,
    completedCount: goals.where((goal) => goal.isCompleted).length,
  );
}

String formatWeeklyGoalProgressLabel(VoidWeeklyGoalProgress goal) {
  switch (goal.id) {
    case kVoidWeeklyGoalFocusId:
      return '${formatFocusDuration(goal.current)} / ${formatFocusDuration(goal.target)}';
    case kVoidWeeklyGoalSessionsId:
      return '${goal.current} / ${goal.target}';
    case kVoidWeeklyGoalStreakId:
      return '${goal.current} / ${goal.target} дн.';
    default:
      return '${goal.current} / ${goal.target}';
  }
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
    required this.deepWorkModeMinutes,
    required this.averageFocusScore,
    required this.last7Days,
    required this.last30Days,
    required this.personalRecords,
    required this.bonusXp,
    required this.weeklyGoals,
    required this.focusModeStats,
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
  final int deepWorkModeMinutes;
  final double averageFocusScore;
  final List<VoidDayActivity> last7Days;
  final List<VoidDayActivity> last30Days;
  final VoidPersonalRecords personalRecords;
  final int bonusXp;
  final VoidWeeklyGoalsData weeklyGoals;
  final VoidFocusModeStats focusModeStats;

  int get todayFocusMinutes => todayFocusSeconds ~/ 60;

  double get dailyGoalProgress => dailyGoalMinutes <= 0
      ? 0
      : (todayFocusSeconds / (dailyGoalMinutes * 60)).clamp(0.0, 1.0);

  bool get isDailyGoalCompleted =>
      todayFocusSeconds >= dailyGoalMinutes * 60;

  int get unlockedAchievementsCount =>
      achievements.where((achievement) => achievement.isUnlocked).length;

  int get totalXp => computeTotalXp(totalFocusSeconds) + bonusXp;

  int get level => computeLevel(totalXp);

  String get levelTitle => resolveLevelTitle(level);

  int get xpInCurrentLevel => computeXpInCurrentLevel(totalXp);

  double get levelProgress => computeLevelProgress(totalXp);

  static final empty = StatsData(
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
    deepWorkModeMinutes: _kDefaultDeepWorkModeMinutes,
    averageFocusScore: 0,
    last7Days: [],
    last30Days: [],
    personalRecords: VoidPersonalRecords.empty,
    bonusXp: 0,
    weeklyGoals: buildWeeklyGoalsData(
      sessionHistory: const [],
      activity: const {},
      claimedIds: const {},
      referenceDate: DateTime(2000, 1, 3),
    ),
    focusModeStats: VoidFocusModeStats.empty,
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

class VoidLevelTitleTier {
  const VoidLevelTitleTier({
    required this.minLevel,
    required this.title,
  });

  final int minLevel;
  final String title;
}

const List<VoidLevelTitleTier> kVoidLevelTitleTiers = [
  VoidLevelTitleTier(minLevel: 50, title: 'VOID Master'),
  VoidLevelTitleTier(minLevel: 25, title: 'Архитектор внимания'),
  VoidLevelTitleTier(minLevel: 10, title: 'Мастер фокуса'),
  VoidLevelTitleTier(minLevel: 5, title: 'Сосредоточенный'),
  VoidLevelTitleTier(minLevel: 1, title: 'Новичок'),
];

String resolveLevelTitle(int level) {
  final normalizedLevel = level < 1 ? 1 : level;
  for (final tier in kVoidLevelTitleTiers) {
    if (normalizedLevel >= tier.minLevel) {
      return tier.title;
    }
  }
  return kVoidLevelTitleTiers.last.title;
}

class VoidBackupImportResult {
  const VoidBackupImportResult({
    required this.success,
    this.error,
    this.sessionsCount = 0,
    this.projectsCount = 0,
    this.tasksCount = 0,
  });

  final bool success;
  final String? error;
  final int sessionsCount;
  final int projectsCount;
  final int tasksCount;
}

Map<String, dynamic>? parseVoidBackupJson(String raw) {
  try {
    final decoded = jsonDecode(raw.trim());
    if (decoded is! Map) return null;
    return decoded.map((key, value) => MapEntry(key.toString(), value));
  } catch (_) {
    return null;
  }
}

bool isLegacyVoidBackup(Map<String, dynamic> backup) =>
    !backup.containsKey('formatVersion') &&
    backup.containsKey('completedSessions');

Map<String, VoidDayActivity> dailyActivityFromLegacyBackup(
  Map<String, dynamic> backup,
) {
  final activity = <String, VoidDayActivity>{};
  final last30Days = backup['last30Days'];
  if (last30Days is List) {
    for (final day in last30Days) {
      if (day is! Map) continue;
      final date = day['date']?.toString();
      final focusSeconds = day['focusSeconds'];
      if (date == null || focusSeconds is! num || focusSeconds <= 0) continue;
      activity[date] = VoidDayActivity(
        date: _parseDateKey(date),
        focusSeconds: focusSeconds.toInt(),
      );
    }
  }
  return activity;
}

Map<String, dynamic> normalizeVoidBackup(Map<String, dynamic> backup) {
  if (!isLegacyVoidBackup(backup)) {
    return backup;
  }

  return {
    'formatVersion': 0,
    'exportedAt': backup['exportedAt'],
    'appVersion': backup['appVersion'],
    'statistics': {
      'completedSessions': backup['completedSessions'] ?? 0,
      'totalFocusSeconds': backup['totalFocusSeconds'] ?? 0,
      'currentStreak': backup['currentStreak'] ?? 0,
      'bestStreak': backup['bestStreak'] ?? 0,
      'todaySessions': backup['todaySessions'] ?? 0,
      'todaySessionsDate': null,
      'totalDistractions': backup['totalDistractions'] ?? 0,
      'preventedDistractionMinutes':
          backup['preventedDistractionMinutes'] ?? 0,
      'dailyGoalMinutes': backup['dailyGoalMinutes'] ?? _kDefaultDailyGoalMinutes,
      'deepWorkModeMinutes':
          backup['deepWorkModeMinutes'] ?? _kDefaultDeepWorkModeMinutes,
      'dailyGoalAchieved': (backup['achievements'] as List?)?.any(
            (entry) =>
                entry is Map &&
                entry['id'] == 'daily_goal' &&
                entry['isUnlocked'] == true,
          ) ??
          false,
      'bonusXp': backup['bonusXp'] ?? 0,
      'weeklyGoalsWeekKey': null,
      'weeklyGoalsClaimed': <String>[],
      'weeklySessionsCount': 0,
      'dailyActivity': exportDailyActivityJson(
        dailyActivityFromLegacyBackup(backup),
      ),
      'focusModeStats': emptyFocusModeStatsMap(),
    },
    'sessions': backup['sessionHistory'] ?? const [],
    'achievements': backup['achievements'] ?? const [],
    'projects': const [],
    'tasks': const [],
  };
}

List<VoidSessionRecord> parseVoidBackupSessions(Object? raw) {
  if (raw is! List) return [];
  return raw
      .whereType<Map>()
      .map(
        (entry) => VoidSessionRecord.fromJson(
          entry.map((key, value) => MapEntry(key.toString(), value)),
        ),
      )
      .toList()
    ..sort((a, b) => b.completedAt.compareTo(a.completedAt));
}

List<VoidProject> parseVoidBackupProjects(Object? raw) {
  if (raw is! List) return [];
  return raw
      .whereType<Map>()
      .map(
        (entry) => VoidProject.fromJson(
          entry.map((key, value) => MapEntry(key.toString(), value)),
        ),
      )
      .toList();
}

List<VoidTask> parseVoidBackupTasks(Object? raw) {
  if (raw is! List) return [];
  return raw
      .whereType<Map>()
      .map(
        (entry) => VoidTask.fromJson(
          entry.map((key, value) => MapEntry(key.toString(), value)),
        ),
      )
      .toList();
}

Map<String, dynamic> buildVoidBackupPayload({
  required StatsData stats,
  required Map<String, VoidDayActivity> dailyActivity,
  required String? todaySessionsDate,
  required int weeklySessionsCount,
  required String? weeklyGoalsWeekKey,
  required Set<String> weeklyGoalsClaimed,
  required bool dailyGoalAchieved,
  required List<VoidProject> projects,
  required List<VoidTask> tasks,
}) {
  return {
    'formatVersion': kVoidBackupFormatVersion,
    'exportedAt': DateTime.now().toIso8601String(),
    'appVersion': kVoidAppVersion,
    'statistics': {
      'completedSessions': stats.completedSessions,
      'totalFocusSeconds': stats.totalFocusSeconds,
      'currentStreak': stats.currentStreak,
      'bestStreak': stats.bestStreak,
      'todaySessions': stats.todaySessions,
      'todaySessionsDate': todaySessionsDate,
      'totalDistractions': stats.distractions,
      'preventedDistractionMinutes': stats.preventedDistractionMinutes,
      'dailyGoalMinutes': stats.dailyGoalMinutes,
      'deepWorkModeMinutes': stats.deepWorkModeMinutes,
      'dailyGoalAchieved': dailyGoalAchieved,
      'bonusXp': stats.bonusXp,
      'weeklyGoalsWeekKey': weeklyGoalsWeekKey,
      'weeklyGoalsClaimed': weeklyGoalsClaimed.toList(),
      'weeklySessionsCount': weeklySessionsCount,
      'dailyActivity': exportDailyActivityJson(dailyActivity),
      'focusModeStats': {
        for (final entry in stats.focusModeStats.entries)
          '${entry.minutes}': {
            'sessions': entry.sessions,
            'focusSeconds': entry.focusSeconds,
          },
      },
    },
    'sessions': stats.sessionHistory.map((session) => session.toJson()).toList(),
    'achievements': stats.achievements
        .map(
          (achievement) => {
            'id': achievement.id,
            'title': achievement.title,
            'description': achievement.description,
            'isUnlocked': achievement.isUnlocked,
          },
        )
        .toList(),
    'projects': projects.map((project) => project.toJson()).toList(),
    'tasks': tasks.map((task) => task.toJson()).toList(),
  };
}

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

Future<VoidProjectEditorResult?> showVoidProjectEditorDialog(
  BuildContext context, {
  String? initialTitle,
  int? initialColorValue,
  String? initialIconName,
  String title = 'Новый проект',
  String confirmLabel = 'Сохранить',
}) async {
  final controller = TextEditingController(text: initialTitle ?? '');
  var selectedColor =
      initialColorValue ?? kDefaultProjectColorValue;
  var selectedIcon = initialIconName ?? kDefaultProjectIconName;

  final result = await showDialog<VoidProjectEditorResult>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
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
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: controller,
                    autofocus: true,
                    maxLength: 120,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.9)),
                    decoration: InputDecoration(
                      hintText: 'Название проекта',
                      hintStyle:
                          TextStyle(color: Colors.white.withValues(alpha: 0.35)),
                      counterStyle:
                          TextStyle(color: Colors.white.withValues(alpha: 0.35)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: kVoidAccent.withValues(alpha: 0.35),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: kVoidAccent),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Цвет',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.45),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: kVoidProjectColorValues.map((colorValue) {
                      final selected = selectedColor == colorValue;
                      return InkWell(
                        onTap: () =>
                            setDialogState(() => selectedColor = colorValue),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(colorValue),
                            border: Border.all(
                              color: selected
                                  ? Colors.white.withValues(alpha: 0.9)
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Иконка',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.45),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: kVoidProjectTemplates.map((template) {
                      final selected = selectedIcon == template.id;
                      return InkWell(
                        onTap: () {
                          setDialogState(() {
                            selectedIcon = template.id;
                            selectedColor = template.colorValue;
                            if (controller.text.trim().isEmpty) {
                              controller.text = template.defaultTitle;
                            }
                          });
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: selected
                                ? Color(selectedColor).withValues(alpha: 0.2)
                                : Colors.white.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: selected
                                  ? Color(selectedColor)
                                      .withValues(alpha: 0.6)
                                  : kVoidAccent.withValues(alpha: 0.15),
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            template.emoji,
                            style: const TextStyle(fontSize: 22),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(
                  'Отмена',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.55)),
                ),
              ),
              TextButton(
                onPressed: () {
                  final value = controller.text.trim();
                  if (value.isEmpty) return;
                  Navigator.pop(
                    dialogContext,
                    VoidProjectEditorResult(
                      title: value,
                      colorValue: selectedColor,
                      iconName: selectedIcon,
                    ),
                  );
                },
                child: Text(
                  confirmLabel,
                  style: const TextStyle(color: kVoidAccent),
                ),
              ),
            ],
          );
        },
      );
    },
  );
  WidgetsBinding.instance.addPostFrameCallback((_) {
    controller.dispose();
  });
  return result;
}

Future<VoidTaskEditorResult?> showVoidTaskEditorDialog(
  BuildContext context, {
  String? initialTitle,
  String? initialDescription,
  bool initialIsCompleted = false,
  int? initialEstimatedSessions,
  String? initialProjectId,
  String title = 'Новая задача',
  String confirmLabel = 'Сохранить',
}) async {
  await TasksService.instance.load(force: true);
  final controller = TextEditingController(text: initialTitle ?? '');
  final descriptionController =
      TextEditingController(text: initialDescription ?? '');
  String? selectedProjectId = initialProjectId;
  var isCompleted = initialIsCompleted;
  var estimatedSessions =
      initialEstimatedSessions ?? kDefaultTaskEstimatedSessions;

  final result = await showDialog<VoidTaskEditorResult>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          final projects = TasksService.instance.projects;

          return AlertDialog(
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
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: controller,
                    autofocus: true,
                    maxLength: 120,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.9)),
                    decoration: InputDecoration(
                      hintText: 'Название задачи',
                      hintStyle:
                          TextStyle(color: Colors.white.withValues(alpha: 0.35)),
                      counterStyle:
                          TextStyle(color: Colors.white.withValues(alpha: 0.35)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: kVoidAccent.withValues(alpha: 0.35),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: kVoidAccent),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descriptionController,
                    maxLength: 500,
                    maxLines: 3,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.9)),
                    decoration: InputDecoration(
                      hintText: 'Описание (необязательно)',
                      hintStyle:
                          TextStyle(color: Colors.white.withValues(alpha: 0.35)),
                      counterStyle:
                          TextStyle(color: Colors.white.withValues(alpha: 0.35)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: kVoidAccent.withValues(alpha: 0.35),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: kVoidAccent),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'План сессий',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.45),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: kVoidAccent.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: estimatedSessions > 1
                              ? () => setDialogState(
                                    () => estimatedSessions -= 1,
                                  )
                              : null,
                          icon: Icon(
                            Icons.remove_rounded,
                            color: estimatedSessions > 1
                                ? kVoidAccent.withValues(alpha: 0.85)
                                : Colors.white.withValues(alpha: 0.2),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            '$estimatedSessions '
                            '${formatVoidSessionCountWord(estimatedSessions)}',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: estimatedSessions < 99
                              ? () => setDialogState(
                                    () => estimatedSessions += 1,
                                  )
                              : null,
                          icon: Icon(
                            Icons.add_rounded,
                            color: estimatedSessions < 99
                                ? kVoidAccent.withValues(alpha: 0.85)
                                : Colors.white.withValues(alpha: 0.2),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Статус',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.45),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      _VoidProjectChip(
                        label: 'Активна',
                        selected: !isCompleted,
                        onTap: () {
                          setDialogState(() => isCompleted = false);
                        },
                      ),
                      _VoidProjectChip(
                        label: 'Завершена',
                        selected: isCompleted,
                        onTap: () {
                          setDialogState(() => isCompleted = true);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Проект',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.45),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _VoidProjectChip(
                        label: 'Без проекта',
                        selected: selectedProjectId == null,
                        onTap: () {
                          setDialogState(() => selectedProjectId = null);
                        },
                      ),
                      ...projects.map(
                        (project) => _VoidProjectChip(
                          label: project.title,
                          selected: selectedProjectId == project.id,
                          onTap: () {
                            setDialogState(() => selectedProjectId = project.id);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(
                  'Отмена',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.55)),
                ),
              ),
              TextButton(
                onPressed: () {
                  final value = controller.text.trim();
                  if (value.isEmpty) return;
                  Navigator.pop(
                    dialogContext,
                    VoidTaskEditorResult(
                      title: value,
                      description: descriptionController.text.trim(),
                      isCompleted: isCompleted,
                      estimatedSessions: estimatedSessions,
                      projectId: selectedProjectId,
                    ),
                  );
                },
                child: Text(
                  confirmLabel,
                  style: const TextStyle(color: kVoidAccent),
                ),
              ),
            ],
          );
        },
      );
    },
  );
  WidgetsBinding.instance.addPostFrameCallback((_) {
    controller.dispose();
  });
  return result;
}

class _VoidProjectChip extends StatelessWidget {
  const _VoidProjectChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? kVoidAccent.withValues(alpha: 0.16)
                : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? kVoidAccent.withValues(alpha: 0.45)
                  : kVoidAccent.withValues(alpha: 0.15),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: selected
                  ? kVoidAccent
                  : Colors.white.withValues(alpha: 0.75),
            ),
          ),
        ),
      ),
    );
  }
}

Future<VoidTaskSelection?> showVoidTaskPicker(BuildContext context) async {
  await TasksService.instance.load(force: true);
  if (!context.mounted) return null;

  String? selectedTaskId;
  var withoutTaskSelected = true;

  return showModalBottomSheet<VoidTaskSelection>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF12121A),
    shape: RoundedRectangleBorder(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      side: BorderSide(color: kVoidAccent.withValues(alpha: 0.28)),
    ),
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (context, setSheetState) {
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 12,
                bottom: 20 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: ListenableBuilder(
                listenable: TasksService.instance,
                builder: (context, _) {
                  final store = TasksService.instance;
                  final tasks = store.activeTasks;
                  final projects = store.projects;

                  return Column(
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
                      Text(
                        'Выберите задачу',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.95),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Сессия будет привязана к выбранной задаче',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.45),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _VoidTaskPickerTile(
                        title: 'Без задачи',
                        subtitle: 'Сессия без привязки',
                        selected: withoutTaskSelected,
                        onTap: () {
                          setSheetState(() {
                            withoutTaskSelected = true;
                            selectedTaskId = null;
                          });
                        },
                      ),
                      if (tasks.isNotEmpty) ...[
                        for (final project in projects) ...[
                          if (store.tasksForProject(project.id, activeOnly: true)
                              .isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(
                              '${project.emoji} ${project.title}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white.withValues(alpha: 0.4),
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...store
                                .tasksForProject(project.id, activeOnly: true)
                                .map(
                              (task) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _VoidTaskPickerTile(
                                  title: task.title,
                                  subtitle: task.sessionProgressLabel,
                                  selected: !withoutTaskSelected &&
                                      selectedTaskId == task.id,
                                  onTap: () {
                                    setSheetState(() {
                                      withoutTaskSelected = false;
                                      selectedTaskId = task.id;
                                    });
                                  },
                                ),
                              ),
                            ),
                          ],
                        ],
                        if (store
                            .tasksForProject(null, activeOnly: true)
                            .isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(
                            'Без проекта',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white.withValues(alpha: 0.4),
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...store.tasksForProject(null, activeOnly: true).map(
                            (task) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _VoidTaskPickerTile(
                                title: task.title,
                                subtitle: task.sessionProgressLabel,
                                selected: !withoutTaskSelected &&
                                    selectedTaskId == task.id,
                                onTap: () {
                                  setSheetState(() {
                                    withoutTaskSelected = false;
                                    selectedTaskId = task.id;
                                  });
                                },
                              ),
                            ),
                          ),
                        ],
                      ],
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: () async {
                          final draft = await showVoidTaskEditorDialog(
                            sheetContext,
                          );
                          if (draft == null) return;
                          final created = await TasksService.instance.addTask(
                            draft.title,
                            projectId: draft.projectId,
                            description: draft.description,
                            isCompleted: draft.isCompleted,
                            estimatedSessions: draft.estimatedSessions,
                          );
                          if (created != null) {
                            setSheetState(() {
                              withoutTaskSelected = false;
                              selectedTaskId = created.id;
                            });
                          }
                        },
                        icon: Icon(
                          Icons.add_rounded,
                          size: 18,
                          color: kVoidAccent.withValues(alpha: 0.85),
                        ),
                        label: const Text(
                          'Добавить задачу',
                          style: TextStyle(color: kVoidAccent),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () {
                            if (withoutTaskSelected) {
                              Navigator.pop(
                                sheetContext,
                                VoidTaskSelection.withoutTask,
                              );
                              return;
                            }
                            final task =
                                TasksService.instance.taskById(selectedTaskId);
                            if (task == null) return;
                            Navigator.pop(
                              sheetContext,
                              VoidTaskSelection(
                                taskId: task.id,
                                taskTitle: task.title,
                              ),
                            );
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: kVoidAccent,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            'Продолжить',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          );
        },
      );
    },
  );
}

class _VoidTaskPickerTile extends StatelessWidget {
  const _VoidTaskPickerTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? kVoidAccent.withValues(alpha: 0.14)
                : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? kVoidAccent.withValues(alpha: 0.55)
                  : kVoidAccent.withValues(alpha: 0.18),
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                size: 20,
                color: selected
                    ? kVoidAccent
                    : Colors.white.withValues(alpha: 0.35),
              ),
              const SizedBox(width: 12),
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
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.42),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
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

bool shouldShowFirstLaunchFeedback({
  required int completedSessions,
  required bool alreadyShown,
  int threshold = kFirstLaunchFeedbackSessionThreshold,
}) {
  return !alreadyShown && completedSessions >= threshold;
}

Future<void> launchVoidFeatureFeedback(BuildContext context) {
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

Future<void> launchVoidBugFeedback(BuildContext context) {
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

class VoidSessionCompleteData {
  const VoidSessionCompleteData({
    required this.elapsedSeconds,
    required this.focusScore,
    required this.xpEarned,
    required this.currentStreak,
    required this.todayFocusSeconds,
    required this.dailyGoalMinutes,
    required this.dailyGoalProgress,
    required this.isDailyGoalCompleted,
    this.taskSelection,
    this.focusSecondsOnTask,
  });

  final int elapsedSeconds;
  final int focusScore;
  final int xpEarned;
  final int currentStreak;
  final int todayFocusSeconds;
  final int dailyGoalMinutes;
  final double dailyGoalProgress;
  final bool isDailyGoalCompleted;
  final VoidTaskSelection? taskSelection;
  final int? focusSecondsOnTask;
}

Future<void> showVoidSessionCompleteDialog({
  required BuildContext context,
  required VoidSessionCompleteData data,
  required VoidCallback onDone,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: 0.78),
    transitionDuration: const Duration(milliseconds: 380),
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return VoidSessionCompleteDialog(
        data: data,
        onDone: () {
          Navigator.pop(dialogContext);
          onDone();
        },
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curve = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: curve,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.9, end: 1).animate(curve),
          child: child,
        ),
      );
    },
  );
}

class VoidSessionCompleteDialog extends StatefulWidget {
  const VoidSessionCompleteDialog({
    super.key,
    required this.data,
    required this.onDone,
  });

  final VoidSessionCompleteData data;
  final VoidCallback onDone;

  @override
  State<VoidSessionCompleteDialog> createState() =>
      _VoidSessionCompleteDialogState();
}

class _VoidSessionCompleteDialogState extends State<VoidSessionCompleteDialog>
    with TickerProviderStateMixin {
  late final AnimationController _contentController;
  late final AnimationController _goalProgressController;
  late final AnimationController _streakProgressController;
  late final AnimationController _xpController;
  late final AnimationController _focusPulseController;
  late Animation<double> _goalProgressAnimation;
  late Animation<double> _streakProgressAnimation;
  late Animation<int> _xpAnimation;
  late final Animation<double> _focusScaleAnimation;

  @override
  void initState() {
    super.initState();
    _contentController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _goalProgressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _streakProgressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _xpController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _focusPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _goalProgressAnimation = Tween<double>(
      begin: 0,
      end: widget.data.dailyGoalProgress.clamp(0.0, 1.0),
    ).animate(
      CurvedAnimation(
        parent: _goalProgressController,
        curve: Curves.easeOutCubic,
      ),
    );
    _streakProgressAnimation = Tween<double>(
      begin: 0,
      end: (widget.data.currentStreak / 7).clamp(0.0, 1.0),
    ).animate(
      CurvedAnimation(
        parent: _streakProgressController,
        curve: Curves.easeOutCubic,
      ),
    );
    _xpAnimation = IntTween(begin: 0, end: widget.data.xpEarned).animate(
      CurvedAnimation(parent: _xpController, curve: Curves.easeOutCubic),
    );
    _focusScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.85, end: 1.08)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 45,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.08, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 55,
      ),
    ]).animate(_focusPulseController);

    _contentController.forward();
    _goalProgressController.forward();
    _streakProgressController.forward();
    _xpController.forward();
    _focusPulseController.forward();
  }

  @override
  void dispose() {
    _contentController.dispose();
    _goalProgressController.dispose();
    _streakProgressController.dispose();
    _xpController.dispose();
    _focusPulseController.dispose();
    super.dispose();
  }

  Animation<double> _stagger(int index) {
    final start = 0.08 + index * 0.1;
    final end = (start + 0.42).clamp(0.0, 1.0);
    return CurvedAnimation(
      parent: _contentController,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );
  }

  String _streakDaysLabel(int count) {
    final mod10 = count % 10;
    final mod100 = count % 100;
    if (mod100 >= 11 && mod100 <= 14) return 'дней';
    if (mod10 == 1) return 'день';
    if (mod10 >= 2 && mod10 <= 4) return 'дня';
    return 'дней';
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final taskLabel = data.taskSelection?.hasTask == true
        ? data.taskSelection!.taskTitle!
        : null;
    final goalAccent =
        data.isDailyGoalCompleted ? kVoidGoalComplete : kVoidAccent;

    return Material(
      color: Colors.transparent,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: AnimatedBuilder(
              animation: Listenable.merge([
                _contentController,
                _goalProgressController,
                _streakProgressController,
                _xpController,
                _focusPulseController,
              ]),
              builder: (context, child) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
                  decoration: BoxDecoration(
                    color: const Color(0xFF12121A),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: kVoidAccent.withValues(alpha: 0.35),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: kVoidAccent.withValues(alpha: 0.18),
                        blurRadius: 36,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FadeTransition(
                        opacity: _stagger(0),
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.08),
                            end: Offset.zero,
                          ).animate(_stagger(0)),
                          child: Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: kVoidAccent.withValues(alpha: 0.14),
                              border: Border.all(
                                color: kVoidAccent.withValues(alpha: 0.45),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: kVoidAccent.withValues(alpha: 0.25),
                                  blurRadius: 18,
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.check_rounded,
                              color: kVoidAccent.withValues(alpha: 0.95),
                              size: 30,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      FadeTransition(
                        opacity: _stagger(1),
                        child: Text(
                          'Сессия завершена',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.96),
                          ),
                        ),
                      ),
                      if (taskLabel != null) ...[
                        const SizedBox(height: 10),
                        FadeTransition(
                          opacity: _stagger(1),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: kVoidAccent.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Text(
                              taskLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      FadeTransition(
                        opacity: _stagger(2),
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.06),
                            end: Offset.zero,
                          ).animate(_stagger(2)),
                          child: _VoidSessionCompleteStatTile(
                            label: 'Длительность',
                            value: formatFocusDuration(data.elapsedSeconds),
                            prominent: true,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      FadeTransition(
                        opacity: _stagger(3),
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.06),
                            end: Offset.zero,
                          ).animate(_stagger(3)),
                          child: Transform.scale(
                            scale: _focusScaleAnimation.value,
                            child: _VoidSessionCompleteStatTile(
                              label: 'Фокус-счёт',
                              value: formatFocusScore(data.focusScore),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      FadeTransition(
                        opacity: _stagger(4),
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.06),
                            end: Offset.zero,
                          ).animate(_stagger(4)),
                          child: _VoidSessionCompleteStatTile(
                            label: 'Получено XP',
                            value: '+${_xpAnimation.value}',
                            accent: true,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      FadeTransition(
                        opacity: _stagger(5),
                        child: _VoidSessionCompleteProgressSection(
                          title: 'Серия',
                          subtitle: data.currentStreak > 0
                              ? '${data.currentStreak} ${_streakDaysLabel(data.currentStreak)} подряд'
                              : 'Начните серию завтра',
                          progress: _streakProgressAnimation.value,
                          percentLabel: data.currentStreak > 0
                              ? '${data.currentStreak}'
                              : '0',
                          accent: data.currentStreak > 0
                              ? kVoidAccent
                              : Colors.white.withValues(alpha: 0.35),
                          icon: Icons.local_fire_department_rounded,
                        ),
                      ),
                      const SizedBox(height: 14),
                      FadeTransition(
                        opacity: _stagger(6),
                        child: _VoidSessionCompleteProgressSection(
                          title: 'Цель дня',
                          subtitle: formatDailyGoalProgress(
                            data.todayFocusSeconds,
                            data.dailyGoalMinutes,
                          ),
                          progress: _goalProgressAnimation.value,
                          percentLabel:
                              '${formatDailyGoalPercent(_goalProgressAnimation.value)}%',
                          accent: goalAccent,
                          icon: data.isDailyGoalCompleted
                              ? Icons.check_circle_rounded
                              : Icons.flag_rounded,
                          completed: data.isDailyGoalCompleted,
                        ),
                      ),
                      const SizedBox(height: 18),
                      FadeTransition(
                        opacity: _stagger(7),
                        child: SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: widget.onDone,
                            style: FilledButton.styleFrom(
                              backgroundColor: kVoidAccent,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              minimumSize: const Size.fromHeight(48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text(
                              'Готово',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    ),
    );
  }
}

class _VoidSessionCompleteStatTile extends StatelessWidget {
  const _VoidSessionCompleteStatTile({
    required this.label,
    required this.value,
    this.prominent = false,
    this.accent = false,
  });

  final String label;
  final String value;
  final bool prominent;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: prominent ? 16 : 13,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: accent
              ? kVoidAccent.withValues(alpha: 0.35)
              : prominent
                  ? kVoidAccent.withValues(alpha: 0.22)
                  : Colors.white.withValues(alpha: 0.08),
        ),
        boxShadow: prominent
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
              fontSize: prominent ? 20 : 16,
              fontWeight: FontWeight.w500,
              color: accent
                  ? kVoidAccent
                  : prominent
                      ? kVoidAccent.withValues(alpha: 0.95)
                      : Colors.white.withValues(alpha: 0.92),
            ),
          ),
        ],
      ),
    );
  }
}

class _VoidSessionCompleteProgressSection extends StatelessWidget {
  const _VoidSessionCompleteProgressSection({
    required this.title,
    required this.subtitle,
    required this.progress,
    required this.percentLabel,
    required this.accent,
    required this.icon,
    this.completed = false,
  });

  final String title;
  final String subtitle;
  final double progress;
  final String percentLabel;
  final Color accent;
  final IconData icon;
  final bool completed;

  @override
  Widget build(BuildContext context) {
    final clampedProgress = progress.clamp(0.0, 1.0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: completed
            ? kVoidGoalComplete.withValues(alpha: 0.05)
            : Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: accent.withValues(alpha: 0.9)),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ),
              const Spacer(),
              Text(
                percentLabel,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: accent.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Colors.white.withValues(alpha: 0.88),
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: clampedProgress,
              minHeight: 6,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation(accent),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> showVoidFirstLaunchFeedbackDialog(BuildContext context) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      Future<void> closeWithAction(Future<void> Function()? action) async {
        await StatsService.instance.markFirstLaunchFeedbackShown();
        if (dialogContext.mounted) {
          Navigator.pop(dialogContext);
        }
        if (action != null && context.mounted) {
          await action();
        }
      }

      return AlertDialog(
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
                letterSpacing: 6,
                fontSize: 22,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Как вам VOID?',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.95),
                fontWeight: FontWeight.w500,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Text(
          'Вы завершили $kFirstLaunchFeedbackSessionThreshold сессии. '
          'Поделитесь впечатлениями — это поможет сделать VOID лучше.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.62),
            height: 1.45,
          ),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          SizedBox(
            width: double.infinity,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton(
                  onPressed: () => closeWithAction(() async {
                    if (context.mounted) {
                      showVoidSnackBar(context, 'Спасибо за отзыв!');
                    }
                  }),
                  style: FilledButton.styleFrom(
                    backgroundColor: kVoidAccent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Нравится',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: () => closeWithAction(
                    () => launchVoidFeatureFeedback(context),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white.withValues(alpha: 0.88),
                    side: BorderSide(color: kVoidAccent.withValues(alpha: 0.35)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Есть идеи',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => closeWithAction(
                    () => launchVoidBugFeedback(context),
                  ),
                  child: Text(
                    'Сообщить о проблеме',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 13,
                    ),
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

bool shouldScheduleDailyReminder({
  required int todayFocusSeconds,
  required int todaySessions,
}) {
  return todayFocusSeconds <= 0 && todaySessions <= 0;
}

bool shouldScheduleStreakWarning({
  required int currentStreak,
  required int todayFocusSeconds,
  required int todaySessions,
}) {
  return currentStreak > 0 &&
      todayFocusSeconds <= 0 &&
      todaySessions <= 0;
}

({int hour, int minute}) computeStreakWarningTime({
  required int reminderHour,
  required int reminderMinute,
}) {
  var hour = reminderHour + 3;
  var minute = reminderMinute;
  if (hour < 20) {
    hour = 20;
    minute = 0;
  }
  if (hour > 22 || (hour == 22 && minute > 0)) {
    hour = 22;
    minute = 0;
  }
  return (hour: hour, minute: minute);
}

String formatNotificationTime(int hour, int minute) {
  return '${hour.toString().padLeft(2, '0')}:'
      '${minute.toString().padLeft(2, '0')}';
}

class VoidNotificationService extends ChangeNotifier {
  VoidNotificationService._();

  static final VoidNotificationService instance = VoidNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool enabled = true;
  int hour = kDefaultNotificationHour;
  int minute = kDefaultNotificationMinute;
  bool isInitialized = false;

  static const _androidSettings = AndroidInitializationSettings(
    '@mipmap/ic_launcher',
  );

  static const _notificationDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      kVoidNotificationChannelId,
      'VOID Напоминания',
      channelDescription: 'Умные напоминания о фокусе и серии',
      importance: Importance.high,
      priority: Priority.high,
      color: Color(0xFF8B5CF6),
      icon: '@mipmap/ic_launcher',
    ),
  );

  Future<void> initialize() async {
    if (isInitialized) return;

    try {
      tz_data.initializeTimeZones();
      final timeZoneInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneInfo.identifier));

      await _plugin.initialize(
        const InitializationSettings(android: _androidSettings),
      );
      await loadPrefs();
      isInitialized = true;
    } catch (_) {
      isInitialized = false;
    }
  }

  Future<void> loadPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      enabled = prefs.getBool(_kNotificationsEnabled) ?? true;
      hour = prefs.getInt(_kNotificationHour) ?? kDefaultNotificationHour;
      minute = prefs.getInt(_kNotificationMinute) ?? kDefaultNotificationMinute;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> setEnabled(bool value) async {
    enabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kNotificationsEnabled, value);
    notifyListeners();

    if (value) {
      await _requestPermission();
    }
    await rescheduleFromStats(StatsService.instance.data);
  }

  Future<void> setReminderTime({
    required int newHour,
    required int newMinute,
  }) async {
    hour = newHour;
    minute = newMinute;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kNotificationHour, newHour);
    await prefs.setInt(_kNotificationMinute, newMinute);
    notifyListeners();
    await rescheduleFromStats(StatsService.instance.data);
  }

  Future<void> _requestPermission() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      final androidPlugin =
          _plugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.requestNotificationsPermission();
    } catch (_) {}
  }

  Future<void> rescheduleFromStats(StatsData stats) async {
    if (!isInitialized) return;

    try {
      await _plugin.cancel(kVoidNotificationDailyReminderId);
      await _plugin.cancel(kVoidNotificationStreakWarningId);
      if (!enabled) return;

      final now = tz.TZDateTime.now(tz.local);
      final needsDailyReminder = shouldScheduleDailyReminder(
        todayFocusSeconds: stats.todayFocusSeconds,
        todaySessions: stats.todaySessions,
      );

      if (needsDailyReminder) {
        final dailyTime = _nextScheduleTime(hour, minute, now);
        await _scheduleNotification(
          id: kVoidNotificationDailyReminderId,
          scheduledDate: dailyTime,
          body: 'Пора сфокусироваться',
        );

        if (shouldScheduleStreakWarning(
          currentStreak: stats.currentStreak,
          todayFocusSeconds: stats.todayFocusSeconds,
          todaySessions: stats.todaySessions,
        )) {
          final streakParts = computeStreakWarningTime(
            reminderHour: hour,
            reminderMinute: minute,
          );
          var streakTime = tz.TZDateTime(
            tz.local,
            now.year,
            now.month,
            now.day,
            streakParts.hour,
            streakParts.minute,
          );
          if (!streakTime.isAfter(dailyTime)) {
            streakTime = dailyTime.add(const Duration(hours: 2));
          }
          if (streakTime.isAfter(now)) {
            await _scheduleNotification(
              id: kVoidNotificationStreakWarningId,
              scheduledDate: streakTime,
              body:
                  'Серия из ${stats.currentStreak} дней может прерваться',
            );
          }
        }
      } else {
        final tomorrow = now.add(const Duration(days: 1));
        final tomorrowTime = tz.TZDateTime(
          tz.local,
          tomorrow.year,
          tomorrow.month,
          tomorrow.day,
          hour,
          minute,
        );
        await _scheduleNotification(
          id: kVoidNotificationDailyReminderId,
          scheduledDate: tomorrowTime,
          body: 'Пора сфокусироваться',
        );
      }
    } catch (_) {}
  }

  tz.TZDateTime _nextScheduleTime(
    int reminderHour,
    int reminderMinute,
    tz.TZDateTime now,
  ) {
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      reminderHour,
      reminderMinute,
    );
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  Future<void> _scheduleNotification({
    required int id,
    required tz.TZDateTime scheduledDate,
    required String body,
  }) {
    return _plugin.zonedSchedule(
      id,
      'VOID',
      body,
      scheduledDate,
      _notificationDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }
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
        deepWorkModeMinutes: _kDefaultDeepWorkModeMinutes,
        averageFocusScore: 0,
        last7Days: _buildLast7Days({}),
        last30Days: _buildLast30Days({}),
        personalRecords: VoidPersonalRecords.empty,
        bonusXp: 0,
        weeklyGoals: buildWeeklyGoalsData(
          sessionHistory: const [],
          activity: const {},
          claimedIds: const {},
          referenceDate: DateTime(2000, 1, 3),
        ),
        focusModeStats: VoidFocusModeStats.empty,
      );

  static VoidFocusModeStats _readFocusModeStats(
    SharedPreferences prefs,
    List<VoidSessionRecord> sessionHistory,
  ) {
    final raw = prefs.getString(_kFocusModeStats);
    if (raw == null || raw.isEmpty) {
      return buildFocusModeStatsFromSessions(sessionHistory);
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return buildFocusModeStatsFromSessions(sessionHistory);
      }
      return parseFocusModeStatsMap(
        decoded.map((key, value) => MapEntry(key.toString(), value)),
      );
    } catch (_) {
      return buildFocusModeStatsFromSessions(sessionHistory);
    }
  }

  static Future<void> _incrementFocusModeStats(
    SharedPreferences prefs,
    int focusModeMinutes,
    int focusSeconds,
  ) async {
    if (focusSeconds <= 0) return;
    final minutes = VoidDeepWorkMode.resolve(focusModeMinutes).minutes;
    final raw = prefs.getString(_kFocusModeStats);
    final stats = raw == null || raw.isEmpty
        ? buildFocusModeStatsFromSessions(_readSessionHistoryRaw(prefs))
        : _readFocusModeStats(prefs, const []);
    final updated = {
      for (final entry in stats.entries)
        '${entry.minutes}': {
          'sessions': entry.sessions,
          'focusSeconds': entry.focusSeconds,
        },
    };
    final bucket = Map<String, dynamic>.from(
      updated['$minutes'] as Map? ?? {'sessions': 0, 'focusSeconds': 0},
    );
    updated['$minutes'] = {
      'sessions': ((bucket['sessions'] as num?)?.toInt() ?? 0) + 1,
      'focusSeconds':
          ((bucket['focusSeconds'] as num?)?.toInt() ?? 0) + focusSeconds,
    };
    await prefs.setString(_kFocusModeStats, jsonEncode(updated));
  }

  int _readBonusXp(SharedPreferences prefs) => prefs.getInt(_kBonusXp) ?? 0;

  int _readWeeklySessionsCount(SharedPreferences prefs) {
    final weekKey = _dateKey(weekBoundsContaining(DateTime.now()).start);
    if (prefs.getString(_kWeeklyGoalsWeekKey) != weekKey) {
      return 0;
    }
    return prefs.getInt(_kWeeklySessionsCount) ?? 0;
  }

  Future<void> _incrementWeeklySessionsCount(SharedPreferences prefs) async {
    final weekKey = _dateKey(weekBoundsContaining(DateTime.now()).start);
    final storedWeekKey = prefs.getString(_kWeeklyGoalsWeekKey);
    var count = prefs.getInt(_kWeeklySessionsCount) ?? 0;
    if (storedWeekKey != weekKey) {
      count = 0;
    }
    count++;
    await prefs.setInt(_kWeeklySessionsCount, count);
    if (storedWeekKey != weekKey) {
      await prefs.setString(_kWeeklyGoalsWeekKey, weekKey);
    }
  }

  Set<String> _readWeeklyGoalsClaimed(SharedPreferences prefs) {
    final raw = prefs.getString(_kWeeklyGoalsClaimed);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return {};
      return decoded.map((entry) => entry.toString()).toSet();
    } catch (_) {
      return {};
    }
  }

  Future<void> _syncWeeklyGoalRewards(
    SharedPreferences prefs,
    List<VoidSessionRecord> sessionHistory,
    Map<String, VoidDayActivity> activity,
  ) async {
    final bounds = weekBoundsContaining(DateTime.now());
    final weekKey = _dateKey(bounds.start);
    final storedWeekKey = prefs.getString(_kWeeklyGoalsWeekKey);

    var claimed = storedWeekKey == weekKey
        ? _readWeeklyGoalsClaimed(prefs)
        : <String>{};

    final goals = buildWeeklyGoalsProgress(
      sessionHistory: sessionHistory,
      activity: activity,
      claimedIds: claimed,
      weeklySessionsCount: _readWeeklySessionsCount(prefs),
    );

    var bonusXp = _readBonusXp(prefs);
    var changed = storedWeekKey != weekKey;

    for (final goal in goals) {
      if (goal.isCompleted && !claimed.contains(goal.id)) {
        bonusXp += goal.xpReward;
        claimed.add(goal.id);
        changed = true;
      }
    }

    if (!changed) return;

    await prefs.setString(_kWeeklyGoalsWeekKey, weekKey);
    await prefs.setInt(_kBonusXp, bonusXp);
    await prefs.setString(_kWeeklyGoalsClaimed, jsonEncode(claimed.toList()));
  }

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
      String? taskId;
      String? taskTitle;
      int? focusModeMinutes;
      if (newestIndex < existing.length) {
        final existingRecord = existing[newestIndex];
        completedAt = existingRecord.completedAt;
        taskId = existingRecord.taskId;
        taskTitle = existingRecord.taskTitle;
        focusModeMinutes = existingRecord.focusModeMinutes;
        if (existingRecord.focusSeconds > 0 &&
            i >= focusSecondsList.length) {
          focusSecondsValue = existingRecord.focusSeconds;
        }
      } else {
        completedAt = DateTime.now().subtract(
          Duration(days: completedSessions - 1 - i, minutes: i * 7),
        );
        focusModeMinutes = VoidDeepWorkMode.resolve(
          prefs.getInt(_kDeepWorkModeMinutes) ?? _kDefaultDeepWorkModeMinutes,
        ).minutes;
      }

      records.add(
        VoidSessionRecord(
          completedAt: completedAt,
          focusSeconds: focusSecondsValue,
          distractions: distractionsValue,
          focusScore: computeFocusScore(distractionsValue),
          xp: computeSessionXp(focusSecondsValue, distractionsValue),
          taskId: taskId,
          taskTitle: taskTitle,
          focusModeMinutes: focusModeMinutes,
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
    Map<String, VoidDayActivity> activity, [
    List<VoidSessionRecord> sessionHistory = const [],
  ]) {
    return _buildLastDays(activity, 7, sessionHistory);
  }

  static List<VoidDayActivity> _buildLast30Days(
    Map<String, VoidDayActivity> activity, [
    List<VoidSessionRecord> sessionHistory = const [],
  ]) {
    return _buildLastDays(activity, kVoidFocusCalendarDays, sessionHistory);
  }

  static List<VoidDayActivity> _buildLastDays(
    Map<String, VoidDayActivity> activity,
    int dayCount,
    List<VoidSessionRecord> sessionHistory,
  ) {
    final sessionDays = aggregateDayActivityFromSessions(sessionHistory);
    final today = DateTime.now();
    return List<VoidDayActivity>.generate(dayCount, (index) {
      final date = DateTime(today.year, today.month, today.day)
          .subtract(Duration(days: dayCount - 1 - index));
      final key = _dateKey(date);
      final stored = activity[key];
      final sessionDay = sessionDays[key];
      final focusSeconds =
          stored?.focusSeconds ?? sessionDay?.focusSeconds ?? 0;

      if (stored != null && stored.sessionsCount > 0) {
        return stored.copyWith(date: date, focusSeconds: focusSeconds);
      }
      if (sessionDay != null) {
        return sessionDay.copyWith(date: date, focusSeconds: focusSeconds);
      }
      return VoidDayActivity(date: date, focusSeconds: focusSeconds);
    });
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
        final activity = parseDailyActivityMap(prefs.getString(_kDailyActivity));
        if (activity.isNotEmpty) {
          final migrated = activity.map(
            (key, day) => MapEntry(
              key,
              day.copyWith(focusSeconds: day.focusSeconds * 60),
            ),
          );
          await prefs.setString(
            _kDailyActivity,
            encodeDailyActivityMap(migrated),
          );
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
    Map<String, VoidDayActivity> activity,
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
    if ((activity[today]?.focusSeconds ?? 0) > 0) {
      await prefs.setString(_kLastActiveDate, today);
    }

    return (current: current, best: best);
  }

  int _readTodayFocusSeconds(
    SharedPreferences prefs,
    Map<String, VoidDayActivity> activity,
  ) {
    return activity[_dateKey(DateTime.now())]?.focusSeconds ?? 0;
  }

  int _readDailyGoalMinutes(SharedPreferences prefs) {
    return prefs.getInt(_kDailyGoalMinutes) ?? _kDefaultDailyGoalMinutes;
  }

  int _readDeepWorkModeMinutes(SharedPreferences prefs) {
    final minutes = prefs.getInt(_kDeepWorkModeMinutes) ??
        _kDefaultDeepWorkModeMinutes;
    return VoidDeepWorkMode.forMinutes(minutes)?.minutes ??
        _kDefaultDeepWorkModeMinutes;
  }

  Future<bool> setDeepWorkModeMinutes(int minutes) async {
    final mode = VoidDeepWorkMode.forMinutes(minutes);
    if (mode == null) return false;

    await initialize();
    final prefs = await _requirePrefs();
    if (prefs == null) return false;

    try {
      await prefs.setInt(_kDeepWorkModeMinutes, mode.minutes);
    } catch (_) {
      return false;
    }

    data = StatsData(
      completedSessions: data.completedSessions,
      totalFocusSeconds: data.totalFocusSeconds,
      currentStreak: data.currentStreak,
      bestStreak: data.bestStreak,
      todaySessions: data.todaySessions,
      distractions: data.distractions,
      averageDistractionsPerSession: data.averageDistractionsPerSession,
      preventedDistractionMinutes: data.preventedDistractionMinutes,
      achievements: data.achievements,
      sessionHistory: data.sessionHistory,
      todayFocusSeconds: data.todayFocusSeconds,
      dailyGoalMinutes: data.dailyGoalMinutes,
      deepWorkModeMinutes: mode.minutes,
      averageFocusScore: data.averageFocusScore,
      last7Days: data.last7Days,
      last30Days: data.last30Days,
      personalRecords: data.personalRecords,
      bonusXp: data.bonusXp,
      weeklyGoals: data.weeklyGoals,
      focusModeStats: data.focusModeStats,
    );
    notifyListeners();
    return true;
  }

  static bool _readDailyGoalAchieved(SharedPreferences prefs) {
    return prefs.getBool(_kDailyGoalAchieved) ?? false;
  }

  static bool _activityContainsDailyGoal(
    Map<String, VoidDayActivity> activity,
    int goalMinutes,
  ) {
    final threshold = goalMinutes * 60;
    return activity.values.any((day) => day.focusSeconds >= threshold);
  }

  Future<void> _syncDailyGoalAchieved(
    SharedPreferences prefs,
    Map<String, VoidDayActivity> activity,
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

      final activity = parseDailyActivityMap(prefs.getString(_kDailyActivity));
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
      final deepWorkModeMinutes = _readDeepWorkModeMinutes(prefs);
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
      final personalRecords = buildPersonalRecords(
        sessionHistory: sessionHistory,
        activity: activity,
        bestStreak: bestStreak,
      );
      await _syncWeeklyGoalRewards(prefs, sessionHistory, activity);
      final bonusXp = _readBonusXp(prefs);
      final weeklyGoals = buildWeeklyGoalsData(
        sessionHistory: sessionHistory,
        activity: activity,
        claimedIds: _readWeeklyGoalsClaimed(prefs),
        weeklySessionsCount: _readWeeklySessionsCount(prefs),
      );
      final focusModeStats = _readFocusModeStats(prefs, sessionHistory);
      final storedFocusModeStats = prefs.getString(_kFocusModeStats);
      if ((storedFocusModeStats == null || storedFocusModeStats.isEmpty) &&
          sessionHistory.isNotEmpty) {
        await prefs.setString(
          _kFocusModeStats,
          jsonEncode({
            for (final entry in focusModeStats.entries)
              '${entry.minutes}': {
                'sessions': entry.sessions,
                'focusSeconds': entry.focusSeconds,
              },
          }),
        );
      }

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
        deepWorkModeMinutes: deepWorkModeMinutes,
        averageFocusScore: averageFocusScore,
        last7Days: _buildLast7Days(activity, sessionHistory),
        last30Days: _buildLast30Days(activity, sessionHistory),
        personalRecords: personalRecords,
        bonusXp: bonusXp,
        weeklyGoals: weeklyGoals,
        focusModeStats: focusModeStats,
      );

      unawaited(
        VoidNotificationService.instance.rescheduleFromStats(data),
      );
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> completeSession({
    required int focusSeconds,
    int sessionDistractions = 0,
    String? taskId,
    String? taskTitle,
    int? focusModeMinutes,
  }) async {
    await initialize();
    final prefs = await _requirePrefs();
    if (prefs == null) {
      return false;
    }

    try {
      await _migrateToSecondsIfNeeded(prefs);

      final today = _dateKey(DateTime.now());

      final completedSessions = _readCompletedSessions(prefs) + 1;
      final totalFocusSeconds =
          _readTotalFocusSeconds(prefs) + focusSeconds;

      final activity = parseDailyActivityMap(prefs.getString(_kDailyActivity));
      activity[today] = mergeDailyActivity(
        dayKey: today,
        existing: activity[today],
        addedFocusSeconds: focusSeconds,
        addedDistractions: sessionDistractions,
        addedFocusScore: computeFocusScore(sessionDistractions),
        addedXp: computeSessionXp(focusSeconds, sessionDistractions),
      );

      final todaySessions = _readTodaySessions(prefs) + 1;
      final totalDistractions =
          (prefs.getInt(_kTotalDistractions) ?? 0) + sessionDistractions;
      final sessionDistractionsHistory =
          _readSessionDistractionsHistory(prefs)..add(sessionDistractions);
      final sessionFocusSecondsHistory =
          _readSessionFocusSecondsHistory(prefs)..add(focusSeconds);

      await prefs.setInt(_kCompletedSessions, completedSessions);
      await prefs.setInt(_kTotalFocusSeconds, totalFocusSeconds);
      await prefs.setString(
        _kDailyActivity,
        encodeDailyActivityMap(activity),
      );
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

      final resolvedFocusModeMinutes = VoidDeepWorkMode.resolve(
        focusModeMinutes ?? _readDeepWorkModeMinutes(prefs),
      ).minutes;

      await _incrementFocusModeStats(
        prefs,
        resolvedFocusModeMinutes,
        focusSeconds,
      );

      await _syncSessionHistory(prefs);

      final history = _readSessionHistoryRaw(prefs);
      history.sort((a, b) => b.completedAt.compareTo(a.completedAt));
      if (history.isNotEmpty) {
        history[0] = history.first.copyWith(
          taskId: taskId ?? history.first.taskId,
          taskTitle: taskTitle ?? history.first.taskTitle,
          focusModeMinutes: resolvedFocusModeMinutes,
        );
        await prefs.setString(
          _kSessionHistory,
          jsonEncode(history.map((record) => record.toJson()).toList()),
        );
      }

      if (taskId != null && focusSeconds > 0) {
        await TasksService.instance.recordTaskSession(
          taskId,
          focusSeconds,
          focusScore: computeFocusScore(sessionDistractions),
        );
      }

      final dailyGoalMinutes = _readDailyGoalMinutes(prefs);
      if ((activity[today]?.focusSeconds ?? 0) >= dailyGoalMinutes * 60) {
        await prefs.setBool(_kDailyGoalAchieved, true);
      }

      await _incrementWeeklySessionsCount(prefs);
      final sessionHistory = _readSessionHistory(prefs);
      await _syncWeeklyGoalRewards(prefs, sessionHistory, activity);
    } catch (_) {
      return false;
    }

    _loadFuture = null;
    await _loadInternal();
    return true;
  }

  Future<bool> shouldPromptFirstLaunchFeedback() async {
    await initialize();
    final prefs = await _requirePrefs();
    if (prefs == null) return false;
    return shouldShowFirstLaunchFeedback(
      completedSessions: _readCompletedSessions(prefs),
      alreadyShown: prefs.getBool(_kFirstLaunchFeedbackShown) ?? false,
    );
  }

  Future<void> markFirstLaunchFeedbackShown() async {
    await initialize();
    final prefs = await _requirePrefs();
    if (prefs == null) return;
    await prefs.setBool(_kFirstLaunchFeedbackShown, true);
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
      await prefs.setBool(_kFirstLaunchFeedbackShown, false);
      await prefs.setInt(_kBonusXp, 0);
      await prefs.remove(_kWeeklyGoalsWeekKey);
      await prefs.remove(_kWeeklyGoalsClaimed);
      await prefs.remove(_kWeeklySessionsCount);
      await prefs.setString(
        _kFocusModeStats,
        jsonEncode(emptyFocusModeStatsMap()),
      );
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

  Future<Map<String, dynamic>> buildBackupPayload() async {
    await load();
    await TasksService.instance.load();
    final prefs = await _requirePrefs();
    if (prefs == null) {
      return buildVoidBackupPayload(
        stats: data,
        dailyActivity: const {},
        todaySessionsDate: null,
        weeklySessionsCount: 0,
        weeklyGoalsWeekKey: null,
        weeklyGoalsClaimed: const {},
        dailyGoalAchieved: false,
        projects: TasksService.instance.projects,
        tasks: TasksService.instance.tasks,
      );
    }

    return buildVoidBackupPayload(
      stats: data,
      dailyActivity: parseDailyActivityMap(prefs.getString(_kDailyActivity)),
      todaySessionsDate: prefs.getString(_kTodaySessionsDate),
      weeklySessionsCount: prefs.getInt(_kWeeklySessionsCount) ?? 0,
      weeklyGoalsWeekKey: prefs.getString(_kWeeklyGoalsWeekKey),
      weeklyGoalsClaimed: _readWeeklyGoalsClaimed(prefs),
      dailyGoalAchieved: _readDailyGoalAchieved(prefs),
      projects: TasksService.instance.projects,
      tasks: TasksService.instance.tasks,
    );
  }

  Future<String> exportBackup() async {
    final payload = await buildBackupPayload();
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  Future<String> exportData() async => exportBackup();

  Future<VoidBackupImportResult> importBackup(String raw) async {
    final parsed = parseVoidBackupJson(raw);
    if (parsed == null) {
      return const VoidBackupImportResult(
        success: false,
        error: 'Некорректный JSON',
      );
    }

    final backup = normalizeVoidBackup(parsed);
    final statistics = backup['statistics'];
    if (statistics is! Map) {
      return const VoidBackupImportResult(
        success: false,
        error: 'Отсутствует раздел statistics',
      );
    }

    final statsMap = statistics.map(
      (key, value) => MapEntry(key.toString(), value),
    );
    final sessions = parseVoidBackupSessions(backup['sessions']);
    final projects = parseVoidBackupProjects(backup['projects']);
    final tasks = parseVoidBackupTasks(backup['tasks']);

    await initialize();
    final prefs = await _requirePrefs();
    if (prefs == null) {
      return const VoidBackupImportResult(
        success: false,
        error: 'Хранилище недоступно',
      );
    }

    try {
      final completedSessions =
          statsMap['completedSessions'] as int? ?? sessions.length;
      final totalFocusSeconds = statsMap['totalFocusSeconds'] as int? ?? 0;
      final currentStreak = statsMap['currentStreak'] as int? ?? 0;
      final bestStreak = statsMap['bestStreak'] as int? ?? 0;
      final todaySessions = statsMap['todaySessions'] as int? ?? 0;
      final todaySessionsDate = statsMap['todaySessionsDate'] as String?;
      final totalDistractions = statsMap['totalDistractions'] as int? ?? 0;
      final preventedDistractionMinutes =
          statsMap['preventedDistractionMinutes'] as int? ?? 0;
      final dailyGoalMinutes =
          statsMap['dailyGoalMinutes'] as int? ?? _kDefaultDailyGoalMinutes;
      final deepWorkModeMinutes = VoidDeepWorkMode.forMinutes(
            statsMap['deepWorkModeMinutes'] as int? ??
                _kDefaultDeepWorkModeMinutes,
          )?.minutes ??
          _kDefaultDeepWorkModeMinutes;
      final dailyGoalAchieved = statsMap['dailyGoalAchieved'] as bool? ?? false;
      final bonusXp = statsMap['bonusXp'] as int? ?? 0;
      final weeklyGoalsWeekKey = statsMap['weeklyGoalsWeekKey'] as String?;
      final weeklySessionsCount =
          statsMap['weeklySessionsCount'] as int? ?? 0;
      final weeklyGoalsClaimedRaw = statsMap['weeklyGoalsClaimed'];
      final weeklyGoalsClaimed = weeklyGoalsClaimedRaw is List
          ? weeklyGoalsClaimedRaw.map((entry) => entry.toString()).toList()
          : <String>[];

      var dailyActivity = <String, VoidDayActivity>{};
      final dailyActivityRaw = statsMap['dailyActivity'];
      if (dailyActivityRaw is Map) {
        dailyActivity = parseDailyActivityFromDynamicMap(dailyActivityRaw);
      }
      if (dailyActivity.isEmpty && sessions.isNotEmpty) {
        dailyActivity = aggregateDayActivityFromSessions(sessions);
      }

      final orderedSessions = [...sessions]
        ..sort((a, b) => a.completedAt.compareTo(b.completedAt));
      final distractionsHistory =
          orderedSessions.map((session) => session.distractions).toList();
      final focusSecondsHistory =
          orderedSessions.map((session) => session.focusSeconds).toList();
      final sessionHistoryNewestFirst = [...sessions]
        ..sort((a, b) => b.completedAt.compareTo(a.completedAt));

      await prefs.setInt(_kCompletedSessions, completedSessions);
      await prefs.setInt(_kTotalFocusSeconds, totalFocusSeconds);
      await prefs.setInt(_kCurrentStreak, currentStreak);
      await prefs.setInt(_kBestStreak, bestStreak);
      await prefs.setString(
        _kDailyActivity,
        encodeDailyActivityMap(dailyActivity),
      );
      if (todaySessionsDate != null && todaySessionsDate.isNotEmpty) {
        await prefs.setString(_kTodaySessionsDate, todaySessionsDate);
      } else {
        await prefs.remove(_kTodaySessionsDate);
      }
      await prefs.setInt(_kTodaySessions, todaySessions);
      await prefs.setInt(_kTotalDistractions, totalDistractions);
      await prefs.setString(
        _kSessionDistractionsHistory,
        jsonEncode(distractionsHistory),
      );
      await prefs.setString(
        _kSessionFocusSecondsHistory,
        jsonEncode(focusSecondsHistory),
      );
      await prefs.setString(
        _kSessionHistory,
        jsonEncode(
          sessionHistoryNewestFirst.map((session) => session.toJson()).toList(),
        ),
      );
      await prefs.setBool(
        _kSessionHistoryManuallyCleared,
        sessionHistoryNewestFirst.isEmpty && completedSessions > 0,
      );
      await prefs.setInt(
        _kPreventedDistractionMinutes,
        preventedDistractionMinutes,
      );
      await prefs.setInt(_kDailyGoalMinutes, dailyGoalMinutes);
      await prefs.setInt(_kDeepWorkModeMinutes, deepWorkModeMinutes);
      await prefs.setBool(_kDailyGoalAchieved, dailyGoalAchieved);
      await prefs.setInt(_kBonusXp, bonusXp);
      if (weeklyGoalsWeekKey != null && weeklyGoalsWeekKey.isNotEmpty) {
        await prefs.setString(_kWeeklyGoalsWeekKey, weeklyGoalsWeekKey);
      } else {
        await prefs.remove(_kWeeklyGoalsWeekKey);
      }
      await prefs.setString(
        _kWeeklyGoalsClaimed,
        jsonEncode(weeklyGoalsClaimed),
      );
      await prefs.setInt(_kWeeklySessionsCount, weeklySessionsCount);
      await prefs.setBool(_kFocusDataUsesSeconds, true);

      final focusModeStatsRaw = statsMap['focusModeStats'];
      if (focusModeStatsRaw is Map) {
        await prefs.setString(
          _kFocusModeStats,
          jsonEncode(
            focusModeStatsRaw.map(
              (key, value) => MapEntry(key.toString(), value),
            ),
          ),
        );
      } else {
        final rebuilt = buildFocusModeStatsFromSessions(
          sessionHistoryNewestFirst,
        );
        await prefs.setString(
          _kFocusModeStats,
          jsonEncode({
            for (final entry in rebuilt.entries)
              '${entry.minutes}': {
                'sessions': entry.sessions,
                'focusSeconds': entry.focusSeconds,
              },
          }),
        );
      }

      final tasksRestored =
          await TasksService.instance.restoreFromBackup(
        projects: projects,
        tasks: tasks,
      );
      if (!tasksRestored) {
        return const VoidBackupImportResult(
          success: false,
          error: 'Не удалось восстановить задачи и проекты',
        );
      }
    } catch (_) {
      return const VoidBackupImportResult(
        success: false,
        error: 'Ошибка при восстановлении данных',
      );
    }

    _loadFuture = null;
    await _loadInternal();
    await TasksService.instance.load(force: true);
    return VoidBackupImportResult(
      success: true,
      sessionsCount: sessions.length,
      projectsCount: projects.length,
      tasksCount: tasks.length,
    );
  }
}

class TasksService extends ChangeNotifier {
  TasksService._();

  static final TasksService instance = TasksService._();

  List<VoidProject> projects = [];
  List<VoidTask> tasks = [];
  VoidTaskSelection? activeTaskSelection;
  bool isLoading = false;
  SharedPreferences? _prefs;
  Future<void>? _initFuture;

  Future<void> initialize({bool force = false}) async {
    if (force) {
      _prefs = null;
      _initFuture = null;
    }
    if (_prefs != null) return;
    _initFuture ??= _initializePrefs();
    await _initFuture;
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

  static List<VoidProject> _readProjectsRaw(SharedPreferences prefs) {
    final raw = prefs.getString(_kVoidProjects);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map(
            (entry) => VoidProject.fromJson(
              entry.map((key, value) => MapEntry(key.toString(), value)),
            ),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  static List<VoidTask> _readTasksRaw(SharedPreferences prefs) {
    final raw = prefs.getString(_kVoidTasks);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map(
            (entry) => VoidTask.fromJson(
              entry.map((key, value) => MapEntry(key.toString(), value)),
            ),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> load({bool force = false}) async {
    if (isLoading && !force) return;
    isLoading = true;
    notifyListeners();
    try {
      final prefs = await _requirePrefs();
      if (prefs == null) {
        projects = [];
        tasks = [];
        return;
      }
      final loadedProjects = _readProjectsRaw(prefs);
      loadedProjects.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      projects = loadedProjects;

      final loadedTasks = _readTasksRaw(prefs);
      loadedTasks.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      tasks = loadedTasks;
      _loadActiveTaskSelection(prefs);
      _validateActiveTaskSelection();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void _loadActiveTaskSelection(SharedPreferences prefs) {
    final taskId = prefs.getString(_kActiveTaskId);
    final taskTitle = prefs.getString(_kActiveTaskTitle);
    if (taskId != null &&
        taskTitle != null &&
        taskTitle.isNotEmpty) {
      activeTaskSelection =
          VoidTaskSelection(taskId: taskId, taskTitle: taskTitle);
    } else {
      activeTaskSelection = null;
    }
  }

  void _validateActiveTaskSelection() {
    final selection = activeTaskSelection;
    if (selection == null || !selection.hasTask) return;
    final task = taskById(selection.taskId);
    if (task == null || task.isCompleted) {
      activeTaskSelection = null;
    }
  }

  Future<bool> setActiveTask(VoidTaskSelection? selection) async {
    await load();
    final prefs = await _requirePrefs();
    if (prefs == null) return false;

    try {
      if (selection != null && selection.hasTask) {
        await prefs.setString(_kActiveTaskId, selection.taskId!);
        await prefs.setString(_kActiveTaskTitle, selection.taskTitle!);
        activeTaskSelection = selection;
      } else {
        await prefs.remove(_kActiveTaskId);
        await prefs.remove(_kActiveTaskTitle);
        activeTaskSelection = null;
      }
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> scheduleLoad({bool force = false}) async {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(load(force: force));
    });
  }

  Future<bool> _saveProjects(List<VoidProject> updated) async {
    final prefs = await _requirePrefs();
    if (prefs == null) return false;
    try {
      await prefs.setString(
        _kVoidProjects,
        jsonEncode(updated.map((project) => project.toJson()).toList()),
      );
      updated.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      projects = updated;
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _saveTasks(List<VoidTask> updated) async {
    final prefs = await _requirePrefs();
    if (prefs == null) return false;
    try {
      await prefs.setString(
        _kVoidTasks,
        jsonEncode(updated.map((task) => task.toJson()).toList()),
      );
      updated.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      tasks = updated;
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> restoreFromBackup({
    required List<VoidProject> projects,
    required List<VoidTask> tasks,
  }) async {
    final prefs = await _requirePrefs();
    if (prefs == null) return false;

    final sortedProjects = [...projects]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final sortedTasks = [...tasks]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    try {
      await prefs.setString(
        _kVoidProjects,
        jsonEncode(sortedProjects.map((project) => project.toJson()).toList()),
      );
      await prefs.setString(
        _kVoidTasks,
        jsonEncode(sortedTasks.map((task) => task.toJson()).toList()),
      );
      this.projects = sortedProjects;
      this.tasks = sortedTasks;
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<VoidProject?> addProject(VoidProjectEditorResult draft) async {
    final trimmed = draft.title.trim();
    if (trimmed.isEmpty) return null;
    await load();
    final project = VoidProject(
      id: generateVoidTaskId(),
      title: trimmed,
      createdAt: DateTime.now(),
      colorValue: draft.colorValue,
      iconName: draft.iconName,
    );
    final updated = [...projects, project];
    final saved = await _saveProjects(updated);
    return saved ? project : null;
  }

  Future<bool> updateProject(VoidProject project) async {
    final trimmed = project.title.trim();
    if (trimmed.isEmpty) return false;
    await load();
    final index = projects.indexWhere((entry) => entry.id == project.id);
    if (index < 0) return false;
    final updated = [...projects];
    updated[index] = project.copyWith(title: trimmed);
    return _saveProjects(updated);
  }

  Future<bool> deleteProject(String id) async {
    await load();
    final updatedProjects =
        projects.where((project) => project.id != id).toList();
    if (updatedProjects.length == projects.length) return false;

    final updatedTasks = tasks
        .map(
          (task) => task.projectId == id
              ? task.copyWith(clearProjectId: true)
              : task,
        )
        .toList();

    final projectsSaved = await _saveProjects(updatedProjects);
    if (!projectsSaved) return false;
    return _saveTasks(updatedTasks);
  }

  Future<VoidTask?> addTask(
    String title, {
    String? projectId,
    String description = '',
    bool isCompleted = false,
    int estimatedSessions = kDefaultTaskEstimatedSessions,
  }) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return null;
    await load();
    if (projectId != null && projectById(projectId) == null) return null;
    final task = VoidTask(
      id: generateVoidTaskId(),
      title: trimmed,
      description: description.trim(),
      isCompleted: isCompleted,
      estimatedSessions: estimatedSessions.clamp(1, 99),
      totalFocusSeconds: 0,
      completedSessions: 0,
      focusScoreSum: 0,
      bestFocusScore: 0,
      createdAt: DateTime.now(),
      projectId: projectId,
    );
    final updated = [...tasks, task];
    final saved = await _saveTasks(updated);
    return saved ? task : null;
  }

  Future<bool> updateTask(VoidTask task) async {
    final trimmed = task.title.trim();
    if (trimmed.isEmpty) return false;
    await load();
    if (task.projectId != null && projectById(task.projectId) == null) {
      return false;
    }
    final index = tasks.indexWhere((entry) => entry.id == task.id);
    if (index < 0) return false;
    final updated = [...tasks];
    updated[index] = task.copyWith(title: trimmed);
    return _saveTasks(updated);
  }

  Future<bool> deleteTask(String id) async {
    await load();
    final updated = tasks.where((task) => task.id != id).toList();
    if (updated.length == tasks.length) return false;
    final saved = await _saveTasks(updated);
    if (saved && activeTaskSelection?.taskId == id) {
      await setActiveTask(null);
    }
    return saved;
  }

  Future<bool> toggleTaskCompleted(String id) async {
    await load();
    final index = tasks.indexWhere((task) => task.id == id);
    if (index < 0) return false;
    final updated = [...tasks];
    final task = updated[index];
    updated[index] = task.copyWith(isCompleted: !task.isCompleted);
    final saved = await _saveTasks(updated);
    if (saved && activeTaskSelection?.taskId == id && updated[index].isCompleted) {
      await setActiveTask(VoidTaskSelection.withoutTask);
    }
    return saved;
  }

  Future<bool> recordTaskSession(
    String taskId,
    int seconds, {
    int focusScore = 0,
  }) async {
    if (seconds <= 0) return false;
    await load();
    final index = tasks.indexWhere((task) => task.id == taskId);
    if (index < 0) return false;
    final updated = [...tasks];
    final task = updated[index];
    updated[index] = task.copyWith(
      totalFocusSeconds: task.totalFocusSeconds + seconds,
      completedSessions: task.completedSessions + 1,
      focusScoreSum: task.focusScoreSum + focusScore,
      bestFocusScore: focusScore > task.bestFocusScore
          ? focusScore
          : task.bestFocusScore,
    );
    return _saveTasks(updated);
  }

  Future<bool> addFocusSeconds(String taskId, int seconds) async =>
      recordTaskSession(taskId, seconds);

  VoidProject? projectById(String? id) {
    if (id == null) return null;
    for (final project in projects) {
      if (project.id == id) return project;
    }
    return null;
  }

  VoidTask? taskById(String? id) {
    if (id == null) return null;
    for (final task in tasks) {
      if (task.id == id) return task;
    }
    return null;
  }

  int projectFocusSeconds(String projectId) {
    return tasks
        .where((task) => task.projectId == projectId)
        .fold<int>(0, (sum, task) => sum + task.totalFocusSeconds);
  }

  int projectSessionsCount(String projectId) {
    return tasks
        .where((task) => task.projectId == projectId)
        .fold<int>(0, (sum, task) => sum + task.completedSessions);
  }

  bool isProjectCompleted(VoidProject project) {
    final projectTasks =
        tasks.where((task) => task.projectId == project.id).toList();
    if (projectTasks.isEmpty) return false;
    return projectTasks.every((task) => task.isCompleted);
  }

  List<VoidTask> get completedTasks =>
      tasks.where((task) => task.isCompleted).toList();

  List<VoidProject> get completedProjects =>
      projects.where(isProjectCompleted).toList();

  List<VoidTask> tasksForProject(String? projectId, {bool activeOnly = false}) {
    return tasks.where((task) {
      final matchesProject = task.projectId == projectId;
      if (!matchesProject) return false;
      return activeOnly ? !task.isCompleted : true;
    }).toList();
  }

  List<VoidTask> get activeTasks =>
      tasks.where((task) => !task.isCompleted).toList();

  int get activeTaskCount => activeTasks.length;

  int get projectCount => projects.length;
}

class VoidMetrics {
  VoidMetrics._({
    required this.paddingH,
    required this.gapS,
    required this.gapM,
    required this.gapL,
    required this.gapXL,
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
  final double gapXL;
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
      gapXL: compact ? 28 : 36,
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
  await TasksService.instance.initialize().catchError((_) {});
  await VoidNotificationService.instance.initialize().catchError((_) {});
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

class _VoidShellState extends State<VoidShell> with WidgetsBindingObserver {
  late int _currentIndex;
  VoidTaskSelection? _taskSelection;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentIndex = widget.initialIndex;
    StatsService.instance.scheduleLoad(force: true);
    TasksService.instance.scheduleLoad(force: true);
    unawaited(
      TasksService.instance.load(force: true).then((_) {
        if (!mounted) return;
        setState(() {
          _taskSelection = TasksService.instance.activeTaskSelection;
        });
      }),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(
        VoidNotificationService.instance.rescheduleFromStats(
          StatsService.instance.data,
        ),
      );
    }
  }

  void _onTabSelected(int index) {
    if (index == _currentIndex) return;
    HapticFeedback.selectionClick();
    setState(() => _currentIndex = index);
    StatsService.instance.load(force: true);
  }

  Future<void> _openFocusTab() async {
    final selection = await showVoidTaskPicker(context);
    if (selection == null || !mounted) return;
    await TasksService.instance.setActiveTask(selection);
    if (!mounted) return;
    HapticFeedback.lightImpact();
    setState(() {
      _taskSelection = selection;
      _currentIndex = 1;
    });
  }

  Future<void> _quickStartFocus() async {
    final selection =
        _taskSelection ?? TasksService.instance.activeTaskSelection;
    if (selection != null && selection.hasTask) {
      HapticFeedback.lightImpact();
      setState(() {
        _taskSelection = selection;
        _currentIndex = 1;
      });
      return;
    }
    await _openFocusTab();
  }

  void _onTaskSelectionChanged(VoidTaskSelection? selection) {
    setState(() => _taskSelection = selection);
    unawaited(TasksService.instance.setActiveTask(selection));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kVoidBackground,
      body: IndexedStack(
        index: _currentIndex,
        children: [
          VoidHomeTab(
            onStartSession: _openFocusTab,
            onQuickStart: _quickStartFocus,
          ),
          VoidFocusTab(
            initialTaskSelection: _taskSelection,
            onTaskSelectionChanged: _onTaskSelectionChanged,
          ),
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

class VoidHomeActiveTaskCard extends StatelessWidget {
  const VoidHomeActiveTaskCard({
    super.key,
    required this.taskSelection,
    required this.onChangeTask,
    required this.onQuickStart,
  });

  final VoidTaskSelection? taskSelection;
  final VoidCallback onChangeTask;
  final VoidCallback onQuickStart;

  @override
  Widget build(BuildContext context) {
    final m = VoidMetrics.of(context);
    final hasTask = taskSelection?.hasTask ?? false;
    final task = hasTask
        ? TasksService.instance.taskById(taskSelection!.taskId)
        : null;
    final project = task?.projectId != null
        ? TasksService.instance.projectById(task!.projectId)
        : null;
    final accent = project?.color ?? kVoidAccent;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasTask
              ? accent.withValues(alpha: 0.35)
              : kVoidAccent.withValues(alpha: 0.18),
        ),
        boxShadow: hasTask
            ? [
                BoxShadow(
                  color: accent.withValues(alpha: 0.12),
                  blurRadius: 18,
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: hasTask
                      ? accent.withValues(alpha: 0.16)
                      : kVoidAccent.withValues(alpha: 0.12),
                  border: Border.all(
                    color: hasTask
                        ? accent.withValues(alpha: 0.35)
                        : kVoidAccent.withValues(alpha: 0.2),
                  ),
                ),
                child: Center(
                  child: hasTask && project != null
                      ? Text(project.emoji, style: const TextStyle(fontSize: 22))
                      : Icon(
                          Icons.task_alt_rounded,
                          size: 22,
                          color: hasTask
                              ? accent.withValues(alpha: 0.9)
                              : Colors.white.withValues(alpha: 0.35),
                        ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Активная задача',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.45),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hasTask ? taskSelection!.taskTitle! : 'Задача не выбрана',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.92),
                      ),
                    ),
                    if (hasTask && project != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${project.emoji} ${project.title}',
                        style: TextStyle(
                          fontSize: 12,
                          color: accent.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (hasTask)
                IconButton(
                  onPressed: onChangeTask,
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    Icons.swap_horiz_rounded,
                    color: kVoidAccent.withValues(alpha: 0.8),
                  ),
                ),
            ],
          ),
          if (hasTask && task != null) ...[
            const SizedBox(height: 14),
            VoidTaskSessionProgressSection(
              task: task,
              accent: accent,
            ),
          ],
          SizedBox(height: m.gapM),
          SizedBox(
            width: double.infinity,
            height: m.buttonHeight,
            child: FilledButton.icon(
              onPressed: hasTask ? onQuickStart : onChangeTask,
              style: FilledButton.styleFrom(
                backgroundColor: kVoidAccent,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(m.buttonRadius),
                ),
              ),
              icon: Icon(
                hasTask ? Icons.play_arrow_rounded : Icons.add_task_rounded,
                size: 20,
              ),
              label: Text(
                hasTask ? 'Быстрый старт' : 'Выбрать задачу',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

}

class VoidCompletedWorkCard extends StatelessWidget {
  const VoidCompletedWorkCard({
    super.key,
    required this.completedTasks,
    required this.completedProjects,
  });

  final List<VoidTask> completedTasks;
  final List<VoidProject> completedProjects;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kVoidAccent.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Завершённая работа',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.45),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Задачи · ${completedTasks.length}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 8),
          if (completedTasks.isEmpty)
            Text(
              'Пока нет завершённых задач',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.4),
              ),
            )
          else
            ...completedTasks.take(3).map(
              (task) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '• ${task.title} · ${formatFocusDuration(task.totalFocusSeconds)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.55),
                  ),
                ),
              ),
            ),
          if (completedTasks.length > 3)
            Text(
              'и ещё ${completedTasks.length - 3}',
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.35),
              ),
            ),
          const SizedBox(height: 14),
          Text(
            'Проекты · ${completedProjects.length}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 8),
          if (completedProjects.isEmpty)
            Text(
              'Пока нет завершённых проектов',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.4),
              ),
            )
          else
            ...completedProjects.take(3).map(
              (project) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Text(
                      project.emoji,
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${project.title} · '
                            '${formatFocusDuration(TasksService.instance.projectFocusSeconds(project.id))}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.55),
                        ),
                      ),
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

class VoidFocusBreakdownListCard extends StatelessWidget {
  const VoidFocusBreakdownListCard({
    super.key,
    required this.title,
    required this.entries,
  });

  final String title;
  final List<VoidFocusBreakdownEntry> entries;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kVoidAccent.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.45),
            ),
          ),
          const SizedBox(height: 12),
          if (entries.isEmpty)
            Text(
              '—',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.35),
              ),
            )
          else
            for (var index = 0; index < entries.length; index++) ...[
              if (index > 0) const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      entries[index].title,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.88),
                      ),
                    ),
                  ),
                  Text(
                    '${formatFocusDuration(entries[index].focusSeconds)} · '
                    '${entries[index].sessionsCount} с.',
                    style: TextStyle(
                      fontSize: 11,
                      color: kVoidAccent.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ],
        ],
      ),
    );
  }
}

class VoidHomeTab extends StatefulWidget {
  const VoidHomeTab({
    super.key,
    required this.onStartSession,
    required this.onQuickStart,
  });

  final Future<void> Function() onStartSession;
  final Future<void> Function() onQuickStart;

  @override
  State<VoidHomeTab> createState() => _VoidHomeTabState();
}

class _VoidHomeTabState extends State<VoidHomeTab> {
  @override
  void initState() {
    super.initState();
    StatsService.instance.scheduleLoad(force: true);
    TasksService.instance.scheduleLoad(force: true);
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
            listenable: Listenable.merge([
              StatsService.instance,
              TasksService.instance,
            ]),
            builder: (context, _) {
              final analytics = StatsService.instance.data;
              final activeTask = TasksService.instance.activeTaskSelection;

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
                          VoidHomeActiveTaskCard(
                            taskSelection: activeTask,
                            onChangeTask: widget.onStartSession,
                            onQuickStart: widget.onQuickStart,
                          ),
                          SizedBox(height: m.gapM),
                          VoidDailyGoalCard(
                            todayFocusSeconds: analytics.todayFocusSeconds,
                            goalMinutes: analytics.dailyGoalMinutes,
                            progress: analytics.dailyGoalProgress,
                          ),
                          SizedBox(height: m.gapM),
                          VoidWeeklyGoalsCard(goalsData: analytics.weeklyGoals),
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
                  if (activeTask == null || !activeTask.hasTask) ...[
                    SizedBox(
                      width: double.infinity,
                      height: m.buttonHeight,
                      child: OutlinedButton(
                        onPressed: widget.onStartSession,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: kVoidAccent,
                          side: BorderSide(
                            color: kVoidAccent.withValues(alpha: 0.45),
                          ),
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
    TasksService.instance.scheduleLoad(force: true);
  }

  @override
  Widget build(BuildContext context) {
    final m = VoidMetrics.of(context);

    return VoidTabScaffold(
      glowCenter: const Alignment(0, -0.5),
      child: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge([
            StatsService.instance,
            TasksService.instance,
          ]),
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
                    VoidWeeklyGoalsCard(goalsData: analytics.weeklyGoals),
                    SizedBox(height: m.gapM),
                    VoidFocusModeStatsCard(stats: analytics.focusModeStats),
                    SizedBox(height: m.gapM),
                    VoidWeeklyReviewAccessCard(
                      reviewData: buildWeeklyReviewData(
                        sessionHistory: analytics.sessionHistory,
                      ),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const VoidWeeklyReviewScreen(),
                          ),
                        );
                      },
                    ),
                    SizedBox(height: m.gapM),
                    VoidProductivityInsightsAccessCard(
                      insights: buildProductivityInsights(
                        sessionHistory: analytics.sessionHistory,
                        tasks: TasksService.instance.tasks,
                        projects: TasksService.instance.projects,
                      ),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                const VoidProductivityInsightsScreen(),
                          ),
                        );
                      },
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
    TasksService.instance.scheduleLoad(force: true);
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
            listenable: Listenable.merge([
              StatsService.instance,
              TasksService.instance,
            ]),
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
                    const SizedBox(height: 6),
                    Text(
                      stats.levelTitle,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.2,
                        color: kVoidAccent.withValues(alpha: 0.88),
                      ),
                    ),
                    SizedBox(height: m.gapL),
                    VoidLevelCard(
                      level: stats.level,
                      levelTitle: stats.levelTitle,
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
                    SizedBox(height: m.gapM),
                    VoidPersonalRecordsCard(records: stats.personalRecords),
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
                    VoidCompletedWorkCard(
                      completedTasks: TasksService.instance.completedTasks,
                      completedProjects: TasksService.instance.completedProjects,
                    ),
                    SizedBox(height: m.gapM),
                    VoidProjectsTasksAccessCard(
                      projectCount: TasksService.instance.projectCount,
                      activeTaskCount: TasksService.instance.activeTaskCount,
                      onTap: () {
                        Navigator.push<void>(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => const VoidProjectsTasksScreen(),
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

class VoidProjectsTasksAccessCard extends StatelessWidget {
  const VoidProjectsTasksAccessCard({
    super.key,
    required this.projectCount,
    required this.activeTaskCount,
    required this.onTap,
  });

  final int projectCount;
  final int activeTaskCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final subtitle = projectCount == 0 && activeTaskCount == 0
        ? 'Создайте проект и задачи для фокуса'
        : '$projectCount ${_projectCountLabel(projectCount)} · '
            '$activeTaskCount ${_taskCountLabel(activeTaskCount)}';

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
                  Icons.folder_special_rounded,
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
                      'Проекты',
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

  static String _projectCountLabel(int count) {
    final mod10 = count % 10;
    final mod100 = count % 100;
    if (mod100 >= 11 && mod100 <= 14) return 'проектов';
    if (mod10 == 1) return 'проект';
    if (mod10 >= 2 && mod10 <= 4) return 'проекта';
    return 'проектов';
  }

  static String _taskCountLabel(int count) {
    final mod10 = count % 10;
    final mod100 = count % 100;
    if (mod100 >= 11 && mod100 <= 14) return 'активных задач';
    if (mod10 == 1) return 'активная задача';
    if (mod10 >= 2 && mod10 <= 4) return 'активные задачи';
    return 'активных задач';
  }
}

class VoidProjectsTasksScreen extends StatefulWidget {
  const VoidProjectsTasksScreen({super.key});

  @override
  State<VoidProjectsTasksScreen> createState() =>
      _VoidProjectsTasksScreenState();
}

class _VoidProjectsTasksScreenState extends State<VoidProjectsTasksScreen> {
  @override
  void initState() {
    super.initState();
    TasksService.instance.scheduleLoad(force: true);
  }

  Future<void> _addProject() async {
    final draft = await showVoidProjectEditorDialog(context);
    if (draft == null || !mounted) return;
    final created = await TasksService.instance.addProject(draft);
    if (!mounted) return;
    if (created == null) {
      showVoidSnackBar(context, 'Не удалось создать проект');
    }
  }

  void _openProject(VoidProject project) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => VoidProjectDetailScreen(projectId: project.id),
      ),
    );
  }

  Future<void> _addTask({String? projectId}) async {
    final draft = await showVoidTaskEditorDialog(
      context,
      initialProjectId: projectId,
    );
    if (draft == null || !mounted) return;
    final created = await TasksService.instance.addTask(
      draft.title,
      projectId: draft.projectId,
      description: draft.description,
      isCompleted: draft.isCompleted,
      estimatedSessions: draft.estimatedSessions,
    );
    if (!mounted) return;
    if (created == null) {
      showVoidSnackBar(context, 'Не удалось создать задачу');
    }
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
          'Проекты',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w400,
            color: Colors.white.withValues(alpha: 0.95),
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _addProject,
            tooltip: 'Добавить проект',
            icon: Icon(
              Icons.create_new_folder_rounded,
              color: kVoidAccent.withValues(alpha: 0.9),
            ),
          ),
          IconButton(
            onPressed: () => unawaited(_addTask()),
            tooltip: 'Добавить задачу',
            icon: Icon(
              Icons.add_task_rounded,
              color: kVoidAccent.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          const VoidAmbientGlow(center: Alignment(0, -0.55)),
          SafeArea(
            child: ListenableBuilder(
              listenable: TasksService.instance,
              builder: (context, _) {
                final store = TasksService.instance;
                final projects = store.projects;
                final unassignedTasks = store.tasksForProject(null);
                final isEmpty = projects.isEmpty && store.tasks.isEmpty;

                if (store.isLoading && isEmpty) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: kVoidAccent,
                      strokeWidth: 2,
                    ),
                  );
                }

                if (isEmpty) {
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
                              Icons.folder_special_rounded,
                              size: 40,
                              color: kVoidAccent.withValues(alpha: 0.6),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'Нет проектов и задач',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w400,
                                color: Colors.white.withValues(alpha: 0.85),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Создайте проект, добавьте задачи и привязывайте к ним фокус-сессии',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.4,
                                color: Colors.white.withValues(alpha: 0.45),
                              ),
                            ),
                            const SizedBox(height: 18),
                            FilledButton(
                              onPressed: _addProject,
                              style: FilledButton.styleFrom(
                                backgroundColor: kVoidAccent,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Создать проект'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                return ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    m.paddingH,
                    m.gapS,
                    m.paddingH,
                    m.gapL,
                  ),
                  children: [
                    for (final project in projects) ...[
                      VoidProjectListCard(
                        project: project,
                        taskCount: store.tasksForProject(project.id).length,
                        focusSeconds: store.projectFocusSeconds(project.id),
                        onTap: () => _openProject(project),
                      ),
                      SizedBox(height: m.gapM),
                    ],
                    if (unassignedTasks.isNotEmpty) ...[
                      Text(
                        'Без проекта',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.45),
                        ),
                      ),
                      SizedBox(height: m.gapS),
                      ...unassignedTasks.map(
                        (task) => Padding(
                          padding: EdgeInsets.only(bottom: m.gapS * 0.5),
                          child: VoidTaskCard(
                            task: task,
                            onToggleComplete: () {
                              unawaited(
                                TasksService.instance
                                    .toggleTaskCompleted(task.id),
                              );
                            },
                            onEdit: () => unawaited(
                              VoidProjectDetailScreen.editTask(context, task),
                            ),
                            onDelete: () => unawaited(
                              VoidProjectDetailScreen.deleteTask(context, task),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class VoidProjectListCard extends StatelessWidget {
  const VoidProjectListCard({
    super.key,
    required this.project,
    required this.taskCount,
    required this.focusSeconds,
    required this.onTap,
  });

  final VoidProject project;
  final int taskCount;
  final int focusSeconds;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: project.color.withValues(alpha: 0.35)),
            boxShadow: [
              BoxShadow(
                color: project.color.withValues(alpha: 0.1),
                blurRadius: 14,
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          project.emoji,
                          style: const TextStyle(fontSize: 22),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            project.title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withValues(alpha: 0.92),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      formatVoidTaskCountLabel(taskCount),
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.55),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formatFocusDuration(focusSeconds),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: project.color.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: project.color.withValues(alpha: 0.65),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class VoidProjectDetailScreen extends StatefulWidget {
  const VoidProjectDetailScreen({
    super.key,
    required this.projectId,
  });

  final String projectId;

  static Future<void> editTask(BuildContext context, VoidTask task) async {
    final draft = await showVoidTaskEditorDialog(
      context,
      initialTitle: task.title,
      initialDescription: task.description,
      initialIsCompleted: task.isCompleted,
      initialEstimatedSessions: task.estimatedSessions,
      initialProjectId: task.projectId,
      title: 'Редактировать задачу',
    );
    if (draft == null || !context.mounted) return;
    final success = await TasksService.instance.updateTask(
      task.copyWith(
        title: draft.title,
        description: draft.description,
        isCompleted: draft.isCompleted,
        estimatedSessions: draft.estimatedSessions,
        projectId: draft.projectId,
        clearProjectId: draft.projectId == null,
      ),
    );
    if (!context.mounted) return;
    if (!success) {
      showVoidSnackBar(context, 'Не удалось сохранить задачу');
    }
  }

  static Future<void> deleteTask(BuildContext context, VoidTask task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF12121A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: kVoidAccent.withValues(alpha: 0.3)),
        ),
        title: Text(
          'Удалить задачу?',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.95),
            fontWeight: FontWeight.w500,
          ),
        ),
        content: Text(
          '«${task.title}» будет удалена без возможности восстановления.',
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
            child: const Text(
              'Удалить',
              style: TextStyle(color: Color(0xFFF87171)),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final success = await TasksService.instance.deleteTask(task.id);
    if (!context.mounted) return;
    if (!success) {
      showVoidSnackBar(context, 'Не удалось удалить задачу');
    }
  }

  @override
  State<VoidProjectDetailScreen> createState() =>
      _VoidProjectDetailScreenState();
}

class _VoidProjectDetailScreenState extends State<VoidProjectDetailScreen> {
  @override
  void initState() {
    super.initState();
    TasksService.instance.scheduleLoad(force: true);
  }

  Future<void> _addTask(VoidProject project) async {
    final draft = await showVoidTaskEditorDialog(
      context,
      initialProjectId: project.id,
    );
    if (draft == null || !mounted) return;
    final created = await TasksService.instance.addTask(
      draft.title,
      projectId: draft.projectId ?? project.id,
      description: draft.description,
      isCompleted: draft.isCompleted,
      estimatedSessions: draft.estimatedSessions,
    );
    if (!mounted) return;
    if (created == null) {
      showVoidSnackBar(context, 'Не удалось создать задачу');
    }
  }

  Future<void> _editProject(VoidProject project) async {
    final draft = await showVoidProjectEditorDialog(
      context,
      initialTitle: project.title,
      initialColorValue: project.colorValue,
      initialIconName: project.iconName,
      title: 'Редактировать проект',
    );
    if (draft == null || !mounted) return;
    final success = await TasksService.instance.updateProject(
      project.copyWith(
        title: draft.title,
        colorValue: draft.colorValue,
        iconName: draft.iconName,
      ),
    );
    if (!mounted) return;
    if (!success) {
      showVoidSnackBar(context, 'Не удалось сохранить проект');
    }
  }

  Future<void> _deleteProject(VoidProject project) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF12121A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: kVoidAccent.withValues(alpha: 0.3)),
        ),
        title: Text(
          'Удалить проект?',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.95),
            fontWeight: FontWeight.w500,
          ),
        ),
        content: Text(
          '«${project.title}» будет удалён. Задачи останутся без проекта.',
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
            child: const Text(
              'Удалить',
              style: TextStyle(color: Color(0xFFF87171)),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final success = await TasksService.instance.deleteProject(project.id);
    if (!mounted) return;
    if (!success) {
      showVoidSnackBar(context, 'Не удалось удалить проект');
      return;
    }
    Navigator.pop(context);
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
        title: ListenableBuilder(
          listenable: TasksService.instance,
          builder: (context, _) {
            final project =
                TasksService.instance.projectById(widget.projectId);
            if (project == null) {
              return Text(
                'Проект',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.white.withValues(alpha: 0.95),
                ),
              );
            }
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(project.emoji, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    project.title,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w400,
                      color: Colors.white.withValues(alpha: 0.95),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        centerTitle: true,
        actions: [
          ListenableBuilder(
            listenable: TasksService.instance,
            builder: (context, _) {
              final project =
                  TasksService.instance.projectById(widget.projectId);
              if (project == null) return const SizedBox.shrink();
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: () => unawaited(_editProject(project)),
                    icon: Icon(
                      Icons.edit_outlined,
                      color: Colors.white.withValues(alpha: 0.55),
                      size: 20,
                    ),
                  ),
                  IconButton(
                    onPressed: () => unawaited(_deleteProject(project)),
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.white.withValues(alpha: 0.45),
                      size: 20,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      floatingActionButton: ListenableBuilder(
        listenable: TasksService.instance,
        builder: (context, _) {
          final project = TasksService.instance.projectById(widget.projectId);
          if (project == null) return const SizedBox.shrink();
          return FloatingActionButton(
            onPressed: () => unawaited(_addTask(project)),
            backgroundColor: kVoidAccent,
            child: const Icon(Icons.add_rounded, color: Colors.white),
          );
        },
      ),
      body: Stack(
        children: [
          const VoidAmbientGlow(center: Alignment(0, -0.55)),
          SafeArea(
            child: ListenableBuilder(
              listenable: TasksService.instance,
              builder: (context, _) {
                final store = TasksService.instance;
                final project = store.projectById(widget.projectId);
                if (project == null) {
                  return Center(
                    child: Text(
                      'Проект не найден',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                      ),
                    ),
                  );
                }

                final tasks = store.tasksForProject(project.id);
                final focusSeconds = store.projectFocusSeconds(project.id);

                return ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    m.paddingH,
                    m.gapM,
                    m.paddingH,
                    m.gapXL + 72,
                  ),
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: project.color.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: project.color.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            formatVoidTaskCountLabel(tasks.length),
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            formatFocusDuration(focusSeconds),
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w500,
                              color: project.color.withValues(alpha: 0.95),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: m.gapL),
                    if (tasks.isEmpty)
                      Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: m.gapL),
                          child: Text(
                            'Нет задач в проекте',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.4),
                            ),
                          ),
                        ),
                      )
                    else
                      ...tasks.map(
                        (task) => Padding(
                          padding: EdgeInsets.only(bottom: m.gapS),
                          child: VoidTaskCard(
                            task: task,
                            accent: project.color,
                            onToggleComplete: () {
                              unawaited(
                                TasksService.instance
                                    .toggleTaskCompleted(task.id),
                              );
                            },
                            onEdit: () => unawaited(
                              VoidProjectDetailScreen.editTask(context, task),
                            ),
                            onDelete: () => unawaited(
                              VoidProjectDetailScreen.deleteTask(context, task),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class VoidTaskCard extends StatelessWidget {
  const VoidTaskCard({
    super.key,
    required this.task,
    required this.onToggleComplete,
    required this.onEdit,
    required this.onDelete,
    this.projectTitle,
    this.accent,
  });

  final VoidTask task;
  final VoidCallback onToggleComplete;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final String? projectTitle;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final progressAccent = accent ?? kVoidAccent;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: task.isCompleted
              ? kVoidGoalComplete.withValues(alpha: 0.35)
              : progressAccent.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: onToggleComplete,
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.only(top: 2, right: 10),
                  child: Icon(
                    task.isCompleted
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 22,
                    color: task.isCompleted
                        ? kVoidGoalComplete
                        : Colors.white.withValues(alpha: 0.35),
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        decoration: task.isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                        color: task.isCompleted
                            ? Colors.white.withValues(alpha: 0.45)
                            : Colors.white.withValues(alpha: 0.92),
                      ),
                    ),
                    if (task.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        task.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.45),
                          height: 1.35,
                        ),
                      ),
                    ],
                    if (projectTitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        projectTitle!,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.38),
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: task.isCompleted
                                ? kVoidGoalComplete.withValues(alpha: 0.12)
                                : kVoidAccent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            task.statusLabel,
                            style: TextStyle(
                              fontSize: 10,
                              color: task.isCompleted
                                  ? kVoidGoalComplete
                                  : kVoidAccent.withValues(alpha: 0.85),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onEdit,
                icon: Icon(
                  Icons.edit_outlined,
                  size: 18,
                  color: Colors.white.withValues(alpha: 0.45),
                ),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
              IconButton(
                onPressed: onDelete,
                icon: Icon(
                  Icons.delete_outline_rounded,
                  size: 18,
                  color: Colors.white.withValues(alpha: 0.35),
                ),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
          const SizedBox(height: 12),
          VoidTaskSessionProgressSection(
            task: task,
            accent: task.isCompleted ? kVoidGoalComplete : progressAccent,
          ),
        ],
      ),
    );
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

class VoidWeeklyReviewAccessCard extends StatelessWidget {
  const VoidWeeklyReviewAccessCard({
    super.key,
    required this.reviewData,
    required this.onTap,
  });

  final VoidWeeklyReviewData reviewData;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final stats = reviewData.currentWeek;
    final subtitle = stats.sessionsCount == 0
        ? formatWeeklyReviewPeriod(stats.weekBounds)
        : '${stats.sessionsCount} ${_sessionsLabel(stats.sessionsCount)} · '
            '${formatFocusDuration(stats.totalFocusSeconds)}';

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
                  Icons.insights_rounded,
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
                      'Недельный обзор',
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

  static String _sessionsLabel(int count) {
    final mod10 = count % 10;
    final mod100 = count % 100;
    if (mod100 >= 11 && mod100 <= 14) return 'сессий';
    if (mod10 == 1) return 'сессия';
    if (mod10 >= 2 && mod10 <= 4) return 'сессии';
    return 'сессий';
  }
}

class VoidProductivityInsightsAccessCard extends StatelessWidget {
  const VoidProductivityInsightsAccessCard({
    super.key,
    required this.insights,
    required this.onTap,
  });

  final VoidProductivityInsights insights;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final subtitle = insights.hasData
        ? '${insights.sessionsCount} ${_sessionsLabel(insights.sessionsCount)} · '
            '${formatFocusDuration(insights.averageSessionDurationSeconds)} в среднем'
        : 'Завершите сессии для инсайтов';

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
                  Icons.psychology_rounded,
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
                      'Инсайты продуктивности',
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

  static String _sessionsLabel(int count) {
    final mod10 = count % 10;
    final mod100 = count % 100;
    if (mod100 >= 11 && mod100 <= 14) return 'сессий';
    if (mod10 == 1) return 'сессия';
    if (mod10 >= 2 && mod10 <= 4) return 'сессии';
    return 'сессий';
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
                      'Данные, резервное копирование и информация',
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

class VoidBackupRestoreScreen extends StatefulWidget {
  const VoidBackupRestoreScreen({super.key});

  @override
  State<VoidBackupRestoreScreen> createState() => _VoidBackupRestoreScreenState();
}

class _VoidBackupRestoreScreenState extends State<VoidBackupRestoreScreen> {
  final TextEditingController _importController = TextEditingController();
  bool _isExporting = false;
  bool _isImporting = false;

  @override
  void dispose() {
    _importController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF12121A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: (isError ? Colors.redAccent : kVoidAccent)
                .withValues(alpha: 0.25),
          ),
        ),
        content: Text(
          message,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.9)),
        ),
      ),
    );
  }

  Future<void> _exportBackup() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);
    try {
      final json = await StatsService.instance.exportBackup();
      await Clipboard.setData(ClipboardData(text: json));
      _showSnackBar('Резервная копия скопирована в буфер обмена');
    } catch (_) {
      _showSnackBar('Не удалось экспортировать данные', isError: true);
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) {
      _showSnackBar('Буфер обмена пуст', isError: true);
      return;
    }
    _importController.text = text;
    _importController.selection = TextSelection.collapsed(offset: text.length);
  }

  Future<void> _confirmImport() async {
    final raw = _importController.text.trim();
    if (raw.isEmpty) {
      _showSnackBar('Вставьте JSON резервной копии', isError: true);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF12121A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: kVoidAccent.withValues(alpha: 0.3)),
        ),
        title: Text(
          'Восстановить данные?',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.95),
            fontWeight: FontWeight.w500,
          ),
        ),
        content: Text(
          'Текущая статистика, сессии, достижения, задачи и проекты '
          'будут заменены данными из резервной копии.',
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
            child: const Text(
              'Восстановить',
              style: TextStyle(color: kVoidAccent),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isImporting = true);
    try {
      final result = await StatsService.instance.importBackup(raw);
      if (!mounted) return;
      if (result.success) {
        _showSnackBar(
          'Восстановлено: ${result.sessionsCount} сессий, '
          '${result.projectsCount} проектов, ${result.tasksCount} задач',
        );
        _importController.clear();
      } else {
        _showSnackBar(
          result.error ?? 'Не удалось восстановить данные',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
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
          'Резервное копирование',
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
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                m.paddingH,
                m.gapS,
                m.paddingH,
                m.gapL,
              ),
              children: [
                Text(
                  'Сохраните или восстановите все данные VOID в формате JSON.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: Colors.white.withValues(alpha: 0.45),
                  ),
                ),
                SizedBox(height: m.gapL),
                const VoidSettingsSectionHeader(title: 'Включает'),
                SizedBox(height: m.gapS),
                const _VoidBackupIncludesCard(),
                SizedBox(height: m.gapL),
                const VoidSettingsSectionHeader(title: 'Экспорт'),
                SizedBox(height: m.gapS),
                VoidSettingsOptionTile(
                  icon: Icons.file_upload_outlined,
                  title: _isExporting ? 'Экспорт...' : 'Экспортировать JSON',
                  subtitle: 'Скопировать резервную копию в буфер обмена',
                  onTap: _isExporting ? () {} : _exportBackup,
                ),
                SizedBox(height: m.gapL),
                const VoidSettingsSectionHeader(title: 'Импорт'),
                SizedBox(height: m.gapS),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: kVoidAccent.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'JSON резервной копии',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.45),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _importController,
                        minLines: 6,
                        maxLines: 10,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: Colors.white.withValues(alpha: 0.85),
                          fontFamily: 'monospace',
                        ),
                        decoration: InputDecoration(
                          hintText: 'Вставьте JSON...',
                          hintStyle: TextStyle(
                            color: Colors.white.withValues(alpha: 0.25),
                          ),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.03),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: kVoidAccent.withValues(alpha: 0.2),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: kVoidAccent.withValues(alpha: 0.2),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: kVoidAccent.withValues(alpha: 0.45),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _isImporting ? null : _pasteFromClipboard,
                              icon: Icon(
                                Icons.content_paste_rounded,
                                size: 18,
                                color: kVoidAccent.withValues(alpha: 0.85),
                              ),
                              label: Text(
                                'Вставить',
                                style: TextStyle(
                                  color: kVoidAccent.withValues(alpha: 0.9),
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color: kVoidAccent.withValues(alpha: 0.35),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _isImporting ? null : _confirmImport,
                              icon: _isImporting
                                  ? SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white.withValues(alpha: 0.9),
                                      ),
                                    )
                                  : Icon(
                                      Icons.restore_rounded,
                                      size: 18,
                                      color: Colors.white.withValues(alpha: 0.95),
                                    ),
                              label: Text(
                                _isImporting ? 'Импорт...' : 'Восстановить',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.95),
                                ),
                              ),
                              style: FilledButton.styleFrom(
                                backgroundColor:
                                    kVoidAccent.withValues(alpha: 0.85),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
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

class _VoidBackupIncludesCard extends StatelessWidget {
  const _VoidBackupIncludesCard();

  static const _items = [
    'Статистика',
    'Сессии',
    'Достижения',
    'Задачи',
    'Проекты',
  ];

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
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _items
            .map(
              (label) => Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: kVoidAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: kVoidAccent.withValues(alpha: 0.28),
                  ),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: kVoidAccent.withValues(alpha: 0.9),
                  ),
                ),
              ),
            )
            .toList(),
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
                  const VoidSettingsSectionHeader(title: 'Уведомления'),
                  SizedBox(height: m.gapS),
                  const VoidNotificationsSettingsSection(),
                  SizedBox(height: m.gapL),
                  const VoidSettingsSectionHeader(title: 'Данные'),
                  SizedBox(height: m.gapS),
                  VoidSettingsOptionTile(
                    icon: Icons.backup_rounded,
                    title: 'Резервное копирование',
                    subtitle: 'Экспорт и восстановление JSON',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => const VoidBackupRestoreScreen(),
                      ),
                    ),
                  ),
                  SizedBox(height: m.gapS),
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

class VoidNotificationsSettingsSection extends StatefulWidget {
  const VoidNotificationsSettingsSection({super.key});

  @override
  State<VoidNotificationsSettingsSection> createState() =>
      _VoidNotificationsSettingsSectionState();
}

class _VoidNotificationsSettingsSectionState
    extends State<VoidNotificationsSettingsSection> {
  @override
  void initState() {
    super.initState();
    unawaited(VoidNotificationService.instance.loadPrefs());
  }

  Future<void> _pickReminderTime() async {
    final service = VoidNotificationService.instance;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: service.hour, minute: service.minute),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: kVoidAccent,
              surface: Color(0xFF12121A),
              onSurface: Colors.white,
            ),
            dialogTheme: const DialogThemeData(
              backgroundColor: Color(0xFF12121A),
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (picked == null) return;
    await service.setReminderTime(
      newHour: picked.hour,
      newMinute: picked.minute,
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = VoidMetrics.of(context);

    return ListenableBuilder(
      listenable: VoidNotificationService.instance,
      builder: (context, _) {
        final service = VoidNotificationService.instance;
        final timeLabel = formatNotificationTime(service.hour, service.minute);

        return Column(
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => service.setEnabled(!service.enabled),
                borderRadius: BorderRadius.circular(14),
                child: Ink(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: service.enabled
                          ? kVoidAccent.withValues(alpha: 0.28)
                          : kVoidAccent.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: kVoidAccent.withValues(alpha: 0.12),
                          border: Border.all(
                            color: kVoidAccent.withValues(alpha: 0.28),
                          ),
                        ),
                        child: Icon(
                          Icons.notifications_active_outlined,
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
                              'Умные напоминания',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withValues(alpha: 0.92),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              service.enabled
                                  ? 'Пора сфокусироваться · серия под угрозой'
                                  : 'Напоминания отключены',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white.withValues(alpha: 0.45),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch.adaptive(
                        value: service.enabled,
                        onChanged: service.setEnabled,
                        activeThumbColor: kVoidAccent,
                        activeTrackColor: kVoidAccent.withValues(alpha: 0.45),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (service.enabled) ...[
              SizedBox(height: m.gapS),
              VoidSettingsOptionTile(
                icon: Icons.schedule_rounded,
                title: 'Время напоминания',
                subtitle:
                    '$timeLabel · если сегодня не было фокус-сессии',
                onTap: _pickReminderTime,
              ),
            ],
          ],
        );
      },
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

class VoidWeeklyReviewScreen extends StatefulWidget {
  const VoidWeeklyReviewScreen({super.key});

  @override
  State<VoidWeeklyReviewScreen> createState() => _VoidWeeklyReviewScreenState();
}

class _VoidWeeklyReviewScreenState extends State<VoidWeeklyReviewScreen> {
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
          'Недельный обзор',
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

                if (store.isLoading && !store.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: kVoidAccent,
                      strokeWidth: 2,
                    ),
                  );
                }

                final review = buildWeeklyReviewData(
                  sessionHistory: store.data.sessionHistory,
                );
                final stats = review.currentWeek;

                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    m.paddingH,
                    m.gapS,
                    m.paddingH,
                    m.gapL,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        formatWeeklyReviewPeriod(stats.weekBounds),
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.45),
                        ),
                      ),
                      SizedBox(height: m.gapM),
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: m.isCompact ? 18 : 22,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: kVoidAccent.withValues(alpha: 0.4),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: kVoidAccent.withValues(alpha: 0.14),
                              blurRadius: 24,
                            ),
                          ],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.auto_awesome_rounded,
                              size: 22,
                              color: kVoidAccent.withValues(alpha: 0.85),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                review.summary,
                                style: TextStyle(
                                  fontSize: m.isCompact ? 15 : 16,
                                  height: 1.45,
                                  fontWeight: FontWeight.w300,
                                  color: Colors.white.withValues(alpha: 0.92),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: m.gapL),
                      VoidStatCard(
                        label: 'Сессий за неделю',
                        value: '${stats.sessionsCount}',
                        prominent: true,
                      ),
                      SizedBox(height: m.gapM),
                      VoidStatCard(
                        label: 'Время в фокусе',
                        value: formatFocusDuration(stats.totalFocusSeconds),
                      ),
                      SizedBox(height: m.gapM),
                      VoidStatCard(
                        label: 'Средний фокус-счёт',
                        value: stats.sessionsCount == 0
                            ? '—'
                            : formatFocusScore(stats.averageFocusScore),
                      ),
                      SizedBox(height: m.gapM),
                      VoidStatCard(
                        label: 'Всего отвлечений',
                        value: '${stats.totalDistractions}',
                      ),
                      SizedBox(height: m.gapM),
                      VoidStatCard(
                        label: 'Лучший день',
                        value: stats.bestDayLabel,
                      ),
                      SizedBox(height: m.gapM),
                      VoidStatCard(
                        label: 'Самая длинная сессия',
                        value: stats.longestSessionSeconds == 0
                            ? '—'
                            : formatFocusDuration(stats.longestSessionSeconds),
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
}

class VoidProductivityInsightsScreen extends StatefulWidget {
  const VoidProductivityInsightsScreen({super.key});

  @override
  State<VoidProductivityInsightsScreen> createState() =>
      _VoidProductivityInsightsScreenState();
}

class _VoidProductivityInsightsScreenState
    extends State<VoidProductivityInsightsScreen> {
  @override
  void initState() {
    super.initState();
    StatsService.instance.scheduleLoad(force: true);
    TasksService.instance.scheduleLoad(force: true);
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
          'Инсайты продуктивности',
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
              listenable: Listenable.merge([
                StatsService.instance,
                TasksService.instance,
              ]),
              builder: (context, _) {
                final store = StatsService.instance;
                final tasksStore = TasksService.instance;

                if (store.isLoading && !store.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: kVoidAccent,
                      strokeWidth: 2,
                    ),
                  );
                }

                final insights = buildProductivityInsights(
                  sessionHistory: store.data.sessionHistory,
                  tasks: tasksStore.tasks,
                  projects: tasksStore.projects,
                );

                if (!insights.hasData) {
                  return Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: m.paddingH),
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
                              Icons.psychology_outlined,
                              size: 40,
                              color: kVoidAccent.withValues(alpha: 0.6),
                            ),
                            SizedBox(height: m.gapM),
                            Text(
                              'Пока нет данных',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w400,
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                            ),
                            SizedBox(height: m.gapS),
                            Text(
                              'Завершите фокус-сессии, чтобы увидеть '
                              'инсайты по проектам и задачам',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.45,
                                color: Colors.white.withValues(alpha: 0.45),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    m.paddingH,
                    m.gapS,
                    m.paddingH,
                    m.gapL,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${insights.sessionsCount} '
                        '${_VoidProductivityInsightsScreenState._sessionsLabel(insights.sessionsCount)} '
                        'проанализировано',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.45),
                        ),
                      ),
                      SizedBox(height: m.gapL),
                      VoidStatCard(
                        label: 'Самый продуктивный проект',
                        value: insights.mostFocusedProjectLabel,
                        prominent: true,
                      ),
                      SizedBox(height: m.gapM),
                      VoidStatCard(
                        label: 'Самая продуктивная задача',
                        value: insights.mostFocusedTaskLabel,
                      ),
                      SizedBox(height: m.gapM),
                      VoidStatCard(
                        label: 'Общее время по проектам',
                        value: insights.totalProjectFocusLabel,
                      ),
                      SizedBox(height: m.gapM),
                      VoidStatCard(
                        label: 'Средняя длительность сессии',
                        value: insights.averageSessionDurationLabel,
                      ),
                      SizedBox(height: m.gapM),
                      VoidStatCard(
                        label: 'Лучший день фокуса',
                        value: insights.bestFocusDayLabel,
                      ),
                      SizedBox(height: m.gapM),
                      VoidStatCard(
                        label: 'Лучшая неделя фокуса',
                        value: insights.bestFocusWeekLabel,
                      ),
                      SizedBox(height: m.gapL),
                      VoidFocusBreakdownListCard(
                        title: 'Фокус по проектам',
                        entries: insights.projectBreakdown,
                      ),
                      SizedBox(height: m.gapM),
                      VoidFocusBreakdownListCard(
                        title: 'Фокус по задачам',
                        entries: insights.taskBreakdown,
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

  static String _sessionsLabel(int count) {
    final mod10 = count % 10;
    final mod100 = count % 100;
    if (mod100 >= 11 && mod100 <= 14) return 'сессий';
    if (mod10 == 1) return 'сессия';
    if (mod10 >= 2 && mod10 <= 4) return 'сессии';
    return 'сессий';
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
          if (session.taskTitle != null) ...[
            const SizedBox(height: 6),
            Text(
              session.taskTitle!,
              style: TextStyle(
                fontSize: 12,
                color: kVoidAccent.withValues(alpha: 0.85),
              ),
            ),
          ],
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

class VoidFocusModeStatsCard extends StatelessWidget {
  const VoidFocusModeStatsCard({super.key, required this.stats});

  final VoidFocusModeStats stats;

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
            color: kVoidAccent.withValues(alpha: 0.08),
            blurRadius: 14,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Режимы фокуса',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.45),
            ),
          ),
          const SizedBox(height: 14),
          for (var index = 0; index < stats.entries.length; index++) ...[
            if (index > 0) const SizedBox(height: 12),
            _VoidFocusModeStatRow(entry: stats.entries[index]),
          ],
        ],
      ),
    );
  }
}

class _VoidFocusModeStatRow extends StatelessWidget {
  const _VoidFocusModeStatRow({required this.entry});

  final VoidFocusModeStatEntry entry;

  @override
  Widget build(BuildContext context) {
    final hasData = entry.sessions > 0 || entry.focusSeconds > 0;
    final sessionsLabel = _sessionsLabel(entry.sessions);

    return Row(
      children: [
        Container(
          width: 52,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: hasData
                ? kVoidAccent.withValues(alpha: 0.14)
                : Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: hasData
                  ? kVoidAccent.withValues(alpha: 0.35)
                  : Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Text(
            '${entry.minutes}м',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: hasData
                  ? kVoidAccent
                  : Colors.white.withValues(alpha: 0.45),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.mode.recommendation,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                hasData
                    ? '${entry.sessions} $sessionsLabel · '
                        '${formatFocusDuration(entry.focusSeconds)}'
                    : 'Пока нет сессий',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.45),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _sessionsLabel(int count) {
    final mod10 = count % 10;
    final mod100 = count % 100;
    if (mod100 >= 11 && mod100 <= 14) return 'сессий';
    if (mod10 == 1) return 'сессия';
    if (mod10 >= 2 && mod10 <= 4) return 'сессии';
    return 'сессий';
  }
}

class VoidDeepWorkModeSelector extends StatelessWidget {
  const VoidDeepWorkModeSelector({
    super.key,
    required this.selectedMinutes,
    required this.onSelected,
    this.enabled = true,
  });

  final int selectedMinutes;
  final ValueChanged<int> onSelected;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final selectedMode = VoidDeepWorkMode.resolve(selectedMinutes);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Режимы фокуса',
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.45),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (var index = 0; index < VoidDeepWorkMode.options.length; index++) ...[
              if (index > 0) const SizedBox(width: 8),
              Expanded(
                child: _VoidDeepWorkModeOption(
                  mode: VoidDeepWorkMode.options[index],
                  selected: VoidDeepWorkMode.options[index].minutes ==
                      selectedMinutes,
                  enabled: enabled,
                  onTap: () =>
                      onSelected(VoidDeepWorkMode.options[index].minutes),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        Text(
          '${selectedMode.durationLabel} = ${selectedMode.recommendation}',
          style: TextStyle(
            fontSize: 12,
            color: kVoidAccent.withValues(alpha: 0.85),
          ),
        ),
      ],
    );
  }
}

class _VoidDeepWorkModeOption extends StatelessWidget {
  const _VoidDeepWorkModeOption({
    required this.mode,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final VoidDeepWorkMode mode;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? kVoidAccent.withValues(alpha: 0.14)
                : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? kVoidAccent.withValues(alpha: 0.45)
                  : kVoidAccent.withValues(alpha: 0.15),
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: kVoidAccent.withValues(alpha: 0.12),
                      blurRadius: 16,
                    ),
                  ]
                : null,
          ),
          child: Column(
            children: [
              Text(
                mode.durationLabel,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: selected
                      ? kVoidAccent
                      : Colors.white.withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                mode.recommendation,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  height: 1.2,
                  color: Colors.white.withValues(alpha: selected ? 0.7 : 0.42),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class VoidFocusTab extends StatefulWidget {
  const VoidFocusTab({
    super.key,
    this.initialTaskSelection,
    this.onTaskSelectionChanged,
  });

  final VoidTaskSelection? initialTaskSelection;
  final ValueChanged<VoidTaskSelection?>? onTaskSelectionChanged;

  @override
  State<VoidFocusTab> createState() => _VoidFocusTabState();
}

class _VoidFocusTabState extends State<VoidFocusTab> {
  int _sessionMinutes = _kDefaultDeepWorkModeMinutes;
  int _remainingSeconds = _kDefaultDeepWorkModeMinutes * 60;

  int get _totalSeconds => _sessionMinutes * 60;
  int _sessionDistractions = 0;
  int _distractionFeedbackTick = 0;
  int _distractionCooldownSeconds = 0;
  bool _isRunning = false;
  bool _isPaused = false;
  bool _isCompleted = false;
  bool _sessionSaved = false;
  VoidTaskSelection? _taskSelection;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _taskSelection = widget.initialTaskSelection;
    _applyDeepWorkMode(StatsService.instance.data.deepWorkModeMinutes);
    StatsService.instance.addListener(_onStatsChanged);
  }

  void _onStatsChanged() {
    if (_isRunning || _isCompleted) return;
    final minutes = StatsService.instance.data.deepWorkModeMinutes;
    if (minutes != _sessionMinutes) {
      setState(() => _applyDeepWorkMode(minutes));
    }
  }

  void _applyDeepWorkMode(int minutes) {
    _sessionMinutes = VoidDeepWorkMode.resolve(minutes).minutes;
    _remainingSeconds = _totalSeconds;
  }

  Future<void> _selectDeepWorkMode(int minutes) async {
    if (_isRunning || _isCompleted) return;
    if (_sessionMinutes == minutes) return;
    await StatsService.instance.setDeepWorkModeMinutes(minutes);
    if (!mounted) return;
    setState(() => _applyDeepWorkMode(minutes));
  }

  @override
  void didUpdateWidget(VoidFocusTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialTaskSelection != oldWidget.initialTaskSelection &&
        !_isRunning &&
        !_isCompleted) {
      _taskSelection = widget.initialTaskSelection;
    }
  }

  @override
  void dispose() {
    StatsService.instance.removeListener(_onStatsChanged);
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
      taskId: _taskSelection?.taskId,
      taskTitle: _taskSelection?.taskTitle,
      focusModeMinutes: _sessionMinutes,
    );

    if (mounted) {
      await _showCompletionDialog(
        elapsedSeconds: elapsedSeconds,
        focusSeconds: focusSeconds,
        distractions: distractions,
        xp: xp,
        focusScore: computeFocusScore(distractions),
        taskSelection: _taskSelection,
      );
    }

    if (mounted && await StatsService.instance.shouldPromptFirstLaunchFeedback()) {
      await showVoidFirstLaunchFeedbackDialog(context);
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

  Future<void> _ensureTaskSelected() async {
    if (_taskSelection != null) return;
    final selection = await showVoidTaskPicker(context);
    if (selection == null || !mounted) return;
    setState(() => _taskSelection = selection);
    widget.onTaskSelectionChanged?.call(selection);
  }

  Future<void> _changeTaskSelection() async {
    if (_isRunning || _isCompleted) return;
    final selection = await showVoidTaskPicker(context);
    if (selection == null || !mounted) return;
    setState(() => _taskSelection = selection);
    widget.onTaskSelectionChanged?.call(selection);
  }

  Future<void> _startSession() async {
    if (_isRunning || _isCompleted) return;
    await _ensureTaskSelected();
    if (_taskSelection == null || !mounted) return;
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
    required int focusSeconds,
    required int distractions,
    required int xp,
    required int focusScore,
    required VoidTaskSelection? taskSelection,
  }) async {
    final stats = StatsService.instance.data;

    await showVoidSessionCompleteDialog(
      context: context,
      data: VoidSessionCompleteData(
        elapsedSeconds: elapsedSeconds,
        focusScore: focusScore,
        xpEarned: xp,
        currentStreak: stats.currentStreak,
        todayFocusSeconds: stats.todayFocusSeconds,
        dailyGoalMinutes: stats.dailyGoalMinutes,
        dailyGoalProgress: stats.dailyGoalProgress,
        isDailyGoalCompleted: stats.isDailyGoalCompleted,
        taskSelection: taskSelection,
        focusSecondsOnTask: focusSeconds,
      ),
      onDone: _resetSession,
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
              if (!_isRunning && !_isCompleted) ...[
                SizedBox(height: m.gapM),
                VoidDeepWorkModeSelector(
                  selectedMinutes: _sessionMinutes,
                  onSelected: (minutes) =>
                      unawaited(_selectDeepWorkMode(minutes)),
                ),
                SizedBox(height: m.gapM),
                _VoidFocusTaskChip(
                  taskSelection: _taskSelection,
                  onTap: _changeTaskSelection,
                ),
              ] else if (_taskSelection?.hasTask == true) ...[
                SizedBox(height: m.gapS),
                Text(
                  _taskSelection!.taskTitle!,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.55),
                  ),
                ),
              ],
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
                      onPressed: _isRunning || _isCompleted
                          ? null
                          : () => unawaited(_startSession()),
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

class _VoidFocusTaskChip extends StatelessWidget {
  const _VoidFocusTaskChip({
    required this.taskSelection,
    required this.onTap,
  });

  final VoidTaskSelection? taskSelection;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasTask = taskSelection?.hasTask == true;
    final label = hasTask ? taskSelection!.taskTitle! : 'Задача не выбрана';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kVoidAccent.withValues(alpha: 0.22)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                hasTask ? Icons.task_alt_rounded : Icons.playlist_add_check_rounded,
                size: 16,
                color: kVoidAccent.withValues(alpha: 0.85),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.72),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.expand_more_rounded,
                size: 16,
                color: Colors.white.withValues(alpha: 0.35),
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

class VoidWeeklyGoalsCard extends StatefulWidget {
  const VoidWeeklyGoalsCard({
    super.key,
    required this.goalsData,
  });

  final VoidWeeklyGoalsData goalsData;

  @override
  State<VoidWeeklyGoalsCard> createState() => _VoidWeeklyGoalsCardState();
}

class _VoidWeeklyGoalsCardState extends State<VoidWeeklyGoalsCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _progressController;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _progressAnimation = CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeOutCubic,
    );
    _progressController.forward();
  }

  @override
  void didUpdateWidget(VoidWeeklyGoalsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.goalsData.completedCount != widget.goalsData.completedCount ||
        oldWidget.goalsData.goals.length != widget.goalsData.goals.length) {
      _progressController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final goalsData = widget.goalsData;
    final completedGoals =
        goalsData.goals.where((goal) => goal.isCompleted).length;

    return AnimatedBuilder(
      animation: _progressAnimation,
      builder: (context, child) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: kVoidAccent.withValues(alpha: 0.24)),
            boxShadow: [
              BoxShadow(
                color: kVoidAccent.withValues(alpha: 0.08),
                blurRadius: 16,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.flag_rounded,
                    size: 16,
                    color: kVoidAccent.withValues(alpha: 0.85),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Цели недели',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.45),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '$completedGoals/${goalsData.goals.length}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: kVoidAccent.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                formatWeeklyReviewPeriod(goalsData.weekBounds),
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.38),
                ),
              ),
              const SizedBox(height: 14),
              for (var index = 0; index < goalsData.goals.length; index++) ...[
                if (index > 0) const SizedBox(height: 12),
                _VoidWeeklyGoalRow(
                  goal: goalsData.goals[index],
                  animationValue: _progressAnimation.value,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _VoidWeeklyGoalRow extends StatelessWidget {
  const _VoidWeeklyGoalRow({
    required this.goal,
    required this.animationValue,
  });

  final VoidWeeklyGoalProgress goal;
  final double animationValue;

  @override
  Widget build(BuildContext context) {
    final accent = goal.isCompleted ? kVoidGoalComplete : kVoidAccent;
    final animatedProgress = (goal.progress * animationValue).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                goal.title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: goal.isCompleted
                      ? kVoidGoalComplete.withValues(alpha: 0.95)
                      : Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ),
            if (goal.isRewardClaimed)
              Icon(
                Icons.check_circle_rounded,
                size: 16,
                color: kVoidGoalComplete.withValues(alpha: 0.9),
              )
            else
              Text(
                '+${goal.xpReward} XP',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: accent.withValues(alpha: 0.85),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          goal.progressLabel,
          style: TextStyle(
            fontSize: 11,
            color: Colors.white.withValues(alpha: 0.42),
          ),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: animatedProgress,
            minHeight: 6,
            backgroundColor: Colors.white.withValues(alpha: 0.08),
            valueColor: AlwaysStoppedAnimation(accent),
          ),
        ),
      ],
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
    required this.levelTitle,
    required this.totalXp,
    required this.xpInLevel,
    required this.progress,
  });

  final int level;
  final String levelTitle;
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$level',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w300,
                  color: Colors.white.withValues(alpha: 0.95),
                ),
              ),
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  levelTitle,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: kVoidAccent.withValues(alpha: 0.8),
                  ),
                ),
              ),
            ],
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

class VoidPersonalRecordsCard extends StatelessWidget {
  const VoidPersonalRecordsCard({
    super.key,
    required this.records,
  });

  final VoidPersonalRecords records;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kVoidAccent.withValues(alpha: 0.22)),
        boxShadow: records.hasAnyRecord
            ? [
                BoxShadow(
                  color: kVoidAccent.withValues(alpha: 0.08),
                  blurRadius: 16,
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: kVoidAccent.withValues(alpha: 0.14),
                  border: Border.all(color: kVoidAccent.withValues(alpha: 0.3)),
                ),
                child: Icon(
                  Icons.emoji_events_rounded,
                  size: 18,
                  color: kVoidAccent.withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Личные рекорды',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.92),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _VoidPersonalRecordRow(
            label: 'Самая длинная сессия',
            value: formatPersonalRecordDuration(records.longestSessionSeconds),
          ),
          const SizedBox(height: 10),
          _VoidPersonalRecordRow(
            label: 'Лучший фокус-счёт',
            value: formatPersonalRecordScore(records.bestFocusScore),
            accent: records.bestFocusScore >= 90,
          ),
          const SizedBox(height: 10),
          _VoidPersonalRecordRow(
            label: 'Сессий за день',
            value: formatPersonalRecordCount(records.mostSessionsInDay),
          ),
          const SizedBox(height: 10),
          _VoidPersonalRecordRow(
            label: 'Лучшая серия',
            value: records.longestStreak > 0
                ? '${records.longestStreak} ${_streakDaysLabel(records.longestStreak)}'
                : '—',
          ),
          const SizedBox(height: 10),
          _VoidPersonalRecordRow(
            label: 'Фокуса за день',
            value: formatPersonalRecordDuration(
              records.mostFocusTimeInDaySeconds,
            ),
          ),
        ],
      ),
    );
  }

  static String _streakDaysLabel(int count) {
    final mod10 = count % 10;
    final mod100 = count % 100;
    if (mod100 >= 11 && mod100 <= 14) return 'дней';
    if (mod10 == 1) return 'день';
    if (mod10 >= 2 && mod10 <= 4) return 'дня';
    return 'дней';
  }
}

class _VoidPersonalRecordRow extends StatelessWidget {
  const _VoidPersonalRecordRow({
    required this.label,
    required this.value,
    this.accent = false,
  });

  final String label;
  final String value;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.45),
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: accent
                ? kVoidAccent
                : Colors.white.withValues(alpha: 0.92),
          ),
        ),
      ],
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
