import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const Color kVoidBackground = Color(0xFF07070A);
const Color kVoidAccent = Color(0xFF8B5CF6);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => const VoidHomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kVoidBackground,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const VoidAmbientGlow(),
          SafeArea(
            child: FadeTransition(
              opacity: _fade,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  children: [
                    const Spacer(flex: 3),
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: kVoidAccent.withValues(alpha: 0.4),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: kVoidAccent.withValues(alpha: 0.3),
                            blurRadius: 24,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: kVoidAccent,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'VOID',
                      style: TextStyle(
                        fontSize: 72,
                        fontWeight: FontWeight.w200,
                        letterSpacing: 24,
                        color: Colors.white.withValues(alpha: 0.95),
                        shadows: [
                          Shadow(
                            color: kVoidAccent.withValues(alpha: 0.5),
                            blurRadius: 30,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Контролируй своё внимание',
                      style: TextStyle(
                        fontSize: 15,
                        letterSpacing: 1.5,
                        color: Colors.white.withValues(alpha: 0.45),
                      ),
                    ),
                    const Spacer(flex: 4),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: FilledButton(
                        onPressed: _openHome,
                        style: FilledButton.styleFrom(
                          backgroundColor: kVoidAccent,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'Начать фокус',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 48),
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

class VoidHomeScreen extends StatelessWidget {
  const VoidHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kVoidBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Главная',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            letterSpacing: 1,
            color: Colors.white.withValues(alpha: 0.7),
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: Colors.white.withValues(alpha: 0.6),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const VoidAmbientGlow(center: Alignment(0, -0.6)),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          Text(
                            'Добро пожаловать',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w300,
                              color: Colors.white.withValues(alpha: 0.95),
                            ),
                          ),
                          const SizedBox(height: 28),
                          const VoidStatCard(
                            label: 'Индекс концентрации',
                            value: '78%',
                            prominent: true,
                          ),
                          const SizedBox(height: 16),
                          const VoidStatCard(
                            label: 'Время фокуса сегодня',
                            value: '2ч 15м',
                          ),
                          const SizedBox(height: 16),
                          const VoidStatCard(
                            label: 'Серия дней',
                            value: '5',
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: FilledButton(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => const VoidFocusSessionScreen(),
                          ),
                        );
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: kVoidAccent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Начать сессию',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class VoidFocusSessionScreen extends StatefulWidget {
  const VoidFocusSessionScreen({super.key});

  @override
  State<VoidFocusSessionScreen> createState() => _VoidFocusSessionScreenState();
}

class _VoidFocusSessionScreenState extends State<VoidFocusSessionScreen> {
  static const int _totalSeconds = 25 * 60;

  int _remainingSeconds = _totalSeconds;
  bool _isPaused = false;
  bool _isCompleted = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

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
    if (_isPaused || _isCompleted) return;
    if (_remainingSeconds <= 1) {
      setState(() => _remainingSeconds = 0);
      _completeSession();
    } else {
      setState(() => _remainingSeconds--);
    }
  }

  void _completeSession() {
    _timer?.cancel();
    setState(() => _isCompleted = true);
    HapticFeedback.mediumImpact();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _showCompletionDialog();
    });
  }

  void _togglePause() {
    if (_isCompleted) return;
    HapticFeedback.lightImpact();
    setState(() => _isPaused = !_isPaused);
  }

  void _finishSession() {
    HapticFeedback.lightImpact();
    _timer?.cancel();
    Navigator.pop(context);
  }

  Future<void> _showCompletionDialog() async {
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
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.95),
            fontWeight: FontWeight.w500,
          ),
        ),
        content: Text(
          'Отличная работа! Вы завершили сессию глубокого фокуса.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              Navigator.pop(context);
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
    final progress = _remainingSeconds / _totalSeconds;

    return Scaffold(
      backgroundColor: kVoidBackground,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const VoidAmbientGlow(center: Alignment(0, 0.1)),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 32),
                  Text(
                    'Глубокий фокус',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w300,
                      letterSpacing: 1,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: 280,
                    height: 280,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox.expand(
                          child: CircularProgressIndicator(
                            value: progress,
                            strokeWidth: 3,
                            backgroundColor: kVoidAccent.withValues(alpha: 0.12),
                            valueColor: const AlwaysStoppedAnimation(kVoidAccent),
                            strokeCap: StrokeCap.round,
                          ),
                        ),
                        Container(
                          width: 220,
                          height: 220,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: kVoidAccent.withValues(alpha: 0.2),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: kVoidAccent.withValues(alpha: 0.15),
                                blurRadius: 40,
                              ),
                            ],
                          ),
                        ),
                        Text(
                          _formatTime(_remainingSeconds),
                          style: TextStyle(
                            fontSize: 56,
                            fontWeight: FontWeight.w200,
                            letterSpacing: 4,
                            color: Colors.white.withValues(alpha: 0.95),
                            shadows: [
                              Shadow(
                                color: kVoidAccent.withValues(alpha: 0.4),
                                blurRadius: 24,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _SessionStat(label: 'Сессий сегодня', value: '0'),
                      Container(
                        width: 1,
                        height: 32,
                        margin: const EdgeInsets.symmetric(horizontal: 32),
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                      _SessionStat(label: 'Отвлечений', value: '0'),
                    ],
                  ),
                  const SizedBox(height: 40),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isCompleted ? null : _togglePause,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white.withValues(alpha: 0.85),
                            side: BorderSide(
                              color: kVoidAccent.withValues(alpha: 0.4),
                            ),
                            minimumSize: const Size.fromHeight(52),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            _isPaused ? 'Продолжить' : 'Пауза',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _finishSession,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white.withValues(alpha: 0.6),
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.15),
                            ),
                            minimumSize: const Size.fromHeight(52),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            'Завершить',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionStat extends StatelessWidget {
  const _SessionStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.4),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
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
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: 20,
        vertical: prominent ? 28 : 20,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: kVoidAccent.withValues(alpha: prominent ? 0.35 : 0.15),
        ),
        boxShadow: prominent
            ? [
                BoxShadow(
                  color: kVoidAccent.withValues(alpha: 0.12),
                  blurRadius: 24,
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
              fontSize: 13,
              letterSpacing: 0.5,
              color: Colors.white.withValues(alpha: 0.45),
            ),
          ),
          SizedBox(height: prominent ? 12 : 8),
          Text(
            value,
            style: TextStyle(
              fontSize: prominent ? 48 : 32,
              fontWeight: FontWeight.w200,
              color: prominent
                  ? kVoidAccent
                  : Colors.white.withValues(alpha: 0.95),
              shadows: prominent
                  ? [
                      Shadow(
                        color: kVoidAccent.withValues(alpha: 0.4),
                        blurRadius: 20,
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
