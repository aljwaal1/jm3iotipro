import 'dart:io';
import 'dart:ui' as ui;

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

  static Future<void> exportPdf(
    JamiyatiController c,
    Association a,
    int roundIndex,
  ) async {
    // Render Arabic with Flutter first, then embed the rendered image in PDF.
    // This keeps the PDF fully offline and avoids downloading Arabic fonts.
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
    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'jamiyati_${a.id}_round_${roundIndex + 1}.pdf',
    );
  }

  static Future<void> exportPng(
    JamiyatiController c,
    Association a,
    int roundIndex,
  ) async {
    final bytes = await _captureStatement(c, a, roundIndex, pixelRatio: 2.4);
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
              _metric('المحصل', '${n(collected)} ${c.currency}', AC.teal),
            ],
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              _metric('المسلّم', '${n(delivered)} ${c.currency}', AC.cyan),
              const SizedBox(width: 7),
              _metric('المتبقي', '${n(remaining)} ${c.currency}', AC.amber),
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
            'دفعات الأعضاء',
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
