import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_theme.dart';
import 'controller.dart';
import 'main.dart' show HomePage;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const JamiyatiProEntry());
}

class JamiyatiProEntry extends StatefulWidget {
  const JamiyatiProEntry({super.key});

  @override
  State<JamiyatiProEntry> createState() => _JamiyatiProEntryState();
}

class _JamiyatiProEntryState extends State<JamiyatiProEntry> {
  static const _onboardingKey = 'jamiyati_pro_onboarding_v3_done';
  final JamiyatiController controller = JamiyatiController();

  bool _bootDone = false;
  bool _showOnboarding = false;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final minimumSplash = Future<void>.delayed(const Duration(milliseconds: 1050));
    final prefs = await SharedPreferences.getInstance();
    await Future.wait<void>([controller.load(), minimumSplash]);
    if (!mounted) return;
    setState(() {
      _showOnboarding = !(prefs.getBool(_onboardingKey) ?? false);
      _bootDone = true;
    });
  }

  Future<void> _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingKey, true);
    if (!mounted) return;
    setState(() => _showOnboarding = false);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'جمعيتي Pro',
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: buildTheme(),
      home: Directionality(
        textDirection: ui.TextDirection.rtl,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 420),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: !_bootDone
              ? const _PremiumSplash(key: ValueKey('splash'))
              : _showOnboarding
                  ? _Onboarding(
                      key: const ValueKey('onboarding'),
                      onFinish: _finishOnboarding,
                    )
                  : HomePage(
                      key: const ValueKey('home'),
                      controller: controller,
                    ),
        ),
      ),
    );
  }
}

class _PremiumSplash extends StatefulWidget {
  const _PremiumSplash({super.key});

  @override
  State<_PremiumSplash> createState() => _PremiumSplashState();
}

