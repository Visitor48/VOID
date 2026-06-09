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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'completedSessions': 8,
      'totalFocusMinutes': 200,
      'totalDistractions': 16,
      'session_distractions_history': '[2,2,2,2,2,2,2,2]',
      'currentStreak': 5,
      'last_active_date': '2026-06-09',
      'daily_activity':
          '{"2026-06-03":15,"2026-06-05":25,"2026-06-07":30,"2026-06-09":25}',
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
    );
    expect(locked.every((achievement) => !achievement.isUnlocked), isTrue);
    expect(locked.map((achievement) => achievement.title), contains('Первая сессия'));

    final unlocked = buildAchievements(
      completedSessions: 10,
      totalFocusSeconds: 3600,
      currentStreak: 7,
      preventedDistractionMinutes: 100,
    );
    expect(unlocked.every((achievement) => achievement.isUnlocked), isTrue);
    expect(unlocked.length, 6);
  });

  test('computeFocusScore subtracts one point per distraction', () {
    expect(computeFocusScore(0), 100);
    expect(computeFocusScore(3), 97);
    expect(computeFocusScore(100), 0);
  });

  test('formatDailyGoalProgress formats minutes', () {
    expect(formatDailyGoalProgress(54, 60), '54 / 60 минут');
    expect(formatDailyGoalProgress(0, 60), '0 / 60 минут');
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

    expect(find.text('Цель дня'), findsOneWidget);
    expect(find.text('54 / 60 минут'), findsOneWidget);
    expect(StatsService.instance.data.dailyGoalMinutes, 60);
    expect(StatsService.instance.data.todayFocusMinutes, 54);
    expect(StatsService.instance.data.dailyGoalProgress, closeTo(0.9, 0.01));
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
    expect(find.text('Серия дней'), findsWidgets);
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
    expect(find.text('8'), findsOneWidget);
    expect(find.text('Всего часов фокуса'), findsOneWidget);
    expect(find.text('3ч 20м'), findsOneWidget);
    expect(find.text('Текущая серия дней'), findsOneWidget);
    expect(find.text('Всего отвлечений'), findsOneWidget);
    expect(find.text('Среднее отвлечений за сессию'), findsOneWidget);
    expect(find.text('Фокус-счёт'), findsOneWidget);
    expect(find.text('98'), findsWidgets);
    expect(find.text('2'), findsWidgets);
    expect(find.text('Последние 7 дней активности'), findsOneWidget);

    await tester.tap(find.text('Профиль'));
    await tester.pumpAndSettle();
    expect(find.text('Пользователь VOID'), findsOneWidget);
    expect(find.text('8'), findsWidgets);
    expect(find.text('3ч 20м'), findsWidgets);
    expect(find.text('История сессий'), findsOneWidget);
    expect(find.text('Достижения'), findsOneWidget);
    expect(find.text('3/6'), findsOneWidget);
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
    expect(find.text('98'), findsWidgets);
    expect(find.text('2'), findsWidgets);

    await tester.tap(find.text('Готово'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Аналитика'));
    await tester.pumpAndSettle();

    expect(find.text('Всего отвлечений'), findsOneWidget);
    expect(find.text('Среднее отвлечений за сессию'), findsOneWidget);
    expect(StatsService.instance.data.distractions, 2);
    expect(StatsService.instance.data.averageDistractionsPerSession, 2);
    expect(StatsService.instance.data.averageFocusScore, 98);
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
    expect(find.text('XP'), findsOneWidget);
    expect(find.text('+4'), findsOneWidget);
    expect(StatsService.instance.data.sessionHistory.length, 1);
    expect(StatsService.instance.data.sessionHistory.first.focusSeconds, 21);
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

    expect(find.text('21с'), findsOneWidget);
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
    expect(find.text('+10'), findsOneWidget);

    expect(StatsService.instance.data.completedSessions, 1);
    expect(StatsService.instance.data.totalFocusSeconds, 60);

    await tester.tap(find.text('Готово'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Аналитика'));
    await tester.pumpAndSettle();

    expect(find.text('Всего сессий'), findsOneWidget);
    expect(find.text('Всего часов фокуса'), findsOneWidget);
    expect(find.text('1м'), findsOneWidget);
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
}
