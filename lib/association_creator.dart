import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

import 'app_theme.dart';
import 'controller.dart';
import 'models.dart';

class CreateAssociationPage extends StatefulWidget {
  const CreateAssociationPage({super.key, required this.controller});

  final JamiyatiController controller;

  @override
  State<CreateAssociationPage> createState() => _CreateAssociationPageState();
}

class _CreateAssociationPageState extends State<CreateAssociationPage> {
  final _name = TextEditingController();
  final _amount = TextEditingController();
  final _dueDay = TextEditingController(text: '5');
  final _year = TextEditingController(text: '${DateTime.now().year}');
  final _note = TextEditingController();
  final List<Member> _members = <Member>[];

  int _month = DateTime.now().month;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _dueDay.dispose();
    _year.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'رجوع',
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_forward_rounded),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('جمعية جديدة'),
            Text(
              'خطوات بسيطة، وكل عضو له بطاقة',
              style: TextStyle(color: AC.muted, fontSize: 9, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 110),
          children: [
            _sectionTitle('بيانات الجمعية', 'أدخل المعلومات الأساسية فقط'),
            _panel(
              children: [
                TextField(
                  controller: _name,
                  decoration: const InputDecoration(
                    labelText: 'اسم الجمعية',
                    prefixIcon: Icon(Icons.groups_2_rounded),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _amount,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'قيمة القسط لكل عضو',
                    prefixIcon: const Icon(Icons.payments_rounded),
                    suffixText: widget.controller.currency,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: _month,
                        decoration: const InputDecoration(labelText: 'شهر البداية'),
                        items: List.generate(
                          12,
                          (i) => DropdownMenuItem(
                            value: i + 1,
                            child: Text(_monthName(i + 1)),
                          ),
                        ),
                        onChanged: (value) {
                          if (value != null) setState(() => _month = value);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _year,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'السنة'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _dueDay,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'يوم استحقاق القسط',
                    helperText: 'من 1 إلى 28',
                    prefixIcon: Icon(Icons.event_available_rounded),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            _sectionTitle(
              'الأعضاء والأدوار',
              'الأول في القائمة له الدور الأول، ثم الثاني وهكذا',
            ),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _pickFromContacts,
                    icon: const Icon(Icons.contacts_rounded),
                    label: const Text('من الهاتف'),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _manualMember(),
                    icon: const Icon(Icons.person_add_alt_1_rounded),
                    label: const Text('إضافة يدويًا'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (_members.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 26),
                decoration: BoxDecoration(
                  color: AC.card,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AC.borderSoft),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.people_outline_rounded, color: AC.hint, size: 38),
                    SizedBox(height: 8),
                    Text(
                      'لم تضف أعضاء بعد',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'اختر شخصًا من الهاتف أو أضفه يدويًا.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AC.muted, fontSize: 10),
                    ),
                  ],
                ),
              )
            else
              _membersList(),
            const SizedBox(height: 22),
            _sectionTitle('ملاحظة', 'اختيارية ويمكن تركها فارغة'),
            TextField(
              controller: _note,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'ملاحظة اختيارية',
                prefixIcon: Icon(Icons.note_alt_rounded),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          decoration: const BoxDecoration(
            color: AC.surface,
            border: Border(top: BorderSide(color: AC.borderSoft)),
          ),
          child: FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_rounded),
            label: Text(_saving ? 'جاري الإنشاء...' : 'إنشاء الجمعية'),
          ),
        ),
      ),
    );
  }

  Widget _membersList() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AC.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AC.borderSoft),
      ),
      child: ReorderableListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        buildDefaultDragHandles: false,
        itemCount: _members.length,
        onReorder: (oldIndex, newIndex) {
          setState(() {
            if (newIndex > oldIndex) newIndex--;
            final item = _members.removeAt(oldIndex);
            _members.insert(newIndex, item);
            _syncTurns();
          });
        },
        itemBuilder: (context, index) {
          final member = _members[index];
          return Container(
            key: ValueKey(member.id),
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: AC.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AC.borderSoft),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AC.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: AC.primary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        member.name,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        member.phone.trim().isEmpty ? 'بدون رقم هاتف' : member.phone,
                        style: const TextStyle(color: AC.muted, fontSize: 10),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'تعديل',
                  onPressed: () => _manualMember(editIndex: index),
                  icon: const Icon(Icons.edit_rounded, color: AC.muted, size: 19),
                ),
                IconButton(
                  tooltip: 'حذف',
                  onPressed: () {
                    setState(() {
                      _members.removeAt(index);
                      _syncTurns();
                    });
                  },
                  icon: const Icon(Icons.delete_outline_rounded, color: AC.rose, size: 20),
                ),
                ReorderableDragStartListener(
                  index: index,
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(Icons.drag_indicator_rounded, color: AC.hint),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _pickFromContacts() async {
    try {
      var allowed = await FlutterContacts.permissions.has(PermissionType.read);
      if (!allowed) {
        await FlutterContacts.permissions.request(PermissionType.read);
        allowed = await FlutterContacts.permissions.has(PermissionType.read);
      }
      if (!allowed) {
        _message('للاختيار من الهاتف، اسمح للتطبيق بقراءة جهات الاتصال.');
        return;
      }

      final contact = await FlutterContacts.native.showPicker(
        properties: {ContactProperty.phone},
      );
      if (contact == null) return;
      final name = (contact.displayName ?? '').trim();
      final phone = contact.phones.isEmpty ? '' : contact.phones.first.number.trim();
      if (name.isEmpty) {
        _message('تعذر قراءة اسم جهة الاتصال.');
        return;
      }
      await _addMember(name, phone);
    } catch (_) {
      _message('تعذر فتح جهات الاتصال. يمكنك إضافة العضو يدويًا.');
    }
  }

  Future<void> _manualMember({int? editIndex}) async {
    final existing = editIndex == null ? null : _members[editIndex];
    final nameController = TextEditingController(text: existing?.name ?? '');
    final phoneController = TextEditingController(text: existing?.phone ?? '');

    final result = await showDialog<(String, String)>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(existing == null ? 'إضافة عضو' : 'تعديل العضو'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'الاسم',
                prefixIcon: Icon(Icons.person_rounded),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'رقم الهاتف (اختياري)',
                hintText: '+962... أو +46...',
                prefixIcon: Icon(Icons.phone_rounded),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(
                dialogContext,
                (name, phoneController.text.trim()),
              );
            },
            child: Text(existing == null ? 'إضافة' : 'حفظ'),
          ),
        ],
      ),
    );
    nameController.dispose();
    phoneController.dispose();
    if (result == null) return;

    if (editIndex != null) {
      final duplicate = _members.asMap().entries.any(
            (entry) =>
                entry.key != editIndex &&
                _sameName(entry.value.name, result.$1),
          );
      if (duplicate && !await _duplicateConfirmation(result.$1)) return;
      setState(() {
        _members[editIndex].name = result.$1;
        _members[editIndex].phone = result.$2;
      });
      return;
    }

    await _addMember(result.$1, result.$2);
  }

  Future<void> _addMember(String name, String phone) async {
    final duplicate = _members.any((m) => _sameName(m.name, name));
    if (duplicate && !await _duplicateConfirmation(name)) return;

    setState(() {
      final id = '${DateTime.now().microsecondsSinceEpoch}-${_members.length}';
      _members.add(
        Member(
          id: id,
          name: name.trim(),
          phone: phone.trim(),
          turn: _members.length + 1,
        ),
      );
      _syncTurns();
    });
  }

  bool _sameName(String a, String b) =>
      a.trim().toLowerCase() == b.trim().toLowerCase();

  Future<bool> _duplicateConfirmation(String name) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            icon: const Icon(Icons.warning_amber_rounded, color: AC.amber, size: 34),
            title: const Text('الاسم موجود بالفعل'),
            content: Text(
              'الاسم «$name» موجود في الجمعية. هل تريد إضافته مرة أخرى؟',
              textAlign: TextAlign.center,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('إضافة على أي حال'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _syncTurns() {
    for (var i = 0; i < _members.length; i++) {
      _members[i].turn = i + 1;
    }
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final amount = double.tryParse(_amount.text.trim().replaceAll(',', '.')) ?? 0;
    final year = int.tryParse(_year.text.trim()) ?? DateTime.now().year;
    final dueDay = (int.tryParse(_dueDay.text.trim()) ?? 5).clamp(1, 28);

    if (name.isEmpty) {
      _message('أدخل اسم الجمعية.');
      return;
    }
    if (amount <= 0) {
      _message('أدخل قيمة قسط صحيحة.');
      return;
    }
    if (_members.length < 2) {
      _message('أضف عضوين على الأقل.');
      return;
    }

    setState(() => _saving = true);
    _syncTurns();
    final association = Association(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
      amount: amount,
      startYear: year,
      startMonth: _month,
      monthsCount: _members.length,
      dueDay: dueDay,
      members: _members,
      note: _note.text.trim(),
    );
    association.rebuildScheduleFromMembers();
    if (!mounted) return;
    Navigator.pop(context, association);
  }

  Widget _panel({required List<Widget> children}) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AC.card,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AC.borderSoft),
        ),
        child: Column(children: children),
      );

  Widget _sectionTitle(String title, String subtitle) => Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(color: AC.muted, fontSize: 10),
            ),
          ],
        ),
      );

  String _monthName(int month) {
    const months = [
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
    return months[(month - 1).clamp(0, 11)];
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}