class _PremiumSplashState extends State<_PremiumSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..forward();
    _scale = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0.75, -0.75),
                  radius: 1.25,
                  colors: [Color(0xFF243A86), Color(0xFF0A1230), AC.bg],
                  stops: [0, 0.48, 1],
                ),
              ),
            ),
          ),
          Positioned(
            top: -70,
            left: -50,
            child: _GlowOrb(color: AC.cyan, size: 220, opacity: 0.10),
          ),
          Positioned(
            bottom: -90,
            right: -60,
            child: _GlowOrb(color: AC.violet, size: 260, opacity: 0.10),
          ),
          SafeArea(
            child: Center(
              child: FadeTransition(
                opacity: _fade,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ScaleTransition(
                      scale: _scale,
                      child: Container(
                        width: 112,
                        height: 112,
                        decoration: BoxDecoration(
                          gradient: AC.heroGrad,
                          borderRadius: BorderRadius.circular(34),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.14),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AC.primary.withValues(alpha: 0.35),
                              blurRadius: 42,
                              spreadRadius: 2,
                              offset: const Offset(0, 16),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.savings_rounded,
                          color: Colors.white,
                          size: 58,
                        ),
                      ),
                    ),
                    const SizedBox(height: 26),
                    const Text(
                      'جمعيتي Pro',
                      style: TextStyle(
                        color: AC.text,
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.8,
                      ),
                    ),
                    const SizedBox(height: 7),
                    const Text(
                      'جمعيتك واضحة.. من أول قسط لآخر دور',
                      style: TextStyle(
                        color: AC.muted,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 30),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: AC.teal.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: AC.teal.withValues(alpha: 0.28),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified_rounded, color: AC.teal, size: 16),
                          SizedBox(width: 6),
                          Text(
                            'مجاني بالكامل',
                            style: TextStyle(
                              color: AC.teal,
                              fontWeight: FontWeight.w900,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 34),
                    const SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.6,
                        color: AC.cyan,
                      ),
                    ),
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

class _Onboarding extends StatefulWidget {
  const _Onboarding({super.key, required this.onFinish});
  final Future<void> Function() onFinish;

  @override
  State<_Onboarding> createState() => _OnboardingState();
}

class _OnboardingState extends State<_Onboarding> {
  final PageController _pageController = PageController();
  int _page = 0;

  static const _pages = <_OnboardingData>[
    _OnboardingData(
      icon: Icons.auto_awesome_rounded,
      eyebrow: 'أهلًا بك',
      title: 'جمعيتك.. منظمة من أول يوم',
      body:
          'أنشئ الجمعية، أضف الأعضاء ورتّب أدوار الاستلام قبل البداية، ثم تابع كل شيء من شاشة واحدة واضحة.',
      accent: AC.primary,
      features: [
        'جمعية واحدة أو أكثر عند التداخل',
        'ترتيب واضح للأعضاء والأدوار',
        'حالات قادمة، نشطة، مكتملة ومؤرشفة',
      ],
    ),
    _OnboardingData(
      icon: Icons.payments_rounded,
      eyebrow: 'متابعة الدفعات',
      title: 'اعرف من دفع ومن تأخر',
      body:
          'سجّل دفع كل عضو مع التاريخ، وحدد يوم الاستحقاق ليُفرّق التطبيق تلقائيًا بين بانتظار الدفع والمتأخر.',
      accent: AC.cyan,
      features: [
        'تاريخ دفع لكل عضو',
        'بانتظار الدفع / متأخر / مدفوع',
        'تذكير سريع عبر واتساب',
      ],
    ),
    _OnboardingData(
      icon: Icons.swap_horiz_rounded,
      eyebrow: 'الأدوار والتسليم',
      title: 'مرونة حقيقية بدون تعقيد',
      body:
          'يمكن تبديل الأدوار القادمة عند اتفاق الأعضاء، وتسجيل تسليم مبلغ الجمعية لصاحب الدور دفعة واحدة أو جزئيًا عند الحاجة.',
      accent: AC.violet,
      features: [
        'تبديل الأدوار القادمة',
        'حماية الأدوار التي انتهت',
        'تسجيل مبلغ وتاريخ التسليم',
      ],
    ),
    _OnboardingData(
      icon: Icons.workspace_premium_rounded,
      eyebrow: 'كل الأدوات معك',
      title: 'احترافي.. ومجاني بالكامل',
      body:
          'كشوفات PDF وPNG، نسخ احتياطي واستعادة، قفل آمن وبصمة عند توفرها — وكل هذه المزايا متاحة مجانًا بالكامل.',
      accent: AC.teal,
      features: [
        'PDF وPNG وتقارير واضحة',
        'نسخ احتياطي واستعادة',
        'بدون اشتراك أو رسوم استخدام',
      ],
      freeBadge: true,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _next() {
    if (_page == _pages.length - 1) {
      widget.onFinish();
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF071126), AC.bg],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          gradient: AC.heroGrad,
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: const Icon(
                          Icons.savings_rounded,
                          color: Colors.white,
                          size: 21,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'جمعيتي Pro',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                      const Spacer(),
                      if (_page < _pages.length - 1)
                        TextButton(
                          onPressed: widget.onFinish,
                          child: const Text(
                            'تخطي',
                            style: TextStyle(color: AC.muted),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _pages.length,
                    onPageChanged: (value) => setState(() => _page = value),
                    itemBuilder: (context, index) => _OnboardingPage(
                      data: _pages[index],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 22),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          _pages.length,
                          (index) => AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            width: index == _page ? 28 : 8,
                            height: 8,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              color: index == _page ? AC.primary : AC.border,
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _next,
                          icon: Icon(
                            _page == _pages.length - 1
                                ? Icons.rocket_launch_rounded
                                : Icons.arrow_back_rounded,
                          ),
                          label: Text(
                            _page == _pages.length - 1
                                ? 'ابدأ استخدام جمعيتي Pro'
                                : 'التالي',
                          ),
                        ),
                      ),
                      if (_page == _pages.length - 1) ...[
                        const SizedBox(height: 10),
                        const Text(
                          'مجاني بالكامل • بدون اشتراك أو رسوم استخدام',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AC.teal,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
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

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({required this.data});
  final _OnboardingData data;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 190,
                  height: 190,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: data.accent.withValues(alpha: 0.055),
                  ),
                ),
                Container(
                  width: 126,
                  height: 126,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        data.accent.withValues(alpha: 0.95),
                        AC.primary,
                      ],
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                    ),
                    borderRadius: BorderRadius.circular(40),
                    boxShadow: [
                      BoxShadow(
                        color: data.accent.withValues(alpha: 0.26),
                        blurRadius: 38,
                        offset: const Offset(0, 18),
                      ),
                    ],
                  ),
                  child: Icon(data.icon, color: Colors.white, size: 62),
                ),
              ],
            ),
          ),
          const Spacer(),
          Text(
            data.eyebrow,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: data.accent,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            data.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AC.text,
              fontSize: 28,
              height: 1.25,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            data.body,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AC.muted,
              fontSize: 13,
              height: 1.75,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AC.card.withValues(alpha: 0.78),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AC.borderSoft),
            ),
            child: Column(
              children: [
                ...data.features.map(
                  (feature) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: data.accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Icon(
                            Icons.check_rounded,
                            color: data.accent,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            feature,
                            style: const TextStyle(
                              color: AC.text,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (data.freeBadge) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      gradient: AC.successGrad,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.favorite_rounded, color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'مجاني 100% — كل المزايا متاحة',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}

class _OnboardingData {
  const _OnboardingData({
    required this.icon,
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.accent,
    required this.features,
    this.freeBadge = false,
  });

  final IconData icon;
  final String eyebrow;
  final String title;
  final String body;
  final Color accent;
  final List<String> features;
  final bool freeBadge;
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({
    required this.color,
    required this.size,
    required this.opacity,
  });

  final Color color;
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: opacity),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: opacity),
              blurRadius: size * 0.42,
              spreadRadius: size * 0.08,
            ),
          ],
        ),
      ),
    );
  }
}
