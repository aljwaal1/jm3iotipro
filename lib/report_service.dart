import 'dart:io';
import 'dart:ui' as ui;

import 'package:excel/excel.dart' as xl;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';

import 'app_theme.dart';
import 'controller.dart';
import 'models.dart';

enum ReportScope { month, toDate }

class ReportService {
  static final NumberFormat _number = NumberFormat('#,##0.##');
  static final DateFormat _date = DateFormat('yyyy/MM/dd HH:mm');
  static final DateFormat _day = DateFormat('yyyy/MM/dd');
  static const _monthsAr = <String>[
    'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
    'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
  ];

  static String n(num value) => _number.format(value);

  static DateTime associationStart(Association a) => DateTime(a.startYear, a.startMonth);
  static DateTime associationEnd(Association a) =>
      DateTime(a.startYear, a.startMonth + a.monthsCount - 1);
  static DateTime roundMonth(Association a, int round) =>
      DateTime(a.startYear, a.startMonth + round);
  static String monthYear(DateTime d) => '${_monthsAr[d.month - 1]} ${d.year}';
  static String associationPeriod(Association a) =>
      '${monthYear(associationStart(a))} — ${monthYear(associationEnd(a))}';

  static int _lastRoundToDate(Association a) {
    final now = DateTime.now();
    var last = -1;
    for (var i = 0; i < a.monthsCount; i++) {
      final d = roundMonth(a, i);
      if (d.isBefore(DateTime(now.year, now.month + 1))) last = i;
    }
    return last.clamp(-1, a.monthsCount - 1);
  }

  static List<int> _roundsFor(Association a, int selectedRound, ReportScope scope) {
    if (scope == ReportScope.month) return [selectedRound.clamp(0, a.monthsCount - 1)];
    final last = _lastRoundToDate(a);
    if (last < 0) return <int>[];
    return List<int>.generate(last + 1, (i) => i);
  }

  static String scopeLabel(Association a, int selectedRound, ReportScope scope) {
    if (scope == ReportScope.month) return monthYear(roundMonth(a, selectedRound));
    return 'من ${monthYear(associationStart(a))} لغاية ${_day.format(DateTime.now())}';
  }

  static int memberPaidRounds(JamiyatiController c, Association a, Member member) {
    var count = 0;
    for (var round = 0; round < a.monthsCount; round++) {
      if (c.isPaid(a, round, member)) count++;
    }
    return count;
  }

  static double memberPaidTotal(JamiyatiController c, Association a, Member member) =>
      memberPaidRounds(c, a, member) * a.amount;

  static List<int> memberReceiverRounds(Association a, Member member) {
    final rounds = <int>[];
    for (var round = 0; round < a.monthsCount; round++) {
      if (a.receiverFor(round)?.id == member.id) rounds.add(round);
    }
    return rounds;
  }

  static double memberReceivedTotal(Association a, Member member) {
    var total = 0.0;
    for (final round in memberReceiverRounds(a, member)) {
      total += a.deliveredTotal(round);
    }
    return total;
  }

  static String memberAccountText(JamiyatiController c, Association a, Member member) {
    final paid = memberPaidTotal(c, a, member);
    final received = memberReceivedTotal(a, member);
    return 'كشف حساب عضو - ${a.name}\n'
        'الفترة: ${associationPeriod(a)}\n'
        'العضو: ${member.name}\n'
        'تم دفع: ${n(paid)} ${c.currency}\n'
        'تم استلام: ${n(received)} ${c.currency}\n'
        'الصافي: ${n(received - paid)} ${c.currency}';
  }

  static double _collectedForRounds(
    JamiyatiController c,
    Association a,
    Iterable<int> rounds,
  ) => rounds.fold<double>(0, (sum, r) => sum + c.collectedAmount(a, r));

  static double _deliveredForRounds(Association a, Iterable<int> rounds) =>
      rounds.fold<double>(0, (sum, r) => sum + a.deliveredTotal(r));

