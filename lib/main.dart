import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const JamiyatiApp());
}

// ─────────────────────────── COLORS ──────────────────────────────
class AC {
  // Background & surfaces
  static const Color bg       = Color(0xFF0A0F1E);
  static const Color surface  = Color(0xFF111827);
  static const Color card     = Color(0xFF1A2235);
  static const Color card2    = Color(0xFF1F2D44);
  static const Color border   = Color(0xFF2A3A56);

  // Text
  static const Color text     = Color(0xFFF0F4FF);
  static const Color muted    = Color(0xFF8B9DC3);
  static const Color hint     = Color(0xFF4A5A7A);

  // Brand accents
  static const Color primary  = Color(0xFF4F8EF7);  // azure blue
  static const Color teal     = Color(0xFF2DD4BF);  // teal-green
  static const Color amber    = Color(0xFFFBBF24);  // warm amber
  static const Color rose     = Color(0xFFF87171);  // soft red
  static const Color violet   = Color(0xFFA78BFA);  // soft violet

  // Gradients
  static const LinearGradient heroGrad = LinearGradient(
    colors: [Color(0xFF1E3A6E), Color(0xFF0A0F1E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient tealGrad = LinearGradient(
    colors: [Color(0xFF0D9488), Color(0xFF0F766E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

// ─────────────────────────── MODELS ──────────────────────────────
class Member {
  String id, name, phone;
  int turn;

  Member({required this.id, required this.name, required this.phone, required this.turn});

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'phone': phone, 'turn': turn};

  factory Member.fromJson(Map<String, dynamic> j) => Member(
        id: '${j['id'] ?? ''}',
        name: '${j['name'] ?? ''}',
        phone: '${j['phone'] ?? ''}',
        turn: (j['turn'] as num?)?.toInt() ?? 1,
      );
}

class Association {
  String id, name, note;
  double amount;
  int startYear, startMonth, monthsCount;
  List<Member> members;
  bool archived;

  Association({
    required this.id, required this.name, required this.amount,
    required this.startYear, required this.startMonth, required this.monthsCount,
    required this.members, this.note = '', this.archived = false,
  });

  double get monthTotal => amount * members.length;

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'amount': amount, 'startYear': startYear,
    'startMonth': startMonth, 'monthsCount': monthsCount,
    'members': members.map((m) => m.toJson()).toList(),
    'note': note, 'archived': archived,
  };

  factory Association.fromJson(Map<String, dynamic> j) {
    final rawM = j['members'];
    final members = <Member>[];
    if (rawM is List) {
      for (final item in rawM) {
        if (item is Map) members.add(Member.fromJson(Map<String, dynamic>.from(item)));
      }
    }
    return Association(
      id: '${j['id'] ?? ''}', name: '${j['name'] ?? ''}',
      amount: (j['amount'] as num?)?.toDouble() ?? 0,
      startYear: (j['startYear'] as num?)?.toInt() ?? DateTime.now().year,
      startMonth: (j['startMonth'] as num?)?.toInt() ?? DateTime.now().month,
      monthsCount: (j['monthsCount'] as num?)?.toInt() ?? max(1, members.length),
      members: members, note: '${j['note'] ?? ''}', archived: j['archived'] == true,
    );
  }
}

// ─────────────────────────── APP ─────────────────────────────────
class JamiyatiApp extends StatelessWidget {
  const JamiyatiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'جمعيتي',
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AC.bg,
        fontFamily: 'sans-serif',
        colorScheme: ColorScheme.dark(
          surface: AC.card,
          primary: AC.primary,
          secondary: AC.teal,
          error: AC.rose,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AC.bg,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: AC.text,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
          iconTheme: IconThemeData(color: AC.muted),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: AC.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AC.card2,
          labelStyle: const TextStyle(color: AC.muted),
          hintStyle: const TextStyle(color: AC.hint),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AC.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AC.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AC.primary, width: 2),
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: AC.card2,
          selectedColor: AC.primary.withValues(alpha: 0.25),
          labelStyle: const TextStyle(color: AC.text, fontSize: 12),
          side: const BorderSide(color: AC.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: AC.surface,
          indicatorColor: AC.primary.withValues(alpha: 0.18),
          labelTextStyle: WidgetStateProperty.all(
            const TextStyle(color: AC.muted, fontSize: 11),
          ),
        ),
      ),
      home: const Directionality(
        textDirection: ui.TextDirection.rtl,
        child: HomePage(),
      ),
    );
  }
}

// ─────────────────────────── HOME ────────────────────────────────
class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  List<Association> associations = [];
  Set<String> paidKeys = {};
  String currency = 'د.أ';
  String pin = '';
  bool loaded = false;
  bool unlocked = true;
  int tab = 0;
  final pinController = TextEditingController();
  late final AnimationController _fabAnim;

  @override
  void initState() {
    super.initState();
    _fabAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    loadData();
  }

  @override
  void dispose() {
    _fabAnim.dispose();
    pinController.dispose();
    super.dispose();
  }

  // ── Data ──
  Future<void> loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final rawA = prefs.getString('associations') ?? '[]';
    final rawP = prefs.getStringList('paidKeys') ?? [];
    final decoded = jsonDecode(rawA);
    final list = <Association>[];
    if (decoded is List) {
      for (final item in decoded) {
        if (item is Map) list.add(Association.fromJson(Map<String, dynamic>.from(item)));
      }
    }
    setState(() {
      associations = list;
      paidKeys = rawP.toSet();
      currency = prefs.getString('currency') ?? 'د.أ';
      pin = prefs.getString('pin') ?? '';
      unlocked = pin.isEmpty;
      loaded = true;
    });
  }

