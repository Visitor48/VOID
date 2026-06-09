import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Color kVoidBackground = Color(0xFF07070A);
const Color kVoidAccent = Color(0xFF8B5CF6);

const _kCompletedSessions = 'completedSessions';
const _kTotalFocusMinutes = 'totalFocusMinutes';
const _kCurrentStreak = 'currentStreak';
const _kLastActiveDate = 'last_active_date';
const _kDailyActivity = 'daily_activity';

const _kDayLabels = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

class VoidDayActivity {
  const VoidDayActivity({
    required this.date,
    required this.focusMinutes,
  });

  final DateTime date;
  final int focusMinutes;

  String get dayLabel => _kDayLabels[date.weekday - 1];
}

class VoidAnalyticsData {
  const VoidAnalyticsData({
    required this.completedSessions,
    required this.totalFocusMinutes,
    required this.currentStreak,
    required this.last7Days,
  });

  final int completedSessions;
  final int totalFocusMinutes;
  final int currentStreak;
  final List<VoidDayActivity> last7Days;

  static const empty = VoidAnalyticsData(
    completedSessions: 0,
    totalFocusMinutes: 0,
    currentStreak: 0,
    last7Days: [],
  );
}

String formatFocusMinutes(int totalMinutes) {
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  if (hours > 0) {
    return '${hours}ч ${minutes}м';
  }
  return '${minutes}м';
}

class VoidAnalyticsStore extends ChangeNotifier {
  VoidAnalyticsStore._();

  static final VoidAnalyticsStore instance = VoidAnalyticsStore._();

  VoidAnalyticsData data = VoidAnalyticsData.empty;
  bool isLoading = false;
  Future<void>? _loadFuture;

  bool get hasData => data.completedSessions > 0;

  static VoidAnalyticsData _emptyData() => VoidAnalyticsData(
        completedSessions: 0,
        totalFocusMinutes: 0,
        currentStreak: 0,
        last7Days: _buildLast7Days({}),
      );

  static Future<SharedPreferences?> _getPrefs() async {
    try {
      return await SharedPreferences.getInstance();
    } catch (_) {
      return null;
    }
  }

