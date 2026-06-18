import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const JamiyatiApp());
}

class AppColor {
  static const Color bg = Color(0xFF0F172A);
  static const Color card = Color(0xFF18233D);
  static const Color card2 = Color(0xFF22304F);
  static const Color text = Color(0xFFF8FAFC);
  static const Color muted = Color(0xFFCBD5E1);
  static const Color blue = Color(0xFF38BDF8);
  static const Color green = Color(0xFF34D399);
  static const Color amber = Color(0xFFFBBF24);
  static const Color red = Color(0xFFFB7185);
}

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
        scaffoldBackgroundColor: AppColor.bg,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColor.blue,
          brightness: Brightness.dark,
          surface: AppColor.card,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColor.bg,
          elevation: 0,
          titleTextStyle: TextStyle(
            color: AppColor.text,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColor.card2,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      home: const Directionality(
        textDirection: TextDirection.rtl,
        child: HomePage(),
      ),
    );
  }
}

class Member {
  Member({
    required this.id,
    required this.name,
    required this.phone,
    required this.turn,
  });

  String id;
  String name;
  String phone;
  int turn;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'turn': turn,
    };
  }

  factory Member.fromJson(Map<String, dynamic> json) {
    return Member(
      id: '${json['id'] ?? ''}',
      name: '${json['name'] ?? ''}',
      phone: '${json['phone'] ?? ''}',
      turn: (json['turn'] as num?)?.toInt() ?? 1,
    );
  }
}

class Association {
  Association({
    required this.id,
    required this.name,
    required this.amount,
    required this.startYear,
    required this.startMonth,
    required this.monthsCount,
    required this.members,
    this.note = '',
    this.archived = false,
  });

  String id;
  String name;
  double amount;
  int startYear;
  int startMonth;
  int monthsCount;
  List<Member> members;
  String note;
  bool archived;