  Future<void> saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('associations', jsonEncode(associations.map((a) => a.toJson()).toList()));
    await prefs.setStringList('paidKeys', paidKeys.toList());
    await prefs.setString('currency', currency);
    await prefs.setString('pin', pin);
  }

  // ── Helpers ──
  String paidKey(String aId, int mi, String mId) => '$aId-$mi-$mId';
  bool isPaid(Association a, int mi, Member m) => paidKeys.contains(paidKey(a.id, mi, m.id));

  Future<void> setPaid(Association a, int mi, Member m, bool v) async {
    final k = paidKey(a.id, mi, m.id);
    setState(() { v ? paidKeys.add(k) : paidKeys.remove(k); });
    await saveData();
  }

  List<Association> get active => associations.where((a) => !a.archived).toList();
  List<Association> get archived => associations.where((a) => a.archived).toList();

  int currentMonth(Association a) {
    final now = DateTime.now();
    final idx = (now.year - a.startYear) * 12 + (now.month - a.startMonth);
    return idx.clamp(0, max(0, a.monthsCount - 1)).toInt();
  }

  String monthLabel(Association a, int idx) {
    final mn = a.startMonth + idx;
    final y = a.startYear + ((mn - 1) ~/ 12);
    final m = ((mn - 1) % 12) + 1;
    final months = ['يناير','فبراير','مارس','أبريل','مايو','يونيو',
                    'يوليو','أغسطس','سبتمبر','أكتوبر','نوفمبر','ديسمبر'];
    return '${months[m - 1]} $y';
  }

  Member? receiverFor(Association a, int mi) {
    if (a.members.isEmpty) return null;
    final turn = (mi % a.members.length) + 1;
    return a.members.firstWhere((m) => m.turn == turn, orElse: () => a.members.first);
  }

  int paidCount(Association a, int mi) => a.members.where((m) => isPaid(a, mi, m)).length;
  int lateCount(Association a, int mi) => a.members.length - paidCount(a, mi);

  int get totalLate => active.fold(0, (s, a) => s + lateCount(a, currentMonth(a)));
  double get totalMonthly => active.fold(0.0, (s, a) => s + a.monthTotal);

  // ── Build ──
  @override
  Widget build(BuildContext context) {
    if (!loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: AC.primary)));
    }
    if (!unlocked) return _buildLockScreen();

    final pages = [_buildDashboard(), _buildAssociationsPage(), _buildStatementsPage(), _buildSettingsPage()];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AC.primary, AC.teal]),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.savings_rounded, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            const Text('جمعيتي'),
          ],
        ),
        actions: [
          _iconBtn(Icons.add_circle_rounded, openForm, color: AC.primary),
          const SizedBox(width: 8),
        ],
      ),
      body: pages[tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (v) => setState(() => tab = v),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_rounded), label: 'الرئيسية'),
          NavigationDestination(icon: Icon(Icons.groups_rounded), label: 'الجمعيات'),
          NavigationDestination(icon: Icon(Icons.receipt_long_rounded), label: 'الكشوفات'),
          NavigationDestination(icon: Icon(Icons.settings_rounded), label: 'الإعدادات'),
        ],
      ),
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback onTap, {Color color = AC.muted}) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, color: color),
    );
  }

  // ── Lock Screen ──
  Widget _buildLockScreen() {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Center(
                child: Container(
                  width: 88, height: 88,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [AC.primary, AC.teal]),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [BoxShadow(color: AC.primary.withValues(alpha: 0.4), blurRadius: 24, offset: const Offset(0, 8))],
                  ),
                  child: const Icon(Icons.savings_rounded, color: Colors.white, size: 44),
                ),
              ),
              const SizedBox(height: 24),
              const Text('جمعيتي', textAlign: TextAlign.center,
                style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: AC.text, letterSpacing: -1)),
              const SizedBox(height: 6),
              const Text('أدخل كلمة المرور للمتابعة', textAlign: TextAlign.center,
                style: TextStyle(color: AC.muted)),
              const SizedBox(height: 28),
              TextField(
                controller: pinController,
                obscureText: true,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, letterSpacing: 6),
                decoration: const InputDecoration(labelText: 'كلمة المرور', prefixIcon: Icon(Icons.lock_rounded)),
              ),
              const SizedBox(height: 14),
              FilledButton(onPressed: _unlock, child: const Text('دخول', style: TextStyle(fontSize: 16))),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  void _unlock() {
    if (pinController.text.trim() == pin) {
      setState(() => unlocked = true);
    } else {
      _showMsg('كلمة المرور غير صحيحة');
    }
  }

  // ── Dashboard ──
  Widget _buildDashboard() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      children: [
        // Hero banner
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: AC.heroGrad,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AC.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AC.primary.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'جمعيتي Pro',
                  style: TextStyle(color: AC.primary, fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 14),
              const Text('إدارة الجمعيات الشهرية\nبكل سهولة وتنظيم',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AC.text, height: 1.3)),
              const SizedBox(height: 10),
              Text('كشوفات PDF • متابعة الدفعات • تذكير واتساب',
                style: TextStyle(color: AC.muted, fontSize: 13)),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: openForm,
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('جمعية جديدة'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: () => setState(() => tab = 2),
                    icon: const Icon(Icons.receipt_long_rounded, size: 18, color: AC.teal),
                    label: const Text('الكشوفات', style: TextStyle(color: AC.teal)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AC.teal),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Stats row
        Row(children: [
          Expanded(child: _statCard('النشطة', '${active.length}', Icons.play_circle_fill_rounded, AC.primary)),
          const SizedBox(width: 10),
          Expanded(child: _statCard('المتأخرون', '$totalLate', Icons.warning_rounded, AC.amber)),
          const SizedBox(width: 10),
          Expanded(child: _statCard('شهريًا', _fmt(totalMonthly), Icons.payments_rounded, AC.teal)),
        ]),

        const SizedBox(height: 22),

        // Active associations
        _sectionTitle('الجمعيات النشطة'),
        if (active.isEmpty)
          _emptyState('لا توجد جمعيات بعد', 'اضغط + لإنشاء أول جمعية', Icons.savings_rounded)
        else
          ...active.map(_assocCard),
      ],
    );
  }

  // ── Associations Page ──
  Widget _buildAssociationsPage() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      children: [
        Row(children: [
          Expanded(child: _sectionTitle('جميع الجمعيات')),
          _addBtn(),
        ]),
        if (associations.isEmpty)
          _emptyState('لا توجد بيانات', 'أنشئ أول جمعية', Icons.group_add_rounded)
        else ...[
          ...active.map(_assocCard),
          if (archived.isNotEmpty) ...[
            const SizedBox(height: 16),
            Row(children: [
              const Icon(Icons.archive_rounded, color: AC.muted, size: 16),
              const SizedBox(width: 6),
              _sectionTitle('الأرشيف'),
            ]),
            ...archived.map(_assocCard),
          ],
        ],
      ],
    );
  }

  // ── Statements Page ──
  Widget _buildStatementsPage() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      children: [
        // Header info box
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: AC.tealGrad,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 36),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('كشوفات الحساب', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)),
                    SizedBox(height: 4),
                    Text('تصدير PDF أو صورة PNG لكل جمعية',
                      style: TextStyle(color: Color(0xFFCCFBF1), fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Quick copy actions
        _sectionTitle('تقارير سريعة'),
        _actionTile(Icons.copy_all_rounded, 'ملخص عام', 'الجمعيات النشطة والمتأخرين', AC.primary,
          () => _copyText(_generalReport())),
        _actionTile(Icons.warning_amber_rounded, 'كشف المتأخرين', 'أسماء المتأخرين الشهر الحالي', AC.amber,
          () => _copyText(_lateReport())),

        const SizedBox(height: 20),

        _sectionTitle('كشوفات الجمعيات'),
        if (associations.isEmpty)
          _emptyState('لا توجد جمعيات', 'أنشئ جمعية أولاً لتظهر هنا', Icons.receipt_long_rounded)
        else
          ...associations.map((a) => _statementCard(a)),
      ],
    );
  }

  Widget _statementCard(Association a) {
    final mi = currentMonth(a);
    final paid = paidCount(a, mi);
    final total = a.members.length;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AC.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AC.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: AC.teal.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.savings_rounded, color: AC.teal, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                      Text('${monthLabel(a, mi)} • $paid/$total دفعوا',
                        style: const TextStyle(color: AC.muted, fontSize: 12)),
                    ],
                  ),
                ),
                if (a.archived)
                  const Chip(label: Text('مؤرشفة', style: TextStyle(fontSize: 11))),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: _statBtn(Icons.picture_as_pdf_rounded, 'PDF', AC.rose, () => _exportPdf(a))),
                const SizedBox(width: 8),
                Expanded(child: _statBtn(Icons.image_rounded, 'صورة PNG', AC.violet, () => _exportPng(a))),
                const SizedBox(width: 8),
                Expanded(child: _statBtn(Icons.copy_rounded, 'نسخ نص', AC.primary, () => _copyText(_assocReport(a, mi)))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statBtn(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  // ── Settings ──
  Widget _buildSettingsPage() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      children: [
        _sectionTitle('الإعدادات'),
        _actionTile(Icons.paid_rounded, 'العملة', currency, AC.teal, changeCurrency),
        _actionTile(Icons.lock_rounded, 'كلمة المرور', pin.isEmpty ? 'غير مفعلة' : 'مفعلة ●●●●', AC.primary, changePin),
        _actionTile(Icons.backup_rounded, 'نسخ احتياطي', 'نسخ البيانات JSON', AC.amber, _copyBackup),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AC.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AC.border),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.info_outline_rounded, color: AC.muted, size: 16),
                SizedBox(width: 8),
                Text('عن التطبيق', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
              ]),
              SizedBox(height: 8),
              Text('جمعيتي Pro v2.0\nإدارة جمعيات شهرية • كشوفات PDF/PNG • بدون إنترنت',
                style: TextStyle(color: AC.muted, fontSize: 12, height: 1.6)),
            ],
          ),
        ),
      ],
    );
  }

  // ── Association Card ──
  Widget _assocCard(Association a) {
    final mi = currentMonth(a);
    final receiver = receiverFor(a, mi);
    final paid = paidCount(a, mi);
    final late = lateCount(a, mi);
    final progress = a.members.isEmpty ? 0.0 : paid / a.members.length;
    final isFullPaid = a.members.isNotEmpty && late == 0;

    return GestureDetector(
      onTap: () => _openDetails(a),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AC.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isFullPaid ? AC.teal.withValues(alpha: 0.4) : AC.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: AC.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Text(
                        a.name.isNotEmpty ? a.name.substring(0, 1) : 'ج',
                        style: const TextStyle(color: AC.primary, fontSize: 20, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(a.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 2),
                        Text(monthLabel(a, mi), style: const TextStyle(color: AC.muted, fontSize: 12)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${_fmt(a.amount)} $currency',
                        style: const TextStyle(color: AC.teal, fontWeight: FontWeight.w800, fontSize: 15)),
                      const SizedBox(height: 2),
                      if (a.archived)
                        const Text('مؤرشفة', style: TextStyle(color: AC.muted, fontSize: 11))
                      else if (isFullPaid)
                        Row(children: const [
                          Icon(Icons.check_circle_rounded, color: AC.teal, size: 13),
                          SizedBox(width: 3),
                          Text('مكتمل', style: TextStyle(color: AC.teal, fontSize: 11)),
                        ]),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Info row
              Row(
                children: [
                  _badge(Icons.person_rounded, receiver == null ? '-' : receiver.name, AC.primary),
                  const SizedBox(width: 8),
                  _badge(Icons.check_rounded, 'دفع $paid', AC.teal),
                  const SizedBox(width: 8),
                  if (late > 0)
                    _badge(Icons.hourglass_empty_rounded, 'متأخر $late', AC.amber),
                ],
              ),
              const SizedBox(height: 12),
              // Progress
              Stack(
                children: [
                  Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: AC.border,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: progress,
                    child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isFullPaid ? [AC.teal, AC.primary] : [AC.primary, AC.violet],
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // ── UI Helpers ──
  Widget _sectionTitle(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(t, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AC.text)),
  );

  Widget _statCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AC.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AC.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
          Text(title, style: const TextStyle(color: AC.muted, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _emptyState(String title, String sub, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AC.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AC.border),
      ),
      child: Column(
        children: [
          Icon(icon, size: 48, color: AC.primary.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(sub, style: const TextStyle(color: AC.muted, fontSize: 13), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _actionTile(IconData icon, String title, String subtitle, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AC.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AC.border),
        ),
        child: Row(
          children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(color: AC.muted, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_left_rounded, color: AC.hint),
          ],
        ),
      ),
    );
  }

  Widget _addBtn() {
    return TextButton.icon(
      onPressed: openForm,
      icon: const Icon(Icons.add_rounded, size: 16),
      label: const Text('إضافة'),
      style: TextButton.styleFrom(foregroundColor: AC.primary),
    );
  }

  void _showMsg(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AC.card2,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  String _fmt(num v) {
    final f = NumberFormat('#,##0.##');
    return f.format(v);
  }

  // ── Open Details ──
  Future<void> _openDetails(Association a) async {
    await Navigator.push(context, MaterialPageRoute(
      builder: (_) => Directionality(
        textDirection: ui.TextDirection.rtl,
        child: DetailsPage(
          association: a, currency: currency,
          isPaid: isPaid, setPaid: setPaid,
          currentMonth: currentMonth, monthLabel: monthLabel,
          receiverFor: receiverFor, paidCount: paidCount, lateCount: lateCount,
          saveData: saveData, refresh: () => setState(() {}),
          deleteAssociation: _deleteAssoc,
          assocReport: _assocReport,
          exportPdf: _exportPdf,
          exportPng: _exportPng,
          formatNum: _fmt,
        ),
      ),
    ));
    setState(() {});
  }

  // ── Form ──
  Future<void> openForm() async {
    final nameC = TextEditingController();
    final amtC = TextEditingController();
    final monthsC = TextEditingController();
    final membersC = TextEditingController();
    final noteC = TextEditingController();
    final now = DateTime.now();
    final yearC = TextEditingController(text: '${now.year}');
    int selMonth = now.month;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setS) => Directionality(
          textDirection: ui.TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: AC.card,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: const Text('إنشاء جمعية جديدة', style: TextStyle(fontSize: 18)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _field(nameC, 'اسم الجمعية', Icons.savings_rounded),
                  const SizedBox(height: 10),
                  _field(amtC, 'قيمة القسط', Icons.payments_rounded, num: true),
                  const SizedBox(height: 10),
                  _field(monthsC, 'عدد الأشهر', Icons.calendar_month_rounded, num: true),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int>(
                    value: selMonth,
                    dropdownColor: AC.card2,
                    decoration: const InputDecoration(labelText: 'شهر البداية', prefixIcon: Icon(Icons.date_range_rounded)),
                    items: List.generate(12, (i) {
                      final months = ['يناير','فبراير','مارس','أبريل','مايو','يونيو',
                                      'يوليو','أغسطس','سبتمبر','أكتوبر','نوفمبر','ديسمبر'];
                      return DropdownMenuItem(value: i + 1, child: Text(months[i]));
                    }),
                    onChanged: (v) { if (v != null) setS(() => selMonth = v); },
                  ),
                  const SizedBox(height: 10),
                  _field(yearC, 'سنة البداية', Icons.calendar_today_rounded, num: true),
                  const SizedBox(height: 10),
                  TextField(
                    controller: membersC,
                    minLines: 4, maxLines: 8,
                    style: const TextStyle(fontSize: 13),
                    decoration: const InputDecoration(
                      labelText: 'الأعضاء بترتيب الدور',
                      hintText: 'كل سطر عضو (الاسم,الهاتف)\nأحمد,0790000000\nمحمد,',
                      prefixIcon: Icon(Icons.people_rounded),
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _field(noteC, 'ملاحظة (اختياري)', Icons.note_rounded),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حفظ')),
            ],
          ),
        ),
      ),
    );

    if (saved != true) return;

    final members = _parseMembers(membersC.text);
    final name = nameC.text.trim();
    final amt = double.tryParse(amtC.text.trim()) ?? 0;
    final months = int.tryParse(monthsC.text.trim()) ?? members.length;
    final year = int.tryParse(yearC.text.trim()) ?? now.year;

    if (name.isEmpty || amt <= 0 || members.isEmpty) {
      _showMsg('أدخل اسم الجمعية والقسط وعضو واحد على الأقل');
      return;
    }

    setState(() {
      associations.insert(0, Association(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: name, amount: amt,
        startYear: year, startMonth: selMonth,
        monthsCount: max(1, months),
        members: members, note: noteC.text.trim(),
      ));
    });
    await saveData();
    _showMsg('✓ تم حفظ الجمعية');
  }

  TextField _field(TextEditingController c, String label, IconData icon, {bool num = false}) {
    return TextField(
      controller: c,
      keyboardType: num ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
    );
  }

  List<Member> _parseMembers(String raw) {
    final members = <Member>[];
    final lines = raw.split('\n');
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      final parts = line.split(',');
      final name = parts.first.trim();
      final phone = parts.length > 1 ? parts[1].trim() : '';
      if (name.isEmpty) continue;
      members.add(Member(
        id: '${DateTime.now().microsecondsSinceEpoch}-$i',
        name: name, phone: phone, turn: members.length + 1,
      ));
    }
    return members;
  }

  Future<void> _deleteAssoc(Association a) async {
    setState(() {
      associations.removeWhere((x) => x.id == a.id);
      paidKeys.removeWhere((k) => k.startsWith('${a.id}-'));
    });
    await saveData();
  }

  Future<void> changeCurrency() async {
    final c = TextEditingController(text: currency);
    final v = await _simpleInput('العملة', 'مثال: د.أ / ر.س', c);
    if (v == null) return;
    setState(() => currency = v.trim().isEmpty ? 'د.أ' : v.trim());
    await saveData();
  }

  Future<void> changePin() async {
    final c = TextEditingController(text: pin);
    final v = await _simpleInput('كلمة المرور', 'اتركها فارغة للإلغاء', c, obscure: true);
    if (v == null) return;
    setState(() { pin = v.trim(); unlocked = pin.isEmpty; });
    await saveData();
    _showMsg(pin.isEmpty ? 'تم إلغاء كلمة المرور' : '✓ تم حفظ كلمة المرور');
  }

  Future<String?> _simpleInput(String title, String label, TextEditingController c, {bool obscure = false}) {
    return showDialog<String>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: ui.TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AC.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(title),
          content: TextField(controller: c, obscureText: obscure, decoration: InputDecoration(labelText: label)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('حفظ')),
          ],
        ),
      ),
    );
  }

  // ── Reports ──
  String _generalReport() {
    return 'تقرير جمعيتي\n'
        '${DateTime.now().toString().substring(0, 10)}\n'
        'الجمعيات النشطة: ${active.length}\n'
        'الجمعيات المؤرشفة: ${archived.length}\n'
        'المتأخرون الآن: $totalLate\n'
        'إجمالي التحصيل الشهري: ${_fmt(totalMonthly)} $currency';
  }

  String _lateReport() {
    final buf = StringBuffer('كشف المتأخرين\n${DateTime.now().toString().substring(0, 10)}\n');
    for (final a in active) {
      final mi = currentMonth(a);
      buf.writeln('\n${a.name} - ${monthLabel(a, mi)}');
      var hasLate = false;
      for (final m in a.members) {
        if (!isPaid(a, mi, m)) {
          hasLate = true;
          buf.writeln('- ${m.name}: ${_fmt(a.amount)} $currency');
        }
      }
      if (!hasLate) buf.writeln('✓ لا يوجد متأخرون');
    }
    return buf.toString();
  }

  String _assocReport(Association a, int mi) {
    final receiver = receiverFor(a, mi);
    final paid = paidCount(a, mi);
    final buf = StringBuffer();
    buf.writeln('═══════════════════════');
    buf.writeln('كشف جمعية: ${a.name}');
    buf.writeln('═══════════════════════');
    buf.writeln('الشهر: ${monthLabel(a, mi)}');
    buf.writeln('قيمة القسط: ${_fmt(a.amount)} $currency');
    buf.writeln('صاحب الدور: ${receiver?.name ?? '-'}');
    buf.writeln('إجمالي الشهر: ${_fmt(a.monthTotal)} $currency');
    buf.writeln('دفعوا: $paid / ${a.members.length}');
    buf.writeln('───────────────────────');
    buf.writeln('الدفعات:');
    for (final m in a.members) {
      final p = isPaid(a, mi, m);
      buf.writeln('${p ? '✓' : '✗'} ${m.turn}. ${m.name}');
    }
    if (a.note.trim().isNotEmpty) {
      buf.writeln('───────────────────────');
      buf.writeln('ملاحظة: ${a.note}');
    }
    return buf.toString();
  }

  Future<void> _copyText(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    _showMsg('✓ تم النسخ');
  }

  Future<void> _copyBackup() async {
    final raw = jsonEncode({
      'associations': associations.map((a) => a.toJson()).toList(),
      'paidKeys': paidKeys.toList(),
      'currency': currency,
    });
    await Clipboard.setData(ClipboardData(text: raw));
    _showMsg('✓ تم نسخ النسخة الاحتياطية');
  }

  // ── PDF Export ──
  Future<void> _exportPdf(Association a) async {
    _showMsg('جاري إنشاء PDF...');
    try {
      final mi = currentMonth(a);
      final pdf = pw.Document();
      final receiver = receiverFor(a, mi);
      final paid = paidCount(a, mi);
      final late = lateCount(a, mi);

      // Colors for PDF
      const primaryColor = PdfColor.fromInt(0xFF4F8EF7);
      const bgColor = PdfColor.fromInt(0xFF0A0F1E);
      const cardColor = PdfColor.fromInt(0xFF1A2235);
      const tealColor = PdfColor.fromInt(0xFF2DD4BF);
      const amberColor = PdfColor.fromInt(0xFFFBBF24);
      const textColor = PdfColor.fromInt(0xFFF0F4FF);
      const mutedColor = PdfColor.fromInt(0xFF8B9DC3);

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          textDirection: pw.TextDirection.rtl,
          margin: const pw.EdgeInsets.all(32),
          build: (ctx) => [
            // Header
            pw.Container(
              padding: const pw.EdgeInsets.all(20),
              decoration: pw.BoxDecoration(
                color: bgColor,
                borderRadius: pw.BorderRadius.circular(16),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('كشف حساب جمعية',
                        style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: textColor)),
                      pw.SizedBox(height: 4),
                      pw.Text(a.name,
                        style: pw.TextStyle(fontSize: 16, color: primaryColor, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 4),
                      pw.Text('الشهر: ${monthLabel(a, mi)}',
                        style: pw.TextStyle(fontSize: 12, color: mutedColor)),
                    ],
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: pw.BoxDecoration(
                      color: cardColor,
                      borderRadius: pw.BorderRadius.circular(12),
                    ),
                    child: pw.Column(
                      children: [
                        pw.Text('إجمالي الشهر', style: pw.TextStyle(color: mutedColor, fontSize: 10)),
                        pw.SizedBox(height: 4),
                        pw.Text('${_fmt(a.monthTotal)} $currency',
                          style: pw.TextStyle(color: tealColor, fontSize: 18, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 16),

            // Stats row
            pw.Row(children: [
              _pdfStat('صاحب الدور', receiver?.name ?? '-', primaryColor, cardColor, textColor),
              pw.SizedBox(width: 8),
              _pdfStat('دفعوا', '$paid', tealColor, cardColor, textColor),
              pw.SizedBox(width: 8),
              _pdfStat('متأخرون', '$late', late == 0 ? tealColor : amberColor, cardColor, textColor),
              pw.SizedBox(width: 8),
              _pdfStat('قيمة القسط', '${_fmt(a.amount)} $currency', primaryColor, cardColor, textColor),
            ]),
            pw.SizedBox(height: 20),

            // Progress bar
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('نسبة التحصيل', style: pw.TextStyle(color: mutedColor, fontSize: 11)),
                    pw.Text(
                      a.members.isEmpty ? '0%' : '${(paid / a.members.length * 100).round()}%',
                      style: pw.TextStyle(color: textColor, fontSize: 11, fontWeight: pw.FontWeight.bold),
                    ),
                  ],
                ),
                pw.SizedBox(height: 6),
                pw.Container(
                  height: 8,
                  decoration: pw.BoxDecoration(
                    color: a.members.isEmpty || paid == 0 ? cardColor : tealColor,
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 20),

            // Members table
            pw.Text('دفعات الأعضاء',
              style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold, color: textColor)),
            pw.SizedBox(height: 10),
            pw.Table(
              border: pw.TableBorder.all(color: const PdfColor.fromInt(0xFF2A3A56), width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(0.5),
                1: const pw.FlexColumnWidth(2),
                2: const pw.FlexColumnWidth(2),
                3: const pw.FlexColumnWidth(1.5),
              },
              children: [
                // Header
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: cardColor),
                  children: [
                    _pdfCell('#', isHeader: true, textColor: textColor),
                    _pdfCell('اسم العضو', isHeader: true, textColor: textColor),
                    _pdfCell('رقم الهاتف', isHeader: true, textColor: textColor),
                    _pdfCell('الحالة', isHeader: true, textColor: textColor),
                  ],
                ),
                // Rows
                ...a.members.map((m) {
                  final p = isPaid(a, mi, m);
                  return pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: m.turn % 2 == 0 ? const PdfColor.fromInt(0xFF0F1828) : bgColor,
                    ),
                    children: [
                      _pdfCell('${m.turn}', textColor: mutedColor),
                      _pdfCell(m.name, textColor: textColor),
                      _pdfCell(m.phone.isEmpty ? '-' : m.phone, textColor: mutedColor),
                      _pdfCell(p ? '✓ دفع' : '✗ لم يدفع',
                        textColor: p ? tealColor : amberColor, bold: true),
                    ],
                  );
                }),
              ],
            ),

            // Note
            if (a.note.trim().isNotEmpty) ...[
              pw.SizedBox(height: 16),
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: cardColor,
                  borderRadius: pw.BorderRadius.circular(10),
                  border: pw.Border.all(color: const PdfColor.fromInt(0xFF2A3A56)),
                ),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('ملاحظة: ', style: pw.TextStyle(color: primaryColor, fontWeight: pw.FontWeight.bold, fontSize: 12)),
                    pw.Expanded(child: pw.Text(a.note, style: pw.TextStyle(color: mutedColor, fontSize: 12))),
                  ],
                ),
              ),
            ],

            // Footer
            pw.SizedBox(height: 20),
            pw.Divider(color: const PdfColor.fromInt(0xFF2A3A56)),
            pw.SizedBox(height: 8),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('تم إنشاؤه بتطبيق جمعيتي',
                  style: pw.TextStyle(color: mutedColor, fontSize: 10)),
                pw.Text(DateTime.now().toString().substring(0, 16),
                  style: pw.TextStyle(color: mutedColor, fontSize: 10)),
              ],
            ),
          ],
        ),
      );

      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename: 'كشف_${a.name}_${monthLabel(a, mi)}.pdf',
      );
    } catch (e) {
      _showMsg('خطأ في إنشاء PDF: $e');
    }
  }

  pw.Widget _pdfStat(String title, String value, PdfColor color, PdfColor bg, PdfColor textColor) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(color: bg, borderRadius: pw.BorderRadius.circular(10)),
        child: pw.Column(
          children: [
            pw.Text(value, style: pw.TextStyle(color: color, fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 3),
            pw.Text(title, style: pw.TextStyle(color: const PdfColor.fromInt(0xFF8B9DC3), fontSize: 9)),
          ],
        ),
      ),
    );
  }

  pw.Widget _pdfCell(String text, {bool isHeader = false, PdfColor? textColor, bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(
          fontSize: isHeader ? 11 : 10,
          fontWeight: (isHeader || bold) ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: textColor ?? const PdfColor.fromInt(0xFFF0F4FF),
        ),
      ),
    );
  }

  // ── PNG Export ──
  Future<void> _exportPng(Association a) async {
    _showMsg('جاري إنشاء الصورة...');
    try {
      final mi = currentMonth(a);
      final receiver = receiverFor(a, mi);
      final paid = paidCount(a, mi);
      final late = lateCount(a, mi);
      final progress = a.members.isEmpty ? 0.0 : paid / a.members.length;

      final controller = ScreenshotController();

      final widget = Directionality(
        textDirection: ui.TextDirection.rtl,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            backgroundColor: AC.bg,
            body: SingleChildScrollView(
              child: _buildStatementWidget(a, mi, receiver, paid, late, progress),
            ),
          ),
        ),
      );

      final bytes = await controller.captureFromWidget(
        widget,
        pixelRatio: 2.5,
      );

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/كشف_${a.name}.png');
      await file.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'كشف جمعية ${a.name} - ${monthLabel(a, mi)}',
      );
    } catch (e) {
      _showMsg('خطأ في إنشاء الصورة: $e');
    }
  }

  Widget _buildStatementWidget(Association a, int mi, Member? receiver, int paid, int late, double progress) {
    return Container(
      width: 420,
      padding: const EdgeInsets.all(24),
      color: AC.bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: AC.heroGrad,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AC.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [AC.primary, AC.teal]),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.savings_rounded, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('كشف حساب جمعية',
                          style: TextStyle(color: AC.muted, fontSize: 12)),
                        Text(a.name,
                          style: const TextStyle(color: AC.text, fontSize: 18, fontWeight: FontWeight.w900)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(monthLabel(a, mi),
                      style: const TextStyle(color: AC.primary, fontWeight: FontWeight.w700, fontSize: 14)),
                    Text('${_fmt(a.monthTotal)} $currency',
                      style: const TextStyle(color: AC.teal, fontWeight: FontWeight.w900, fontSize: 18)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Stats
          Row(children: [
            _pngStat('صاحب الدور', receiver?.name ?? '-', AC.primary),
            const SizedBox(width: 8),
            _pngStat('دفعوا', '$paid/${a.members.length}', AC.teal),
            const SizedBox(width: 8),
            _pngStat('متأخرون', '$late', late == 0 ? AC.teal : AC.amber),
            const SizedBox(width: 8),
            _pngStat('القسط', '${_fmt(a.amount)} $currency', AC.violet),
          ]),
          const SizedBox(height: 14),

          // Progress
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('نسبة التحصيل', style: TextStyle(color: AC.muted, fontSize: 11)),
                  Text('${(progress * 100).round()}%',
                    style: const TextStyle(color: AC.text, fontSize: 11, fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 6),
              Stack(children: [
                Container(height: 8, decoration: BoxDecoration(color: AC.card2, borderRadius: BorderRadius.circular(4))),
                FractionallySizedBox(
                  widthFactor: progress,
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [AC.primary, AC.teal]),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ]),
            ],
          ),
          const SizedBox(height: 16),

          // Members list
          const Text('دفعات الأعضاء',
            style: TextStyle(color: AC.text, fontSize: 14, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: AC.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AC.border),
            ),
            child: Column(
              children: a.members.asMap().entries.map((entry) {
                final idx = entry.key;
                final m = entry.value;
                final p = isPaid(a, mi, m);
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    border: idx < a.members.length - 1
                      ? const Border(bottom: BorderSide(color: AC.border, width: 0.5))
                      : null,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 30, height: 30,
                        decoration: BoxDecoration(
                          color: p ? AC.teal.withValues(alpha: 0.15) : AC.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text('${m.turn}',
                            style: TextStyle(color: p ? AC.teal : AC.amber, fontWeight: FontWeight.w900, fontSize: 12)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(m.name,
                          style: const TextStyle(color: AC.text, fontWeight: FontWeight.w700, fontSize: 13)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: p ? AC.teal.withValues(alpha: 0.15) : AC.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(p ? Icons.check_circle_rounded : Icons.hourglass_empty_rounded,
                              color: p ? AC.teal : AC.amber, size: 12),
                            const SizedBox(width: 4),
                            Text(p ? 'دفع' : 'لم يدفع',
                              style: TextStyle(color: p ? AC.teal : AC.amber, fontSize: 11, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),

          // Note
          if (a.note.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AC.card2,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AC.border),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.note_rounded, color: AC.primary, size: 14),
                  const SizedBox(width: 8),
                  Expanded(child: Text(a.note, style: const TextStyle(color: AC.muted, fontSize: 12))),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Footer
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('تطبيق جمعيتي', style: TextStyle(color: AC.hint, fontSize: 10)),
              Text(DateTime.now().toString().substring(0, 16), style: const TextStyle(color: AC.hint, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pngStat(String title, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AC.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AC.border),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w900)),
            const SizedBox(height: 3),
            Text(title, style: const TextStyle(color: AC.muted, fontSize: 9), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────── DETAILS PAGE ────────────────────────
class DetailsPage extends StatefulWidget {
  const DetailsPage({
    super.key,
    required this.association,
    required this.currency,
    required this.isPaid,
    required this.setPaid,
    required this.currentMonth,
    required this.monthLabel,
    required this.receiverFor,
    required this.paidCount,
    required this.lateCount,
    required this.saveData,
    required this.refresh,
    required this.deleteAssociation,
    required this.assocReport,
    required this.exportPdf,
    required this.exportPng,
    required this.formatNum,
  });

  final Association association;
  final String currency;
  final bool Function(Association, int, Member) isPaid;
  final Future<void> Function(Association, int, Member, bool) setPaid;
  final int Function(Association) currentMonth;
  final String Function(Association, int) monthLabel;
  final Member? Function(Association, int) receiverFor;
  final int Function(Association, int) paidCount;
  final int Function(Association, int) lateCount;
  final Future<void> Function() saveData;
  final VoidCallback refresh;
  final Future<void> Function(Association) deleteAssociation;
  final String Function(Association, int) assocReport;
  final Future<void> Function(Association) exportPdf;
  final Future<void> Function(Association) exportPng;
  final String Function(num) formatNum;

  @override
  State<DetailsPage> createState() => _DetailsPageState();
}

class _DetailsPageState extends State<DetailsPage> {
  late int selMonth;

  @override
  void initState() {
    super.initState();
    selMonth = widget.currentMonth(widget.association);
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.association;
    final receiver = widget.receiverFor(a, selMonth);
    final paid = widget.paidCount(a, selMonth);
    final late = widget.lateCount(a, selMonth);
    final total = a.members.length;
    final progress = total == 0 ? 0.0 : paid / total;

    return Scaffold(
      appBar: AppBar(
        title: Text(a.name),
        actions: [
          // Export PDF
          IconButton(
            onPressed: () => widget.exportPdf(a),
            icon: const Icon(Icons.picture_as_pdf_rounded, color: AC.rose),
            tooltip: 'تصدير PDF',
          ),
          // Export PNG
          IconButton(
            onPressed: () => widget.exportPng(a),
            icon: const Icon(Icons.image_rounded, color: AC.violet),
            tooltip: 'تصدير صورة',
          ),
          // Copy text
          IconButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: widget.assocReport(a, selMonth)));
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('✓ تم نسخ الكشف'),
                    backgroundColor: AC.card2,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                );
              }
            },
            icon: const Icon(Icons.copy_rounded, color: AC.muted),
          ),
          PopupMenuButton<String>(
            color: AC.card2,
            onSelected: _handleMenu,
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'archive',
                child: Text(a.archived ? 'إلغاء الأرشفة' : 'أرشفة'),
              ),
              const PopupMenuItem(value: 'delete', child: Text('حذف الجمعية', style: TextStyle(color: AC.rose))),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          // Summary card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: AC.heroGrad,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AC.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.monthLabel(a, selMonth),
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 4),
                          Text('صاحب الدور: ${receiver?.name ?? '-'}',
                            style: const TextStyle(color: AC.primary, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('${widget.formatNum(a.monthTotal)} ${widget.currency}',
                          style: const TextStyle(color: AC.teal, fontSize: 16, fontWeight: FontWeight.w900)),
                        Text('إجمالي الشهر', style: const TextStyle(color: AC.muted, fontSize: 11)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(children: [
                  _mini('دفعوا', '$paid', AC.teal),
                  const SizedBox(width: 8),
                  _mini('متأخرون', '$late', late == 0 ? AC.teal : AC.amber),
                  const SizedBox(width: 8),
                  _mini('المحصل', widget.formatNum(paid * a.amount), AC.primary),
                ]),
                const SizedBox(height: 12),
                // Progress
                Stack(children: [
                  Container(height: 6, decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(3))),
                  FractionallySizedBox(
                    widthFactor: progress,
                    child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [AC.primary, AC.teal]),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ]),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Export buttons row
          Row(children: [
            Expanded(child: _exportBtn(Icons.picture_as_pdf_rounded, 'PDF', AC.rose, () => widget.exportPdf(a))),
            const SizedBox(width: 8),
            Expanded(child: _exportBtn(Icons.image_rounded, 'صورة PNG', AC.violet, () => widget.exportPng(a))),
          ]),

          const SizedBox(height: 14),

          // Month chips
          SizedBox(
            height: 42,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: a.monthsCount,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (_, idx) => ChoiceChip(
                selected: selMonth == idx,
                label: Text(widget.monthLabel(a, idx), style: const TextStyle(fontSize: 11)),
                onSelected: (_) => setState(() => selMonth = idx),
              ),
            ),
          ),

          const SizedBox(height: 14),

          // Members
          const Text('دفعات الأعضاء',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),

          Container(
            decoration: BoxDecoration(
              color: AC.card,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AC.border),
            ),
            child: Column(
              children: a.members.asMap().entries.map((entry) {
                final idx = entry.key;
                final m = entry.value;
                final p = widget.isPaid(a, selMonth, m);
                return Container(
                  decoration: BoxDecoration(
                    border: idx < a.members.length - 1
                      ? const Border(bottom: BorderSide(color: AC.border, width: 0.5))
                      : null,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(
                      children: [
                        Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: p ? AC.teal.withValues(alpha: 0.15) : AC.amber.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text('${m.turn}',
                              style: TextStyle(
                                color: p ? AC.teal : AC.amber,
                                fontWeight: FontWeight.w900, fontSize: 14,
                              )),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(m.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                              Text(p ? 'تم الدفع' : 'لم يدفع بعد',
                                style: TextStyle(color: p ? AC.teal : AC.muted, fontSize: 12)),
                            ],
                          ),
                        ),
                        if (m.phone.isNotEmpty)
                          IconButton(
                            onPressed: () => _sendWhatsapp(m),
                            icon: const Icon(Icons.chat_rounded, color: AC.teal, size: 20),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                          ),
                        Switch(
                          value: p,
                          activeThumbColor: AC.teal,
                          onChanged: (v) async {
                            await widget.setPaid(a, selMonth, m, v);
                            setState(() {});
                          },
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 12),

          // Add member
          GestureDetector(
            onTap: _addMember,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AC.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AC.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: AC.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.person_add_rounded, color: AC.primary, size: 18),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('إضافة عضو', style: TextStyle(fontWeight: FontWeight.w800)),
                        Text('يضاف في آخر ترتيب الدور', style: TextStyle(color: AC.muted, fontSize: 12)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_left_rounded, color: AC.hint),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _mini(String title, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w900)),
            const SizedBox(height: 2),
            Text(title, style: const TextStyle(color: AC.muted, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _exportBtn(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Future<void> _addMember() async {
    final nameC = TextEditingController();
    final phoneC = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: ui.TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AC.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('إضافة عضو'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameC, decoration: const InputDecoration(labelText: 'اسم العضو', prefixIcon: Icon(Icons.person_rounded))),
              const SizedBox(height: 10),
              TextField(controller: phoneC, keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'رقم الهاتف (اختياري)', prefixIcon: Icon(Icons.phone_rounded))),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('إضافة')),
          ],
        ),
      ),
    );

    if (saved == true && nameC.text.trim().isNotEmpty) {
      setState(() {
        widget.association.members.add(Member(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          name: nameC.text.trim(),
          phone: phoneC.text.trim(),
          turn: widget.association.members.length + 1,
        ));
      });
      widget.refresh();
      await widget.saveData();
    }
  }

  Future<void> _handleMenu(String value) async {
    if (value == 'archive') {
      setState(() => widget.association.archived = !widget.association.archived);
      widget.refresh();
      await widget.saveData();
      return;
    }
    if (value == 'delete') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => Directionality(
          textDirection: ui.TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: AC.card,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('حذف الجمعية؟'),
            content: const Text('سيتم حذف الجمعية وجميع دفعاتها بشكل نهائي.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AC.rose),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('حذف'),
              ),
            ],
          ),
        ),
      );
      if (ok == true) {
        await widget.deleteAssociation(widget.association);
        if (mounted) Navigator.pop(context);
      }
    }
  }

  Future<void> _sendWhatsapp(Member m) async {
    final a = widget.association;
    final text = 'السلام عليكم ${m.name} 🌟\n'
        'تذكير بدفع قسط جمعية: ${a.name}\n'
        'الشهر: ${widget.monthLabel(a, selMonth)}\n'
        'المبلغ: ${widget.formatNum(a.amount)} ${widget.currency}\n'
        'وشكرًا جزيلًا 🙏';
    final encoded = Uri.encodeComponent(text);
    final cleanPhone = m.phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = cleanPhone.isEmpty
        ? Uri.parse('https://wa.me/?text=$encoded')
        : Uri.parse('https://wa.me/$cleanPhone?text=$encoded');
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened) {
      await Clipboard.setData(ClipboardData(text: text));
    }
  }
}
