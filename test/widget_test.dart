import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:void_app/main.dart';

String _todayActivityKey() {
  final now = DateTime.now();
  final year = now.year.toString().padLeft(4, '0');
  final month = now.month.toString().padLeft(2, '0');
  final day = now.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

String _activityKeyFor(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

Map<String, int> _consecutiveActivity({
  required int streakDays,
  int secondsPerDay = 600,
}) {
  final activity = <String, int>{};
  final today = DateTime.now();
  for (var index = 0; index < streakDays; index++) {
    final date = DateTime(today.year, today.month, today.day)
        .subtract(Duration(days: index));
    activity[_activityKeyFor(date)] = secondsPerDay;
  }
  return activity;
}

Future<void> _confirmTaskPicker(
  WidgetTester tester, {
  String? taskTitle,
}) async {
  expect(
    find.text('Сессия будет привязана к выбранной задаче'),
    findsOneWidget,
  );
  if (taskTitle != null) {
    await tester.tap(find.text(taskTitle).last);
    await tester.pumpAndSettle();
  }
  await tester.tap(find.text('Продолжить'));
  await tester.pumpAndSettle();
}

Future<void> _openFocusFromHome(WidgetTester tester) async {
  await tester.tap(find.text('Начать сессию'));
  await tester.pumpAndSettle();
  await _confirmTaskPicker(tester);
}

Future<void> _dismissSessionCompleteDialog(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Готово'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Готово'));
  await tester.pumpAndSettle();
}

Future<void> _startFocusSession(WidgetTester tester, {String? taskTitle}) async {
  await tester.tap(find.text('Старт'));
  await tester.pumpAndSettle();
  if (find
      .text('Сессия будет привязана к выбранной задаче')
      .evaluate()
      .isNotEmpty) {
    await _confirmTaskPicker(tester, taskTitle: taskTitle);
    await tester.tap(find.text('Старт'));
    await tester.pumpAndSettle();
  }
}