  static String associationText(
    JamiyatiController c,
    Association a,
    int roundIndex, {
    ReportScope scope = ReportScope.month,
  }) {
    final rounds = _roundsFor(a, roundIndex, scope);
    final b = StringBuffer();
    b.writeln('كشف جمعية: ${a.name}');
    b.writeln('نوع الكشف: ${scope == ReportScope.month ? 'شهري' : 'لغاية تاريخه'}');
    b.writeln('الفترة: ${scopeLabel(a, roundIndex, scope)}');
    b.writeln('قيمة القسط: ${n(a.amount)} ${c.currency}');
    b.writeln('================================');

    if (rounds.isEmpty) {
      b.writeln('لم تبدأ الجمعية بعد.');
      return b.toString();
    }

    for (final round in rounds) {
      b.writeln('\n${monthYear(roundMonth(a, round))} — الدور ${round + 1}');
      b.writeln('صاحب الدور: ${a.receiverFor(round)?.name ?? '-'}');
      b.writeln('دفعات الأعضاء:');
      for (final member in a.members) {
        final paidAt = c.paymentDate(a, round, member);
        final stage = c.contributionStage(a, round, member);
        final status = stage == ContributionStage.paid
            ? 'تم الدفع'
            : stage == ContributionStage.late
                ? 'متأخر'
                : 'لم يدفع بعد';
        b.write('- ${member.name}: $status');
        if (paidAt != null) {
          b.write(' • ${n(a.amount)} ${c.currency} • ${_date.format(paidAt)}');
        }
        b.writeln();
      }
      b.writeln('التسليم:');
      final receiver = a.receiverFor(round)?.name ?? '-';
      final deliveries = a.deliveryFor(round);
      if (deliveries.isEmpty) {
        b.writeln('- $receiver: لم يتم تسجيل تسليم');
      } else {
        for (final d in deliveries) {
          b.writeln('- $receiver: ${n(d.amount)} ${c.currency} • ${_date.format(d.date)}');
        }
      }
      b.writeln('إجمالي المدفوع: ${n(c.collectedAmount(a, round))} ${c.currency}');
      b.writeln('إجمالي المسلّم: ${n(a.deliveredTotal(round))} ${c.currency}');
    }

    b.writeln('\n================================');
    b.writeln('إجمالي الفترة:');
    b.writeln('المدفوع: ${n(_collectedForRounds(c, a, rounds))} ${c.currency}');
    b.writeln('المسلّم: ${n(_deliveredForRounds(a, rounds))} ${c.currency}');
    return b.toString();
  }

  static Future<Uint8List> _captureWidget(Widget child, {double pixelRatio = 2.3}) {
    final controller = ScreenshotController();
    return controller.captureFromWidget(
      Directionality(
        textDirection: ui.TextDirection.rtl,
        child: Material(color: AC.bg, child: child),
      ),
      pixelRatio: pixelRatio,
      delay: const Duration(milliseconds: 80),
    );
  }

