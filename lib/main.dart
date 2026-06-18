import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

// حزم التقارير والكشوفات
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const JamiyatiApp());
}

// ثيم الألوان المالي الزمردي
class AppColor {
  static const Color bg = Color(0xFF09120E);
  static const Color card = Color(0xFF12241C);
  static const Color card2 = Color(0xFF1A3328);
  static const Color text = Color(0xFFF1F7F4);
  static const Color muted = Color(0xFF8FA399);
  static const Color primary = Color(0xFF10B981);
  static const Color accent = Color(0xFF34D399);
  static const Color amber = Color(0xFFF59E0B);
  static const Color red = Color(0xFFEF4444);
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
        scaffoldBackgroundColor: AppColor.bg,
        fontFamily: 'Cairo', 
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColor.primary,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const MainScreen(),
    );
  }
}

class Association {
  String id;
  String name;
  num amount;
  int months;
  String startDate;
  List<Member> members;

  Association({
    required this.id,
    required this.name,
    required this.amount,
    required this.months,
    required this.startDate,
    required this.members,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'amount': amount,
      'months': months,
      'startDate': startDate,
      'members': members.map((m) => m.toMap()).toList(),
    };
  }

  factory Association.fromMap(Map<String, dynamic> map) {
    return Association(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      amount: map['amount'] ?? 0,
      months: map['months'] ?? 1,
      startDate: map['startDate'] ?? '',
      members: (map['members'] as List? ?? [])
          .map((m) => Member.fromMap(m))
          .toList(),
    );
  }
}

class Member {
  String id;
  String name;
  String phone;
  String note;
  int turn;
  bool active;
  Map<String, bool> payments; 

  Member({
    required this.id,
    required this.name,
    this.phone = '',
    this.note = '',
    required this.turn,
    this.active = true,
    Map<String, bool>? payments,
  }) : payments = payments ?? {};

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'note': note,
      'turn': turn,
      'active': active,
      'payments': payments,
    };
  }

  factory Member.fromMap(Map<String, dynamic> map) {
    return Member(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      note: map['note'] ?? '',
      turn: map['turn'] ?? 1,
      active: map['active'] ?? true,
      payments: Map<String, bool>.from(map['payments'] ?? {}),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  List<Association> associations = [];
  bool isLoading = true;
  String currency = 'دينار';

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      currency = prefs.getString('currency') ?? 'دينار';
      final raw = prefs.getString('associations');
      if (raw != null) {
        final List decoded = jsonDecode(raw);
        setState(() {
          associations = decoded.map((item) => Association.fromMap(item)).toList();
        });
      }
    } catch (_) {}
    setState(() => isLoading = false);
  }

  Future<void> saveData() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(associations.map((a) => a.toMap()).toList());
    await prefs.setString('associations', raw);
  }

  Future<void> saveCurrency(String c) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('currency', c);
    setState(() {
      currency = c;
    });
  }

  void addAssociation(Association a) {
    setState(() {
      associations.add(a);
    });
    saveData();
  }

  Future<void> deleteAssociation(Association a) async {
    setState(() {
      associations.removeWhere((item) => item.id == a.id);
    });
    await saveData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('جمعيتي 📊', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColor.card,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: AppColor.primary),
            onPressed: () => showCurrencyDialog(),
          )
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColor.primary))
          : associations.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.account_balance_wallet, size: 64, color: AppColor.muted.withAlpha(128)),
                      const SizedBox(height: 16),
                      const Text('لا توجد جمعيات حالية', style: TextStyle(color: AppColor.muted, fontSize: 16)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: associations.length,
                  itemBuilder: (context, index) {
                    final a = associations[index];
                    final totalCash = a.amount * a.members.length;
                    return Card(
                      color: AppColor.card,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 2,
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        title: Text(a.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColor.text)),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            'المبلغ: ${formatNumber(a.amount)} $currency | الأعضاء: ${a.members.length}\nإجمالي الجمعية: ${formatNumber(totalCash)} $currency',
                            style: const TextStyle(color: AppColor.muted, height: 1.4),
                          ),
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios, color: AppColor.primary, size: 18),
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AssociationDetailsScreen(
                                association: a,
                                currency: currency,
                                deleteAssociation: deleteAssociation,
                                saveData: saveData,
                              ),
                            ),
                          );
                          setState(() {});
                        },
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showAddAssociationDialog(),
        backgroundColor: AppColor.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('جمعية جديدة', style: TextStyle(fontWeight: FontWeight.bold)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  void showCurrencyDialog() {
    final controller = TextEditingController(text: currency);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColor.card2,
        title: const Text('تغيير العملة'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'رمز العملة (مثلا: دينار، ريال، \$)',
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColor.primary)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء', style: TextStyle(color: AppColor.muted))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColor.primary),
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                saveCurrency(controller.text.trim());
              }
              Navigator.pop(context);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  void showAddAssociationDialog() {
    final nameCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final monthsCtrl = TextEditingController();
    final membersCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColor.card2,
        title: const Text('إنشاء جمعية جديدة 📝'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'اسم الجمعية')),
              TextField(controller: amountCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'القسط الشهري')),
              TextField(controller: monthsCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'عدد الأشهر (المدة)')),
              TextField(
                controller: membersCtrl,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'أسماء المشتركين (اسم في كل سطر)',
                  hintText: 'أحمد\nمحمد\nعلي',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء', style: TextStyle(color: AppColor.muted))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColor.primary),
            onPressed: () {
              final name = nameCtrl.text.trim();
              final amt = num.tryParse(amountCtrl.text) ?? 0;
              final mos = int.tryParse(monthsCtrl.text) ?? 0;
              final lines = membersCtrl.text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

              if (name.isEmpty || amt <= 0 || mos <= 0 || lines.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('الرجاء ملء جميع الحقول بشكل صحيح')),
                );
                return;
              }

              List<Member> mList = [];
              for (int i = 0; i < lines.length; i++) {
                mList.add(Member(
                  id: DateTime.now().microsecondsSinceEpoch.toString() + i.toString(),
                  name: lines[i],
                  turn: i + 1,
                ));
              }

              final now = DateTime.now();
              final startStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-01';

              addAssociation(Association(
                id: DateTime.now().microsecondsSinceEpoch.toString(),
                name: name,
                amount: amt,
                months: mos,
                startDate: startStr,
                members: mList,
              ));

              Navigator.pop(context);
            },
            child: const Text('إنشاء'),
          ),
        ],
      ),
    );
  }
}

