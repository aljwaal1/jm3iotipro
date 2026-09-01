import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';

import 'app_theme.dart';
import 'controller.dart';
import 'models.dart';

class ReportService {
  static final NumberFormat _number = NumberFormat('#,##0.##');
  static final DateFormat _date = DateFormat('yyyy/MM/dd HH:mm');

  static String n(num value) => _number.format(value);

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
    b.writeln('الدور: ${roundIndex + 1} من ${a.monthsCount}');
    b.writeln('الفترة: ${c.roundLabel(a, roundIndex)}');
    b.writeln('صاحب الدور: ${receiver?.name ?? '-'}');
    b.writeln('قيمة القسط: ${n(a.amount)} ${c.currency}');
    b.writeln('إجمالي الدور: ${n(a.roundTotal)} ${c.currency}');
    b.writeln('دفعوا: $paid / ${a.members.length}');
    b.writeln('بانتظار الدفع: $waiting');
    b.writeln('متأخرون: $late');
    b.writeln('المحصل: ${n(c.collectedAmount(a, roundIndex))} ${c.currency}');
    b.writeln('المسلّم لصاحب الدور: ${n(delivered)} ${c.currency}');
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
    if (a.note.trim().isNotEmpty) {
      b.writeln('------------------------------');
      b.writeln('ملاحظة: ${a.note}');
    }
    return b.toString();
  }

  static Future<void> exportPdf(
    JamiyatiController c,
    Association a,
    int roundIndex,
  ) async {
    final pdf = pw.Document();
    pw.Font? regular;
    pw.Font? bold;
    try {
      regular = await PdfGoogleFonts.notoNaskhArabicRegular();
      bold = await PdfGoogleFonts.notoNaskhArabicBold();
    } catch (_) {
      regular = null;
      bold = null;
    }

    final receiver = a.receiverFor(roundIndex);
    final paid = c.paidCount(a, roundIndex);
    final late = c.lateCount(a, roundIndex);
    final waiting = c.waitingCount(a, roundIndex);
    final collected = c.collectedAmount(a, roundIndex);
    final delivered = a.deliveredTotal(roundIndex);
    final remaining = a.deliveryRemaining(roundIndex);

    final baseStyle = pw.TextStyle(font: regular, fontSize: 11, color: PdfColors.blueGrey900);
    final boldStyle = pw.TextStyle(font: bold ?? regular, fontSize: 11, fontWeight: pw.FontWeight.bold);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(30),
        theme: pw.ThemeData.withFont(base: regular, bold: bold),
        textDirection: pw.TextDirection.rtl,
        build: (_) => [
          pw.Container(
            padding: const pw.EdgeInsets.all(20),
            decoration: pw.BoxDecoration(
              gradient: const pw.LinearGradient(
                colors: [PdfColor.fromInt(0xFF5B6CFF), PdfColor.fromInt(0xFF087D8C)],
              ),
              borderRadius: pw.BorderRadius.circular(16),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'جمعيتي Pro',
                      style: pw.TextStyle(
                        font: bold ?? regular,
                        fontSize: 13,
                        color: PdfColors.white,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 5),
                    pw.Text(
                      a.name,
                      style: pw.TextStyle(
                        font: bold ?? regular,
                        fontSize: 24,
                        color: PdfColors.white,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'الدور ${roundIndex + 1} من ${a.monthsCount} • ${c.roundLabel(a, roundIndex)}',
                      style: pw.TextStyle(font: regular, fontSize: 11, color: PdfColors.white),
                    ),
                  ],
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                  decoration: pw.BoxDecoration(
                    color: const PdfColor.fromInt(0x22FFFFFF),
                    borderRadius: pw.BorderRadius.circular(12),
                  ),
                  child: pw.Column(
                    children: [
                      pw.Text('صاحب الدور', style: pw.TextStyle(font: regular, color: PdfColors.white, fontSize: 9)),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        receiver?.name ?? '-',
                        style: pw.TextStyle(
                          font: bold ?? regular,
                          color: PdfColors.white,
                          fontSize: 15,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 16),
          pw.Row(
            children: [
              _stat('إجمالي الدور', '${n(a.roundTotal)} ${c.currency}', PdfColors.indigo, bold, regular),
              pw.SizedBox(width: 8),
              _stat('المحصل', '${n(collected)} ${c.currency}', PdfColors.teal, bold, regular),
              pw.SizedBox(width: 8),
              _stat('المسلّم', '${n(delivered)} ${c.currency}', PdfColors.blue, bold, regular),
              pw.SizedBox(width: 8),
              _stat('متبقي للتسليم', '${n(remaining)} ${c.currency}', PdfColors.orange, bold, regular),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            children: [
              _stat('دفعوا', '$paid', PdfColors.green, bold, regular),
              pw.SizedBox(width: 8),
              _stat('بانتظار الدفع', '$waiting', PdfColors.blueGrey, bold, regular),
              pw.SizedBox(width: 8),
              _stat('متأخرون', '$late', PdfColors.red, bold, regular),
              pw.SizedBox(width: 8),
              _stat('قيمة القسط', '${n(a.amount)} ${c.currency}', PdfColors.deepPurple, bold, regular),
            ],
          ),
          pw.SizedBox(height: 18),
          pw.Text('دفعات الأعضاء', style: pw.TextStyle(font: bold ?? regular, fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.blueGrey200, width: 0.6),
            columnWidths: const {
              0: pw.FlexColumnWidth(0.6),
              1: pw.FlexColumnWidth(2.0),
              2: pw.FlexColumnWidth(1.2),
              3: pw.FlexColumnWidth(1.8),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF1F5F9)),
                children: [
                  _cell('#', boldStyle),
                  _cell('العضو', boldStyle),
                  _cell('الحالة', boldStyle),
                  _cell('تاريخ الدفع', boldStyle),
                ],
              ),
              ...a.members.asMap().entries.map((entry) {
                final m = entry.value;
                final stage = c.contributionStage(a, roundIndex, m);
                final stageText = stage == ContributionStage.paid
                    ? 'دفع'
                    : stage == ContributionStage.late
                        ? 'متأخر'
                        : 'بانتظار الدفع';
                final paymentDate = c.paymentDate(a, roundIndex, m);
                return pw.TableRow(
                  children: [
                    _cell('${entry.key + 1}', baseStyle),
                    _cell(m.name, baseStyle),
                    _cell(stageText, baseStyle),
                    _cell(paymentDate == null ? '-' : _date.format(paymentDate), baseStyle),
                  ],
                );
              }),
            ],
          ),
          if (a.deliveryFor(roundIndex).isNotEmpty) ...[
            pw.SizedBox(height: 18),
            pw.Text('سجل التسليم لصاحب الدور', style: pw.TextStyle(font: bold ?? regular, fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            ...a.deliveryFor(roundIndex).map(
              (d) => pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 6),
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: const PdfColor.fromInt(0xFFF8FAFC),
                  borderRadius: pw.BorderRadius.circular(8),
                  border: pw.Border.all(color: PdfColors.blueGrey100),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('${n(d.amount)} ${c.currency}', style: boldStyle),
                    pw.Text(_date.format(d.date), style: baseStyle),
                  ],
                ),
              ),
            ),
          ],
          if (a.note.trim().isNotEmpty) ...[
            pw.SizedBox(height: 16),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: const PdfColor.fromInt(0xFFFFFBEB),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Text('ملاحظة: ${a.note}', style: baseStyle),
            ),
          ],
          pw.SizedBox(height: 20),
          pw.Divider(color: PdfColors.blueGrey200),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('تم إنشاؤه بواسطة جمعيتي Pro', style: pw.TextStyle(font: regular, fontSize: 9, color: PdfColors.blueGrey500)),
              pw.Text(_date.format(DateTime.now()), style: pw.TextStyle(font: regular, fontSize: 9, color: PdfColors.blueGrey500)),
            ],
          ),
        ],
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'jamiyati_${a.name}_round_${roundIndex + 1}.pdf',
    );
  }

  static pw.Widget _stat(
    String title,
    String value,
    PdfColor color,
    pw.Font? bold,
    pw.Font? regular,
  ) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(11),
        decoration: pw.BoxDecoration(
          color: const PdfColor.fromInt(0xFFF8FAFC),
          borderRadius: pw.BorderRadius.circular(10),
          border: pw.Border.all(color: const PdfColor.fromInt(0xFFE2E8F0)),
        ),
        child: pw.Column(
          children: [
            pw.Text(value, style: pw.TextStyle(font: bold ?? regular, color: color, fontSize: 13, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 3),
            pw.Text(title, style: pw.TextStyle(font: regular, color: PdfColors.blueGrey500, fontSize: 8)),
          ],
        ),
      ),
    );
  }

  static pw.Widget _cell(String text, pw.TextStyle style) => pw.Padding(
        padding: const pw.EdgeInsets.all(7),
        child: pw.Text(text, textAlign: pw.TextAlign.center, style: style),
      );

  static Future<void> exportPng(
    JamiyatiController c,
    Association a,
    int roundIndex,
  ) async {
    final controller = ScreenshotController();
    final bytes = await controller.captureFromWidget(
      Directionality(
        textDirection: TextDirection.rtl,
        child: Material(
          color: AC.bg,
          child: _statementWidget(c, a, roundIndex),
        ),
      ),
      pixelRatio: 2.4,
      delay: const Duration(milliseconds: 80),
    );
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/jamiyati_${a.id}_round_${roundIndex + 1}.png');
    await file.writeAsBytes(bytes);
    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'كشف ${a.name} - الدور ${roundIndex + 1}',
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
    final progress = a.roundTotal <= 0 ? 0.0 : (collected / a.roundTotal).clamp(0.0, 1.0);

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
                const Text('جمعيتي Pro', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(a.name, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Text('الدور ${roundIndex + 1} من ${a.monthsCount} • ${c.roundLabel(a, roundIndex)}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('صاحب الدور', style: TextStyle(color: Colors.white70, fontSize: 11)),
                        Text(receiver?.name ?? '-', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('إجمالي الدور', style: TextStyle(color: Colors.white70, fontSize: 11)),
                        Text('${n(a.roundTotal)} ${c.currency}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _pngStat('المحصل', '${n(collected)} ${c.currency}', AC.teal),
              const SizedBox(width: 8),
              _pngStat('المسلّم', '${n(delivered)} ${c.currency}', AC.cyan),
              const SizedBox(width: 8),
              _pngStat('المتبقي', '${n(remaining)} ${c.currency}', AC.amber),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _pngStat('دفعوا', '$paid', AC.teal),
              const SizedBox(width: 8),
              _pngStat('بانتظار', '$waiting', AC.primary),
              const SizedBox(width: 8),
              _pngStat('متأخرون', '$late', AC.rose),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('نسبة التحصيل', style: TextStyle(color: AC.muted, fontSize: 11)),
              Text('${(progress * 100).round()}%', style: const TextStyle(color: AC.text, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: AC.card2,
              valueColor: const AlwaysStoppedAnimation(AC.teal),
            ),
          ),
          const SizedBox(height: 16),
          const Text('دفعات الأعضاء', style: TextStyle(color: AC.text, fontSize: 15, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: AC.card,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AC.border),
            ),
            child: Column(
              children: a.members.asMap().entries.map((entry) {
                final m = entry.value;
                final stage = c.contributionStage(a, roundIndex, m);
                final paidStage = stage == ContributionStage.paid;
                final color = paidStage
                    ? AC.teal
                    : stage == ContributionStage.late
                        ? AC.rose
                        : AC.amber;
                final label = paidStage
                    ? 'دفع'
                    : stage == ContributionStage.late
                        ? 'متأخر'
                        : 'بانتظار';
                final d = c.paymentDate(a, roundIndex, m);
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
                  decoration: BoxDecoration(
                    border: entry.key == a.members.length - 1
                        ? null
                        : const Border(bottom: BorderSide(color: AC.borderSoft)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Center(child: Text('${entry.key + 1}', style: TextStyle(color: color, fontWeight: FontWeight.w900))),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(m.name, style: const TextStyle(color: AC.text, fontWeight: FontWeight.w800)),
                            if (d != null) Text(_date.format(d), style: const TextStyle(color: AC.muted, fontSize: 9)),
                          ],
                        ),
                      ),
                      Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('جمعيتي Pro', style: TextStyle(color: AC.hint, fontSize: 10)),
              Text(_date.format(DateTime.now()), style: const TextStyle(color: AC.hint, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }

  static Widget _pngStat(String title, String value, Color color) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(
            color: AC.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AC.borderSoft),
          ),
          child: Column(
            children: [
              Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w900)),
              const SizedBox(height: 3),
              Text(title, style: const TextStyle(color: AC.muted, fontSize: 9)),
            ],
          ),
        ),
      );
}