  static Widget _paymentRow(
    JamiyatiController c,
    Association a,
    int round,
    Member member,
  ) {
    final paidAt = c.paymentDate(a, round, member);
    final stage = c.contributionStage(a, round, member);
    final paid = stage == ContributionStage.paid;
    final color = paid ? AC.teal : stage == ContributionStage.late ? AC.rose : AC.amber;
    final status = paid ? 'تم الدفع' : stage == ContributionStage.late ? 'متأخر' : 'لم يدفع بعد';
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: AC.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AC.borderSoft),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(member.name, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
          ),
          Expanded(
            flex: 3,
            child: Text(
              paid ? '${n(a.amount)} ${c.currency}' : '—',
              style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800),
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              paidAt == null ? status : _day.format(paidAt),
              textAlign: TextAlign.end,
              style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _roundBlock(JamiyatiController c, Association a, int round) {
    final receiver = a.receiverFor(round)?.name ?? '-';
    final deliveries = a.deliveryFor(round);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AC.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AC.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${monthYear(roundMonth(a, round))} • الدور ${round + 1}',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
                ),
              ),
              Text('صاحب الدور: $receiver', style: const TextStyle(color: AC.muted, fontSize: 9)),
            ],
          ),
          const SizedBox(height: 10),
          const Row(
            children: [
              Expanded(flex: 4, child: Text('العضو', style: TextStyle(color: AC.muted, fontSize: 9, fontWeight: FontWeight.w800))),
              Expanded(flex: 3, child: Text('المبلغ', style: TextStyle(color: AC.muted, fontSize: 9, fontWeight: FontWeight.w800))),
              Expanded(flex: 4, child: Text('تاريخ/حالة الدفع', textAlign: TextAlign.end, style: TextStyle(color: AC.muted, fontSize: 9, fontWeight: FontWeight.w800))),
            ],
          ),
          const SizedBox(height: 5),
          ...a.members.map((m) => _paymentRow(c, a, round, m)),
          const SizedBox(height: 7),
          const Text('التسليم لصاحب الدور', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
          const SizedBox(height: 5),
          if (deliveries.isEmpty)
            Text('$receiver • لم يتم تسجيل تسليم', style: const TextStyle(color: AC.amber, fontSize: 10))
          else
            ...deliveries.map(
              (d) => Container(
                margin: const EdgeInsets.only(bottom: 5),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(color: AC.card2, borderRadius: BorderRadius.circular(10)),
                child: Row(
                  children: [
                    Expanded(child: Text(receiver, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800))),
                    Text('${n(d.amount)} ${c.currency}', style: const TextStyle(color: AC.cyan, fontSize: 10, fontWeight: FontWeight.w900)),
                    const SizedBox(width: 12),
                    Text(_day.format(d.date), style: const TextStyle(color: AC.muted, fontSize: 9)),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 7),
          Row(
            children: [
              Expanded(child: _metric('إجمالي المدفوع', '${n(c.collectedAmount(a, round))} ${c.currency}', AC.teal)),
              const SizedBox(width: 7),
              Expanded(child: _metric('إجمالي المسلّم', '${n(a.deliveredTotal(round))} ${c.currency}', AC.cyan)),
            ],
          ),
        ],
      ),
    );
  }

  static Widget _statementWidget(
    JamiyatiController c,
    Association a,
    int roundIndex,
    ReportScope scope,
  ) {
    final rounds = _roundsFor(a, roundIndex, scope);
    final collected = _collectedForRounds(c, a, rounds);
    final delivered = _deliveredForRounds(a, rounds);
    return Container(
      width: 470,
      padding: const EdgeInsets.all(20),
      color: AC.bg,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(gradient: AC.heroGrad, borderRadius: BorderRadius.circular(20)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('جمعيتي Pro', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(a.name, style: const TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                Text(
                  scope == ReportScope.month ? 'كشف شهري • ${scopeLabel(a, roundIndex, scope)}' : 'كشف لغاية تاريخه • ${scopeLabel(a, roundIndex, scope)}',
                  style: const TextStyle(color: Colors.white70, fontSize: 10),
                ),
                const SizedBox(height: 8),
                Text('قيمة القسط: ${n(a.amount)} ${c.currency}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (rounds.isEmpty)
            const Padding(
              padding: EdgeInsets.all(18),
              child: Text('لم تبدأ الجمعية بعد.', style: TextStyle(color: AC.muted)),
            )
          else
            ...rounds.map((r) => _roundBlock(c, a, r)),
          Row(
            children: [
              Expanded(child: _metric('إجمالي المدفوع للفترة', '${n(collected)} ${c.currency}', AC.teal)),
              const SizedBox(width: 7),
              Expanded(child: _metric('إجمالي المسلّم للفترة', '${n(delivered)} ${c.currency}', AC.cyan)),
            ],
          ),
          const SizedBox(height: 10),
          Text('تم إنشاء الكشف ${_date.format(DateTime.now())}', style: const TextStyle(color: AC.hint, fontSize: 8)),
        ],
      ),
    );
  }

  static Future<File> _createPngFile(
    JamiyatiController c,
    Association a,
    int roundIndex,
    ReportScope scope,
  ) async {
    final bytes = await _captureWidget(_statementWidget(c, a, roundIndex, scope), pixelRatio: 2.25);
    final dir = await getTemporaryDirectory();
    final suffix = scope == ReportScope.month ? 'month_${roundIndex + 1}' : 'to_date';
    final file = File('${dir.path}/Jamiyati_${a.id}_$suffix.png');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  static Future<File> _createPdfFile(
    JamiyatiController c,
    Association a,
    int roundIndex,
    ReportScope scope,
  ) async {
    final pdf = pw.Document();
    final rounds = _roundsFor(a, roundIndex, scope);
    final pageRounds = scope == ReportScope.month ? rounds : rounds;
    if (pageRounds.isEmpty) {
      final png = await _captureWidget(_statementWidget(c, a, roundIndex, scope), pixelRatio: 2.4);
      final image = pw.MemoryImage(png);
      pdf.addPage(pw.Page(pageFormat: PdfPageFormat.a4, margin: const pw.EdgeInsets.all(18), build: (_) => pw.Center(child: pw.Image(image, fit: pw.BoxFit.contain))));
    } else {
      for (final round in pageRounds) {
        final png = await _captureWidget(
          _statementWidget(c, a, round, ReportScope.month),
          pixelRatio: 2.4,
        );
        final image = pw.MemoryImage(png);
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(18),
            build: (_) => pw.Center(child: pw.Image(image, fit: pw.BoxFit.contain)),
          ),
        );
      }
    }
    final dir = await getTemporaryDirectory();
    final suffix = scope == ReportScope.month ? 'month_${roundIndex + 1}' : 'to_date';
    final file = File('${dir.path}/Jamiyati_${a.id}_$suffix.pdf');
    await file.writeAsBytes(await pdf.save(), flush: true);
    return file;
  }

  static xl.CellStyle _headerStyle() => xl.CellStyle(
        bold: true,
        fontColorHex: xl.ExcelColor.white,
        backgroundColorHex: xl.ExcelColor.fromHexString('#176B57'),
        horizontalAlign: xl.HorizontalAlign.Center,
        verticalAlign: xl.VerticalAlign.Center,
        textWrapping: xl.TextWrapping.WrapText,
      );

  static void _styleRow(xl.Sheet sheet, int row, int lastColumn) {
    for (var col = 0; col <= lastColumn; col++) {
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row)).cellStyle = _headerStyle();
    }
  }

  static Future<File> _createExcelFile(
    JamiyatiController c,
    Association a,
    int roundIndex,
    ReportScope scope,
  ) async {
    final rounds = _roundsFor(a, roundIndex, scope);
    final excel = xl.Excel.createExcel();
    excel.rename('Sheet1', 'الحركات');
    final sheet = excel['الحركات'];
    sheet.appendRow([
      xl.TextCellValue('الشهر'),
      xl.TextCellValue('الدور'),
      xl.TextCellValue('نوع الحركة'),
      xl.TextCellValue('الاسم'),
      xl.TextCellValue('الحالة'),
      xl.TextCellValue('المبلغ'),
      xl.TextCellValue('العملة'),
      xl.TextCellValue('التاريخ'),
    ]);
    _styleRow(sheet, 0, 7);

    for (final round in rounds) {
      for (final member in a.members) {
        final paidAt = c.paymentDate(a, round, member);
        final stage = c.contributionStage(a, round, member);
        final status = stage == ContributionStage.paid
            ? 'تم الدفع'
            : stage == ContributionStage.late
                ? 'متأخر'
                : 'لم يدفع بعد';
        sheet.appendRow([
          xl.TextCellValue(monthYear(roundMonth(a, round))),
          xl.IntCellValue(round + 1),
          xl.TextCellValue('دفع'),
          xl.TextCellValue(member.name),
          xl.TextCellValue(status),
          xl.DoubleCellValue(paidAt == null ? 0 : a.amount),
          xl.TextCellValue(c.currency),
          xl.TextCellValue(paidAt == null ? '' : _date.format(paidAt)),
        ]);
      }
      final receiver = a.receiverFor(round)?.name ?? '-';
      for (final d in a.deliveryFor(round)) {
        sheet.appendRow([
          xl.TextCellValue(monthYear(roundMonth(a, round))),
          xl.IntCellValue(round + 1),
          xl.TextCellValue('تسليم'),
          xl.TextCellValue(receiver),
          xl.TextCellValue('تم التسليم'),
          xl.DoubleCellValue(d.amount),
          xl.TextCellValue(c.currency),
          xl.TextCellValue(_date.format(d.date)),
        ]);
      }
    }
    sheet.setColumnWidth(0, 18);
    sheet.setColumnWidth(1, 9);
    sheet.setColumnWidth(2, 14);
    sheet.setColumnWidth(3, 22);
    sheet.setColumnWidth(4, 18);
    sheet.setColumnWidth(5, 16);
    sheet.setColumnWidth(6, 10);
    sheet.setColumnWidth(7, 22);

    final summary = excel['الملخص'];
    summary.appendRow([xl.TextCellValue('جمعيتي Pro — ${a.name}')]);
    summary.appendRow([xl.TextCellValue('نوع الكشف'), xl.TextCellValue(scope == ReportScope.month ? 'شهري' : 'لغاية تاريخه')]);
    summary.appendRow([xl.TextCellValue('الفترة'), xl.TextCellValue(scopeLabel(a, roundIndex, scope))]);
    summary.appendRow([xl.TextCellValue('إجمالي المدفوع'), xl.DoubleCellValue(_collectedForRounds(c, a, rounds)), xl.TextCellValue(c.currency)]);
    summary.appendRow([xl.TextCellValue('إجمالي المسلّم'), xl.DoubleCellValue(_deliveredForRounds(a, rounds)), xl.TextCellValue(c.currency)]);
    summary.setColumnWidth(0, 24);
    summary.setColumnWidth(1, 28);
    summary.setColumnWidth(2, 12);

    excel.setDefaultSheet('الحركات');
    final bytes = excel.save();
    if (bytes == null) throw StateError('تعذر إنشاء ملف Excel');
    final dir = await getTemporaryDirectory();
    final suffix = scope == ReportScope.month ? 'month_${roundIndex + 1}' : 'to_date';
    final file = File('${dir.path}/Jamiyati_${a.id}_$suffix.xlsx');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  static Future<void> exportPdf(
    JamiyatiController c,
    Association a,
    int roundIndex, {
    ReportScope scope = ReportScope.month,
  }) async {
    final file = await _createPdfFile(c, a, roundIndex, scope);
    await Share.shareXFiles([XFile(file.path)], text: 'كشف ${a.name} — PDF');
  }

  static Future<void> exportPng(
    JamiyatiController c,
    Association a,
    int roundIndex, {
    ReportScope scope = ReportScope.month,
  }) async {
    final file = await _createPngFile(c, a, roundIndex, scope);
    await Share.shareXFiles([XFile(file.path)], text: 'كشف ${a.name} — PNG');
  }

  static Future<void> exportExcel(
    JamiyatiController c,
    Association a,
    int roundIndex, {
    ReportScope scope = ReportScope.month,
  }) async {
    final file = await _createExcelFile(c, a, roundIndex, scope);
    await Share.shareXFiles([XFile(file.path)], text: 'كشف ${a.name} — Excel');
  }

  static Future<void> exportAll(
    JamiyatiController c,
    Association a,
    int roundIndex, {
    ReportScope scope = ReportScope.month,
  }) async {
    final files = await Future.wait<File>([
      _createPdfFile(c, a, roundIndex, scope),
      _createPngFile(c, a, roundIndex, scope),
      _createExcelFile(c, a, roundIndex, scope),
    ]);
    await Share.shareXFiles(
      files.map((f) => XFile(f.path)).toList(),
      text: 'تقارير ${a.name} — PDF + PNG + Excel',
    );
  }

  static Widget _metric(String title, String value, Color color) => Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w900)),
            const SizedBox(height: 2),
            Text(title, style: const TextStyle(color: AC.muted, fontSize: 8)),
          ],
        ),
      );
}