  double get monthTotal {
    return amount * members.length;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'amount': amount,
      'startYear': startYear,
      'startMonth': startMonth,
      'monthsCount': monthsCount,
      'members': members.map((member) => member.toJson()).toList(),
      'note': note,
      'archived': archived,
    };
  }

  factory Association.fromJson(Map<String, dynamic> json) {
    final rawMembers = json['members'];
    final members = <Member>[];
    if (rawMembers is List) {
      for (final item in rawMembers) {
        if (item is Map) {
          members.add(Member.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }
    return Association(
      id: '${json['id'] ?? ''}',
      name: '${json['name'] ?? ''}',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      startYear: (json['startYear'] as num?)?.toInt() ?? DateTime.now().year,
      startMonth: (json['startMonth'] as num?)?.toInt() ?? DateTime.now().month,
      monthsCount: (json['monthsCount'] as num?)?.toInt() ?? max(1, members.length),
      members: members,
      note: '${json['note'] ?? ''}',
      archived: json['archived'] == true,
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Association> associations = <Association>[];
  Set<String> paidKeys = <String>{};
  String currency = 'د.أ';
  String pin = '';
  bool loaded = false;
  bool unlocked = true;
  int tab = 0;
  final TextEditingController pinController = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final rawAssociations = prefs.getString('associations') ?? '[]';
    final rawPaid = prefs.getStringList('paidKeys') ?? <String>[];
    final loadedAssociations = <Association>[];
    final decoded = jsonDecode(rawAssociations);
    if (decoded is List) {
      for (final item in decoded) {
        if (item is Map) {
          loadedAssociations.add(Association.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }
    setState(() {
      associations = loadedAssociations;
      paidKeys = rawPaid.toSet();
      currency = prefs.getString('currency') ?? 'د.أ';
      pin = prefs.getString('pin') ?? '';
      unlocked = pin.isEmpty;
      loaded = true;
    });
  }

  Future<void> saveData() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(associations.map((item) => item.toJson()).toList());
    await prefs.setString('associations', raw);
    await prefs.setStringList('paidKeys', paidKeys.toList());
    await prefs.setString('currency', currency);
    await prefs.setString('pin', pin);
  }

  String paidKey(String associationId, int monthIndex, String memberId) {
    return '$associationId-$monthIndex-$memberId';
  }

  bool isPaid(Association association, int monthIndex, Member member) {
    return paidKeys.contains(paidKey(association.id, monthIndex, member.id));
  }

  Future<void> setPaid(Association association, int monthIndex, Member member, bool value) async {
    final key = paidKey(association.id, monthIndex, member.id);
    setState(() {
      if (value) {
        paidKeys.add(key);
      } else {
        paidKeys.remove(key);
      }
    });
    await saveData();
  }

  List<Association> get activeAssociations {
    return associations.where((item) => !item.archived).toList();
  }

  List<Association> get archivedAssociations {
    return associations.where((item) => item.archived).toList();
  }

  int currentMonthIndex(Association association) {
    final now = DateTime.now();
    final index = (now.year - association.startYear) * 12 + (now.month - association.startMonth);
    final last = max(0, association.monthsCount - 1);
    return index.clamp(0, last).toInt();
  }

  String monthLabel(Association association, int index) {
    final monthNumber = association.startMonth + index;
    final year = association.startYear + ((monthNumber - 1) ~/ 12);
    final month = ((monthNumber - 1) % 12) + 1;
    return '$month / $year';
  }

  Member? receiverFor(Association association, int monthIndex) {
    if (association.members.isEmpty) {
      return null;
    }
    final turn = (monthIndex % association.members.length) + 1;
    for (final member in association.members) {
      if (member.turn == turn) {
        return member;
      }
    }
    return association.members.first;
  }

  int paidCount(Association association, int monthIndex) {
    var count = 0;
    for (final member in association.members) {
      if (isPaid(association, monthIndex, member)) {
        count++;
      }
    }
    return count;
  }

  int lateCount(Association association, int monthIndex) {
    return association.members.length - paidCount(association, monthIndex);
  }

  int totalLateNow() {
    var total = 0;
    for (final association in activeAssociations) {
      total += lateCount(association, currentMonthIndex(association));
    }
    return total;
  }

  double totalMonthlyAmount() {
    var total = 0.0;
    for (final association in activeAssociations) {
      total += association.monthTotal;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    if (!loaded) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (!unlocked) {
      return buildLockScreen();
    }

    final pages = <Widget>[
      buildDashboard(),
      buildAssociationsPage(),
      buildReportsPage(),
      buildSettingsPage(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('جمعيتي'),
        actions: [
          IconButton(
            onPressed: openAssociationForm,
            icon: const Icon(Icons.add_circle_rounded, color: AppColor.blue),
          ),
        ],
      ),
      body: pages[tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        backgroundColor: AppColor.card,
        indicatorColor: AppColor.blue.withOpacity(0.18),
        onDestinationSelected: (value) {
          setState(() {
            tab = value;
          });
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_rounded), label: 'الرئيسية'),
          NavigationDestination(icon: Icon(Icons.groups_rounded), label: 'الجمعيات'),
          NavigationDestination(icon: Icon(Icons.receipt_long_rounded), label: 'التقارير'),
          NavigationDestination(icon: Icon(Icons.settings_rounded), label: 'الإعدادات'),
        ],
      ),
    );
  }

  Widget buildLockScreen() {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              const Icon(Icons.savings_rounded, size: 76, color: AppColor.blue),
              const SizedBox(height: 16),
              const Text(
                'جمعيتي',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              const Text(
                'أدخل كلمة المرور',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColor.muted),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: pinController,
                obscureText: true,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                decoration: const InputDecoration(labelText: 'كلمة المرور'),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: unlock,
                child: const Text('دخول'),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  void unlock() {
    if (pinController.text.trim() == pin) {
      setState(() {
        unlocked = true;
      });
    } else {
      showMessage('كلمة المرور غير صحيحة');
    }
  }

  Widget buildDashboard() {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: roundedBox(AppColor.card, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'إدارة الجمعيات الشهرية بسهولة',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, height: 1.25),
              ),
              const SizedBox(height: 8),
              const Text(
                'الأعضاء، الأدوار، الدفعات، المتأخرين، والتذكير عبر واتساب في مكان واحد.',
                style: TextStyle(color: AppColor.muted, height: 1.5),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: openAssociationForm,
                icon: const Icon(Icons.add_rounded),
                label: const Text('إنشاء جمعية جديدة'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: statTile('النشطة', '${activeAssociations.length}', Icons.play_circle_rounded, AppColor.blue),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: statTile('المتأخرون', '${totalLateNow()}', Icons.warning_rounded, AppColor.amber),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: statTile('شهريًا', '${formatNumber(totalMonthlyAmount())} $currency', Icons.payments_rounded, AppColor.green),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: statTile('الأرشيف', '${archivedAssociations.length}', Icons.archive_rounded, AppColor.muted),
            ),
          ],
        ),
        const SizedBox(height: 18),
        sectionTitle('الجمعيات النشطة'),
        if (activeAssociations.isEmpty)
          emptyBox('لا توجد جمعية بعد', 'ابدأ بإنشاء جمعية وإضافة الأعضاء حسب ترتيب الدور.')
        else
          ...activeAssociations.map(associationCard),
      ],
    );
  }

  Widget buildAssociationsPage() {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Row(
          children: [
            Expanded(child: sectionTitle('كل الجمعيات')),
            TextButton.icon(
              onPressed: openAssociationForm,
              icon: const Icon(Icons.add_rounded),
              label: const Text('إضافة'),
            ),
          ],
        ),
        if (associations.isEmpty)
          emptyBox('لا توجد بيانات', 'أدخل أول جمعية حتى تظهر هنا.')
        else
          ...activeAssociations.map(associationCard),
        if (archivedAssociations.isNotEmpty) ...[
          const SizedBox(height: 18),
          sectionTitle('الأرشيف'),
          ...archivedAssociations.map(associationCard),
        ],
      ],
    );
  }

  Widget buildReportsPage() {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        sectionTitle('التقارير'),
        actionLine(
          Icons.copy_rounded,
          'نسخ ملخص عام',
          'الجمعيات النشطة والمتأخرين والتحصيل الشهري',
          () => copyReport(generalReport()),
        ),
        actionLine(
          Icons.warning_rounded,
          'نسخ كشف المتأخرين',
          'أسماء المتأخرين في الشهر الحالي',
          () => copyReport(lateReport()),
        ),
        const SizedBox(height: 16),
        sectionTitle('كشوفات الجمعيات'),
        if (associations.isEmpty)
          emptyBox('لا توجد كشوفات', 'أنشئ جمعية أولًا.')
        else
          ...associations.map((association) {
            return actionLine(
              Icons.description_rounded,
              'كشف ${association.name}',
              'نسخ كشف الشهر الحالي',
              () {
                final index = currentMonthIndex(association);
                copyReport(associationReport(association, index));
              },
            );
          }),
      ],
    );
  }

  Widget buildSettingsPage() {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        sectionTitle('الإعدادات'),
        actionLine(
          Icons.paid_rounded,
          'العملة',
          currency,
          changeCurrency,
        ),
        actionLine(
          Icons.lock_rounded,
          'كلمة المرور',
          pin.isEmpty ? 'غير مفعلة' : 'مفعلة',
          changePin,
        ),
        actionLine(
          Icons.backup_rounded,
          'نسخ احتياطي',
          'نسخ البيانات بصيغة JSON',
          copyBackup,
        ),
        const SizedBox(height: 16),
        const Text(
          'هذه النسخة مصممة للبناء المستقر: بدون test وبدون مكتبات ثقيلة. التذكير يتم عبر واتساب من صفحة الجمعية.',
          style: TextStyle(color: AppColor.muted, height: 1.5),
        ),
      ],
    );
  }

  Widget associationCard(Association association) {
    final index = currentMonthIndex(association);
    final receiver = receiverFor(association, index);
    final paid = paidCount(association, index);
    final late = lateCount(association, index);
    final progress = association.members.isEmpty ? 0.0 : paid / association.members.length;

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () => openDetails(association),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: roundedBox(AppColor.card, 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    association.name,
                    style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
                  ),
                ),
                if (association.archived)
                  const Chip(label: Text('مؤرشفة'))
                else
                  Text(
                    '${formatNumber(association.amount)} $currency',
                    style: const TextStyle(color: AppColor.green, fontWeight: FontWeight.w800),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'الدور: ${receiver == null ? '-' : receiver.name} • دفع $paid • متأخر $late • شهر ${monthLabel(association, index)}',
              style: const TextStyle(color: AppColor.muted),
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                color: AppColor.green,
                backgroundColor: Colors.white10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> openDetails(Association association) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: DetailsPage(
              association: association,
              currency: currency,
              isPaid: isPaid,
              setPaid: setPaid,
              currentMonthIndex: currentMonthIndex,
              monthLabel: monthLabel,
              receiverFor: receiverFor,
              paidCount: paidCount,
              lateCount: lateCount,
              saveData: saveData,
              refresh: () {
                setState(() {});
              },
              deleteAssociation: deleteAssociation,
              copyReport: copyReport,
              associationReport: associationReport,
            ),
          );
        },
      ),
    );
    setState(() {});
  }

  Future<void> openAssociationForm() async {
    final nameController = TextEditingController();
    final amountController = TextEditingController();
    final monthsController = TextEditingController();
    final membersController = TextEditingController();
    final noteController = TextEditingController();
    final now = DateTime.now();
    final yearController = TextEditingController(text: '${now.year}');
    int selectedMonth = now.month;

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('إنشاء جمعية'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'اسم الجمعية'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'قيمة القسط'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: monthsController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'عدد الأشهر'),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int>(
                    value: selectedMonth,
                    decoration: const InputDecoration(labelText: 'شهر البداية'),
                    items: List.generate(12, (index) {
                      final month = index + 1;
                      return DropdownMenuItem<int>(
                        value: month,
                        child: Text('$month'),
                      );
                    }),
                    onChanged: (value) {
                      selectedMonth = value ?? selectedMonth;
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: yearController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'سنة البداية'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: membersController,
                    minLines: 4,
                    maxLines: 7,
                    decoration: const InputDecoration(
                      labelText: 'الأعضاء حسب ترتيب الدور',
                      hintText: 'كل سطر عضو ويمكن كتابة الرقم بعد فاصلة\nأحمد,0790000000\nمحمد,',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: noteController,
                    decoration: const InputDecoration(labelText: 'ملاحظة اختيارية'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('حفظ'),
              ),
            ],
          ),
        );
      },
    );

    if (saved != true) {
      return;
    }

    final members = parseMembers(membersController.text);
    final name = nameController.text.trim();
    final amount = double.tryParse(amountController.text.trim()) ?? 0;
    final months = int.tryParse(monthsController.text.trim()) ?? members.length;
    final year = int.tryParse(yearController.text.trim()) ?? now.year;

    if (name.isEmpty || amount <= 0 || members.isEmpty) {
      showMessage('أدخل اسم الجمعية وقيمة القسط وعضو واحد على الأقل');
      return;
    }

    final association = Association(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
      amount: amount,
      startYear: year,
      startMonth: selectedMonth,
      monthsCount: max(1, months),
      members: members,
      note: noteController.text.trim(),
    );

    setState(() {
      associations.insert(0, association);
    });
    await saveData();
    showMessage('تم حفظ الجمعية');
  }

  List<Member> parseMembers(String raw) {
    final members = <Member>[];
    final lines = raw.split('\n');
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) {
        continue;
      }
      final parts = line.split(',');
      final name = parts.first.trim();
      final phone = parts.length > 1 ? parts[1].trim() : '';
      if (name.isEmpty) {
        continue;
      }
      members.add(
        Member(
          id: '${DateTime.now().microsecondsSinceEpoch}-$i',
          name: name,
          phone: phone,
          turn: members.length + 1,
        ),
      );
    }
    return members;
  }

  Future<void> deleteAssociation(Association association) async {
    setState(() {
      associations.removeWhere((item) => item.id == association.id);
      paidKeys.removeWhere((key) => key.startsWith('${association.id}-'));
    });
    await saveData();
  }

  Future<void> changeCurrency() async {
    final controller = TextEditingController(text: currency);
    final value = await simpleInput('العملة', 'مثال: د.أ / ر.س / ريال', controller);
    if (value == null) {
      return;
    }
    setState(() {
      currency = value.trim().isEmpty ? 'د.أ' : value.trim();
    });
    await saveData();
  }

  Future<void> changePin() async {
    final controller = TextEditingController(text: pin);
    final value = await simpleInput('كلمة المرور', 'اتركها فارغة للإلغاء', controller, obscure: true);
    if (value == null) {
      return;
    }
    setState(() {
      pin = value.trim();
      unlocked = pin.isEmpty;
    });
    await saveData();
    showMessage(pin.isEmpty ? 'تم إلغاء كلمة المرور' : 'تم حفظ كلمة المرور');
  }

  Future<String?> simpleInput(
    String title,
    String label,
    TextEditingController controller, {
    bool obscure = false,
  }) async {
    return showDialog<String>(
      context: context,
      builder: (context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: Text(title),
            content: TextField(
              controller: controller,
              obscureText: obscure,
              decoration: InputDecoration(labelText: label),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, controller.text),
                child: const Text('حفظ'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> copyBackup() async {
    final raw = jsonEncode({
      'associations': associations.map((item) => item.toJson()).toList(),
      'paidKeys': paidKeys.toList(),
      'currency': currency,
    });
    await Clipboard.setData(ClipboardData(text: raw));
    showMessage('تم نسخ النسخة الاحتياطية');
  }

  Future<void> copyReport(String report) async {
    await Clipboard.setData(ClipboardData(text: report));
    showMessage('تم نسخ التقرير');
  }

  String generalReport() {
    return 'تقرير جمعيتي\n'
        'الجمعيات النشطة: ${activeAssociations.length}\n'
        'الجمعيات المؤرشفة: ${archivedAssociations.length}\n'
        'المتأخرون الآن: ${totalLateNow()}\n'
        'إجمالي التحصيل الشهري: ${formatNumber(totalMonthlyAmount())} $currency';
  }

  String lateReport() {
    final buffer = StringBuffer('كشف المتأخرين\n');
    for (final association in activeAssociations) {
      final index = currentMonthIndex(association);
      buffer.writeln('\n${association.name} - شهر ${monthLabel(association, index)}');
      var hasLate = false;
      for (final member in association.members) {
        if (!isPaid(association, index, member)) {
          hasLate = true;
          buffer.writeln('- ${member.name}: ${formatNumber(association.amount)} $currency');
        }
      }
      if (!hasLate) {
        buffer.writeln('لا يوجد متأخرون');
      }
    }
    return buffer.toString();
  }

  String associationReport(Association association, int monthIndex) {
    final receiver = receiverFor(association, monthIndex);
    final buffer = StringBuffer();
    buffer.writeln('كشف جمعية: ${association.name}');
    buffer.writeln('الشهر: ${monthLabel(association, monthIndex)}');
    buffer.writeln('قيمة القسط: ${formatNumber(association.amount)} $currency');
    buffer.writeln('صاحب الدور: ${receiver == null ? '-' : receiver.name}');
    buffer.writeln('عدد الأعضاء: ${association.members.length}');
    buffer.writeln('إجمالي الشهر: ${formatNumber(association.monthTotal)} $currency');
    buffer.writeln('\nالدفعات:');
    for (final member in association.members) {
      final paid = isPaid(association, monthIndex, member);
      buffer.writeln('${member.turn}. ${member.name} - ${paid ? 'دفع' : 'لم يدفع'}');
    }
    if (association.note.trim().isNotEmpty) {
      buffer.writeln('\nملاحظة: ${association.note}');
    }
    return buffer.toString();
  }

  Widget sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
      ),
    );
  }

  Widget statTile(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: roundedBox(AppColor.card, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          Text(
            title,
            style: const TextStyle(color: AppColor.muted),
          ),
        ],
      ),
    );
  }

  Widget emptyBox(String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: roundedBox(AppColor.card, 22),
      child: Column(
        children: [
          const Icon(Icons.savings_rounded, size: 46, color: AppColor.blue),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColor.muted, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget actionLine(IconData icon, String title, String subtitle, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: roundedBox(AppColor.card, 18),
        child: Row(
          children: [
            Icon(icon, color: AppColor.blue),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 3),
                  Text(subtitle, style: const TextStyle(color: AppColor.muted, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_left_rounded, color: AppColor.muted),
          ],
        ),
      ),
    );
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class DetailsPage extends StatefulWidget {
  const DetailsPage({
    super.key,
    required this.association,
    required this.currency,
    required this.isPaid,
    required this.setPaid,
    required this.currentMonthIndex,
    required this.monthLabel,
    required this.receiverFor,
    required this.paidCount,
    required this.lateCount,
    required this.saveData,
    required this.refresh,
    required this.deleteAssociation,
    required this.copyReport,
    required this.associationReport,
  });

  final Association association;
  final String currency;
  final bool Function(Association association, int monthIndex, Member member) isPaid;
  final Future<void> Function(Association association, int monthIndex, Member member, bool value) setPaid;
  final int Function(Association association) currentMonthIndex;
  final String Function(Association association, int monthIndex) monthLabel;
  final Member? Function(Association association, int monthIndex) receiverFor;
  final int Function(Association association, int monthIndex) paidCount;
  final int Function(Association association, int monthIndex) lateCount;
  final Future<void> Function() saveData;
  final VoidCallback refresh;
  final Future<void> Function(Association association) deleteAssociation;
  final Future<void> Function(String report) copyReport;
  final String Function(Association association, int monthIndex) associationReport;

  @override
  State<DetailsPage> createState() => _DetailsPageState();
}

class _DetailsPageState extends State<DetailsPage> {
  late int selectedMonth;

  @override
  void initState() {
    super.initState();
    selectedMonth = widget.currentMonthIndex(widget.association);
  }

  @override
  Widget build(BuildContext context) {
    final association = widget.association;
    final receiver = widget.receiverFor(association, selectedMonth);
    final paid = widget.paidCount(association, selectedMonth);
    final late = widget.lateCount(association, selectedMonth);

    return Scaffold(
      appBar: AppBar(
        title: Text(association.name),
        actions: [
          IconButton(
            onPressed: () => widget.copyReport(widget.associationReport(association, selectedMonth)),
            icon: const Icon(Icons.copy_rounded),
          ),
          PopupMenuButton<String>(
            onSelected: handleMenu,
            itemBuilder: (context) {
              return [
                PopupMenuItem<String>(
                  value: 'archive',
                  child: Text(association.archived ? 'إلغاء الأرشفة' : 'أرشفة'),
                ),
                const PopupMenuItem<String>(
                  value: 'delete',
                  child: Text('حذف الجمعية'),
                ),
              ];
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: roundedBox(AppColor.card, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'شهر ${widget.monthLabel(association, selectedMonth)}',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                Text(
                  'صاحب الدور: ${receiver == null ? '-' : receiver.name}',
                  style: const TextStyle(color: AppColor.blue, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(child: miniStat('دفعوا', '$paid', AppColor.green)),
                    const SizedBox(width: 8),
                    Expanded(child: miniStat('متأخرون', '$late', late == 0 ? AppColor.green : AppColor.amber)),
                    const SizedBox(width: 8),
                    Expanded(child: miniStat('المحصل', formatNumber(paid * association.amount), AppColor.blue)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: association.monthsCount,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                return ChoiceChip(
                  selected: selectedMonth == index,
                  label: Text(widget.monthLabel(association, index)),
                  onSelected: (value) {
                    setState(() {
                      selectedMonth = index;
                    });
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'دفعات الأعضاء',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          ...association.members.map(memberLine),
          const SizedBox(height: 10),
          actionButton(
            Icons.person_add_rounded,
            'إضافة عضو',
            'يضاف في آخر ترتيب الدور',
            addMember,
          ),
        ],
      ),
    );
  }

  Widget memberLine(Member member) {
    final paid = widget.isPaid(widget.association, selectedMonth, member);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: roundedBox(AppColor.card, 18),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: paid ? AppColor.green.withOpacity(0.18) : AppColor.amber.withOpacity(0.18),
            child: Text(
              '${member.turn}',
              style: TextStyle(
                color: paid ? AppColor.green : AppColor.amber,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(member.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                Text(
                  paid ? 'تم الدفع' : 'لم يدفع بعد',
                  style: TextStyle(color: paid ? AppColor.green : AppColor.muted),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => sendWhatsapp(member),
            icon: const Icon(Icons.chat_rounded, color: AppColor.green),
          ),
          Switch(
            value: paid,
            onChanged: (value) async {
              await widget.setPaid(widget.association, selectedMonth, member, value);
              setState(() {});
            },
          ),
        ],
      ),
    );
  }

  Widget miniStat(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: roundedBox(AppColor.card2, 16),
      child: Column(
        children: [
          Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w900)),
          Text(title, style: const TextStyle(color: AppColor.muted, fontSize: 12)),
        ],
      ),
    );
  }

  Widget actionButton(IconData icon, String title, String subtitle, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: roundedBox(AppColor.card, 18),
        child: Row(
          children: [
            Icon(icon, color: AppColor.blue),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 3),
                  Text(subtitle, style: const TextStyle(color: AppColor.muted, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> addMember() async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('إضافة عضو'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'اسم العضو'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'رقم الهاتف اختياري'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('إضافة'),
              ),
            ],
          ),
        );
      },
    );

    if (saved == true && nameController.text.trim().isNotEmpty) {
      setState(() {
        widget.association.members.add(
          Member(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            name: nameController.text.trim(),
            phone: phoneController.text.trim(),
            turn: widget.association.members.length + 1,
          ),
        );
      });
      widget.refresh();
      await widget.saveData();
    }
  }

  Future<void> handleMenu(String value) async {
    if (value == 'archive') {
      setState(() {
        widget.association.archived = !widget.association.archived;
      });
      widget.refresh();
      await widget.saveData();
      return;
    }

    if (value == 'delete') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              title: const Text('حذف الجمعية؟'),
              content: const Text('سيتم حذف الجمعية ودفعاتها من الجهاز.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('إلغاء'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('حذف'),
                ),
              ],
            ),
          );
        },
      );
      if (ok == true) {
        await widget.deleteAssociation(widget.association);
        if (mounted) {
          Navigator.pop(context);
        }
      }
    }
  }

  Future<void> sendWhatsapp(Member member) async {
    final text = 'السلام عليكم ${member.name}\n'
        'تذكير بدفع قسط جمعية: ${widget.association.name}\n'
        'الشهر: ${widget.monthLabel(widget.association, selectedMonth)}\n'
        'المبلغ: ${formatNumber(widget.association.amount)} ${widget.currency}\n'
        'وشكرًا.';
    final encoded = Uri.encodeComponent(text);
    final cleanPhone = member.phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = cleanPhone.isEmpty
        ? Uri.parse('https://wa.me/?text=$encoded')
        : Uri.parse('https://wa.me/$cleanPhone?text=$encoded');
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened) {
      await Clipboard.setData(ClipboardData(text: text));
    }
  }
}

BoxDecoration roundedBox(Color color, double radius) {
  return BoxDecoration(
    color: color,
    borderRadius: BorderRadius.circular(radius),
  );
}

String formatNumber(num value) {
  if (value == value.roundToDouble()) {
    return value.round().toString();
  }
  return value.toStringAsFixed(2);
}
