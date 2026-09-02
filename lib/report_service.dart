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

class ReportService {
  static final NumberFormat _number = NumberFormat('#,##0.##');
  static final DateFormat _date = DateFormat('yyyy/MM/dd HH:mm');
  static const _monthsAr = <String>[
    'يناير',
    'فبراير',
    'مارس',
    'أبريل',
    'مايو',
    'يونيو',
    'يوليو',
    'أغسطس',
    'سبتمبر',
    'أكتوبر',
    'نوفمبر',
    'ديسمبر',
  ];

  static String n(num value) => _number.format(value);

  static DateTime associationStart(Association a) => DateTime(a.startYear, a.startMonth);

  static DateTime associationEnd(Association a) =>
      DateTime(a.startYear, a.startMonth + a.monthsCount - 1);

  static String monthYear(DateTime d) => '${_monthsAr[d.month - 1]} ${d.year}';

  static String associationPeriod(Association a) =>
      '${monthYear(associationStart(a))} — ${monthYear(associationEnd(a))}';

  static int memberPaidRounds(
    JamiyatiController c,
    Association a,
    Member member,
  ) {
    var count = 0;
    for (var round = 0; round < a.monthsCount; round++) {
      if (c.isPaid(a, round, member)) count++;
    }
    return count;
  }

  static double memberPaidTotal(
    JamiyatiController c,
    Association a,
    Member member,
  ) => memberPaidRounds(c, a, member) * a.amount;

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

  static String memberAccountText(
    JamiyatiController c,
    Association a,
    Member member,
  ) {
    final paidRounds = memberPaidRounds(c, a, member);
    final paid = memberPaidTotal(c, a, member);
    final receiverRounds = memberReceiverRounds(a, member);
    final received = memberReceivedTotal(a, member);
    final net = received - paid;
    final b = StringBuffer();
    b.writeln('كشف حساب عضو - ${a.name}');
    b.writeln('الفترة: ${associationPeriod(a)}');
    b.writeln('العضو: ${member.name}');
    if (member.phone.trim().isNotEmpty) b.writeln('الهاتف: ${member.phone}');
    b.writeln('تم دفع: ${n(paid)} ${c.currency} ($paidRounds دفعات)');
    b.writeln('تم استلام: ${n(received)} ${c.currency}');
    if (receiverRounds.isNotEmpty) {
      b.writeln('أدوار الاستلام: ${receiverRounds.map((e) => e + 1).join('، ')}');
    }
    b.writeln('الصافي (استلم - دفع): ${n(net)} ${c.currency}');
    return b.toString();
  }

  static String associationText(
    JamiyatiController c,
    Association a,
    int roundIndex,
  ) {
    final receiver = a.receiverFor(roundIndex);
    final paid = c.paidCount(a, roundIndex);
    final late = c.lateCount(a, roundIndex);
    final waiting = c.waitingCount(a, roundIndex);
    final delivered = a.deliveredTotal(roundIndex);
    final remaining = a.deliveryRemaining(roundIndex);
    final b = StringBuffer();
    b.writeln('كشف جمعية: ${a.name}');
    b.writeln('بدء الجمعية: ${monthYear(associationStart(a))}');
    b.writeln('انتهاء الجمعية: ${monthYear(associationEnd(a))}');
    b.writeln('الدور: ${roundIndex + 1} من ${a.monthsCount}');
    b.writeln('الفترة: ${c.roundLabel(a, roundIndex)}');
    b.writeln('صاحب الدور: ${receiver?.name ?? '-'}');
    b.writeln('قيمة القسط: ${n(a.amount)} ${c.currency}');
    b.writeln('إجمالي الدور: ${n(a.roundTotal)} ${c.currency}');
    b.writeln('دفعوا: $paid / ${a.members.length}');
    b.writeln('بانتظار الدفع: $waiting');
    b.writeln('متأخرون: $late');
    b.writeln('تم دفع: ${n(c.collectedAmount(a, roundIndex))} ${c.currency}');
    b.writeln('تم تسليم: ${n(delivered)} ${c.currency}');
    b.writeln('المتبقي للتسليم: ${n(remaining)} ${c.currency}');
    b.writeln('------------------------------');
    for (final m in a.members) {
      final stage = c.contributionStage(a, roundIndex, m);
      final label = stage == ContributionStage.paid
          ? 'دفع'
          : stage == ContributionStage.late
              ? 'متأخر'
              : 'بانتظار الدفع';
      final when = c.paymentDate(a, roundIndex, m);
      b.write('${m.name}: $label');
      if (when != null) b.write(' - ${_date.format(when)}');
      b.writeln();
    }
    final deliveries = a.deliveryFor(roundIndex);
    if (deliveries.isNotEmpty) {
      b.writeln('------------------------------');
      b.writeln('سجل التسليم:');
      for (final d in deliveries) {
        b.writeln('${n(d.amount)} ${c.currency} - ${_date.format(d.date)}');
      }
    }
    b.writeln('------------------------------');
    b.writeln('كشف حساب الأعضاء - جميع الأدوار:');
    for (final member in a.members) {
      final totalPaid = memberPaidTotal(c, a, member);
      final totalReceived = memberReceivedTotal(a, member);
      final net = totalReceived - totalPaid;
      b.writeln(
        '${member.name}: دفع ${n(totalPaid)} • استلم ${n(totalReceived)} • الصافي ${n(net)} ${c.currency}',
      );
    }
    if (a.note.trim().isNotEmpty) {
      b.writeln('------------------------------');
      b.writeln('ملاحظة: ${a.note}');
    }
    return b.toString();
  }

