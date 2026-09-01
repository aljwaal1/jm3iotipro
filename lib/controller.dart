import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

class JamiyatiController extends ChangeNotifier {
  static const _pinKey = 'jamiyati_secure_pin';
  final FlutterSecureStorage _secure = const FlutterSecureStorage();
  final LocalAuthentication _auth = LocalAuthentication();

  List<Association> associations = <Association>[];
  Set<String> paidKeys = <String>{};
  Map<String, DateTime> paidAt = <String, DateTime>{};
  String currency = 'د.أ';
  bool loaded = false;
  bool unlocked = true;
  bool pinConfigured = false;
  bool biometricAvailable = false;

  List<Association> get activeAssociations => associations
      .where((a) => stageOf(a) == AssociationStage.active || stageOf(a) == AssociationStage.upcoming)
      .toList();

  List<Association> get archivedAssociations =>
      associations.where((a) => a.archived).toList();

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final raw = prefs.getString('associations') ?? '[]';
      final decoded = jsonDecode(raw);
      final list = <Association>[];
      if (decoded is List) {
        for (final item in decoded) {
          if (item is Map) {
            list.add(Association.fromJson(Map<String, dynamic>.from(item)));
          }
        }
      }
      associations = list;
    } catch (_) {
      associations = <Association>[];
    }

    paidKeys = (prefs.getStringList('paidKeys') ?? <String>[]).toSet();
    currency = prefs.getString('currency') ?? 'د.أ';

    try {
      final rawPaidAt = prefs.getString('paidAt') ?? '{}';
      final decoded = jsonDecode(rawPaidAt);
      if (decoded is Map) {
        decoded.forEach((key, value) {
          final d = DateTime.tryParse('$value');
          if (d != null) paidAt['$key'] = d;
        });
      }
    } catch (_) {}

    var securePin = await _secure.read(key: _pinKey) ?? '';
    final legacyPin = prefs.getString('pin') ?? '';
    if (securePin.isEmpty && legacyPin.isNotEmpty) {
      securePin = legacyPin;
      await _secure.write(key: _pinKey, value: legacyPin);
      await prefs.remove('pin');
    }
    pinConfigured = securePin.isNotEmpty;
    unlocked = !pinConfigured;

    try {
      biometricAvailable = await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
    } catch (_) {
      biometricAvailable = false;
    }

    loaded = true;
    notifyListeners();
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'associations',
      jsonEncode(associations.map((a) => a.toJson()).toList()),
    );
    await prefs.setStringList('paidKeys', paidKeys.toList());
    await prefs.setString('currency', currency);
    await prefs.setString(
      'paidAt',
      jsonEncode(paidAt.map((key, value) => MapEntry(key, value.toIso8601String()))),
    );
  }

  String paymentKey(Association a, int roundIndex, Member m) =>
      '${a.id}-$roundIndex-${m.id}';

  bool isPaid(Association a, int roundIndex, Member m) =>
      paidKeys.contains(paymentKey(a, roundIndex, m));

  DateTime? paymentDate(Association a, int roundIndex, Member m) =>
      paidAt[paymentKey(a, roundIndex, m)];

  Future<void> setPaid(
    Association a,
    int roundIndex,
    Member m,
    bool value, {
    DateTime? date,
  }) async {
    final key = paymentKey(a, roundIndex, m);
    if (value) {
      paidKeys.add(key);
      paidAt[key] = date ?? DateTime.now();
      addActivity(a, 'تم تسجيل دفع ${m.name} للدور ${roundIndex + 1}');
    } else {
      paidKeys.remove(key);
      paidAt.remove(key);
      addActivity(a, 'تم إلغاء تسجيل دفع ${m.name} للدور ${roundIndex + 1}');
    }
    await save();
    notifyListeners();
  }

  Future<void> updatePaymentDate(
    Association a,
    int roundIndex,
    Member m,
    DateTime date,
  ) async {
    final key = paymentKey(a, roundIndex, m);
    if (!paidKeys.contains(key)) return;
    paidAt[key] = date;
    addActivity(a, 'تم تعديل تاريخ دفع ${m.name} للدور ${roundIndex + 1}');
    await save();
    notifyListeners();
  }

  int roundIndexNow(Association a) {
    final now = DateTime.now();
    final idx = (now.year - a.startYear) * 12 + (now.month - a.startMonth);
    if (idx < 0) return -1;
    if (idx >= a.monthsCount) return a.monthsCount;
    return idx;
  }

  int displayRound(Association a) {
    final idx = roundIndexNow(a);
    if (idx < 0) return 0;
    if (idx >= a.monthsCount) return max(0, a.monthsCount - 1);
    return idx;
  }

  AssociationStage stageOf(Association a) {
    if (a.archived) return AssociationStage.archived;
    final idx = roundIndexNow(a);
    if (idx < 0) return AssociationStage.upcoming;
    if (idx >= a.monthsCount) return AssociationStage.completed;
    return AssociationStage.active;
  }

  String stageLabel(Association a) {
    switch (stageOf(a)) {
      case AssociationStage.upcoming:
        return 'قادمة';
      case AssociationStage.active:
        return 'نشطة';
      case AssociationStage.completed:
        return 'مكتملة';
      case AssociationStage.archived:
        return 'مؤرشفة';
    }
  }

  DateTime roundMonth(Association a, int roundIndex) =>
      DateTime(a.startYear, a.startMonth + roundIndex, 1);

  String roundLabel(Association a, int roundIndex) {
    const months = <String>[
      'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
    ];
    final d = roundMonth(a, roundIndex);
    return '${months[d.month - 1]} ${d.year}';
  }

  DateTime dueDate(Association a, int roundIndex) {
    final d = roundMonth(a, roundIndex);
    final last = DateTime(d.year, d.month + 1, 0).day;
    return DateTime(d.year, d.month, min(a.dueDay, last), 23, 59, 59);
  }

  ContributionStage contributionStage(
    Association a,
    int roundIndex,
    Member m,
  ) {
    if (isPaid(a, roundIndex, m)) return ContributionStage.paid;
    if (DateTime.now().isAfter(dueDate(a, roundIndex))) {
      return ContributionStage.late;
    }
    return ContributionStage.waiting;
  }

  int paidCount(Association a, int roundIndex) =>
      a.members.where((m) => isPaid(a, roundIndex, m)).length;

  int lateCount(Association a, int roundIndex) => a.members
      .where((m) => contributionStage(a, roundIndex, m) == ContributionStage.late)
      .length;

  int waitingCount(Association a, int roundIndex) => a.members
      .where((m) => contributionStage(a, roundIndex, m) == ContributionStage.waiting)
      .length;

  double collectedAmount(Association a, int roundIndex) =>
      paidCount(a, roundIndex) * a.amount;

  int get totalLate {
    var total = 0;
    for (final a in associations) {
      if (stageOf(a) != AssociationStage.active) continue;
      total += lateCount(a, displayRound(a));
    }
    return total;
  }

  int get totalWaiting {
    var total = 0;
    for (final a in associations) {
      if (stageOf(a) != AssociationStage.active) continue;
      total += waitingCount(a, displayRound(a));
    }
    return total;
  }

  double get totalExpectedThisRound {
    var total = 0.0;
    for (final a in associations) {
      if (stageOf(a) == AssociationStage.active) total += a.roundTotal;
    }
    return total;
  }

  double get totalCollectedThisRound {
    var total = 0.0;
    for (final a in associations) {
      if (stageOf(a) == AssociationStage.active) {
        total += collectedAmount(a, displayRound(a));
      }
    }
    return total;
  }

  Future<void> addAssociation(Association a) async {
    a.normalize();
    associations.insert(0, a);
    addActivity(a, 'تم إنشاء الجمعية');
    await save();
    notifyListeners();
  }

  Future<void> updateAssociation(Association a) async {
    a.normalize();
    addActivity(a, 'تم تعديل بيانات الجمعية');
    await save();
    notifyListeners();
  }

  Future<void> archiveAssociation(Association a, bool value) async {
    a.archived = value;
    addActivity(a, value ? 'تمت أرشفة الجمعية' : 'تم إلغاء الأرشفة');
    await save();
    notifyListeners();
  }

  Future<void> deleteAssociation(Association a) async {
    associations.removeWhere((x) => x.id == a.id);
    paidKeys.removeWhere((k) => k.startsWith('${a.id}-'));
    paidAt.removeWhere((k, _) => k.startsWith('${a.id}-'));
    await save();
    notifyListeners();
  }

  bool canChangeStructure(Association a) => stageOf(a) == AssociationStage.upcoming;

  int firstChangeableRound(Association a) {
    final idx = roundIndexNow(a);
    if (idx < 0) return 0;
    if (idx >= a.monthsCount) return a.monthsCount;
    return idx;
  }

  Future<bool> swapReceiverRounds(
    Association a,
    int firstRound,
    int secondRound,
  ) async {
    if (firstRound == secondRound) return false;
    final minRound = firstChangeableRound(a);
    if (firstRound < minRound || secondRound < minRound) return false;
    if (firstRound < 0 || secondRound < 0) return false;
    if (firstRound >= a.receiverOrder.length || secondRound >= a.receiverOrder.length) {
      return false;
    }
    final firstName = a.receiverFor(firstRound)?.name ?? '-';
    final secondName = a.receiverFor(secondRound)?.name ?? '-';
    final tmp = a.receiverOrder[firstRound];
    a.receiverOrder[firstRound] = a.receiverOrder[secondRound];
    a.receiverOrder[secondRound] = tmp;
    addActivity(a, 'تم تبديل دور $firstName مع $secondName');
    await save();
    notifyListeners();
    return true;
  }

  Future<void> addMemberBeforeStart(Association a, Member member) async {
    if (!canChangeStructure(a)) return;
    a.members.add(member);
    a.rebuildScheduleFromMembers();
    addActivity(a, 'تمت إضافة العضو ${member.name} قبل بدء الجمعية');
    await save();
    notifyListeners();
  }

  Future<void> removeMemberBeforeStart(Association a, Member member) async {
    if (!canChangeStructure(a)) return;
    a.members.removeWhere((m) => m.id == member.id);
    a.rebuildScheduleFromMembers();
    addActivity(a, 'تم حذف العضو ${member.name} قبل بدء الجمعية');
    await save();
    notifyListeners();
  }

  Future<void> moveMemberBeforeStart(
    Association a,
    int oldIndex,
    int newIndex,
  ) async {
    if (!canChangeStructure(a)) return;
    if (oldIndex < 0 || oldIndex >= a.members.length) return;
    if (newIndex > oldIndex) newIndex--;
    final item = a.members.removeAt(oldIndex);
    a.members.insert(newIndex.clamp(0, a.members.length), item);
    a.rebuildScheduleFromMembers();
    addActivity(a, 'تم تعديل ترتيب الأدوار قبل بدء الجمعية');
    await save();
    notifyListeners();
  }

  Future<void> updateMember(
    Association a,
    Member m, {
    required String name,
    required String phone,
  }) async {
    m.name = name.trim();
    m.phone = phone.trim();
    addActivity(a, 'تم تعديل بيانات العضو ${m.name}');
    await save();
    notifyListeners();
  }

  Future<void> addDelivery(
    Association a,
    int roundIndex,
    double amount,
    DateTime date, {
    String note = '',
  }) async {
    if (amount <= 0) return;
    final list = a.deliveries.putIfAbsent('$roundIndex', () => <DeliveryEntry>[]);
    list.add(DeliveryEntry(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      amount: amount,
      date: date,
      note: note,
    ));
    final receiver = a.receiverFor(roundIndex)?.name ?? 'صاحب الدور';
    addActivity(a, 'تم تسجيل تسليم مبلغ إلى $receiver للدور ${roundIndex + 1}');
    await save();
    notifyListeners();
  }

  Future<void> removeDelivery(
    Association a,
    int roundIndex,
    DeliveryEntry entry,
  ) async {
    a.deliveries['$roundIndex']?.removeWhere((e) => e.id == entry.id);
    addActivity(a, 'تم حذف حركة تسليم من الدور ${roundIndex + 1}');
    await save();
    notifyListeners();
  }

  void addActivity(Association a, String text) {
    a.activity.insert(
      0,
      ActivityEntry(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        text: text,
        date: DateTime.now(),
      ),
    );
    if (a.activity.length > 200) {
      a.activity = a.activity.take(200).toList();
    }
  }

  Future<void> setCurrency(String value) async {
    currency = value.trim().isEmpty ? 'د.أ' : value.trim();
    await save();
    notifyListeners();
  }

  Future<bool> unlockWithPin(String value) async {
    final stored = await _secure.read(key: _pinKey) ?? '';
    if (stored.isNotEmpty && stored == value.trim()) {
      unlocked = true;
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<bool> unlockWithBiometric() async {
    if (!biometricAvailable || !pinConfigured) return false;
    try {
      final ok = await _auth.authenticate(
        localizedReason: 'استخدم البصمة أو قفل الجهاز لفتح جمعيتي Pro',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
      if (ok) {
        unlocked = true;
        notifyListeners();
      }
      return ok;
    } catch (_) {
      return false;
    }
  }

  Future<void> setPin(String value) async {
    final pin = value.trim();
    if (pin.isEmpty) {
      await _secure.delete(key: _pinKey);
      pinConfigured = false;
      unlocked = true;
    } else {
      await _secure.write(key: _pinKey, value: pin);
      pinConfigured = true;
      unlocked = true;
    }
    notifyListeners();
  }

  void lock() {
    if (!pinConfigured) return;
    unlocked = false;
    notifyListeners();
  }

  Map<String, dynamic> backupMap() => {
        'format': 'jamiyati-pro-backup',
        'version': 3,
        'createdAt': DateTime.now().toIso8601String(),
        'currency': currency,
        'associations': associations.map((a) => a.toJson()).toList(),
        'paidKeys': paidKeys.toList(),
        'paidAt': paidAt.map((key, value) => MapEntry(key, value.toIso8601String())),
      };

  String backupJson() => const JsonEncoder.withIndent('  ').convert(backupMap());

  Future<void> restoreFromJson(String raw) async {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) throw const FormatException('ملف النسخة الاحتياطية غير صالح');
    final map = Map<String, dynamic>.from(decoded);
    if ('${map['format'] ?? ''}' != 'jamiyati-pro-backup') {
      throw const FormatException('هذا الملف ليس نسخة احتياطية من جمعيتي Pro');
    }

    final restored = <Association>[];
    final rawAssociations = map['associations'];
    if (rawAssociations is List) {
      for (final item in rawAssociations) {
        if (item is Map) {
          restored.add(Association.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }

    final restoredKeys = <String>{};
    final rawKeys = map['paidKeys'];
    if (rawKeys is List) restoredKeys.addAll(rawKeys.map((e) => '$e'));

    final restoredDates = <String, DateTime>{};
    final rawDates = map['paidAt'];
    if (rawDates is Map) {
      rawDates.forEach((key, value) {
        final d = DateTime.tryParse('$value');
        if (d != null) restoredDates['$key'] = d;
      });
    }

    associations = restored;
    paidKeys = restoredKeys;
    paidAt = restoredDates;
    currency = '${map['currency'] ?? 'د.أ'}';
    await save();
    notifyListeners();
  }
}
