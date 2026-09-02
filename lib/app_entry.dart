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
  static const _onboardingKey = 'jamiyati_pro_onboarding_v4_done';
  final JamiyatiController controller = JamiyatiController();

  bool _bootDone = false;
  bool _showOnboarding = false;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final minimumSplash = Future<void>.delayed(const Duration(milliseconds: 900));
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
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: buildTheme(),
      home: Directionality(
        textDirection: ui.TextDirection.rtl,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 360),
          child: !_bootDone
              ? const _Splash(key: ValueKey('splash'))
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

class _Splash extends StatefulWidget {
  const _Splash({super.key});

  @override
  State<_Splash> createState() => _SplashState();
}

class _SplashState extends State<_Splash> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 760),
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
                  center: Alignment(0.72, -0.75),
                  radius: 1.28,
                  colors: [Color(0xFF1C4C3F), Color(0xFF0C211B), AC.bg],
                  stops: [0, 0.48, 1],
                ),
              ),
            ),
          ),
          Positioned(
            top: -70,
            left: -55,
            child: _Glow(color: AC.teal, size: 220),
          ),
          Positioned(
            bottom: -100,
            right: -70,
            child: _Glow(color: AC.amber, size: 250),
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
                        width: 108,
                        height: 108,
                        decoration: BoxDecoration(
                          gradient: AC.heroGrad,
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.12),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AC.primary.withValues(alpha: 0.20),
                              blurRadius: 38,
                              offset: const Offset(0, 15),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.account_balance_wallet_rounded,
                          color: Colors.white,
                          size: 54,
                        ),
                      ),
                    ),
                    const SizedBox(height: 25),
                    const Text(
                      'جمعيتي Pro',
                      style: TextStyle(
                        color: AC.text,
                        fontSize: 35,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 7),
                    const Text(
                      'كل دور واضح، وكل دفعة محسوبة',
                      style: TextStyle(
                        color: AC.muted,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: AC.teal.withValues(alpha: 0.09),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: AC.teal.withValues(alpha: 0.22),
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
                    const SizedBox(height: 32),
                    const SizedBox(
                      width: 25,
                      height: 25,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AC.primary,
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
  final PageController _controller = PageController();
  int _page = 0;

  static const pages = <_Benefit>[
    _Benefit(
      icon: Icons.person_add_alt_1_rounded,
      eyebrow: 'ابدأ بسهولة',
      title: 'أضف أعضاء جمعيتك ورتّب الأدوار',
      body:
          'اختر الأعضاء من هاتفك أو أضفهم يدويًا. أول عضو تضيفه له الدور الأول، ويمكنك تغيير الترتيب قبل البداية.',
      accent: AC.primary,
      items: [
        'إضافة من جهات اتصال الهاتف',
        'بطاقة واضحة لكل عضو',
        'ترتيب الأدوار بالسحب قبل البداية',
      ],
    ),
    _Benefit(
      icon: Icons.payments_rounded,
      eyebrow: 'الدفعات',
      title: 'اعرف فورًا من دفع ومن بقي',
      body:
          'تابع قسط كل عضو وتاريخ الدفع، واعرف المتأخرين بسرعة عندما يحين موعد الاستحقاق.',
      accent: AC.teal,
      items: [
        'مدفوع، بانتظار الدفع، أو متأخر',
        'تاريخ واضح لكل دفعة',
        'تذكير سريع عبر واتساب',
      ],
    ),
    _Benefit(
      icon: Icons.how_to_reg_rounded,
      eyebrow: 'الدور والتسليم',
      title: 'صاحب الدور ومبلغ التسليم أمامك',
      body:
          'تعرف من يستلم هذا الدور، وتسجل التسليم كاملًا أو جزئيًا، وتبدّل الأدوار القادمة عند الحاجة.',
      accent: AC.amber,
      items: [
        'صاحب الدور ظاهر بوضوح',
        'تسليم كامل أو جزئي مع التاريخ',
        'تبديل الأدوار القادمة بسهولة',
      ],
    ),
    _Benefit(
      icon: Icons.description_rounded,
      eyebrow: 'الكشوفات والأمان',
      title: 'احفظ سجلك وشاركه وقت ما تحتاج',
      body:
          'أنشئ كشفًا واضحًا، احفظ نسخة احتياطية، واحمِ التطبيق برمز الدخول أو البصمة — وكل المزايا مجانية.',
      accent: AC.violet,
      items: [
        'كشوفات PDF وصور جاهزة للمشاركة',
        'نسخة احتياطية واستعادة',
        'مجاني بالكامل بدون اشتراك',
      ],
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_page == pages.length - 1) {
      widget.onFinish();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 340),
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
                  colors: [Color(0xFF0D211C), AC.bg],
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
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
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
                          Icons.account_balance_wallet_rounded,
                          color: Colors.white,
                          size: 20,
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
                      if (_page < pages.length - 1)
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
                    controller: _controller,
                    itemCount: pages.length,
                    onPageChanged: (value) => setState(() => _page = value),
                    itemBuilder: (_, index) => _BenefitPage(data: pages[index]),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          pages.length,
                          (index) => AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            width: index == _page ? 27 : 8,
                            height: 8,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              color: index == _page ? AC.primary : AC.border,
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _next,
                          icon: Icon(
                            _page == pages.length - 1
                                ? Icons.check_rounded
                                : Icons.arrow_forward_rounded,
                          ),
                          label: Text(
                            _page == pages.length - 1
                                ? 'ابدأ استخدام جمعيتي Pro'
                                : 'التالي',
                          ),
                        ),
                      ),
                      if (_page == pages.length - 1) ...[
                        const SizedBox(height: 9),
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

class _BenefitPage extends StatelessWidget {
  const _BenefitPage({required this.data});

  final _Benefit data;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight - 36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: data.accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(23),
                  border: Border.all(
                    color: data.accent.withValues(alpha: 0.18),
                  ),
                ),
                child: Icon(data.icon, color: data.accent, size: 37),
              ),
              const SizedBox(height: 24),
              Text(
                data.eyebrow,
                style: TextStyle(
                  color: data.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                data.title,
                style: const TextStyle(
                  fontSize: 27,
                  height: 1.3,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                data.body,
                style: const TextStyle(
                  color: AC.muted,
                  fontSize: 13,
                  height: 1.75,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: AC.card,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AC.borderSoft),
                ),
                child: Column(
                  children: data.items
                      .map(
                        (item) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          child: Row(
                            children: [
                              Container(
                                width: 27,
                                height: 27,
                                decoration: BoxDecoration(
                                  color: data.accent.withValues(alpha: 0.09),
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
                                  item,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Benefit {
  const _Benefit({
    required this.icon,
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.accent,
    required this.items,
  });

  final IconData icon;
  final String eyebrow;
  final String title;
  final String body;
  final Color accent;
  final List<String> items;
}

class _Glow extends StatelessWidget {
  const _Glow({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.06),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.08),
              blurRadius: 70,
              spreadRadius: 18,
            ),
          ],
        ),
      ),
    );
  }
}
