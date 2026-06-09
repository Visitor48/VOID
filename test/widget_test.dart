import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:void_app/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'completedSessions': 8,
      'totalFocusMinutes': 200,
      'currentStreak': 5,
      'last_active_date': '2026-06-09',
      'daily_activity':
          '{"2026-06-03":15,"2026-06-05":25,"2026-06-07":30,"2026-06-09":25}',
    });
  });
  testWidgets('VOID onboarding screen renders in Russian', (WidgetTester tester) async {
    await tester.pumpWidget(const VoidApp());
    await tester.pumpAndSettle();

    expect(find.text('VOID'), findsOneWidget);
    expect(find.text('Контролируй своё внимание'), findsOneWidget);
    expect(find.text('Начать фокус'), findsOneWidget);
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
    expect(find.text('Последние 7 дней активности'), findsOneWidget);

    await tester.tap(find.text('Профиль'));
    await tester.pumpAndSettle();
    expect(find.text('Пользователь VOID'), findsOneWidget);
  });

  testWidgets('analytics shows empty state when no data', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

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
    expect(VoidAnalyticsStore.instance.isLoading, isFalse);
    expect(VoidAnalyticsStore.instance.hasData, isFalse);
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

  testWidgets('Завершить сессию saves data and shows dialog', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const VoidApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Начать фокус'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Фокус'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Старт'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Завершить сессию'));
    await tester.pumpAndSettle();

    expect(find.text('Сессия завершена'), findsOneWidget);

    expect(VoidAnalyticsStore.instance.data.completedSessions, 1);
    expect(VoidAnalyticsStore.instance.data.totalFocusMinutes, 25);

    await tester.tap(find.text('Готово'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Аналитика'));
    await tester.pumpAndSettle();

    expect(find.text('Всего сессий'), findsOneWidget);
    expect(find.text('Всего часов фокуса'), findsOneWidget);
    expect(find.text('25м'), findsOneWidget);
    expect(VoidAnalyticsStore.instance.hasData, isTrue);
  });
}