class AssociationDetailsScreen extends StatefulWidget {
  final Association association;
  final String currency;
  final Future<void> Function(Association) deleteAssociation;
  final Future<void> Function() saveData;

  const AssociationDetailsScreen({
    super.key,
    required this.association,
    required this.currency,
    required this.deleteAssociation,
    required this.saveData,
  });

  @override
  State<AssociationDetailsScreen> createState() => _AssociationDetailsScreenState();

  DateTime monthDate(Association a, int offset) {
    final start = DateTime.parse(a.startDate);
    return DateTime(start.year, start.month + offset, 1);
  }

  String monthKey(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}';
  String monthLabel(Association a, int offset) {
    final d = monthDate(a, offset);
    return '${d.month.toString().padLeft(2, '0')} / ${d.year}';
  }
}

class _AssociationDetailsScreenState extends State<AssociationDetailsScreen> {
  int selectedMonth = 0;
  final ScreenshotController screenshotController = ScreenshotController(); 

  @override
  Widget build(BuildContext context) {
    final currentMonthDate = widget.monthDate(widget.association, selectedMonth);
    final currentMonthKey = widget.monthKey(currentMonthDate);

    int totalPaidMembers = 0;
    for (var m in widget.association.members) {
      if (m.payments[currentMonthKey] == true) {
        totalPaidMembers++;
      }
    }
    final collected = totalPaidMembers * widget.association.amount;
    final remaining = (widget.association.members.length - totalPaidMembers) * widget.association.amount;

    final targetTurn = (selectedMonth % widget.association.members.length) + 1;
    Member? receiver;
    for (var m in widget.association.members) {
      if (m.turn == targetTurn) {
        receiver = m;
        break;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.association.name),
        backgroundColor: AppColor.card,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.share, color: AppColor.primary),
            onSelected: (val) {
              if (val == 'pdf') {
                exportDetailedPDF();
              } else if (val == 'png') {
                exportQuickPNG();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'pdf', child: Row(children: [Icon(Icons.picture_as_pdf, color: AppColor.red), SizedBox(width: 8), Text('كشف PDF تفصيلي')])),
              const PopupMenuItem(value: 'png', child: Row(children: [Icon(Icons.image, color: AppColor.primary), SizedBox(width: 8), Text('صورة إيصال PNG')])),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: AppColor.red),
            onPressed: () => confirmDelete(),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: AppColor.card,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios, color: AppColor.primary),
                  onPressed: selectedMonth > 0 ? () => setState(() => selectedMonth--) : null,
                ),
                Text(
                  'الشهر: ${widget.monthLabel(widget.association, selectedMonth)}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColor.accent),
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_forward_ios, color: AppColor.primary),
                  onPressed: selectedMonth < widget.association.months - 1 ? () => setState(() => selectedMonth++) : null,
                ),
              ],
            ),
          ),
          
          Screenshot(
            controller: screenshotController,
            child: Container(
              color: AppColor.bg,
              padding: const EdgeInsets.all(12),
              child: Card(
                color: AppColor.card2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          statWidget('المجموع', '${formatNumber(collected)} ${widget.currency}', AppColor.primary),
                          statWidget('المتبقي', '${formatNumber(remaining)} ${widget.currency}', AppColor.amber),
                        ],
                      ),
                      const Divider(height: 24, color: Colors.white10),
                      if (receiver != null)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.stars, color: AppColor.amber, size: 20),
                            const SizedBox(width: 6),
                            Text(
                              'قبض هذا الشهر: ${receiver.name} (دور: ${receiver.turn})',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColor.text),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: widget.association.members.length,
              itemBuilder: (context, index) {
                final m = widget.association.members[index];
                final isPaid = m.payments[currentMonthKey] == true;
                return Card(
                  color: AppColor.card,
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: m.turn == targetTurn ? AppColor.amber : AppColor.card2,
                      foregroundColor: m.turn == targetTurn ? Colors.black : AppColor.text,
                      child: Text('${m.turn}'),
                    ),
                    title: Text(m.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: m.phone.isNotEmpty ? Text(m.phone, style: const TextStyle(color: AppColor.muted, fontSize: 13)) : null,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.message, color: AppColor.accent, size: 20),
                          onPressed: () => sendWhatsapp(m),
                        ),
                        Switch(
                          value: isPaid,
                          activeTrackColor: AppColor.primary,
                          activeThumbColor: Colors.white,
                          onChanged: (val) async {
                            HapticFeedback.lightImpact();
                            setState(() {
                              m.payments[currentMonthKey] = val;
                            });
                            await widget.saveData();
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget statWidget(String title, String val, Color col) {
    return Column(
      children: [
        Text(title, style: const TextStyle(color: AppColor.muted, fontSize: 14)),
        const SizedBox(height: 4),
        Text(val, style: TextStyle(color: col, fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Future<void> exportDetailedPDF() async {
    final pdf = pw.Document();
    final arabicFont = await PdfGoogleFonts.cairoRegular();
    final arabicFontBold = await PdfGoogleFonts.cairoBold();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: arabicFont, bold: arabicFontBold),
        build: (pw.Context context) {
          return pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Center(
                  child: pw.Text('تقرير كشف حساب: ${widget.association.name}', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.teal)),
                ),
                pw.SizedBox(height: 8),
                pw.Text('تاريخ استخراج التقرير: ${DateTime.now().toString().split(' ')[0]}', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey)),
                pw.Text('قيمة القسط الشهري: ${formatNumber(widget.association.amount)} ${widget.currency}', style: const pw.TextStyle(fontSize: 13)),
                pw.Divider(thickness: 1.5, color: PdfColors.teal),
                pw.SizedBox(height: 16),

                pw.TableHelper.fromTextArray(
                  headers: ['رقم الدور', 'اسم المشترك', 'رقم الهاتف', 'الحالة السداد (الشهر الحالي)'],
                  data: widget.association.members.map((m) {
                    final currentMonthKey = widget.monthKey(widget.monthDate(widget.association, selectedMonth));
                    final isPaid = m.payments[currentMonthKey] == true;
                    return [
                      m.turn.toString(),
                      m.name,
                      m.phone.isEmpty ? '-' : m.phone,
                      isPaid ? 'تم السداد' : 'لم يسدد بعد',
                    ];
                  }).toList(),
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                  headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF10B981)),
                  cellAlignment:
