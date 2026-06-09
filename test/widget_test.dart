import 'package:flutter_test/flutter_test.dart';
import 'package:void_app/main.dart';

void main() {
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
    expect(find.text('78%'), findsOneWidget);
    expect(find.text('2ч 15м'), findsOneWidget);
    expect(find.text('Начать сессию'), findsOneWidget);
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
    expect(find.text('Пауза'), findsOneWidget);
    expect(find.text('Завершить'), findsOneWidget);
    expect(find.text('Сессий сегодня'), findsOneWidget);
    expect(find.text('Отвлечений'), findsOneWidget);
  });

  testWidgets('countdown ticks and pause works', (WidgetTester tester) async {
    await tester.pumpWidget(const VoidApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Начать фокус'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Начать сессию'));
    await tester.pumpAndSettle();

    await tester.pump(const Duration(seconds: 3));
    expect(find.text('24:57'), findsOneWidget);

    await tester.tap(find.text('Пауза'));
    await tester.pumpAndSettle();
    expect(find.text('Продолжить'), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
    expect(find.text('24:57'), findsOneWidget);
  });
}