String _currentWeekKey() {
  final monday = weekBoundsContaining(DateTime.now()).start;
  return _activityKeyFor(monday);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'completedSessions': 8,
      'totalFocusMinutes': 200,
      'totalDistractions': 16,
      'session_distractions_history': '[2,2,2,2,2,2,2,2]',
      'currentStreak': 5,
      'bestStreak': 5,
      'last_active_date': _todayActivityKey(),
      'daily_activity': jsonEncode(_consecutiveActivity(streakDays: 5)),
      'focus_data_uses_seconds': true,
      'totalFocusSeconds': 12000,
      'weekly_goals_week_key': _currentWeekKey(),
      'weekly_goals_claimed': jsonEncode([
        kVoidWeeklyGoalFocusId,
        kVoidWeeklyGoalSessionsId,
        kVoidWeeklyGoalStreakId,
      ]),
    });
    await StatsService.instance.initialize(force: true);
    await StatsService.instance.load(force: true);
    await TasksService.instance.initialize(force: true);
    await TasksService.instance.load(force: true);
  });

  test('buildAchievements unlocks based on stats', () {
    final locked = buildAchievements(
      completedSessions: 0,
      totalFocusSeconds: 0,
      currentStreak: 0,
      preventedDistractionMinutes: 0,
      dailyGoalAchieved: false,
    );
    expect(locked.every((achievement) => !achievement.isUnlocked), isTrue);
    expect(locked.map((achievement) => achievement.title), contains('Первая сессия'));
    expect(
      locked.map((achievement) => achievement.title),
      contains('Цель дня выполнена'),
    );

    final unlocked = buildAchievements(
      completedSessions: 10,
      totalFocusSeconds: 3600,
      currentStreak: 7,
      preventedDistractionMinutes: 100,
      dailyGoalAchieved: true,
    );
    expect(unlocked.every((achievement) => achievement.isUnlocked), isTrue);
    expect(unlocked.length, 7);
  });

  test('session history sync rebuilds all completed sessions', () async {
    SharedPreferences.setMockInitialValues({
      'completedSessions': 11,
      'totalFocusSeconds': 6600,
      'totalDistractions': 22,
      'session_distractions_history': '[2,2,2,2,2,2,2,2,2,2,2]',
      'focus_data_uses_seconds': true,
    });
    await StatsService.instance.initialize(force: true);
    await StatsService.instance.load(force: true);

    expect(StatsService.instance.data.completedSessions, 11);
    expect(StatsService.instance.data.sessionHistory.length, 11);
    expect(
      StatsService.instance.data.sessionHistory.first.focusScore,
      94,
    );
  });

  test('focus calendar resolves day status from activity', () {
    expect(
      resolveFocusDayStatus(focusSeconds: 0, goalMinutes: 60),
      VoidFocusDayStatus.none,
    );
    expect(
      resolveFocusDayStatus(focusSeconds: 900, goalMinutes: 60),
      VoidFocusDayStatus.partial,
    );
    expect(
      resolveFocusDayStatus(focusSeconds: 3600, goalMinutes: 60),
      VoidFocusDayStatus.completed,
    );
    expect(StatsService.instance.data.last30Days.length, 30);
  });

  test('first launch feedback appears after three completed sessions', () {
    expect(
      shouldShowFirstLaunchFeedback(
        completedSessions: 2,
        alreadyShown: false,
      ),
      isFalse,
    );
    expect(
      shouldShowFirstLaunchFeedback(
        completedSessions: 3,
        alreadyShown: false,
      ),
      isTrue,
    );
    expect(
      shouldShowFirstLaunchFeedback(
        completedSessions: 3,
        alreadyShown: true,
      ),
      isFalse,
    );
  });

  test('smart notifications schedule only without focus today', () {
    expect(
      shouldScheduleDailyReminder(
        todayFocusSeconds: 0,
        todaySessions: 0,
      ),
      isTrue,
    );
    expect(
      shouldScheduleDailyReminder(
        todayFocusSeconds: 600,
        todaySessions: 1,
      ),
      isFalse,
    );
    expect(
      shouldScheduleStreakWarning(
        currentStreak: 5,
        todayFocusSeconds: 0,
        todaySessions: 0,
      ),
      isTrue,
    );
    expect(
      shouldScheduleStreakWarning(
        currentStreak: 0,
        todayFocusSeconds: 0,
        todaySessions: 0,
      ),
      isFalse,
    );
    expect(
      computeStreakWarningTime(reminderHour: 19, reminderMinute: 0),
      (hour: 22, minute: 0),
    );
    expect(
      computeStreakWarningTime(reminderHour: 9, reminderMinute: 30),
      (hour: 20, minute: 0),
    );
    expect(formatNotificationTime(9, 5), '09:05');
    expect(VoidNotificationService.instance.hour, kDefaultNotificationHour);
  });

  test('streak continues with daily focus and resets after missed day', () {
    final today = DateTime.now();
    final todayKey = _activityKeyFor(
      DateTime(today.year, today.month, today.day),
    );
    final yesterday = today.subtract(const Duration(days: 1));
    final yesterdayKey = _activityKeyFor(
      DateTime(yesterday.year, yesterday.month, yesterday.day),
    );

    expect(
      computeCurrentStreakFromActivity({
        todayKey: 600,
        yesterdayKey: 900,
      }),
      2,
    );
    expect(
      computeCurrentStreakFromActivity({
        yesterdayKey: 900,
      }),
      1,
    );
    expect(
      computeCurrentStreakFromActivity({
        '2026-01-01': 600,
        '2026-01-03': 600,
      }),
      0,
    );
    expect(
      computeBestStreakFromActivity({
        '2026-01-01': 600,
        '2026-01-02': 600,
        '2026-01-04': 600,
        '2026-01-05': 600,
      }),
      2,
    );
    expect(StatsService.instance.data.currentStreak, 5);
    expect(StatsService.instance.data.bestStreak, 5);
  });

  test('calendar month stats and longest streak use last 30 days', () {
    final days = [
      VoidDayActivity(
        date: DateTime(2026, 6, 1),
        focusSeconds: 600,
        sessionsCount: 1,
        distractions: 2,
        averageFocusScore: 94,
      ),
      VoidDayActivity(
        date: DateTime(2026, 6, 2),
        focusSeconds: 1200,
        sessionsCount: 2,
        distractions: 0,
        averageFocusScore: 100,
      ),
      VoidDayActivity(date: DateTime(2026, 6, 3), focusSeconds: 0),
      VoidDayActivity(
        date: DateTime(2026, 6, 4),
        focusSeconds: 900,
        sessionsCount: 1,
        distractions: 1,
        averageFocusScore: 97,
      ),
    ];

    final stats = VoidCalendarMonthStats.fromDays(days);
    expect(stats.activeDays, 3);
    expect(stats.totalFocusSeconds, 2700);
    expect(stats.longestStreak, 2);
    expect(computeLongestActiveStreak(days), 2);
  });

  test('xp and level follow focus minute rules', () {
    expect(computeSessionXp(60, 0), 1);
    expect(computeSessionXp(21, 0), 0);
    expect(computeTotalXp(12000), 200);
    expect(computeLevel(0), 1);
    expect(computeLevel(99), 1);
    expect(computeLevel(100), 2);
    expect(computeLevel(250), 3);
    expect(computeXpInCurrentLevel(250), 50);
    expect(formatLevelXpProgress(50), '50 / 100 XP');
    expect(StatsService.instance.data.totalXp, 200);
    expect(StatsService.instance.data.level, 3);
    expect(StatsService.instance.data.xpInCurrentLevel, 0);
    expect(StatsService.instance.data.levelTitle, 'Новичок');
  });

  test('level titles resolve from milestone tiers', () {
    expect(resolveLevelTitle(1), 'Новичок');
    expect(resolveLevelTitle(4), 'Новичок');
    expect(resolveLevelTitle(5), 'Сосредоточенный');
    expect(resolveLevelTitle(9), 'Сосредоточенный');
    expect(resolveLevelTitle(10), 'Мастер фокуса');
    expect(resolveLevelTitle(24), 'Мастер фокуса');
    expect(resolveLevelTitle(25), 'Архитектор внимания');
    expect(resolveLevelTitle(49), 'Архитектор внимания');
    expect(resolveLevelTitle(50), 'VOID Master');
    expect(resolveLevelTitle(99), 'VOID Master');
    expect(resolveLevelTitle(0), 'Новичок');
  });

  test('buildWeeklyGoalsProgress tracks focus sessions and streak', () {
    final reference = DateTime(2026, 6, 4);
    final monday = weekBoundsContaining(reference).start;
    final activity = {
      _activityKeyFor(monday): VoidDayActivity(
        date: monday,
        focusSeconds: 3600,
      ),
      _activityKeyFor(monday.add(const Duration(days: 1))): VoidDayActivity(
        date: monday.add(const Duration(days: 1)),
        focusSeconds: 3600,
      ),
      _activityKeyFor(monday.add(const Duration(days: 2))): VoidDayActivity(
        date: monday.add(const Duration(days: 2)),
        focusSeconds: 3600,
      ),
    };
    final history = List.generate(
      12,
      (index) => VoidSessionRecord(
        completedAt: monday.add(Duration(hours: index + 1)),
        focusSeconds: 900,
        distractions: 0,
        focusScore: 100,
        xp: 15,
      ),
    );

    final goals = buildWeeklyGoalsProgress(
      sessionHistory: history,
      activity: activity,
      claimedIds: const {},
      referenceDate: reference,
      weeklySessionsCount: 12,
    );

    expect(goals.length, 3);
    expect(goals[0].title, '5 часов фокуса');
    expect(goals[0].current, 10800);
    expect(goals[1].current, 12);
    expect(goals[2].current, 3);
    expect(goals[2].isCompleted, isTrue);
    expect(
      goals[0].progressLabel,
      contains('3ч'),
    );
  });

  test('weekly goals award bonus XP once when session target reached', () async {
    SharedPreferences.setMockInitialValues({'focus_data_uses_seconds': true});
    await StatsService.instance.initialize(force: true);

    for (var index = 0; index < 20; index++) {
      await StatsService.instance.completeSession(focusSeconds: 60);
    }
    await StatsService.instance.load(force: true);

    final sessionsGoal = StatsService.instance.data.weeklyGoals.goals
        .firstWhere((goal) => goal.id == kVoidWeeklyGoalSessionsId);
    expect(sessionsGoal.isCompleted, isTrue);
    expect(sessionsGoal.isRewardClaimed, isTrue);
    expect(StatsService.instance.data.bonusXp, kVoidWeeklyGoalSessionsXp);

    final bonusBefore = StatsService.instance.data.bonusXp;
    await StatsService.instance.completeSession(focusSeconds: 60);
    await StatsService.instance.load(force: true);
    expect(StatsService.instance.data.bonusXp, bonusBefore);
  });

  test('buildPersonalRecords derives records from history and activity', () {
    final today = DateTime.now();
    final todayKey = _activityKeyFor(today);
    final yesterday = today.subtract(const Duration(days: 1));
    final yesterdayKey = _activityKeyFor(yesterday);

    final records = buildPersonalRecords(
      sessionHistory: [
        VoidSessionRecord(
          completedAt: DateTime(today.year, today.month, today.day, 10),
          focusSeconds: 5400,
          distractions: 0,
          focusScore: 100,
          xp: 90,
        ),
        VoidSessionRecord(
          completedAt: DateTime(today.year, today.month, today.day, 12),
          focusSeconds: 1800,
          distractions: 2,
          focusScore: 94,
          xp: 30,
        ),
        VoidSessionRecord(
          completedAt: DateTime(
            yesterday.year,
            yesterday.month,
            yesterday.day,
            9,
          ),
          focusSeconds: 900,
          distractions: 5,
          focusScore: 85,
          xp: 15,
        ),
      ],
      activity: {
        todayKey: VoidDayActivity(
          date: today,
          focusSeconds: 7200,
        ),
        yesterdayKey: VoidDayActivity(
          date: yesterday,
          focusSeconds: 900,
        ),
      },
      bestStreak: 5,
    );

    expect(records.longestSessionSeconds, 5400);
    expect(records.bestFocusScore, 100);
    expect(records.mostSessionsInDay, 2);
    expect(records.longestStreak, 5);
    expect(records.mostFocusTimeInDaySeconds, 7200);
    expect(formatPersonalRecordDuration(records.longestSessionSeconds), '1ч 30м');
    expect(formatPersonalRecordDuration(0), '—');
  });

  test('VoidDeepWorkMode resolves focus recommendations', () {
    expect(VoidDeepWorkMode.light.recommendation, 'Light Focus');
    expect(VoidDeepWorkMode.deep.recommendation, 'Deep Focus');
    expect(VoidDeepWorkMode.elite.recommendation, 'Elite Focus');
    expect(VoidDeepWorkMode.forMinutes(50)?.minutes, 50);
    expect(VoidDeepWorkMode.resolve(90).recommendation, 'Elite Focus');
    expect(VoidDeepWorkMode.resolve(15).minutes, 25);
  });

  test('buildFocusModeStatsFromSessions groups by focus mode', () {
    final stats = buildFocusModeStatsFromSessions([
      VoidSessionRecord(
        completedAt: DateTime(2026, 6, 1, 10),
        focusSeconds: 1500,
        distractions: 0,
        focusScore: 100,
        xp: 25,
        focusModeMinutes: 25,
      ),
      VoidSessionRecord(
        completedAt: DateTime(2026, 6, 2, 10),
        focusSeconds: 3000,
        distractions: 1,
        focusScore: 97,
        xp: 50,
        focusModeMinutes: 50,
      ),
      VoidSessionRecord(
        completedAt: DateTime(2026, 6, 3, 10),
        focusSeconds: 1500,
        distractions: 0,
        focusScore: 100,
        xp: 25,
      ),
    ]);

    expect(stats.entryForMinutes(25).sessions, 2);
    expect(stats.entryForMinutes(25).focusSeconds, 3000);
    expect(stats.entryForMinutes(50).sessions, 1);
    expect(stats.entryForMinutes(50).focusSeconds, 3000);
    expect(stats.entryForMinutes(90).sessions, 0);
  });

  test('completeSession tracks focus mode statistics separately', () async {
    SharedPreferences.setMockInitialValues({});
    await StatsService.instance.initialize(force: true);

    await StatsService.instance.completeSession(
      focusSeconds: 1200,
      focusModeMinutes: 25,
    );
    await StatsService.instance.completeSession(
      focusSeconds: 3000,
      focusModeMinutes: 50,
    );
    await StatsService.instance.load(force: true);

    expect(
      StatsService.instance.data.focusModeStats.entryForMinutes(25).sessions,
      1,
    );
    expect(
      StatsService.instance.data.focusModeStats.entryForMinutes(25).focusSeconds,
      1200,
    );
    expect(
      StatsService.instance.data.focusModeStats.entryForMinutes(50).sessions,
      1,
    );
    expect(
      StatsService.instance.data.focusModeStats.entryForMinutes(50).focusSeconds,
      3000,
    );
    expect(
      StatsService.instance.data.sessionHistory.first.focusModeMinutes,
      50,
    );
  });

  test('setDeepWorkModeMinutes persists locally', () async {
    expect(StatsService.instance.data.deepWorkModeMinutes, 25);

    final saved = await StatsService.instance.setDeepWorkModeMinutes(90);
    expect(saved, isTrue);
    expect(StatsService.instance.data.deepWorkModeMinutes, 90);

    await StatsService.instance.load(force: true);
    expect(StatsService.instance.data.deepWorkModeMinutes, 90);
  });

  test('weekBoundsContaining uses Monday through Sunday', () {
    final bounds = weekBoundsContaining(DateTime(2026, 6, 4));
    expect(bounds.start.weekday, DateTime.monday);
    expect(bounds.end.weekday, DateTime.sunday);
    expect(bounds.end.difference(bounds.start).inDays, 6);
  });

  test('buildWeeklyReviewData aggregates current week sessions', () {
    final reference = DateTime(2026, 6, 4);
    final monday = weekBoundsContaining(reference).start;
    final wednesday = monday.add(const Duration(days: 2));
    final lastWeekTuesday = monday.subtract(const Duration(days: 6));

    final history = [
      VoidSessionRecord(
        completedAt: DateTime(monday.year, monday.month, monday.day, 10),
        focusSeconds: 3600,
        distractions: 0,
        focusScore: 100,
        xp: 60,
      ),
      VoidSessionRecord(
        completedAt: DateTime(
          wednesday.year,
          wednesday.month,
          wednesday.day,
          15,
        ),
        focusSeconds: 1800,
        distractions: 4,
        focusScore: 88,
        xp: 30,
      ),
      VoidSessionRecord(
        completedAt: DateTime(
          lastWeekTuesday.year,
          lastWeekTuesday.month,
          lastWeekTuesday.day,
          12,
        ),
        focusSeconds: 900,
        distractions: 0,
        focusScore: 100,
        xp: 15,
      ),
    ];

    final review = buildWeeklyReviewData(
      sessionHistory: history,
      referenceDate: reference,
    );
    final stats = review.currentWeek;

    expect(stats.sessionsCount, 2);
    expect(stats.totalFocusSeconds, 5400);
    expect(stats.totalDistractions, 4);
    expect(stats.averageFocusScore, 94);
    expect(stats.longestSessionSeconds, 3600);
    expect(stats.bestDay, monday);
    expect(stats.bestDayFocusSeconds, 3600);
    expect(
      review.summary,
      contains('1ч 30м'),
    );
  });

  test('buildWeeklyMotivationalSummary highlights focus improvement', () {
    final reference = DateTime(2026, 6, 4);
    final currentMonday = weekBoundsContaining(reference).start;
    final previousMonday = currentMonday.subtract(const Duration(days: 7));

    final history = [
      VoidSessionRecord(
        completedAt: DateTime(
          currentMonday.year,
          currentMonday.month,
          currentMonday.day,
          10,
        ),
        focusSeconds: 1200,
        distractions: 0,
        focusScore: 100,
        xp: 20,
      ),
      VoidSessionRecord(
        completedAt: DateTime(
          currentMonday.year,
          currentMonday.month,
          currentMonday.day + 1,
          11,
        ),
        focusSeconds: 1200,
        distractions: 2,
        focusScore: 94,
        xp: 20,
      ),
      VoidSessionRecord(
        completedAt: DateTime(
          previousMonday.year,
          previousMonday.month,
          previousMonday.day,
          10,
        ),
        focusSeconds: 1200,
        distractions: 10,
        focusScore: 70,
        xp: 20,
      ),
      VoidSessionRecord(
        completedAt: DateTime(
          previousMonday.year,
          previousMonday.month,
          previousMonday.day + 1,
          11,
        ),
        focusSeconds: 1200,
        distractions: 8,
        focusScore: 76,
        xp: 20,
      ),
    ];

    final review = buildWeeklyReviewData(
      sessionHistory: history,
      referenceDate: reference,
    );

    expect(review.summary, contains('улучшили концентрацию'));
  });

  test('buildProductivityInsights aggregates session history', () {
    final projectAlpha = VoidProject(
      id: 'p1',
      title: 'Alpha',
      createdAt: DateTime(2026, 1, 1),
    );
    final projectBeta = VoidProject(
      id: 'p2',
      title: 'Beta',
      createdAt: DateTime(2026, 1, 1),
    );
    final taskAlpha = VoidTask(
      id: 't1',
      title: 'Task Alpha',
      description: '',
      isCompleted: false,
      estimatedSessions: 5,
      totalFocusSeconds: 0,
      completedSessions: 0,
      focusScoreSum: 0,
      bestFocusScore: 0,
      createdAt: DateTime(2026, 1, 1),
      projectId: 'p1',
    );
    final taskAlpha2 = VoidTask(
      id: 't2',
      title: 'Task Alpha 2',
      description: '',
      isCompleted: false,
      estimatedSessions: 5,
      totalFocusSeconds: 0,
      completedSessions: 0,
      focusScoreSum: 0,
      bestFocusScore: 0,
      createdAt: DateTime(2026, 1, 1),
      projectId: 'p1',
    );
    final taskBeta = VoidTask(
      id: 't3',
      title: 'Task Beta',
      description: '',
      isCompleted: false,
      estimatedSessions: 5,
      totalFocusSeconds: 0,
      completedSessions: 0,
      focusScoreSum: 0,
      bestFocusScore: 0,
      createdAt: DateTime(2026, 1, 1),
      projectId: 'p2',
    );

    final monday = weekBoundsContaining(DateTime(2026, 6, 4)).start;
    final tuesday = monday.add(const Duration(days: 1));
    final nextMonday = monday.add(const Duration(days: 7));

    final history = [
      VoidSessionRecord(
        completedAt: DateTime(monday.year, monday.month, monday.day, 10),
        focusSeconds: 3600,
        distractions: 0,
        focusScore: 100,
        xp: 60,
        taskId: 't1',
        taskTitle: 'Task Alpha',
      ),
      VoidSessionRecord(
        completedAt: DateTime(monday.year, monday.month, monday.day, 14),
        focusSeconds: 1800,
        distractions: 0,
        focusScore: 100,
        xp: 30,
        taskId: 't2',
        taskTitle: 'Task Alpha 2',
      ),
      VoidSessionRecord(
        completedAt: DateTime(tuesday.year, tuesday.month, tuesday.day, 10),
        focusSeconds: 600,
        distractions: 0,
        focusScore: 100,
        xp: 10,
        taskId: 't3',
        taskTitle: 'Task Beta',
      ),
      VoidSessionRecord(
        completedAt: DateTime(
          nextMonday.year,
          nextMonday.month,
          nextMonday.day,
          10,
        ),
        focusSeconds: 900,
        distractions: 0,
        focusScore: 100,
        xp: 15,
        taskId: 't1',
        taskTitle: 'Task Alpha',
      ),
    ];

    final insights = buildProductivityInsights(
      sessionHistory: history,
      tasks: [taskAlpha, taskAlpha2, taskBeta],
      projects: [projectAlpha, projectBeta],
    );

    expect(insights.hasData, isTrue);
    expect(insights.sessionsCount, 4);
    expect(insights.mostFocusedProjectTitle, 'Alpha');
    expect(insights.mostFocusedProjectSeconds, 6300);
    expect(insights.mostFocusedTaskTitle, 'Task Alpha');
    expect(insights.mostFocusedTaskSeconds, 4500);
    expect(insights.averageSessionDurationSeconds, 1725);
    expect(insights.bestFocusDay, monday);
    expect(insights.bestFocusDaySeconds, 5400);
    expect(insights.bestFocusWeekSeconds, 6000);
    expect(insights.bestFocusWeekBounds?.start, monday);
    expect(insights.mostFocusedProjectLabel, contains('Alpha'));
    expect(insights.mostFocusedProjectLabel, contains('1ч 45м'));
    expect(insights.bestFocusDayLabel, contains('1 июн'));
    expect(insights.bestFocusDayLabel, contains('1ч 30м'));
    expect(
      insights.bestFocusWeekLabel,
      contains(formatWeeklyReviewPeriod(weekBoundsContaining(monday))),
    );
    expect(insights.totalProjectFocusSeconds, 6900);
    expect(insights.totalProjectFocusLabel, contains('1ч 55м'));
    expect(insights.projectBreakdown, hasLength(2));
    expect(insights.projectBreakdown.first.title, 'Alpha');
    expect(insights.taskBreakdown.first.title, 'Task Alpha');
    expect(insights.taskBreakdown.first.sessionsCount, 2);
  });

  test('buildProductivityInsights returns empty for no sessions', () {
    final insights = buildProductivityInsights(
      sessionHistory: const [],
      tasks: const [],
      projects: const [],
    );

    expect(insights.hasData, isFalse);
    expect(insights.sessionsCount, 0);
    expect(insights.mostFocusedProjectLabel, '—');
    expect(insights.mostFocusedTaskLabel, '—');
    expect(insights.averageSessionDurationLabel, '—');
    expect(insights.bestFocusDayLabel, '—');
    expect(insights.bestFocusWeekLabel, '—');
    expect(insights.projectBreakdown, isEmpty);
    expect(insights.taskBreakdown, isEmpty);
  });

  test('recordTaskSession increments focus time and session count', () async {
    SharedPreferences.setMockInitialValues({});
    await TasksService.instance.initialize(force: true);
    final task = await TasksService.instance.addTask('Дизайн');
    expect(task, isNotNull);

    expect(
      await TasksService.instance.recordTaskSession(
        task!.id,
        300,
        focusScore: 95,
      ),
      isTrue,
    );
    await TasksService.instance.load(force: true);

    expect(TasksService.instance.tasks.first.totalFocusSeconds, 300);
    expect(TasksService.instance.tasks.first.completedSessions, 1);
    expect(TasksService.instance.tasks.first.focusScoreSum, 95);
    expect(TasksService.instance.tasks.first.bestFocusScore, 95);
    expect(
      TasksService.instance.tasks.first.estimatedSessions,
      kDefaultTaskEstimatedSessions,
    );
  });

  test('VoidTask session progress uses completed over estimated sessions', () {
    const task = VoidTask(
      id: 't1',
      title: 'Create notification system',
      description: '',
      isCompleted: false,
      estimatedSessions: 5,
      totalFocusSeconds: 2700,
      completedSessions: 3,
      focusScoreSum: 285,
      bestFocusScore: 95,
      createdAt: DateTime(2026, 1, 1),
    );

    expect(task.sessionProgressLabel, '3 / 5 сессий');
    expect(task.sessionProgressPercent, 60);
    expect(task.sessionProgressBarValue, 0.6);
  });

  test('kVoidProjectTemplates provides default emoji projects', () {
    expect(kVoidProjectTemplates, hasLength(8));
    expect(resolveVoidProjectEmoji('study'), '📚');
    expect(resolveVoidProjectEmoji('void'), '🚀');
    expect(voidProjectTemplateById('health')?.defaultTitle, 'Здоровье');
  });

  test('formatVoidTaskCountLabel uses Russian plural forms', () {
    expect(formatVoidTaskCountLabel(1), '1 задача');
    expect(formatVoidTaskCountLabel(3), '3 задачи');
    expect(formatVoidTaskCountLabel(12), '12 задач');
  });

  test('completedProjects includes projects with all tasks done', () async {
    SharedPreferences.setMockInitialValues({});
    await TasksService.instance.initialize(force: true);
    final project = await TasksService.instance.addProject(
      const VoidProjectEditorResult(
        title: 'Спринт',
        colorValue: kDefaultProjectColorValue,
        iconName: kDefaultProjectIconName,
      ),
    );
    final task = await TasksService.instance.addTask(
      'Отчёт',
      projectId: project!.id,
    );
    await TasksService.instance.toggleTaskCompleted(task!.id);
    await TasksService.instance.load(force: true);

    expect(TasksService.instance.completedTasks, hasLength(1));
    expect(TasksService.instance.completedProjects, hasLength(1));
    expect(TasksService.instance.completedProjects.first.title, 'Спринт');
  });

  test('computeFocusScore subtracts three points per distraction', () {
    expect(computeFocusScore(0), 100);
    expect(computeFocusScore(3), 91);
    expect(computeFocusScore(34), 0);
    expect(computeFocusScore(100), 0);
  });

  test('formatDailyGoalProgress formats focus time toward daily goal', () {
    expect(formatDailyGoalProgress(190, 60), '3м 10с / 60м');
    expect(formatDailyGoalProgress(1380, 60), '23м / 60м');
    expect(formatDailyGoalProgress(175, 60), '2м 55с / 60м');
    expect(formatDailyGoalProgress(3240, 60), '54м / 60м');
    expect(formatDailyGoalProgress(3600, 60), '60м / 60м');
    expect(formatDailyGoalProgress(0, 60), '0с / 60м');
    expect(formatDailyGoalProgress(21, 60), '21с / 60м');
  });

  test('daily goal achievement unlocks after completing 60 minutes', () async {
    final todayKey = _todayActivityKey();
    SharedPreferences.setMockInitialValues({
      'daily_activity': '{"$todayKey":3600}',
      'focus_data_uses_seconds': true,
    });
    await StatsService.instance.initialize(force: true);
    await StatsService.instance.load(force: true);

    final dailyGoal = StatsService.instance.data.achievements
        .firstWhere((achievement) => achievement.title == 'Цель дня выполнена');
    expect(dailyGoal.isUnlocked, isTrue);
  });

  test('today focus resets automatically for a new day', () async {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final yesterdayKey =
        '${yesterday.year.toString().padLeft(4, '0')}-'
        '${yesterday.month.toString().padLeft(2, '0')}-'
        '${yesterday.day.toString().padLeft(2, '0')}';
    SharedPreferences.setMockInitialValues({
      'daily_activity': '{"$yesterdayKey":3600}',
      'focus_data_uses_seconds': true,
    });
    await StatsService.instance.initialize(force: true);
    await StatsService.instance.load(force: true);

    expect(StatsService.instance.data.todayFocusMinutes, 0);
    expect(StatsService.instance.data.dailyGoalMinutes, 60);
  });

  test('formatFocusDuration formats seconds correctly', () {
    expect(formatFocusDuration(21), '21с');
    expect(formatFocusDuration(65), '1м 5с');
    expect(formatFocusDuration(3725), '1ч 2м 5с');
    expect(formatFocusDuration(12000), '3ч 20м');
  });

  testWidgets('VOID onboarding screen renders in Russian', (WidgetTester tester) async {
    await tester.pumpWidget(const VoidApp());
    await tester.pumpAndSettle();

    expect(find.text('VOID'), findsOneWidget);
    expect(find.text('Контролируй своё внимание'), findsOneWidget);
    expect(find.text('Начать фокус'), findsOneWidget);
  });

  testWidgets('home screen shows daily goal progress', (WidgetTester tester) async {
    final todayKey = _todayActivityKey();
    SharedPreferences.setMockInitialValues({
      'daily_activity': '{"$todayKey":3240}',
      'focus_data_uses_seconds': true,
    });
    await StatsService.instance.initialize(force: true);
    await StatsService.instance.load(force: true);

    await tester.pumpWidget(const VoidApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Начать фокус'));
    await tester.pumpAndSettle();

    expect(find.text('Сегодня'), findsOneWidget);
    expect(find.text('54м / 60м'), findsOneWidget);
    expect(find.text('90%'), findsOneWidget);
    expect(StatsService.instance.data.dailyGoalMinutes, 60);
    expect(StatsService.instance.data.todayFocusSeconds, 3240);
    expect(StatsService.instance.data.dailyGoalProgress, closeTo(0.9, 0.01));
  });

  testWidgets('daily goal shows completed state at 60 minutes', (
    WidgetTester tester,
  ) async {
    final todayKey = _todayActivityKey();
    SharedPreferences.setMockInitialValues({
      'daily_activity': '{"$todayKey":3600}',
      'focus_data_uses_seconds': true,
    });
    await StatsService.instance.initialize(force: true);
    await StatsService.instance.load(force: true);

    await tester.pumpWidget(const VoidApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Начать фокус'));
    await tester.pumpAndSettle();

    expect(find.text('60м / 60м'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
    expect(find.text('Цель дня выполнена'), findsWidgets);
    expect(StatsService.instance.data.isDailyGoalCompleted, isTrue);
  });

  testWidgets('daily goal shows partial minutes in progress text', (
    WidgetTester tester,
  ) async {
    final todayKey = _todayActivityKey();
    SharedPreferences.setMockInitialValues({
      'daily_activity': '{"$todayKey":175}',
      'focus_data_uses_seconds': true,
    });
    await StatsService.instance.initialize(force: true);
    await StatsService.instance.load(force: true);

    await tester.pumpWidget(const VoidApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Начать фокус'));
    await tester.pumpAndSettle();

    expect(find.text('2м 55с / 60м'), findsOneWidget);
    expect(find.text('5%'), findsOneWidget);
    expect(
      StatsService.instance.data.dailyGoalProgress,
      closeTo(175 / 3600, 0.001),
    );
  });

  testWidgets('Начать фокус navigates to home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const VoidApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Начать фокус'));
    await tester.pumpAndSettle();

    expect(find.text('Главная'), findsOneWidget);
    expect(find.text('Добро пожаловать'), findsOneWidget);
    expect(find.text('Цели недели'), findsOneWidget);
    expect(find.byType(VoidWeeklyGoalsCard), findsOneWidget);
    expect(find.text('5 часов фокуса'), findsWidgets);
    expect(find.text('20 сессий'), findsWidgets);
    expect(find.text('3 дня серии'), findsWidgets);
    expect(find.text('Всего сессий'), findsWidgets);
    expect(find.text('8'), findsWidgets);
    expect(find.text('3ч 20м'), findsOneWidget);
    expect(find.text('Текущая серия'), findsWidgets);
    expect(find.text('Лучшая серия'), findsWidgets);
    expect(find.byType(VoidStreakCard), findsOneWidget);
    expect(find.text('Начать сессию'), findsOneWidget);
    expect(find.text('Фокус'), findsOneWidget);
    expect(find.text('Аналитика'), findsOneWidget);
    expect(find.text('Профиль'), findsOneWidget);
    expect(StatsService.instance.data.totalFocusSeconds, 12000);
  });

  testWidgets('bottom nav switches tabs', (WidgetTester tester) async {
    await tester.pumpWidget(const VoidApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Начать фокус'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Аналитика'));
    await tester.pumpAndSettle();
    expect(find.text('Всего сессий'), findsOneWidget);
    expect(find.text('8'), findsWidgets);
    expect(find.text('Всего часов фокуса'), findsOneWidget);
    expect(find.text('3ч 20м'), findsOneWidget);
    expect(find.text('Текущая серия'), findsOneWidget);
    expect(find.byType(VoidStreakCard), findsOneWidget);
    expect(find.text('Всего отвлечений'), findsOneWidget);
    expect(find.text('Среднее отвлечений за сессию'), findsOneWidget);
    expect(find.text('Фокус-счёт'), findsOneWidget);
    expect(find.text('94'), findsWidgets);
    expect(find.text('2'), findsWidgets);
    expect(find.text('Последние 7 дней активности'), findsOneWidget);
    expect(find.byType(VoidFocusModeStatsCard), findsOneWidget);
    expect(find.text('Light Focus'), findsOneWidget);
    expect(find.text('Deep Focus'), findsOneWidget);
    expect(find.text('Elite Focus'), findsOneWidget);
    expect(find.text('Недельный обзор'), findsOneWidget);
    expect(find.byType(VoidWeeklyReviewAccessCard), findsOneWidget);
    expect(find.text('Инсайты продуктивности'), findsOneWidget);
    expect(find.byType(VoidProductivityInsightsAccessCard), findsOneWidget);
    expect(find.text('Календарь фокуса'), findsOneWidget);
    expect(find.text('Последние 30 дней'), findsOneWidget);
    expect(find.text('Активные дни'), findsOneWidget);
    expect(find.text('Всего фокуса'), findsWidgets);
    expect(find.text('Серия (30 дн.)'), findsOneWidget);
    expect(find.text('Цель выполнена'), findsOneWidget);
    expect(find.text('Был фокус'), findsOneWidget);
    expect(find.text('Нет фокуса'), findsOneWidget);
    expect(find.byType(VoidFocusCalendar), findsOneWidget);

    await tester.tap(find.text('Профиль'));
    await tester.pumpAndSettle();
    expect(find.text('Пользователь VOID'), findsOneWidget);
    expect(find.text('Новичок'), findsNWidgets(2));
    expect(find.text('Уровень'), findsOneWidget);
    expect(find.text('3'), findsWidgets);
    expect(find.text('200 XP'), findsOneWidget);
    expect(find.text('0 / 100 XP'), findsOneWidget);
    expect(find.text('8'), findsWidgets);
    expect(find.text('3ч 20м'), findsWidgets);
    expect(find.text('Личные рекорды'), findsOneWidget);
    expect(find.byType(VoidPersonalRecordsCard), findsOneWidget);
    expect(find.text('Самая длинная сессия'), findsOneWidget);
    expect(find.text('Лучший фокус-счёт'), findsOneWidget);
    expect(find.text('Сессий за день'), findsOneWidget);
    expect(find.text('Фокуса за день'), findsOneWidget);
    expect(find.text('История сессий'), findsOneWidget);
    expect(find.text('Календарь фокуса'), findsOneWidget);
    expect(find.byType(VoidCalendarAccessCard), findsOneWidget);
    expect(find.text('Достижения'), findsOneWidget);
    expect(find.text('3/7'), findsOneWidget);
    expect(find.text('Первая сессия'), findsOneWidget);
    expect(find.text('10 минут фокуса'), findsOneWidget);
    expect(find.text('1 час фокуса'), findsOneWidget);
    expect(find.text('10 сессий'), findsOneWidget);
    expect(find.text('100 отвлечений предотвращено'), findsOneWidget);
    expect(find.text('7 дней подряд'), findsOneWidget);
    expect(StatsService.instance.data.unlockedAchievementsCount, 3);
  });

  testWidgets('analytics shows empty state when no data', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await StatsService.instance.initialize(force: true);

    await tester.pumpWidget(const VoidApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Начать фокус'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Аналитика'));
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Не удалось загрузить данные'), findsNothing);
    expect(
      find.text('Завершите первую фокус-сессию для просмотра статистики'),
      findsOneWidget,
    );
    expect(StatsService.instance.isLoading, isFalse);
    expect(StatsService.instance.hasData, isFalse);
  });

  testWidgets('Начать сессию opens focus session with countdown', (WidgetTester tester) async {
    await tester.pumpWidget(const VoidApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Начать фокус'));
    await tester.pumpAndSettle();
    await _openFocusFromHome(tester);

    expect(find.text('Глубокий фокус'), findsOneWidget);
    expect(find.text('25:00'), findsOneWidget);
    expect(find.text('Старт'), findsOneWidget);
    expect(find.text('Пауза'), findsOneWidget);
    expect(find.text('Сброс'), findsOneWidget);
    expect(find.text('Завершить сессию'), findsOneWidget);
    expect(find.text('Сессий сегодня'), findsOneWidget);
    expect(find.text('Отвлечений'), findsOneWidget);
    expect(find.text('Нажмите при потере концентрации'), findsNothing);
  });

  testWidgets('distraction tracking updates counter and analytics', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await StatsService.instance.initialize(force: true);

    await tester.pumpWidget(const VoidApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Начать фокус'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Фокус'));
    await tester.pumpAndSettle();
    await _startFocusSession(tester);
    await tester.pumpAndSettle();

    expect(find.text('Нажмите при потере концентрации'), findsOneWidget);
    expect(
      find.text('Отмечайте моменты, когда вы отвлеклись от задачи'),
      findsOneWidget,
    );

    await tester.tap(find.text('Отвлечений'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Отвлечение зафиксировано'), findsOneWidget);
    expect(find.text('1'), findsWidgets);

    await tester.tap(find.text('Отвлечений'));
    await tester.pump();
    expect(find.text('1'), findsWidgets);

    await tester.pump(const Duration(seconds: 3));
    await tester.tap(find.text('Отвлечений'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Завершить сессию'));
    await tester.pumpAndSettle();

    expect(find.byType(VoidSessionCompleteDialog), findsOneWidget);
    expect(find.text('Фокус-счёт'), findsOneWidget);
    expect(find.text('94'), findsOneWidget);

    await _dismissSessionCompleteDialog(tester);

    await tester.tap(find.text('Аналитика'));
    await tester.pumpAndSettle();

    expect(find.text('Всего отвлечений'), findsOneWidget);
    expect(find.text('Среднее отвлечений за сессию'), findsOneWidget);
    expect(StatsService.instance.data.distractions, 2);
    expect(StatsService.instance.data.averageDistractionsPerSession, 2);
    expect(StatsService.instance.data.averageFocusScore, 94);
  });

  testWidgets('session history shows completed sessions newest first', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await StatsService.instance.initialize(force: true);

    await tester.pumpWidget(const VoidApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Начать фокус'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Фокус'));
    await tester.pumpAndSettle();
    await _startFocusSession(tester);
    await tester.pump();
    await tester.pump(const Duration(seconds: 21));
    await tester.tap(find.text('Завершить сессию'));
    await tester.pumpAndSettle();
    await _dismissSessionCompleteDialog(tester);

    await tester.tap(find.text('Профиль'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('История сессий'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('История сессий'));
    await tester.pumpAndSettle();

    expect(find.text('Длительность'), findsOneWidget);
    expect(find.text('21с'), findsOneWidget);
    expect(find.text('Отвлечения'), findsOneWidget);
    expect(find.text('Фокус-счёт'), findsWidgets);
    expect(find.text('XP'), findsOneWidget);
    expect(find.text('+0'), findsOneWidget);
    expect(find.text('100'), findsWidgets);
    expect(StatsService.instance.data.sessionHistory.length, 1);
    expect(StatsService.instance.data.sessionHistory.first.focusSeconds, 21);
    expect(StatsService.instance.data.sessionHistory.first.focusScore, 100);
  });

  testWidgets('distraction cooldown blocks spam clicks', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await StatsService.instance.initialize(force: true);

    await tester.pumpWidget(const VoidApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Начать фокус'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Фокус'));
    await tester.pumpAndSettle();
    await _startFocusSession(tester);
    await tester.pumpAndSettle();

    for (var i = 0; i < 5; i++) {
      await tester.tap(find.text('Отвлечений'));
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('1'), findsWidgets);
  });

  testWidgets('countdown starts on Старт and pause works', (WidgetTester tester) async {
    await tester.pumpWidget(const VoidApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Начать фокус'));
    await tester.pumpAndSettle();
    await _openFocusFromHome(tester);

    await tester.pump(const Duration(seconds: 3));
    expect(find.text('25:00'), findsOneWidget);

    await tester.tap(find.text('Старт'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('24:57'), findsOneWidget);

    await tester.tap(find.text('Пауза'));
    await tester.pumpAndSettle();
    expect(find.text('Продолжить'), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
    expect(find.text('24:57'), findsOneWidget);
  });

  testWidgets('Сброс restores timer to 25:00', (WidgetTester tester) async {
    await tester.pumpWidget(const VoidApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Начать фокус'));
    await tester.pumpAndSettle();
    await _openFocusFromHome(tester);
    await tester.tap(find.text('Старт'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));
    expect(find.text('24:55'), findsOneWidget);

    await tester.tap(find.text('Сброс'));
    await tester.pumpAndSettle();
    expect(find.text('25:00'), findsOneWidget);
  });

  testWidgets('21 second session saves exact seconds', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await StatsService.instance.initialize(force: true);

    await tester.pumpWidget(const VoidApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Начать фокус'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Фокус'));
    await tester.pumpAndSettle();

    await _startFocusSession(tester);
    await tester.pump();
    await tester.pump(const Duration(seconds: 21));

    await tester.tap(find.text('Завершить сессию'));
    await tester.pumpAndSettle();

    expect(find.text('21с'), findsWidgets);
    expect(StatsService.instance.data.completedSessions, 1);
    expect(StatsService.instance.data.totalFocusSeconds, 21);

    await _dismissSessionCompleteDialog(tester);

    await tester.tap(find.text('Аналитика'));
    await tester.pumpAndSettle();

    expect(find.text('21с'), findsWidgets);
    expect(StatsService.instance.hasData, isTrue);
  });

  testWidgets('first launch feedback dialog appears on third session', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'completedSessions': 2,
      'focus_data_uses_seconds': true,
    });
    await StatsService.instance.initialize(force: true);

    await tester.pumpWidget(const VoidApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Начать фокус'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Фокус'));
    await tester.pumpAndSettle();

    await _startFocusSession(tester);
    await tester.pump();
    await tester.pump(const Duration(seconds: 60));

    await tester.tap(find.text('Завершить сессию'));
    await tester.pumpAndSettle();

    expect(find.text('Сессия завершена'), findsOneWidget);
    await _dismissSessionCompleteDialog(tester);

    expect(find.text('Как вам VOID?'), findsOneWidget);
    expect(find.text('Нравится'), findsOneWidget);
    expect(find.text('Есть идеи'), findsOneWidget);
    expect(find.text('Сообщить о проблеме'), findsOneWidget);

    await tester.tap(find.text('Нравится'));
    await tester.pumpAndSettle();

    expect(find.text('Как вам VOID?'), findsNothing);
    expect(
      await StatsService.instance.shouldPromptFirstLaunchFeedback(),
      isFalse,
    );
  });

  testWidgets('Завершить сессию saves data and shows dialog', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await StatsService.instance.initialize(force: true);

    await tester.pumpWidget(const VoidApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Начать фокус'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Фокус'));
    await tester.pumpAndSettle();

    await _startFocusSession(tester);
    await tester.pump();
    await tester.pump(const Duration(seconds: 60));

    await tester.tap(find.text('Завершить сессию'));
    await tester.pumpAndSettle();

    expect(find.text('Сессия завершена'), findsOneWidget);
    expect(find.byType(VoidSessionCompleteDialog), findsOneWidget);
    expect(find.text('Длительность'), findsOneWidget);
    expect(find.text('Фокус-счёт'), findsOneWidget);
    expect(find.text('Получено XP'), findsOneWidget);
    expect(find.text('Серия'), findsOneWidget);
    expect(find.text('Цель дня'), findsOneWidget);
    expect(find.text('1м'), findsWidgets);
    expect(find.text('+1'), findsOneWidget);

    expect(StatsService.instance.data.completedSessions, 1);
    expect(StatsService.instance.data.totalFocusSeconds, 60);

    await _dismissSessionCompleteDialog(tester);

    await tester.tap(find.text('Аналитика'));
    await tester.pumpAndSettle();

    expect(find.text('Всего сессий'), findsOneWidget);
    expect(find.text('Всего часов фокуса'), findsOneWidget);
    expect(find.text('1м'), findsNWidgets(2));
    expect(StatsService.instance.hasData, isTrue);
  });

  testWidgets('early finish after 10 minutes saves 600 seconds', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await StatsService.instance.initialize(force: true);

    await tester.pumpWidget(const VoidApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Начать фокус'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Фокус'));
    await tester.pumpAndSettle();

    await _startFocusSession(tester);
    await tester.pump();
    await tester.pump(const Duration(seconds: 600));

    await tester.tap(find.text('Завершить сессию'));
    await tester.pumpAndSettle();

    expect(find.text('10м'), findsWidgets);
    expect(StatsService.instance.data.totalFocusSeconds, 600);
  });

  testWidgets('timer completion saves full 1500 seconds', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await StatsService.instance.initialize(force: true);

    await tester.pumpWidget(const VoidApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Начать фокус'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Фокус'));
    await tester.pumpAndSettle();

    await _startFocusSession(tester);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1500));
    await tester.pump();

    expect(find.text('Сессия завершена'), findsOneWidget);
    expect(find.text('25м'), findsWidgets);
    expect(StatsService.instance.data.totalFocusSeconds, 1500);
  });

  Future<void> _openSettings(WidgetTester tester) async {
    await tester.pumpWidget(const VoidApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Начать фокус'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Профиль'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Настройки'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Настройки'));
    await tester.pumpAndSettle();
  }

  testWidgets('settings screen renders all options', (WidgetTester tester) async {
    await _openSettings(tester);

    expect(find.text('Уведомления'), findsOneWidget);
    expect(find.text('Умные напоминания'), findsOneWidget);
    expect(find.text('Время напоминания'), findsOneWidget);
    expect(find.text('Данные'), findsOneWidget);
    expect(find.text('Сбросить статистику'), findsOneWidget);
    expect(find.text('Очистить историю сессий'), findsOneWidget);
    expect(find.text('Резервное копирование'), findsOneWidget);
    expect(find.text('Обратная связь'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Сообщить об ошибке'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Сообщить об ошибке'), findsOneWidget);
    expect(find.text('Предложить функцию'), findsOneWidget);
    expect(find.text('Оценить приложение'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('О приложении'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('О приложении'), findsOneWidget);
  });

  testWidgets('feedback actions complete without error', (WidgetTester tester) async {
    await _openSettings(tester);

    await tester.ensureVisible(find.text('Сообщить об ошибке'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Сообщить об ошибке'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.ensureVisible(find.text('Предложить функцию'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Предложить функцию'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.ensureVisible(find.text('Оценить приложение'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Оценить приложение'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('reset statistics clears stats after confirmation', (WidgetTester tester) async {
    await _openSettings(tester);

    await tester.tap(find.text('Сбросить статистику'));
    await tester.pumpAndSettle();
    expect(find.text('Сбросить статистику?'), findsOneWidget);

    await tester.tap(find.text('Сбросить'));
    await tester.pumpAndSettle();

    expect(find.text('Статистика сброшена'), findsOneWidget);
    expect(StatsService.instance.data.completedSessions, 0);
    expect(StatsService.instance.data.totalFocusSeconds, 0);
    expect(StatsService.instance.data.currentStreak, 0);
    expect(StatsService.instance.data.dailyGoalMinutes, 60);
  });

  testWidgets('clear session history keeps aggregate stats', (WidgetTester tester) async {
    await _openSettings(tester);

    await tester.tap(find.text('Очистить историю сессий'));
    await tester.pumpAndSettle();
    expect(find.text('Очистить историю?'), findsOneWidget);

    await tester.tap(find.text('Очистить'));
    await tester.pumpAndSettle();

    expect(find.text('История сессий очищена'), findsOneWidget);
    expect(StatsService.instance.data.completedSessions, 8);
    expect(StatsService.instance.data.totalFocusSeconds, 12000);
    expect(StatsService.instance.data.sessionHistory, isEmpty);
  });

  test('exportBackup returns structured JSON with all sections', () async {
    final json = await StatsService.instance.exportBackup();
    final decoded = jsonDecode(json) as Map<String, dynamic>;
    expect(decoded['formatVersion'], kVoidBackupFormatVersion);
    expect(decoded['appVersion'], '1.0.0');
    expect(decoded['statistics'], isA<Map<String, dynamic>>());
    expect(decoded['sessions'], isA<List<dynamic>>());
    expect(decoded['achievements'], isA<List<dynamic>>());
    expect(decoded['projects'], isA<List<dynamic>>());
    expect(decoded['tasks'], isA<List<dynamic>>());

    final statistics = decoded['statistics'] as Map<String, dynamic>;
    expect(statistics['completedSessions'], 8);
    expect(statistics['totalFocusSeconds'], 12000);
  });

  test('importBackup restores exported data', () async {
    await TasksService.instance.addProject(
      const VoidProjectEditorResult(
        title: 'VOID App',
        colorValue: kDefaultProjectColorValue,
        iconName: kDefaultProjectIconName,
      ),
    );
    final task = await TasksService.instance.addTask(
      'Backup test',
      projectId: TasksService.instance.projects.first.id,
    );
    expect(task, isNotNull);

    final exported = await StatsService.instance.exportBackup();
    expect(await StatsService.instance.resetAllStats(), isTrue);
    await TasksService.instance.deleteProject(TasksService.instance.projects.first.id);

    final result = await StatsService.instance.importBackup(exported);
    expect(result.success, isTrue);
    expect(StatsService.instance.data.completedSessions, 8);
    expect(StatsService.instance.data.totalFocusSeconds, 12000);
    expect(StatsService.instance.data.sessionHistory, isNotEmpty);
    expect(TasksService.instance.projects, hasLength(1));
    expect(TasksService.instance.tasks, hasLength(1));
    expect(TasksService.instance.tasks.first.title, 'Backup test');
  });

  test('normalizeVoidBackup supports legacy flat export', () {
    final legacy = {
      'completedSessions': 3,
      'totalFocusSeconds': 1800,
      'sessionHistory': [
        {
          'completedAt': '2026-06-01T10:00:00.000',
          'focusSeconds': 600,
          'distractions': 1,
          'focusScore': 97,
          'xp': 10,
        },
      ],
      'achievements': [
        {'id': 'first_session', 'title': 'Первая сессия', 'isUnlocked': true},
      ],
      'last30Days': [
        {'date': '2026-06-01', 'focusSeconds': 1800},
      ],
    };

    expect(isLegacyVoidBackup(legacy), isTrue);
    final normalized = normalizeVoidBackup(legacy);
    final statistics = normalized['statistics'] as Map<String, dynamic>;
    expect(statistics['completedSessions'], 3);
    expect(statistics['dailyActivity'], {'2026-06-01': 1800});
    expect(normalized['sessions'], isA<List<dynamic>>());
  });

  test('resetAllStats clears counters but keeps daily goal', () async {
    expect(await StatsService.instance.resetAllStats(), isTrue);
    expect(StatsService.instance.data.completedSessions, 0);
    expect(StatsService.instance.data.totalFocusSeconds, 0);
    expect(StatsService.instance.data.dailyGoalMinutes, 60);
  });

  test('clearSessionHistory empties history but keeps totals', () async {
    expect(await StatsService.instance.clearSessionHistory(), isTrue);
    expect(StatsService.instance.data.sessionHistory, isEmpty);
    expect(StatsService.instance.data.completedSessions, 8);
    expect(StatsService.instance.data.totalFocusSeconds, 12000);
  });

  testWidgets('settings opens backup restore screen', (WidgetTester tester) async {
    await _openSettings(tester);
    await tester.tap(find.text('Резервное копирование'));
    await tester.pumpAndSettle();

    expect(find.byType(VoidBackupRestoreScreen), findsOneWidget);
    expect(find.text('Экспортировать JSON'), findsOneWidget);
    expect(find.text('Статистика'), findsOneWidget);
    expect(find.text('Сессии'), findsOneWidget);
    expect(find.text('Достижения'), findsOneWidget);
    expect(find.text('Задачи'), findsOneWidget);
    expect(find.text('Проекты'), findsOneWidget);
  });

  testWidgets('profile opens focus calendar screen', (WidgetTester tester) async {
    await tester.pumpWidget(const VoidApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Начать фокус'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Профиль'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byType(VoidCalendarAccessCard));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(VoidCalendarAccessCard));
    await tester.pumpAndSettle();

    expect(find.byType(VoidFocusCalendarScreen), findsOneWidget);
    expect(find.text('Последние 30 дней'), findsWidgets);
    expect(find.text('Нажмите на день, чтобы увидеть детали'), findsOneWidget);
    expect(find.text('5'), findsWidgets);
    expect(find.byType(VoidFocusCalendar), findsOneWidget);
    expect(find.text('Активные дни'), findsOneWidget);
    expect(find.text('Серия (30 дн.)'), findsOneWidget);
    expect(find.text('Цель выполнена'), findsOneWidget);
    expect(find.text('Был фокус'), findsOneWidget);
    expect(find.text('Нет фокуса'), findsOneWidget);
  });

  testWidgets('tapping calendar day opens detail sheet', (WidgetTester tester) async {
    await tester.pumpWidget(const VoidApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Начать фокус'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Профиль'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(VoidCalendarAccessCard));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(VoidCalendarAccessCard));
    await tester.pumpAndSettle();

    final dayFinder = find.byKey(
      Key('calendar-day-${_todayActivityKey()}'),
    );
    await tester.scrollUntilVisible(
      dayFinder,
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    final dayBox = tester.renderObject<RenderBox>(dayFinder);
    final dayCenter = dayBox.localToGlobal(dayBox.size.center(Offset.zero));
    await tester.tapAt(dayCenter);
    await tester.pumpAndSettle();

    expect(find.text('Всего фокуса'), findsNWidgets(2));
    expect(find.text('Сессий завершено'), findsOneWidget);
    expect(find.text('Средний фокус-счёт'), findsOneWidget);
    expect(find.text('Всего отвлечений'), findsOneWidget);
    expect(find.text('Заработано XP'), findsOneWidget);
    expect(find.text('Сегодня'), findsOneWidget);
  });

  testWidgets('empty calendar day shows no activity message', (WidgetTester tester) async {
    await tester.pumpWidget(const VoidApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Начать фокус'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Профиль'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(VoidCalendarAccessCard));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(VoidCalendarAccessCard));
    await tester.pumpAndSettle();

    final emptyDate = DateTime.now().subtract(const Duration(days: 20));
    final emptyKey = StatsService.dateKey(
      DateTime(emptyDate.year, emptyDate.month, emptyDate.day),
    );
    final dayFinder = find.byKey(Key('calendar-day-$emptyKey'));
    await tester.scrollUntilVisible(
      dayFinder,
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    final dayBox = tester.renderObject<RenderBox>(dayFinder);
    final dayCenter = dayBox.localToGlobal(dayBox.size.center(Offset.zero));
    await tester.tapAt(dayCenter);
    await tester.pumpAndSettle();

    expect(
      find.text('В этот день не было фокус-сессий'),
      findsOneWidget,
    );
    expect(find.text('Заработано XP'), findsNothing);
    expect(find.text('Сессий завершено'), findsNothing);
  });

  testWidgets('analytics opens weekly review screen', (WidgetTester tester) async {
    await tester.pumpWidget(const VoidApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Начать фокус'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Аналитика'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Недельный обзор'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Недельный обзор'));
    await tester.pumpAndSettle();

    expect(find.text('Сессий за неделю'), findsOneWidget);
    expect(find.text('Время в фокусе'), findsOneWidget);
    expect(find.text('Средний фокус-счёт'), findsOneWidget);
    expect(find.text('Лучший день'), findsOneWidget);
    expect(find.text('Самая длинная сессия'), findsOneWidget);
  });

  testWidgets('analytics opens productivity insights screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const VoidApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Начать фокус'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Аналитика'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Инсайты продуктивности'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Инсайты продуктивности'));
    await tester.pumpAndSettle();

    expect(find.text('Самый фокусный проект'), findsOneWidget);
    expect(find.text('Самая фокусная задача'), findsOneWidget);
    expect(find.text('Средняя длительность сессии'), findsOneWidget);
    expect(find.text('Лучший день фокуса'), findsOneWidget);
    expect(find.text('Лучшая неделя фокуса'), findsOneWidget);
    expect(find.byType(VoidProductivityInsightsScreen), findsOneWidget);
  });

  testWidgets('about app dialog shows version', (WidgetTester tester) async {
    await _openSettings(tester);

    await tester.scrollUntilVisible(
      find.text('О приложении'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('О приложении'));
    await tester.pumpAndSettle();

    expect(find.text('VOID'), findsWidgets);
    expect(find.text('v1.0.0'), findsOneWidget);
    expect(find.text('Закрыть'), findsOneWidget);
  });

  test('TasksService persists project and task operations', () async {
    SharedPreferences.setMockInitialValues({});
    await TasksService.instance.initialize(force: true);
    await TasksService.instance.load(force: true);

    final project = await TasksService.instance.addProject(
      const VoidProjectEditorResult(
        title: 'VOID App',
        colorValue: kDefaultProjectColorValue,
        iconName: kDefaultProjectIconName,
      ),
    );
    expect(project, isNotNull);

    final task = await TasksService.instance.addTask(
      'Написать отчёт',
      projectId: project!.id,
    );
    expect(task, isNotNull);
    expect(task!.projectId, project.id);
    expect(TasksService.instance.projectFocusSeconds(project.id), 0);

    await StatsService.instance.completeSession(
      focusSeconds: 300,
      taskId: task.id,
      taskTitle: task.title,
    );
    await TasksService.instance.load(force: true);

    expect(TasksService.instance.tasks.first.totalFocusSeconds, 300);
    expect(TasksService.instance.tasks.first.completedSessions, 1);
    expect(TasksService.instance.projectFocusSeconds(project.id), 300);
    expect(TasksService.instance.projectSessionsCount(project.id), 1);

    await TasksService.instance.updateProject(project.copyWith(title: 'VOID 2.0'));
    expect(TasksService.instance.projects.first.title, 'VOID 2.0');

    await TasksService.instance.deleteProject(project.id);
    expect(TasksService.instance.projects, isEmpty);
    expect(TasksService.instance.tasks.first.projectId, isNull);
  });

  test('TasksService persists task CRUD operations', () async {
    SharedPreferences.setMockInitialValues({});
    await TasksService.instance.initialize(force: true);
    await TasksService.instance.load(force: true);

    expect(TasksService.instance.tasks, isEmpty);

    final created = await TasksService.instance.addTask('Написать отчёт');
    expect(created, isNotNull);
    expect(TasksService.instance.tasks.length, 1);
    expect(TasksService.instance.tasks.first.title, 'Написать отчёт');

    await TasksService.instance.initialize(force: true);
    await TasksService.instance.load(force: true);
    expect(TasksService.instance.tasks.length, 1);

    final task = TasksService.instance.tasks.first;
    await TasksService.instance.updateTask(task.copyWith(title: 'Отчёт Q2'));
    expect(TasksService.instance.tasks.first.title, 'Отчёт Q2');

    await TasksService.instance.toggleTaskCompleted(task.id);
    expect(TasksService.instance.tasks.first.isCompleted, isTrue);
    expect(TasksService.instance.activeTaskCount, 0);

    await TasksService.instance.deleteTask(task.id);
    expect(TasksService.instance.tasks, isEmpty);
  });

  test('completeSession links task and updates task focus time', () async {
    SharedPreferences.setMockInitialValues({});
    await StatsService.instance.initialize(force: true);
    await TasksService.instance.initialize(force: true);

    final task = await TasksService.instance.addTask('Код-ревью');
    expect(task, isNotNull);

    final saved = await StatsService.instance.completeSession(
      focusSeconds: 120,
      sessionDistractions: 1,
      taskId: task!.id,
      taskTitle: task.title,
    );
    expect(saved, isTrue);

    await StatsService.instance.load(force: true);
    await TasksService.instance.load(force: true);

    expect(TasksService.instance.tasks.first.totalFocusSeconds, 120);
    expect(StatsService.instance.data.sessionHistory.length, 1);
    expect(StatsService.instance.data.sessionHistory.first.taskId, task.id);
    expect(StatsService.instance.data.sessionHistory.first.taskTitle, 'Код-ревью');
  });

  testWidgets('task picker appears before session from home', (WidgetTester tester) async {
    await tester.pumpWidget(const VoidApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Начать фокус'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Начать сессию'));
    await tester.pumpAndSettle();

    expect(find.text('Выберите задачу'), findsOneWidget);
    expect(find.text('Без задачи'), findsOneWidget);
    expect(find.text('Продолжить'), findsOneWidget);
  });

  testWidgets('completion dialog shows selected task name', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await StatsService.instance.initialize(force: true);
    await TasksService.instance.initialize(force: true);
    await TasksService.instance.addTask('Подготовка презентации');

    await tester.pumpWidget(const VoidApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Начать фокус'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Начать сессию'));
    await tester.pumpAndSettle();
    await _confirmTaskPicker(
      tester,
      taskTitle: 'Подготовка презентации',
    );

    await tester.tap(find.text('Старт'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 21));

    await tester.tap(find.text('Завершить сессию'));
    await tester.pumpAndSettle();

    expect(find.byType(VoidSessionCompleteDialog), findsOneWidget);
    expect(find.text('Подготовка презентации'), findsWidgets);
    expect(find.text('Длительность'), findsOneWidget);
    expect(find.text('21с'), findsWidgets);
    expect(TasksService.instance.tasks.first.totalFocusSeconds, 21);
  });

  testWidgets('tasks screen supports add edit delete complete', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await TasksService.instance.initialize(force: true);

    await tester.pumpWidget(const VoidApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Начать фокус'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Профиль'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Проекты и задачи'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Проекты и задачи'));
    await tester.pumpAndSettle();

    expect(find.text('Нет проектов и задач'), findsOneWidget);
    await tester.tap(find.text('Создать проект'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Спринт 1');
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    expect(find.text('Спринт 1'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add_task_rounded));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'План спринта');
    await tester.tap(find.text('Спринт 1').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();

    expect(find.text('План спринта'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.edit_outlined).last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'План спринта v2');
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    expect(find.text('План спринта v2'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.radio_button_unchecked_rounded));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete_outline_rounded).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Удалить'));
    await tester.pumpAndSettle();
    expect(find.text('Нет задач в проекте'), findsOneWidget);
  });

  testWidgets('deep work mode selector switches timer duration', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const VoidApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Начать фокус'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Фокус'));
    await tester.pumpAndSettle();

    expect(find.text('Режимы фокуса'), findsWidgets);
    expect(find.text('25 мин = Light Focus'), findsOneWidget);
    expect(find.text('50:00'), findsNothing);
    expect(find.text('25:00'), findsOneWidget);

    await tester.tap(find.text('50 мин'));
    await tester.pumpAndSettle();

    expect(find.text('50:00'), findsOneWidget);
    expect(find.text('50 мин = Deep Focus'), findsOneWidget);
    expect(StatsService.instance.data.deepWorkModeMinutes, 50);

    await tester.tap(find.text('90 мин'));
    await tester.pumpAndSettle();

    expect(find.text('90:00'), findsOneWidget);
    expect(find.text('90 мин = Elite Focus'), findsOneWidget);
    expect(StatsService.instance.data.deepWorkModeMinutes, 90);
  });
}