  static Future<Uint8List> _captureStatement(
    JamiyatiController c,
    Association a,
    int roundIndex, {
    double pixelRatio = 2.2,
  }) async {
    final controller = ScreenshotController();
    return controller.captureFromWidget(
      Directionality(
        textDirection: ui.TextDirection.rtl,
        child: Material(
          color: AC.bg,
          child: _statementWidget(c, a, roundIndex),
        ),
      ),
      pixelRatio: pixelRatio,
      delay: const Duration(milliseconds: 80),
    );
  }

  static Future<File> _createPngFile(
    JamiyatiController c,
    Association a,
    int roundIndex,
  ) async {
    final bytes = await _captureStatement(c, a, roundIndex, pixelRatio: 2.4);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/Jamiyati_${a.id}_round_${roundIndex + 1}.png');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  static Future<File> _createPdfFile(
    JamiyatiController c,
    Association a,
    int roundIndex,
  ) async {
    final png = await _captureStatement(c, a, roundIndex, pixelRatio: 2.5);
    final image = pw.MemoryImage(png);
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(18),
        build: (_) => pw.Center(
          child: pw.FittedBox(
            fit: pw.BoxFit.contain,
            child: pw.Image(image),
          ),
        ),
      ),
    );
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/Jamiyati_${a.id}_round_${roundIndex + 1}.pdf');
    await file.writeAsBytes(await pdf.save(), flush: true);
    return file;
  }

  static xl.CellStyle _excelHeaderStyle() => xl.CellStyle(
        bold: true,
        fontColorHex: xl.ExcelColor.white,
        backgroundColorHex: xl.ExcelColor.fromHexString('#176B57'),
        horizontalAlign: xl.HorizontalAlign.Center,
        verticalAlign: xl.VerticalAlign.Center,
        textWrapping: xl.TextWrapping.WrapText,
      );

  static xl.CellStyle _excelTitleStyle() => xl.CellStyle(
        bold: true,
        fontSize: 16,
        fontColorHex: xl.ExcelColor.white,
        backgroundColorHex: xl.ExcelColor.fromHexString('#0F4035'),
        horizontalAlign: xl.HorizontalAlign.Center,
        verticalAlign: xl.VerticalAlign.Center,
      );

  static xl.CellStyle _excelLabelStyle() => xl.CellStyle(
        bold: true,
        fontColorHex: xl.ExcelColor.fromHexString('#176B57'),
        backgroundColorHex: xl.ExcelColor.fromHexString('#E8F5F0'),
        horizontalAlign: xl.HorizontalAlign.Right,
      );

  static void _styleRow(
    xl.Sheet sheet,
    int row,
    int fromColumn,
    int toColumn,
    xl.CellStyle style,
  ) {
    for (var col = fromColumn; col <= toColumn; col++) {
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row)).cellStyle = style;
    }
  }

  static Future<File> _createExcelFile(
    JamiyatiController c,
    Association a,
    int roundIndex,
  ) async {
    final excel = xl.Excel.createExcel();
    excel.rename('Sheet1', 'ملخص');

    final summary = excel['ملخص'];
    summary.merge(xl.CellIndex.indexByString('A1'), xl.CellIndex.indexByString('D1'));
    summary.cell(xl.CellIndex.indexByString('A1'))
      ..value = xl.TextCellValue('جمعيتي Pro — ${a.name}')
      ..cellStyle = _excelTitleStyle();

    final summaryRows = <List<xl.CellValue>>[
      [xl.TextCellValue('بدء الجمعية'), xl.TextCellValue(monthYear(associationStart(a)))],
      [xl.TextCellValue('انتهاء الجمعية'), xl.TextCellValue(monthYear(associationEnd(a)))],
      [xl.TextCellValue('عدد الأعضاء'), xl.IntCellValue(a.members.length)],
      [xl.TextCellValue('عدد الأدوار'), xl.IntCellValue(a.monthsCount)],
      [xl.TextCellValue('قيمة القسط'), xl.DoubleCellValue(a.amount), xl.TextCellValue(c.currency)],
      [xl.TextCellValue('إجمالي كل دور'), xl.DoubleCellValue(a.roundTotal), xl.TextCellValue(c.currency)],
      [xl.TextCellValue('الدور المحدد'), xl.IntCellValue(roundIndex + 1)],
      [xl.TextCellValue('فترة الدور'), xl.TextCellValue(c.roundLabel(a, roundIndex))],
      [xl.TextCellValue('صاحب الدور'), xl.TextCellValue(a.receiverFor(roundIndex)?.name ?? '-')],
      [xl.TextCellValue('تم دفع'), xl.DoubleCellValue(c.collectedAmount(a, roundIndex)), xl.TextCellValue(c.currency)],
      [xl.TextCellValue('تم تسليم'), xl.DoubleCellValue(a.deliveredTotal(roundIndex)), xl.TextCellValue(c.currency)],
      [xl.TextCellValue('متبقي للتسليم'), xl.DoubleCellValue(a.deliveryRemaining(roundIndex)), xl.TextCellValue(c.currency)],
    ];
    for (final row in summaryRows) {
      summary.appendRow(row);
    }
    for (var r = 1; r <= summaryRows.length; r++) {
      summary.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: r)).cellStyle = _excelLabelStyle();
    }
    summary.setColumnWidth(0, 24);
    summary.setColumnWidth(1, 24);
    summary.setColumnWidth(2, 14);
    summary.setColumnWidth(3, 14);

    final accounts = excel['حسابات الأعضاء'];
    accounts.appendRow([
      xl.TextCellValue('الترتيب'),
      xl.TextCellValue('الاسم'),
      xl.TextCellValue('الهاتف'),
      xl.TextCellValue('عدد الدفعات'),
      xl.TextCellValue('تم دفع'),
      xl.TextCellValue('تم استلام'),
      xl.TextCellValue('الصافي'),
      xl.TextCellValue('أدوار الاستلام'),
    ]);
    _styleRow(accounts, 0, 0, 7, _excelHeaderStyle());
    for (var i = 0; i < a.members.length; i++) {
      final member = a.members[i];
      final paidRounds = memberPaidRounds(c, a, member);
      final totalPaid = memberPaidTotal(c, a, member);
      final totalReceived = memberReceivedTotal(a, member);
      final receiverRounds = memberReceiverRounds(a, member);
      accounts.appendRow([
        xl.IntCellValue(i + 1),
        xl.TextCellValue(member.name),
        xl.TextCellValue(member.phone),
        xl.IntCellValue(paidRounds),
        xl.DoubleCellValue(totalPaid),
        xl.DoubleCellValue(totalReceived),
        xl.DoubleCellValue(totalReceived - totalPaid),
        xl.TextCellValue(receiverRounds.map((e) => e + 1).join('، ')),
      ]);
    }
    accounts.setColumnWidth(0, 10);
    accounts.setColumnWidth(1, 22);
    accounts.setColumnWidth(2, 20);
    accounts.setColumnWidth(3, 14);
    accounts.setColumnWidth(4, 16);
    accounts.setColumnWidth(5, 16);
    accounts.setColumnWidth(6, 16);
    accounts.setColumnWidth(7, 20);

    final payments = excel['الدفعات'];
    payments.appendRow([
      xl.TextCellValue('الدور'),
      xl.TextCellValue('الشهر'),
      xl.TextCellValue('صاحب الدور'),
      xl.TextCellValue('العضو'),
      xl.TextCellValue('الحالة'),
      xl.TextCellValue('قيمة القسط'),
      xl.TextCellValue('تاريخ الدفع'),
    ]);
    _styleRow(payments, 0, 0, 6, _excelHeaderStyle());
    for (var round = 0; round < a.monthsCount; round++) {
      for (final member in a.members) {
        final stage = c.contributionStage(a, round, member);
        final status = stage == ContributionStage.paid
            ? 'تم الدفع'
            : stage == ContributionStage.late
                ? 'متأخر'
                : 'بانتظار الدفع';
        final paidAt = c.paymentDate(a, round, member);
        payments.appendRow([
          xl.IntCellValue(round + 1),
          xl.TextCellValue(c.roundLabel(a, round)),
          xl.TextCellValue(a.receiverFor(round)?.name ?? '-'),
          xl.TextCellValue(member.name),
          xl.TextCellValue(status),
          xl.DoubleCellValue(a.amount),
          xl.TextCellValue(paidAt == null ? '' : _date.format(paidAt)),
        ]);
      }
    }
    payments.setColumnWidth(0, 9);
    payments.setColumnWidth(1, 18);
    payments.setColumnWidth(2, 22);
    payments.setColumnWidth(3, 22);
    payments.setColumnWidth(4, 18);
    payments.setColumnWidth(5, 16);
    payments.setColumnWidth(6, 22);

    final deliveries = excel['التسليم'];
    deliveries.appendRow([
      xl.TextCellValue('الدور'),
      xl.TextCellValue('الشهر'),
      xl.TextCellValue('صاحب الدور'),
      xl.TextCellValue('المبلغ المسلّم'),
      xl.TextCellValue('التاريخ'),
      xl.TextCellValue('ملاحظة'),
    ]);
    _styleRow(deliveries, 0, 0, 5, _excelHeaderStyle());
    for (var round = 0; round < a.monthsCount; round++) {
      for (final d in a.deliveryFor(round)) {
        deliveries.appendRow([
          xl.IntCellValue(round + 1),
          xl.TextCellValue(c.roundLabel(a, round)),
          xl.TextCellValue(a.receiverFor(round)?.name ?? '-'),
          xl.DoubleCellValue(d.amount),
          xl.TextCellValue(_date.format(d.date)),
          xl.TextCellValue(d.note),
        ]);
      }
    }
    deliveries.setColumnWidth(0, 9);
    deliveries.setColumnWidth(1, 18);
    deliveries.setColumnWidth(2, 22);
    deliveries.setColumnWidth(3, 18);
    deliveries.setColumnWidth(4, 22);
    deliveries.setColumnWidth(5, 26);

    excel.setDefaultSheet('ملخص');
    final bytes = excel.save();
    if (bytes == null) throw StateError('تعذر إنشاء ملف Excel');
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/Jamiyati_${a.id}_report.xlsx');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  static Future<void> exportPdf(
    JamiyatiController c,
    Association a,
    int roundIndex,
  ) async {
    final file = await _createPdfFile(c, a, roundIndex);
    await Share.shareXFiles([XFile(file.path)], text: 'كشف ${a.name} — PDF');
  }

  static Future<void> exportPng(
    JamiyatiController c,
    Association a,
    int roundIndex,
  ) async {
    final file = await _createPngFile(c, a, roundIndex);
    await Share.shareXFiles([XFile(file.path)], text: 'كشف ${a.name} — صورة');
  }

  static Future<void> exportExcel(
    JamiyatiController c,
    Association a,
    int roundIndex,
  ) async {
    final file = await _createExcelFile(c, a, roundIndex);
    await Share.shareXFiles([XFile(file.path)], text: 'كشف ${a.name} — Excel');
  }

  static Future<void> exportAll(
    JamiyatiController c,
    Association a,
    int roundIndex,
  ) async {
    final files = await Future.wait<File>([
      _createPdfFile(c, a, roundIndex),
      _createPngFile(c, a, roundIndex),
      _createExcelFile(c, a, roundIndex),
    ]);
    await Share.shareXFiles(
      files.map((f) => XFile(f.path)).toList(),
      text: 'تقارير ${a.name} — PDF + PNG + Excel',
    );
  }

  static Widget _statementWidget(
    JamiyatiController c,
    Association a,
    int roundIndex,
  ) {
    final receiver = a.receiverFor(roundIndex);
    final paid = c.paidCount(a, roundIndex);
    final late = c.lateCount(a, roundIndex);
    final waiting = c.waitingCount(a, roundIndex);
    final collected = c.collectedAmount(a, roundIndex);
    final delivered = a.deliveredTotal(roundIndex);
    final remaining = a.deliveryRemaining(roundIndex);
    final progress = a.roundTotal <= 0
        ? 0.0
        : (collected / a.roundTotal).clamp(0.0, 1.0);

    return Container(
      width: 430,
      padding: const EdgeInsets.all(22),
      color: AC.bg,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: AC.heroGrad,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'جمعيتي Pro',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  a.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${monthYear(associationStart(a))} — ${monthYear(associationEnd(a))}',
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
                const SizedBox(height: 4),
                Text(
                  'الدور ${roundIndex + 1} من ${a.monthsCount} • ${c.roundLabel(a, roundIndex)}',
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
                const SizedBox(height: 12),
                Text(
                  'صاحب الدور: ${receiver?.name ?? '-'}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _metric('إجمالي الدور', '${n(a.roundTotal)} ${c.currency}', AC.primary),
              const SizedBox(width: 7),
              _metric('تم دفع', '${n(collected)} ${c.currency}', AC.teal),
            ],
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              _metric('تم تسليم', '${n(delivered)} ${c.currency}', AC.cyan),
              const SizedBox(width: 7),
              _metric('متبقي للتسليم', '${n(remaining)} ${c.currency}', AC.amber),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'دفع $paid • انتظار $waiting • متأخر $late',
            style: const TextStyle(color: AC.muted, fontSize: 11),
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor: AC.borderSoft,
              valueColor: const AlwaysStoppedAnimation<Color>(AC.teal),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'دفعات الأعضاء - هذا الدور',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 7),
          ...a.members.map((m) {
            final stage = c.contributionStage(a, roundIndex, m);
            final paidDate = c.paymentDate(a, roundIndex, m);
            final color = stage == ContributionStage.paid
                ? AC.teal
                : stage == ContributionStage.late
                    ? AC.rose
                    : AC.amber;
            final label = stage == ContributionStage.paid
                ? 'تم الدفع'
                : stage == ContributionStage.late
                    ? 'متأخر'
                    : 'بانتظار الدفع';
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
              decoration: BoxDecoration(
                color: AC.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AC.borderSoft),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      m.name,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                    ),
                  ),
                  Text(
                    paidDate == null
                        ? label
                        : '$label • ${DateFormat('yyyy/MM/dd').format(paidDate)}',
                    style: TextStyle(
                      color: color,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            );
          }),
          if (a.deliveryFor(roundIndex).isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text(
              'سجل التسليم لصاحب الدور',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 7),
            ...a.deliveryFor(roundIndex).map(
              (d) => Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                decoration: BoxDecoration(
                  color: AC.card2,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${n(d.amount)} ${c.currency}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    Text(
                      _date.format(d.date),
                      style: const TextStyle(color: AC.muted, fontSize: 9),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          const Text(
            'كشف حساب الأعضاء - جميع الأدوار',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 7),
          ...a.members.map((member) {
            final totalPaid = memberPaidTotal(c, a, member);
            final totalReceived = memberReceivedTotal(a, member);
            final net = totalReceived - totalPaid;
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AC.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AC.borderSoft),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member.name,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'دفع: ${n(totalPaid)} ${c.currency}',
                          style: const TextStyle(color: AC.teal, fontSize: 10, fontWeight: FontWeight.w800),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'استلم: ${n(totalReceived)} ${c.currency}',
                          style: const TextStyle(color: AC.cyan, fontSize: 10, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'الصافي: ${n(net)} ${c.currency}',
                    style: const TextStyle(color: AC.muted, fontSize: 9, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            );
          }),
          if (a.note.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: AC.amber.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Text(
                'ملاحظة: ${a.note}',
                style: const TextStyle(color: AC.text, fontSize: 10, height: 1.5),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            'تم إنشاؤه بواسطة جمعيتي Pro • ${_date.format(DateTime.now())}',
            style: const TextStyle(color: AC.hint, fontSize: 9),
          ),
        ],
      ),
    );
  }

  static Widget _metric(String title, String value, Color color) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(title, style: const TextStyle(color: AC.muted, fontSize: 9)),
            ],
          ),
        ),
      );
}
