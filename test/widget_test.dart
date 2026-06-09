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
    });
    await StatsService.instance.initialize(force: true);
    await StatsService.instance.load(force: true);
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
    expect(find.text('Уровень'), findsOneWidget);
    expect(find.text('3'), findsWidgets);
    expect(find.text('200 XP'), findsOneWidget);
    expect(find.text('0 / 100 XP'), findsOneWidget);
    expect(find.text('8'), findsWidgets);
    expect(find.text('3ч 20м'), findsWidgets);
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
    await tester.tap(find.text('Начать сессию'));
    await tester.pumpAndSettle();

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
    await tester.tap(find.text('Старт'));
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

    expect(find.text('Отвлечения'), findsOneWidget);
    expect(find.text('Фокус-счёт'), findsWidgets);
    expect(find.text('94'), findsWidgets);
    expect(find.text('2'), findsWidgets);

    await tester.tap(find.text('Готово'));
    await tester.pumpAndSettle();

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
    await tester.tap(find.text('Старт'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 21));
    await tester.tap(find.text('Завершить сессию'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Готово'));
    await tester.pumpAndSettle();

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
    await tester.tap(find.text('Старт'));
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
    await tester.tap(find.text('Начать сессию'));
    await tester.pumpAndSettle();

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
    await tester.tap(find.text('Начать сессию'));
    await tester.pumpAndSettle();
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

    await tester.tap(find.text('Старт'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 21));

    await tester.tap(find.text('Завершить сессию'));
    await tester.pumpAndSettle();

    expect(find.text('21с'), findsWidgets);
    expect(StatsService.instance.data.completedSessions, 1);
    expect(StatsService.instance.data.totalFocusSeconds, 21);

    await tester.tap(find.text('Готово'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Аналитика'));
    await tester.pumpAndSettle();

    expect(find.text('21с'), findsNWidgets(2));
    expect(StatsService.instance.hasData, isTrue);
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

    await tester.tap(find.text('Старт'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 60));

    await tester.tap(find.text('Завершить сессию'));
    await tester.pumpAndSettle();

    expect(find.text('Сессия завершена'), findsOneWidget);
    expect(find.text('Длительность'), findsOneWidget);
    expect(find.text('Отвлечения'), findsOneWidget);
    expect(find.text('Получено XP'), findsOneWidget);
    expect(find.text('1м'), findsWidgets);
    expect(find.text('+1'), findsOneWidget);

    expect(StatsService.instance.data.completedSessions, 1);
    expect(StatsService.instance.data.totalFocusSeconds, 60);

    await tester.tap(find.text('Готово'));
    await tester.pumpAndSettle();

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

    await tester.tap(find.text('Старт'));
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

    await tester.tap(find.text('Старт'));
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

    expect(find.text('Сбросить статистику'), findsOneWidget);
    expect(find.text('Очистить историю сессий'), findsOneWidget);
    expect(find.text('Экспорт данных'), findsOneWidget);
    expect(find.text('Обратная связь'), findsOneWidget);
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

  test('exportData returns JSON with stats', () async {
    final json = await StatsService.instance.exportData();
    final decoded = jsonDecode(json) as Map<String, dynamic>;
    expect(decoded['completedSessions'], 8);
    expect(decoded['totalFocusSeconds'], 12000);
    expect(decoded['appVersion'], '1.0.0');
    expect(decoded['sessionHistory'], isA<List<dynamic>>());
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

  testWidgets('export data action completes without error', (WidgetTester tester) async {
    await _openSettings(tester);
    await tester.tap(find.text('Экспорт данных'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final json = await StatsService.instance.exportData();
    expect(json, contains('"completedSessions"'));
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
}
