import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_theme.dart';
import 'controller.dart';
import 'models.dart';
import 'report_service.dart';

class DetailsPage extends StatefulWidget {
  const DetailsPage({
    super.key,
    required this.controller,
    required this.association,
  });

  final JamiyatiController controller;
  final Association association;

  @override
  State<DetailsPage> createState() => _DetailsPageState();
}

class _DetailsPageState extends State<DetailsPage> {
  late int selectedRound;
  final DateFormat _date = DateFormat('yyyy/MM/dd');

  JamiyatiController get c => widget.controller;
  Association get a => widget.association;

  @override
  void initState() {
    super.initState();
    selectedRound = c.displayRound(a);
    c.addListener(_refresh);
  }

  @override
  void dispose() {
    c.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final receiver = a.receiverFor(selectedRound);
    final paid = c.paidCount(a, selectedRound);
    final late = c.lateCount(a, selectedRound);
    final waiting = c.waitingCount(a, selectedRound);
    final collected = c.collectedAmount(a, selectedRound);
    final progress = a.roundTotal <= 0 ? 0.0 : (collected / a.roundTotal).clamp(0.0, 1.0);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(a.name),
            Text(
              '${c.stageLabel(a)} • ${a.members.length} أعضاء',
              style: const TextStyle(color: AC.muted, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'PDF',
            onPressed: () => _run(() => ReportService.exportPdf(c, a, selectedRound), 'جاري إنشاء PDF...'),
            icon: const Icon(Icons.picture_as_pdf_rounded, color: AC.rose),
          ),
          PopupMenuButton<String>(
            color: AC.card2,
            onSelected: _menu,
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Text('تعديل الجمعية')),
              PopupMenuItem(value: 'archive', child: Text(a.archived ? 'إلغاء الأرشفة' : 'أرشفة الجمعية')),
              const PopupMenuItem(value: 'delete', child: Text('حذف الجمعية', style: TextStyle(color: AC.rose))),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 34),
        children: [
          _summaryCard(receiver, paid, late, waiting, collected, progress),
          const SizedBox(height: 14),
          _roundSelector(),
          const SizedBox(height: 14),
          _receiverCard(receiver),
          const SizedBox(height: 14),
          _paymentsCard(),
          const SizedBox(height: 14),
          _deliveryCard(receiver),
          const SizedBox(height: 14),
          _membersCard(),
          const SizedBox(height: 14),
          _activityCard(),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _run(() => ReportService.exportPng(c, a, selectedRound), 'جاري إنشاء الصورة...'),
                  icon: const Icon(Icons.image_rounded, color: AC.violet),
                  label: const Text('مشاركة صورة'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _copyReport,
                  icon: const Icon(Icons.copy_rounded, color: AC.cyan),
                  label: const Text('نسخ الكشف'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryCard(
    Member? receiver,
    int paid,
    int late,
    int waiting,
    double collected,
    double progress,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AC.heroGrad,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: AC.primary.withValues(alpha: 0.18),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'الدور ${selectedRound + 1} من ${a.monthsCount}',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
                ),
              ),
              const Spacer(),
              Text(c.roundLabel(a, selectedRound), style: const TextStyle(color: Colors.white70, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 14),
          const Text('صاحب الدور', style: TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 3),
          Text(
            receiver?.name ?? '-',
            style: const TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _heroMetric('إجمالي الدور', '${ReportService.n(a.roundTotal)} ${c.currency}'),
              const SizedBox(width: 8),
              _heroMetric('المحصل', '${ReportService.n(collected)} ${c.currency}'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('دفع $paid • انتظار $waiting • متأخر $late', style: const TextStyle(color: Colors.white70, fontSize: 11)),
              Text('${(progress * 100).round()}%', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor: Colors.white.withValues(alpha: 0.15),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroMetric(String title, String value) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)),
              const SizedBox(height: 2),
              Text(title, style: const TextStyle(color: Colors.white70, fontSize: 9)),
            ],
          ),
        ),
      );

  Widget _roundSelector() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.route_rounded, color: AC.primary, size: 19),
              SizedBox(width: 8),
              Text('الأدوار', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 42,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: a.monthsCount,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (_, i) {
                final rec = a.receiverFor(i);
                return ChoiceChip(
                  selected: selectedRound == i,
                  onSelected: (_) => setState(() => selectedRound = i),
                  label: Text('${i + 1} • ${rec?.name ?? '-'}'),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _receiverCard(Member? receiver) {
    final minRound = c.firstChangeableRound(a);
    final canSwap = !a.archived && selectedRound >= minRound && selectedRound < a.monthsCount;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AC.cardGrad,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AC.borderSoft),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AC.violet.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(Icons.workspace_premium_rounded, color: AC.violet),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('استلام الدور', style: TextStyle(color: AC.muted, fontSize: 11)),
                const SizedBox(height: 2),
                Text(receiver?.name ?? '-', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                Text('الدور ${selectedRound + 1} • ${c.roundLabel(a, selectedRound)}', style: const TextStyle(color: AC.muted, fontSize: 10)),
              ],
            ),
          ),
          FilledButton.tonalIcon(
            onPressed: canSwap ? _swapRole : null,
            icon: const Icon(Icons.swap_horiz_rounded, size: 17),
            label: const Text('تبديل'),
          ),
        ],
      ),
    );
  }

  Widget _paymentsCard() {
    return Container(
      decoration: _cardDecoration(),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: Row(
              children: [
                const Icon(Icons.payments_rounded, color: AC.teal, size: 20),
                const SizedBox(width: 8),
                const Expanded(child: Text('دفعات الأعضاء', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900))),
                Text('استحقاق يوم ${a.dueDay}', style: const TextStyle(color: AC.muted, fontSize: 10)),
              ],
            ),
          ),
          ...a.members.asMap().entries.map((entry) {
            final m = entry.value;
            final stage = c.contributionStage(a, selectedRound, m);
            final isPaid = stage == ContributionStage.paid;
            final color = isPaid
                ? AC.teal
                : stage == ContributionStage.late
                    ? AC.rose
                    : AC.amber;
            final label = isPaid
                ? 'تم الدفع'
                : stage == ContributionStage.late
                    ? 'متأخر'
                    : 'بانتظار الدفع';
            final paidDate = c.paymentDate(a, selectedRound, m);
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                border: entry.key == a.members.length - 1
                    ? null
                    : const Border(bottom: BorderSide(color: AC.borderSoft)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text('${entry.key + 1}', style: TextStyle(color: color, fontWeight: FontWeight.w900)),
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(m.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        InkWell(
                          onTap: isPaid ? () => _changePaymentDate(m) : null,
                          child: Text(
                            isPaid && paidDate != null
                                ? '$label • ${_date.format(paidDate)}'
                                : label,
                            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (m.phone.trim().isNotEmpty)
                    IconButton(
                      tooltip: 'واتساب',
                      onPressed: () => _sendWhatsapp(m),
                      icon: const Icon(Icons.chat_rounded, color: AC.cyan, size: 20),
                    ),
                  Switch(
                    value: isPaid,
                    activeThumbColor: AC.teal,
                    activeTrackColor: AC.teal.withValues(alpha: 0.35),
                    onChanged: a.archived ? null : (v) => c.setPaid(a, selectedRound, m, v),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _deliveryCard(Member? receiver) {
    final delivered = a.deliveredTotal(selectedRound);
    final remaining = a.deliveryRemaining(selectedRound);
    final entries = a.deliveryFor(selectedRound);
    final completed = remaining <= 0.005 && a.roundTotal > 0;
    final partial = delivered > 0 && !completed;
    final color = completed ? AC.teal : partial ? AC.amber : AC.primary;
    final label = completed ? 'تم التسليم بالكامل' : partial ? 'تسليم جزئي' : 'لم يتم التسليم';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(13)),
                child: Icon(Icons.handshake_rounded, color: color),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('تسليم صاحب الدور', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                    Text('${receiver?.name ?? '-'} • $label', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Row(
            children: [
              _smallMetric('المطلوب', a.roundTotal, AC.primary),
              const SizedBox(width: 7),
              _smallMetric('تم تسليمه', delivered, AC.teal),
              const SizedBox(width: 7),
              _smallMetric('المتبقي', remaining, AC.amber),
            ],
          ),
          const SizedBox(height: 12),
          if (!completed && !a.archived)
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: remaining > 0 ? _deliverFull : null,
                    icon: const Icon(Icons.check_circle_rounded, size: 18),
                    label: const Text('تسليم كامل'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: remaining > 0 ? _deliverPartial : null,
                    icon: const Icon(Icons.add_rounded, size: 18, color: AC.amber),
                    label: const Text('تسليم جزئي'),
                  ),
                ),
              ],
            ),
          if (entries.isNotEmpty) ...[
            const SizedBox(height: 13),
            const Text('سجل التسليم', style: TextStyle(color: AC.muted, fontSize: 11, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            ...entries.map(
              (d) => Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                decoration: BoxDecoration(color: AC.card2, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    const Icon(Icons.payments_outlined, size: 16, color: AC.teal),
                    const SizedBox(width: 8),
                    Expanded(child: Text('${ReportService.n(d.amount)} ${c.currency}', style: const TextStyle(fontWeight: FontWeight.w800))),
                    Text(_date.format(d.date), style: const TextStyle(color: AC.muted, fontSize: 10)),
                    if (!a.archived)
                      IconButton(
                        tooltip: 'حذف الحركة',
                        onPressed: () => _confirmDeleteDelivery(d),
                        icon: const Icon(Icons.close_rounded, color: AC.hint, size: 17),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _smallMetric(String title, double value, Color color) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 7),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.09), borderRadius: BorderRadius.circular(13)),
          child: Column(
            children: [
              Text('${ReportService.n(value)} ${c.currency}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w900)),
              const SizedBox(height: 2),
              Text(title, style: const TextStyle(color: AC.muted, fontSize: 9)),
            ],
          ),
        ),
      );

  Widget _membersCard() {
    final structureOpen = c.canChangeStructure(a) && !a.archived;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.groups_rounded, color: AC.primary, size: 20),
              const SizedBox(width: 8),
              const Expanded(child: Text('أعضاء الجمعية', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15))),
              if (structureOpen)
                TextButton.icon(onPressed: _addMember, icon: const Icon(Icons.person_add_alt_1_rounded, size: 16), label: const Text('إضافة')),
            ],
          ),
          if (!structureOpen)
            const Padding(
              padding: EdgeInsets.only(top: 4, bottom: 8),
              child: Text('بعد بدء الجمعية تبقى العضوية ثابتة. يمكن تعديل الاسم أو الهاتف وتبديل الأدوار القادمة فقط.', style: TextStyle(color: AC.muted, fontSize: 10, height: 1.5)),
            ),
          if (structureOpen)
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: a.members.length,
              onReorder: (oldIndex, newIndex) => c.moveMemberBeforeStart(a, oldIndex, newIndex),
              itemBuilder: (_, i) => _memberManagementRow(a.members[i], i, true, key: ValueKey(a.members[i].id)),
            )
          else
            ...a.members.asMap().entries.map((e) => _memberManagementRow(e.value, e.key, false)),
        ],
      ),
    );
  }

  Widget _memberManagementRow(Member m, int index, bool canRemove, {Key? key}) {
    return Container(
      key: key,
      margin: const EdgeInsets.only(top: 7),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(color: AC.card2, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          if (canRemove) const Icon(Icons.drag_handle_rounded, color: AC.hint, size: 18),
          if (canRemove) const SizedBox(width: 6),
          CircleAvatar(
            radius: 16,
            backgroundColor: AC.primary.withValues(alpha: 0.14),
            child: Text('${index + 1}', style: const TextStyle(color: AC.primary, fontSize: 11, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                if (m.phone.isNotEmpty) Text(m.phone, style: const TextStyle(color: AC.muted, fontSize: 10)),
              ],
            ),
          ),
          IconButton(onPressed: () => _editMember(m), icon: const Icon(Icons.edit_rounded, color: AC.cyan, size: 18), visualDensity: VisualDensity.compact),
          if (canRemove)
            IconButton(onPressed: () => _removeMember(m), icon: const Icon(Icons.delete_outline_rounded, color: AC.rose, size: 18), visualDensity: VisualDensity.compact),
        ],
      ),
    );
  }

  Widget _activityCard() {
    final items = a.activity.take(8).toList();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.history_rounded, color: AC.cyan, size: 20),
              SizedBox(width: 8),
              Text('سجل النشاط', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 8),
          if (items.isEmpty)
            const Text('لا توجد عمليات مسجلة بعد.', style: TextStyle(color: AC.muted, fontSize: 11))
          else
            ...items.map(
              (x) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(width: 7, height: 7, margin: const EdgeInsets.only(top: 5), decoration: const BoxDecoration(color: AC.cyan, shape: BoxShape.circle)),
                    const SizedBox(width: 9),
                    Expanded(child: Text(x.text, style: const TextStyle(color: AC.text, fontSize: 11, height: 1.4))),
                    const SizedBox(width: 8),
                    Text(_date.format(x.date), style: const TextStyle(color: AC.hint, fontSize: 9)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration() => BoxDecoration(
        color: AC.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AC.borderSoft),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 18, offset: const Offset(0, 8))],
      );

  Future<void> _swapRole() async {
    final minRound = c.firstChangeableRound(a);
    final candidates = List.generate(a.monthsCount, (i) => i)
        .where((i) => i >= minRound && i != selectedRound)
        .toList();
    if (candidates.isEmpty) {
      _msg('لا توجد أدوار قادمة متاحة للتبديل');
      return;
    }
    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: AC.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('تبديل الدور مع', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              const Text('الأدوار التي انتهت تبقى محفوظة ولا تتغير.', style: TextStyle(color: AC.muted, fontSize: 11)),
              const SizedBox(height: 12),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: candidates.map((i) {
                    final m = a.receiverFor(i);
                    return ListTile(
                      leading: CircleAvatar(backgroundColor: AC.violet.withValues(alpha: 0.15), child: Text('${i + 1}', style: const TextStyle(color: AC.violet))),
                      title: Text(m?.name ?? '-'),
                      subtitle: Text('الدور ${i + 1} • ${c.roundLabel(a, i)}'),
                      onTap: () => Navigator.pop(context, i),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (picked == null) return;
    final ok = await c.swapReceiverRounds(a, selectedRound, picked);
    if (ok) _msg('✓ تم تبديل الدور مع الحفاظ على الأدوار السابقة');
  }

  Future<void> _changePaymentDate(Member m) async {
    final current = c.paymentDate(a, selectedRound, m) ?? DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(a.startYear - 1),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (d == null) return;
    final updated = DateTime(d.year, d.month, d.day, current.hour, current.minute);
    await c.updatePaymentDate(a, selectedRound, m, updated);
    _msg('✓ تم تعديل تاريخ الدفع');
  }

  Future<void> _deliverFull() async {
    final remaining = a.deliveryRemaining(selectedRound);
    if (remaining <= 0) return;
    final d = await _pickDeliveryDate();
    if (d == null) return;
    await c.addDelivery(a, selectedRound, remaining, d);
    _msg('✓ تم تسجيل التسليم الكامل');
  }

  Future<void> _deliverPartial() async {
    final remaining = a.deliveryRemaining(selectedRound);
    final amountC = TextEditingController();
    DateTime selectedDate = DateTime.now();
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (_, setS) => AlertDialog(
          title: const Text('تسليم جزئي'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountC,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: 'المبلغ', helperText: 'المتبقي ${ReportService.n(remaining)} ${c.currency}'),
              ),
              const SizedBox(height: 10),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today_rounded, color: AC.primary),
                title: const Text('تاريخ التسليم'),
                subtitle: Text(_date.format(selectedDate)),
                onTap: () async {
                  final d = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime(a.startYear - 1), lastDate: DateTime.now().add(const Duration(days: 3650)));
                  if (d != null) setS(() => selectedDate = d);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            FilledButton(
              onPressed: () {
                final v = double.tryParse(amountC.text.trim().replaceAll(',', '.')) ?? 0;
                if (v <= 0 || v > remaining + 0.005) return;
                Navigator.pop(ctx, v);
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
    if (result == null) return;
    await c.addDelivery(a, selectedRound, result, selectedDate);
    _msg('✓ تم تسجيل دفعة التسليم');
  }

  Future<DateTime?> _pickDeliveryDate() => showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime(a.startYear - 1),
        lastDate: DateTime.now().add(const Duration(days: 3650)),
      );

  Future<void> _confirmDeleteDelivery(DeliveryEntry d) async {
    final ok = await _confirm('حذف حركة التسليم؟', 'سيتم حذف مبلغ ${ReportService.n(d.amount)} ${c.currency} من سجل التسليم.');
    if (ok) await c.removeDelivery(a, selectedRound, d);
  }

  Future<void> _addMember() async {
    if (!c.canChangeStructure(a)) return;
    final data = await _memberDialog();
    if (data == null) return;
    await c.addMemberBeforeStart(
      a,
      Member(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: data.$1,
        phone: data.$2,
        turn: a.members.length + 1,
      ),
    );
  }

  Future<void> _editMember(Member m) async {
    final data = await _memberDialog(member: m);
    if (data == null) return;
    await c.updateMember(a, m, name: data.$1, phone: data.$2);
  }

  Future<(String, String)?> _memberDialog({Member? member}) async {
    final nameC = TextEditingController(text: member?.name ?? '');
    final phoneC = TextEditingController(text: member?.phone ?? '');
    return showDialog<(String, String)>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(member == null ? 'إضافة عضو' : 'تعديل العضو'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameC, decoration: const InputDecoration(labelText: 'الاسم', prefixIcon: Icon(Icons.person_rounded))),
            const SizedBox(height: 10),
            TextField(controller: phoneC, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'رقم الهاتف', prefixIcon: Icon(Icons.phone_rounded))),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () {
              final name = nameC.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(ctx, (name, phoneC.text.trim()));
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  Future<void> _removeMember(Member m) async {
    if (a.members.length <= 2) {
      _msg('يجب أن يبقى عضوان على الأقل');
      return;
    }
    final ok = await _confirm('حذف ${m.name}؟', 'هذا مسموح فقط لأن الجمعية لم تبدأ بعد.');
    if (ok) await c.removeMemberBeforeStart(a, m);
  }

  Future<void> _editAssociation() async {
    final structural = c.canChangeStructure(a);
    final nameC = TextEditingController(text: a.name);
    final amountC = TextEditingController(text: '${a.amount}');
    final noteC = TextEditingController(text: a.note);
    final dueC = TextEditingController(text: '${a.dueDay}');
    int month = a.startMonth;
    final yearC = TextEditingController(text: '${a.startYear}');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (_, setS) => AlertDialog(
          title: const Text('تعديل الجمعية'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameC, decoration: const InputDecoration(labelText: 'اسم الجمعية')),
                const SizedBox(height: 10),
                TextField(controller: amountC, enabled: structural, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: 'قيمة القسط', helperText: structural ? null : 'مقفلة بعد بدء الجمعية')),
                const SizedBox(height: 10),
                TextField(controller: dueC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'يوم الاستحقاق (1-28)')),
                if (structural) ...[
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int>(
                    initialValue: month,
                    decoration: const InputDecoration(labelText: 'شهر البداية'),
                    items: List.generate(12, (i) => DropdownMenuItem(value: i + 1, child: Text('${i + 1}'))),
                    onChanged: (v) { if (v != null) setS(() => month = v); },
                  ),
                  const SizedBox(height: 10),
                  TextField(controller: yearC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'سنة البداية')),
                ],
                const SizedBox(height: 10),
                TextField(controller: noteC, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'ملاحظة')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حفظ')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final name = nameC.text.trim();
    final amount = double.tryParse(amountC.text.trim().replaceAll(',', '.')) ?? a.amount;
    final due = int.tryParse(dueC.text.trim()) ?? a.dueDay;
    final year = int.tryParse(yearC.text.trim()) ?? a.startYear;
    if (name.isEmpty || amount <= 0) return;
    a.name = name;
    a.note = noteC.text.trim();
    a.dueDay = due.clamp(1, 28);
    if (structural) {
      a.amount = amount;
      a.startMonth = month;
      a.startYear = year;
    }
    await c.updateAssociation(a);
    _msg('✓ تم حفظ التعديلات');
  }

  Future<void> _menu(String value) async {
    if (value == 'edit') {
      await _editAssociation();
      return;
    }
    if (value == 'archive') {
      await c.archiveAssociation(a, !a.archived);
      _msg(a.archived ? '✓ تمت الأرشفة' : '✓ تم إلغاء الأرشفة');
      return;
    }
    if (value == 'delete') {
      final ok = await _confirm('حذف الجمعية نهائيًا؟', 'سيتم حذف الجمعية ودفعاتها وسجلها بالكامل.');
      if (!ok) return;
      await c.deleteAssociation(a);
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _sendWhatsapp(Member m) async {
    final text = 'السلام عليكم ${m.name} 🌟\n'
        'تذكير بقسط جمعية ${a.name}\n'
        'الدور: ${selectedRound + 1}\n'
        'الفترة: ${c.roundLabel(a, selectedRound)}\n'
        'المبلغ: ${ReportService.n(a.amount)} ${c.currency}\n'
        'شكرًا لك 🙏';
    final phone = m.phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final encoded = Uri.encodeComponent(text);
    final uri = phone.isEmpty
        ? Uri.parse('https://wa.me/?text=$encoded')
        : Uri.parse('https://wa.me/$phone?text=$encoded');
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      await Clipboard.setData(ClipboardData(text: text));
      _msg('تعذر فتح واتساب، تم نسخ الرسالة');
    }
  }

  Future<void> _copyReport() async {
    await Clipboard.setData(ClipboardData(text: ReportService.associationText(c, a, selectedRound)));
    _msg('✓ تم نسخ الكشف');
  }

  Future<void> _run(Future<void> Function() action, String loading) async {
    _msg(loading);
    try {
      await action();
    } catch (e) {
      _msg('تعذر إكمال العملية: $e');
    }
  }

  Future<bool> _confirm(String title, String body) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(title),
            content: Text(body),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('تأكيد')),
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
