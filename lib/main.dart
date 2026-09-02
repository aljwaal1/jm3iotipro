import 'dart:io';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'app_theme.dart';
import 'association_creator.dart';
import 'controller.dart';
import 'currency_picker.dart';
import 'details_page.dart';
import 'developer_contact.dart';
import 'models.dart';
import 'report_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const JamiyatiApp());
}

class JamiyatiApp extends StatefulWidget {
  const JamiyatiApp({super.key});

  @override
  State<JamiyatiApp> createState() => _JamiyatiAppState();
}

class _JamiyatiAppState extends State<JamiyatiApp> {
  final JamiyatiController controller = JamiyatiController();

  @override
  void initState() {
    super.initState();
    controller.load();
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
        child: HomePage(controller: controller),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.controller});

  final JamiyatiController controller;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  int tab = 0;
  final TextEditingController pinController = TextEditingController();
  DateTime? _pausedAt;

  JamiyatiController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    c.addListener(_refresh);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    c.removeListener(_refresh);
    pinController.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _pausedAt = DateTime.now();
    }
    if (state == AppLifecycleState.resumed && c.pinConfigured && _pausedAt != null) {
      if (DateTime.now().difference(_pausedAt!) > const Duration(seconds: 30)) {
        c.lock();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!c.loaded) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AC.primary),
              SizedBox(height: 14),
              Text('جاري تجهيز جمعيتي Pro...', style: TextStyle(color: AC.muted)),
            ],
          ),
        ),
      );
    }
    if (!c.unlocked) return _lockScreen();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 39,
              height: 39,
              decoration: BoxDecoration(
                gradient: AC.heroGrad,
                borderRadius: BorderRadius.circular(13),
                boxShadow: [
                  BoxShadow(
                    color: AC.primary.withValues(alpha: 0.16),
                    blurRadius: 18,
                    offset: const Offset(0, 7),
                  ),
                ],
              ),
              child: const Icon(
                Icons.account_balance_wallet_rounded,
                color: Colors.white,
                size: 21,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('جمعيتي Pro'),
                  Text(
                    'كل دور واضح، وكل دفعة محسوبة',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AC.muted,
                      fontSize: 9,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'جمعية جديدة',
            onPressed: _createAssociation,
            icon: const Icon(Icons.add_circle_rounded, color: AC.primary, size: 27),
          ),
          if (c.pinConfigured)
            IconButton(
              tooltip: 'قفل الآن',
              onPressed: c.lock,
              icon: const Icon(Icons.lock_outline_rounded, color: AC.muted, size: 20),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: IndexedStack(
        index: tab,
        children: [
          _dashboard(),
          _associationsPage(),
          _statementsPage(),
          _settingsPage(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (value) => setState(() => tab = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.space_dashboard_rounded),
            label: 'الرئيسية',
          ),
          NavigationDestination(
            icon: Icon(Icons.groups_2_rounded),
            label: 'الجمعيات',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_rounded),
            label: 'الكشوفات',
          ),
          NavigationDestination(
            icon: Icon(Icons.tune_rounded),
            label: 'الإعدادات',
          ),
        ],
      ),
    );
  }

  Widget _lockScreen() {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.7, -0.8),
                  radius: 1.2,
                  colors: [
                    AC.primary.withValues(alpha: 0.12),
                    AC.bg,
                    AC.bg,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Spacer(),
                  Center(
                    child: Container(
                      width: 94,
                      height: 94,
                      decoration: BoxDecoration(
                        gradient: AC.heroGrad,
                        borderRadius: BorderRadius.circular(29),
                        boxShadow: [
                          BoxShadow(
                            color: AC.primary.withValues(alpha: 0.20),
                            blurRadius: 30,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet_rounded,
                        color: Colors.white,
                        size: 46,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'جمعيتي Pro',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'بيانات جمعيتك محمية',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AC.muted),
                  ),
                  const SizedBox(height: 28),
                  TextField(
                    controller: pinController,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 12,
                    style: const TextStyle(
                      fontSize: 20,
                      letterSpacing: 7,
                      fontWeight: FontWeight.w800,
                    ),
                    decoration: const InputDecoration(
                      counterText: '',
                      labelText: 'رمز الدخول',
                      prefixIcon: Icon(Icons.password_rounded),
                    ),
                    onSubmitted: (_) => _unlockPin(),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _unlockPin,
                    icon: const Icon(Icons.lock_open_rounded),
                    label: const Text('فتح التطبيق'),
                  ),
                  if (c.biometricAvailable) ...[
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: c.unlockWithBiometric,
                      icon: const Icon(Icons.fingerprint_rounded, color: AC.cyan),
                      label: const Text('استخدام البصمة أو قفل الجهاز'),
                    ),
                  ],
                  const Spacer(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _unlockPin() async {
    final ok = await c.unlockWithPin(pinController.text);
    if (ok) {
      pinController.clear();
    } else {
      _msg('رمز الدخول غير صحيح');
    }
  }

  Widget _dashboard() {
    final live = c.associations
        .where((a) => !a.archived && c.stageOf(a) != AssociationStage.completed)
        .toList();
    final active = c.associations
        .where((a) => c.stageOf(a) == AssociationStage.active)
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        live.isEmpty ? _emptyHero() : _liveHero(active),
        if (live.isNotEmpty) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _statCard(
                  'جارية الآن',
                  '${active.length}',
                  Icons.play_circle_fill_rounded,
                  AC.teal,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: _statCard(
                  'بانتظار',
                  '${c.totalWaiting}',
                  Icons.hourglass_top_rounded,
                  AC.amber,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: _statCard(
                  'متأخرون',
                  '${c.totalLate}',
                  Icons.error_rounded,
                  AC.rose,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          _sectionHeader('الجمعيات الحالية', 'كل ما يحتاج متابعتك الآن'),
          ...live.map(_associationCard),
        ],
        if (c.associations.any(
          (a) => c.stageOf(a) == AssociationStage.completed && !a.archived,
        )) ...[
          const SizedBox(height: 12),
          _sectionHeader('مكتملة', 'يمكنك إبقاؤها أو نقلها إلى الأرشيف'),
          ...c.associations
              .where(
                (a) =>
                    c.stageOf(a) == AssociationStage.completed && !a.archived,
              )
              .map(_associationCard),
        ],
      ],
    );
  }

  Widget _emptyHero() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AC.heroGrad,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AC.primary.withValues(alpha: 0.14),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              'ابدأ بسهولة',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'جمعيتك مرتبة\nمن أول عضو لآخر دور',
            style: TextStyle(
              color: Colors.white,
              fontSize: 27,
              height: 1.25,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'أضف الأعضاء، تابع الدفعات، واعرف صاحب الدور والتسليم من مكان واحد.',
            style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.6),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF12382E),
            ),
            onPressed: _createAssociation,
            icon: const Icon(Icons.add_rounded),
            label: const Text('إنشاء أول جمعية'),
          ),
        ],
      ),
    );
  }

  Widget _liveHero(List<Association> active) {
    final expected = c.totalExpectedThisRound;
    final collected = c.totalCollectedThisRound;
    final ratio = expected <= 0 ? 0.0 : (collected / expected).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: AC.heroGrad,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AC.primary.withValues(alpha: 0.12),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.insights_rounded, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text(
                'نظرة سريعة',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '${ReportService.n(collected)} ${c.currency}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 29,
              fontWeight: FontWeight.w900,
            ),
          ),
          const Text(
            'تم تحصيله في الأدوار الجارية',
            style: TextStyle(color: Colors.white70, fontSize: 11),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.14),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'من ${ReportService.n(expected)} ${c.currency}',
                style: const TextStyle(color: Colors.white70, fontSize: 10),
              ),
              Text(
                '${(ratio * 100).round()}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AC.card,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: AC.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(title, style: const TextStyle(color: AC.muted, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _associationsPage() {
    final current = c.associations
        .where((a) => !a.archived && c.stageOf(a) != AssociationStage.completed)
        .toList();
    final completed = c.associations
        .where((a) => !a.archived && c.stageOf(a) == AssociationStage.completed)
        .toList();
    final archived = c.archivedAssociations;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        _sectionHeader(
          'الجمعيات',
          'الحالية أولًا، والأرشيف محفوظ بعيدًا عن الزحام',
          action: TextButton.icon(
            onPressed: _createAssociation,
            icon: const Icon(Icons.add_rounded),
            label: const Text('جديدة'),
          ),
        ),
        if (current.isEmpty && completed.isEmpty && archived.isEmpty)
          _emptyState(
            'لا توجد جمعيات',
            'أنشئ جمعية وأضف أعضاءها بالترتيب الذي تريده.',
            Icons.groups_2_rounded,
          )
        else ...[
          ...current.map(_associationCard),
          if (completed.isNotEmpty) ...[
            const SizedBox(height: 15),
            _sectionHeader('مكتملة', 'جمعيات انتهت أدوارها'),
            ...completed.map(_associationCard),
          ],
          if (archived.isNotEmpty) ...[
            const SizedBox(height: 15),
            _sectionHeader('الأرشيف', 'سجلات محفوظة للرجوع إليها'),
            ...archived.map(_associationCard),
          ],
        ],
      ],
    );
  }

  Widget _associationCard(Association a) {
    final round = c.displayRound(a);
    final stage = c.stageOf(a);
    final receiver = a.receiverFor(round);
    final paid = c.paidCount(a, round);
    final late = c.lateCount(a, round);
    final waiting = c.waitingCount(a, round);
    final collected = c.collectedAmount(a, round);
    final progress = a.roundTotal <= 0
        ? 0.0
        : (collected / a.roundTotal).clamp(0.0, 1.0);
    final stageColor = stage == AssociationStage.active
        ? AC.teal
        : stage == AssociationStage.upcoming
            ? AC.primary
            : stage == AssociationStage.completed
                ? AC.violet
                : AC.hint;

    return GestureDetector(
      onTap: () => _openDetails(a),
      child: Container(
        margin: const EdgeInsets.only(bottom: 11),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: AC.cardGrad,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: stage == AssociationStage.active
                ? AC.primary.withValues(alpha: 0.24)
                : AC.borderSoft,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 16,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 47,
                  height: 47,
                  decoration: BoxDecoration(
                    color: stageColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    a.name.isEmpty ? 'ج' : a.name.characters.first,
                    style: TextStyle(
                      color: stageColor,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        a.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'الدور ${round + 1}/${a.monthsCount} • ${c.roundLabel(a, round)}',
                        style: const TextStyle(color: AC.muted, fontSize: 10),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: stageColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    c.stageLabel(a),
                    style: TextStyle(
                      color: stageColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_left_rounded, color: AC.hint, size: 20),
              ],
            ),
            const SizedBox(height: 13),
            Row(
              children: [
                Expanded(
                  child: _mini(
                    Icons.person_pin_circle_rounded,
                    'صاحب الدور',
                    receiver?.name ?? '-',
                    AC.violet,
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: _mini(
                    Icons.check_circle_rounded,
                    'دفعوا',
                    '$paid/${a.members.length}',
                    AC.teal,
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: _mini(
                    Icons.schedule_rounded,
                    'انتظار/تأخير',
                    '$waiting / $late',
                    late > 0 ? AC.rose : AC.amber,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 11),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: AC.borderSoft,
                valueColor: AlwaysStoppedAnimation<Color>(
                  late > 0 ? AC.amber : AC.teal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mini(IconData icon, String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AC.muted, fontSize: 8),
          ),
        ],
      ),
    );
  }

  Widget _statementsPage() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: AC.successGrad,
            borderRadius: BorderRadius.circular(25),
          ),
          child: const Row(
            children: [
              Icon(Icons.description_rounded, color: Colors.white, size: 34),
              SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'كشوفات واضحة وجاهزة للمشاركة',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'PDF عربي • صورة • نص مع الدفع والتسليم',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _sectionHeader('تقارير سريعة', 'للمتابعة اليومية'),
        _actionTile(
          Icons.analytics_rounded,
          'ملخص عام',
          'عدد الجمعيات والتحصيل والمتأخرين',
          AC.primary,
          () => _copy(_generalReport()),
        ),
        _actionTile(
          Icons.warning_amber_rounded,
          'كشف المتأخرين',
          'من تجاوزوا موعد الاستحقاق',
          AC.rose,
          () => _copy(_lateReport()),
        ),
        const SizedBox(height: 15),
        _sectionHeader('كشوفات الجمعيات', 'افتح الجمعية واختر الدور الذي تريده'),
        if (c.associations.isEmpty)
          _emptyState(
            'لا توجد بيانات',
            'أنشئ جمعية أولًا لتظهر كشوفاتها.',
            Icons.receipt_long_rounded,
          )
        else
          ...c.associations.map((a) {
            final round = c.displayRound(a);
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AC.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AC.borderSoft),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AC.teal.withValues(alpha: 0.09),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(
                      Icons.receipt_long_rounded,
                      color: AC.teal,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          a.name,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        Text(
                          'الدور ${round + 1} • ${a.receiverFor(round)?.name ?? '-'}',
                          style: const TextStyle(color: AC.muted, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'PDF',
                    onPressed: () => _run(
                      () => ReportService.exportPdf(c, a, round),
                    ),
                    icon: const Icon(Icons.picture_as_pdf_rounded, color: AC.rose),
                  ),
                  IconButton(
                    tooltip: 'صورة',
                    onPressed: () => _run(
                      () => ReportService.exportPng(c, a, round),
                    ),
                    icon: const Icon(Icons.image_rounded, color: AC.violet),
                  ),
                  IconButton(
                    tooltip: 'فتح',
                    onPressed: () => _openDetails(a),
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: AC.hint,
                      size: 17,
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _settingsPage() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        _sectionHeader('الإعدادات', 'خيارات مهمة بدون تعقيد'),
        _actionTile(
          Icons.currency_exchange_rounded,
          'العملة',
          c.currency,
          AC.teal,
          _changeCurrency,
        ),
        _actionTile(
          Icons.lock_rounded,
          'رمز الدخول',
          c.pinConfigured ? 'مفعّل • مع دعم قفل الجهاز' : 'غير مفعّل',
          AC.primary,
          _changePin,
        ),
        const SizedBox(height: 15),
        _sectionHeader('النسخ الاحتياطي', 'احفظ بياناتك وانقلها لهاتف آخر'),
        _actionTile(
          Icons.upload_file_rounded,
          'تصدير نسخة احتياطية',
          'ملف يشمل الجمعيات والدفعات والتسليم',
          AC.amber,
          _exportBackup,
        ),
        _actionTile(
          Icons.settings_backup_restore_rounded,
          'استعادة نسخة احتياطية',
          'اختر ملف جمعيتي Pro',
          AC.violet,
          _restoreBackup,
        ),
        const SizedBox(height: 15),
        _sectionHeader('الدعم', 'اقتراح، مشكلة أو ملاحظة'),
        _actionTile(
          Icons.support_agent_rounded,
          'مراسلة المطور',
          developerEmail,
          AC.cyan,
          _contactDeveloper,
        ),
        const SizedBox(height: 15),
        Container(
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            color: AC.card,
            borderRadius: BorderRadius.circular(21),
            border: Border.all(color: AC.borderSoft),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.verified_user_outlined, color: AC.teal, size: 19),
                  SizedBox(width: 8),
                  Text(
                    'جمعيتي Pro 3.0',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Text(
                'تابع أعضاء جمعيتك ودفعاتهم وأدوارهم والتسليم، وأنشئ كشوفات ونسخًا احتياطية. التطبيق مجاني بالكامل.',
                style: TextStyle(color: AC.muted, fontSize: 11, height: 1.65),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sectionHeader(String title, String subtitle, {Widget? action}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(color: AC.muted, fontSize: 10),
                ),
              ],
            ),
          ),
          if (action != null) action,
        ],
      ),
    );
  }

  Widget _actionTile(
    IconData icon,
    String title,
    String subtitle,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 9),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AC.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AC.borderSoft),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(color: AC.muted, fontSize: 10),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_left_rounded, color: AC.hint),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(String title, String subtitle, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: AC.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AC.borderSoft),
      ),
      child: Column(
        children: [
          Icon(icon, color: AC.primary.withValues(alpha: 0.50), size: 45),
          const SizedBox(height: 11),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AC.muted, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Future<void> _openDetails(Association a) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Directionality(
          textDirection: ui.TextDirection.rtl,
          child: DetailsPage(controller: c, association: a),
        ),
      ),
    );
  }

  Future<void> _createAssociation() async {
    final association = await Navigator.push<Association>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => Directionality(
          textDirection: ui.TextDirection.rtl,
          child: CreateAssociationPage(controller: c),
        ),
      ),
    );
    if (association == null) return;
    await c.addAssociation(association);
    _msg('✓ تم إنشاء الجمعية');
    await _openDetails(association);
  }

  String _generalReport() {
    final active = c.associations
        .where((a) => c.stageOf(a) == AssociationStage.active)
        .length;
    final upcoming = c.associations
        .where((a) => c.stageOf(a) == AssociationStage.upcoming)
        .length;
    final completed = c.associations
        .where((a) => c.stageOf(a) == AssociationStage.completed)
        .length;
    return 'تقرير جمعيتي Pro\n'
        '${DateFormat('yyyy/MM/dd').format(DateTime.now())}\n\n'
        'نشطة: $active\n'
        'قادمة: $upcoming\n'
        'مكتملة: $completed\n'
        'مؤرشفة: ${c.archivedAssociations.length}\n'
        'بانتظار الدفع الآن: ${c.totalWaiting}\n'
        'متأخرون الآن: ${c.totalLate}\n'
        'المتوقع في الأدوار الجارية: ${ReportService.n(c.totalExpectedThisRound)} ${c.currency}\n'
        'المحصل: ${ReportService.n(c.totalCollectedThisRound)} ${c.currency}';
  }

  String _lateReport() {
    final b = StringBuffer(
      'كشف المتأخرين - جمعيتي Pro\n${DateFormat('yyyy/MM/dd').format(DateTime.now())}\n',
    );
    var found = false;
    for (final a in c.associations) {
      if (c.stageOf(a) != AssociationStage.active) continue;
      final round = c.displayRound(a);
      final lateMembers = a.members
          .where(
            (m) =>
                c.contributionStage(a, round, m) == ContributionStage.late,
          )
          .toList();
      if (lateMembers.isEmpty) continue;
      found = true;
      b.writeln('\n${a.name} - الدور ${round + 1}');
      for (final member in lateMembers) {
        b.writeln(
          '- ${member.name}: ${ReportService.n(a.amount)} ${c.currency}',
        );
      }
    }
    if (!found) b.writeln('\n✓ لا يوجد متأخرون حاليًا');
    return b.toString();
  }

  Future<void> _changeCurrency() async {
    final value = await showCurrencyPicker(context, current: c.currency);
    if (value == null || value.trim().isEmpty) return;
    await c.setCurrency(value.trim());
  }

  Future<void> _changePin() async {
    final text = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(c.pinConfigured ? 'تغيير رمز الدخول' : 'تفعيل رمز الدخول'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: text,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 12,
              decoration: const InputDecoration(
                labelText: 'رمز جديد',
                helperText: 'اتركه فارغًا لإلغاء القفل',
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'رمز الدخول لا يدخل ضمن النسخة الاحتياطية.',
              style: TextStyle(color: AC.muted, fontSize: 10),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, text.text),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    text.dispose();
    if (value == null) return;
    await c.setPin(value);
    _msg(
      value.trim().isEmpty
          ? 'تم إلغاء رمز الدخول'
          : '✓ تم حفظ رمز الدخول بأمان',
    );
  }

  Future<void> _contactDeveloper() async {
    final ok = await contactDeveloper();
    if (!ok) {
      await Clipboard.setData(const ClipboardData(text: developerEmail));
      _msg('تعذر فتح تطبيق البريد، تم نسخ بريد المطور');
    }
  }

  Future<void> _exportBackup() async {
    try {
      final dir = await getTemporaryDirectory();
      final stamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      final file = File('${dir.path}/Jamiyati_Pro_Backup_$stamp.json');
      await file.writeAsString(c.backupJson());
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'نسخة احتياطية من جمعيتي Pro',
      );
    } catch (e) {
      _msg('تعذر إنشاء النسخة الاحتياطية: $e');
    }
  }

  Future<void> _restoreBackup() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      final path = result?.files.single.path;
      if (path == null) return;
      final raw = await File(path).readAsString();
      final ok = await _confirm(
        'استعادة النسخة؟',
        'ستحل بيانات الملف محل البيانات الحالية. رمز الدخول لن يتغير.',
      );
      if (!ok) return;
      await c.restoreFromJson(raw);
      _msg('✓ تمت استعادة النسخة الاحتياطية');
    } catch (e) {
      _msg('تعذر استعادة النسخة: $e');
    }
  }

  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    _msg('✓ تم النسخ');
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      _msg('تعذر إكمال العملية: $e');
    }
  }

  Future<bool> _confirm(String title, String body) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(title),
            content: Text(body),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('تأكيد'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _msg(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}