  static String _dateKey(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static List<VoidDayActivity> _buildLast7Days(Map<String, int> activity) {
    final today = DateTime.now();
    return List<VoidDayActivity>.generate(7, (index) {
      final date = DateTime(today.year, today.month, today.day)
          .subtract(Duration(days: 6 - index));
      final key = _dateKey(date);
      return VoidDayActivity(
        date: date,
        focusMinutes: activity[key] ?? 0,
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

  int _readCompletedSessions(SharedPreferences prefs) {
    return prefs.getInt(_kCompletedSessions) ??
        prefs.getInt('total_sessions') ??
        0;
  }

  int _readTotalFocusMinutes(SharedPreferences prefs) {
    return prefs.getInt(_kTotalFocusMinutes) ??
        ((prefs.getInt('total_focus_seconds') ?? 0) ~/ 60);
  }

  int _readCurrentStreak(SharedPreferences prefs) {
    return prefs.getInt(_kCurrentStreak) ??
        prefs.getInt('current_streak') ??
        0;
  }

  Future<void> _loadInternal() async {
    isLoading = true;
    notifyListeners();

    try {
      final prefs = await _getPrefs();
      if (prefs == null) {
        data = _emptyData();
        print('[VOID] Loaded: prefs unavailable, using empty analytics');
        return;
      }

      final activity = _parseActivity(prefs.getString(_kDailyActivity));
      final completedSessions = _readCompletedSessions(prefs);
      final totalFocusMinutes = _readTotalFocusMinutes(prefs);
      final currentStreak = _readCurrentStreak(prefs);

      data = VoidAnalyticsData(
        completedSessions: completedSessions,
        totalFocusMinutes: totalFocusMinutes,
        currentStreak: currentStreak,
        last7Days: _buildLast7Days(activity),
      );

      print(
        '[VOID] Loaded: completedSessions=$completedSessions, '
        'totalFocusMinutes=$totalFocusMinutes, currentStreak=$currentStreak',
      );
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> recordCompletedSession({required int focusMinutes}) async {
    final prefs = await _getPrefs();
    if (prefs == null) {
      print('[VOID] Save failed: SharedPreferences unavailable');
      return false;
    }

    try {
      final today = _dateKey(DateTime.now());
      final yesterday =
          _dateKey(DateTime.now().subtract(const Duration(days: 1)));

      final completedSessions = _readCompletedSessions(prefs) + 1;
      final totalFocusMinutes = _readTotalFocusMinutes(prefs) + focusMinutes;

      final activity = _parseActivity(prefs.getString(_kDailyActivity));
      activity[today] = (activity[today] ?? 0) + focusMinutes;

      final lastActive = prefs.getString(_kLastActiveDate);
      int streak = _readCurrentStreak(prefs);
      if (lastActive == today) {
        streak = streak == 0 ? 1 : streak;
      } else if (lastActive == yesterday) {
        streak += 1;
      } else {
        streak = 1;
      }

      await prefs.setInt(_kCompletedSessions, completedSessions);
      await prefs.setInt(_kTotalFocusMinutes, totalFocusMinutes);
      await prefs.setInt(_kCurrentStreak, streak);
      await prefs.setString(_kLastActiveDate, today);
      await prefs.setString(_kDailyActivity, jsonEncode(activity));

      print(
        '[VOID] Saved: completedSessions=$completedSessions, '
        'totalFocusMinutes=$totalFocusMinutes, currentStreak=$streak',
      );
    } catch (e) {
      print('[VOID] Save failed: $e');
      return false;
    }

    _loadFuture = null;
    await _loadInternal();
    return true;
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
  try {
    await SharedPreferences.getInstance();
  } catch (_) {
    // Plugin may be unavailable after hot reload; analytics falls back to empty.
  }
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
    VoidAnalyticsStore.instance.scheduleLoad(force: true);
  }

  void _onTabSelected(int index) {
    if (index == _currentIndex) return;
    HapticFeedback.selectionClick();
    setState(() => _currentIndex = index);
    if (index == 0 || index == 2) {
      VoidAnalyticsStore.instance.load(force: true);
    }
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
    VoidAnalyticsStore.instance.scheduleLoad(force: true);
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
            listenable: VoidAnalyticsStore.instance,
            builder: (context, _) {
              final analytics = VoidAnalyticsStore.instance.data;

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
                          VoidStatCard(
                            label: 'Всего сессий',
                            value: '${analytics.completedSessions}',
                            prominent: true,
                          ),
                          SizedBox(height: m.gapM),
                          VoidStatCard(
                            label: 'Время фокуса',
                            value: formatFocusMinutes(
                              analytics.totalFocusMinutes,
                            ),
                          ),
                          SizedBox(height: m.gapM),
                          VoidStatCard(
                            label: 'Серия дней',
                            value: '${analytics.currentStreak}',
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
    VoidAnalyticsStore.instance.scheduleLoad(force: true);
  }

  @override
  Widget build(BuildContext context) {
    final m = VoidMetrics.of(context);

    return VoidTabScaffold(
      glowCenter: const Alignment(0, -0.5),
      child: SafeArea(
        child: ListenableBuilder(
          listenable: VoidAnalyticsStore.instance,
          builder: (context, _) {
            final store = VoidAnalyticsStore.instance;
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
                      value: formatFocusMinutes(analytics.totalFocusMinutes),
                    ),
                    SizedBox(height: m.gapM),
                    VoidStatCard(
                      label: 'Текущая серия дней',
                      value: '${analytics.currentStreak}',
                    ),
                    SizedBox(height: m.gapM),
                    VoidActivityChart(days: analytics.last7Days),
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
    final maxMinutes = days.fold<int>(
      0,
      (max, day) => day.focusMinutes > max ? day.focusMinutes : max,
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
                                  day.focusMinutes,
                                  maxMinutes,
                                  maxBarHeight,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(6),
                                  gradient: day.focusMinutes > 0
                                  ? LinearGradient(
                                      begin: Alignment.bottomCenter,
                                      end: Alignment.topCenter,
                                      colors: [
                                        kVoidAccent.withValues(alpha: 0.7),
                                        kVoidAccent,
                                      ],
                                    )
                                  : null,
                              color: day.focusMinutes == 0
                                  ? Colors.white.withValues(alpha: 0.06)
                                  : null,
                              boxShadow: day.focusMinutes > 0
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

class VoidProfileTab extends StatelessWidget {
  const VoidProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    final m = VoidMetrics.of(context);

    return VoidTabScaffold(
      glowCenter: const Alignment(0, -0.4),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: m.paddingH),
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
              const VoidStatCard(
                label: 'Всего сессий',
                value: '42',
              ),
              SizedBox(height: m.gapM),
              const VoidStatCard(
                label: 'Серия дней',
                value: '5',
              ),
            ],
          ),
        ),
      ),
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
    if (!_isRunning || _isPaused || _isCompleted) return;
    if (_remainingSeconds <= 1) {
      setState(() => _remainingSeconds = 0);
      unawaited(_finishSession());
    } else {
      setState(() => _remainingSeconds--);
    }
  }

  Future<void> _finishSession() async {
    if (_sessionSaved || _isCompleted) return;

    _timer?.cancel();
    setState(() {
      _isRunning = false;
      _isPaused = false;
      _isCompleted = true;
      _remainingSeconds = 0;
    });
    HapticFeedback.mediumImpact();

    await VoidAnalyticsStore.instance.recordCompletedSession(
      focusMinutes: _sessionMinutes,
    );
    _sessionSaved = true;

    if (mounted) await _showCompletionDialog();
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
      _isRunning = false;
      _isPaused = false;
      _isCompleted = false;
      _sessionSaved = false;
    });
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
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.95),
            fontWeight: FontWeight.w500,
          ),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Expanded(
                    child: _SessionStat(
                      label: 'Сессий сегодня',
                      value: '0',
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 28,
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                  const Expanded(
                    child: _SessionStat(
                      label: 'Отвлечений',
                      value: '0',
                    ),
                  ),
                ],
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

class _SessionStat extends StatelessWidget {
  const _SessionStat({required this.label, required this.value});

  final String label;
  final String value;

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
