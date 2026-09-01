import 'dart:math';

enum AssociationStage { upcoming, active, completed, archived }
enum ContributionStage { paid, waiting, late }

class Member {
  String id;
  String name;
  String phone;
  int turn;

  Member({
    required this.id,
    required this.name,
    required this.phone,
    required this.turn,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'turn': turn,
      };

  factory Member.fromJson(Map<String, dynamic> j) => Member(
        id: '${j['id'] ?? ''}',
        name: '${j['name'] ?? ''}',
        phone: '${j['phone'] ?? ''}',
        turn: (j['turn'] as num?)?.toInt() ?? 1,
      );
}

class DeliveryEntry {
  String id;
  double amount;
  DateTime date;
  String note;

  DeliveryEntry({
    required this.id,
    required this.amount,
    required this.date,
    this.note = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'amount': amount,
        'date': date.toIso8601String(),
        'note': note,
      };

  factory DeliveryEntry.fromJson(Map<String, dynamic> j) => DeliveryEntry(
        id: '${j['id'] ?? ''}',
        amount: (j['amount'] as num?)?.toDouble() ?? 0,
        date: DateTime.tryParse('${j['date'] ?? ''}') ?? DateTime.now(),
        note: '${j['note'] ?? ''}',
      );
}

class ActivityEntry {
  String id;
  String text;
  DateTime date;

  ActivityEntry({required this.id, required this.text, required this.date});

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'date': date.toIso8601String(),
      };

  factory ActivityEntry.fromJson(Map<String, dynamic> j) => ActivityEntry(
        id: '${j['id'] ?? ''}',
        text: '${j['text'] ?? ''}',
        date: DateTime.tryParse('${j['date'] ?? ''}') ?? DateTime.now(),
      );
}

class Association {
  String id;
  String name;
  String note;
  double amount;
  int startYear;
  int startMonth;
  int monthsCount;
  int dueDay;
  List<Member> members;
  bool archived;
  List<String> receiverOrder;
  Map<String, List<DeliveryEntry>> deliveries;
  List<ActivityEntry> activity;

  Association({
    required this.id,
    required this.name,
    required this.amount,
    required this.startYear,
    required this.startMonth,
    required this.monthsCount,
    required this.members,
    this.dueDay = 5,
    this.note = '',
    this.archived = false,
    List<String>? receiverOrder,
    Map<String, List<DeliveryEntry>>? deliveries,
    List<ActivityEntry>? activity,
  })  : receiverOrder = receiverOrder ?? <String>[],
        deliveries = deliveries ?? <String, List<DeliveryEntry>>{},
        activity = activity ?? <ActivityEntry>[] {
    normalize();
  }

  double get roundTotal => amount * members.length;

  DateTime get startDate => DateTime(startYear, startMonth, 1);

  DateTime get monthAfterEnd => DateTime(startYear, startMonth + monthsCount, 1);

  bool get hasStarted {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    return !monthStart.isBefore(startDate);
  }

  void normalize() {
    monthsCount = max(1, monthsCount);
    dueDay = dueDay.clamp(1, 28).toInt();
    for (var i = 0; i < members.length; i++) {
      if (members[i].turn <= 0) members[i].turn = i + 1;
    }
    final validIds = members.map((e) => e.id).toSet();
    receiverOrder.removeWhere((id) => !validIds.contains(id));
    if (receiverOrder.length != monthsCount) {
      final sorted = [...members]..sort((a, b) => a.turn.compareTo(b.turn));
      receiverOrder = List.generate(
        monthsCount,
        (i) => sorted.isEmpty ? '' : sorted[i % sorted.length].id,
      );
    }
  }

  void rebuildScheduleFromMembers() {
    for (var i = 0; i < members.length; i++) {
      members[i].turn = i + 1;
    }
    monthsCount = max(1, members.length);
    receiverOrder = members.map((e) => e.id).toList();
  }

  Member? memberById(String id) {
    for (final m in members) {
      if (m.id == id) return m;
    }
    return null;
  }

  Member? receiverFor(int roundIndex) {
    if (members.isEmpty || receiverOrder.isEmpty) return null;
    final idx = roundIndex.clamp(0, receiverOrder.length - 1).toInt();
    return memberById(receiverOrder[idx]);
  }

  List<DeliveryEntry> deliveryFor(int roundIndex) =>
      deliveries['$roundIndex'] ?? <DeliveryEntry>[];

  double deliveredTotal(int roundIndex) => deliveryFor(roundIndex)
      .fold<double>(0, (sum, item) => sum + item.amount);

  double deliveryRemaining(int roundIndex) =>
      max(0, roundTotal - deliveredTotal(roundIndex)).toDouble();

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'amount': amount,
        'startYear': startYear,
        'startMonth': startMonth,
        'monthsCount': monthsCount,
        'dueDay': dueDay,
        'members': members.map((m) => m.toJson()).toList(),
        'note': note,
        'archived': archived,
        'receiverOrder': receiverOrder,
        'deliveries': deliveries.map(
          (key, value) => MapEntry(key, value.map((e) => e.toJson()).toList()),
        ),
        'activity': activity.map((e) => e.toJson()).toList(),
      };

  factory Association.fromJson(Map<String, dynamic> j) {
    final members = <Member>[];
    final rawMembers = j['members'];
    if (rawMembers is List) {
      for (final item in rawMembers) {
        if (item is Map) {
          members.add(Member.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }

    final deliveryMap = <String, List<DeliveryEntry>>{};
    final rawDeliveries = j['deliveries'];
    if (rawDeliveries is Map) {
      rawDeliveries.forEach((key, value) {
        final entries = <DeliveryEntry>[];
        if (value is List) {
          for (final item in value) {
            if (item is Map) {
              entries.add(DeliveryEntry.fromJson(Map<String, dynamic>.from(item)));
            }
          }
        }
        deliveryMap['$key'] = entries;
      });
    }

    final activity = <ActivityEntry>[];
    final rawActivity = j['activity'];
    if (rawActivity is List) {
      for (final item in rawActivity) {
        if (item is Map) {
          activity.add(ActivityEntry.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }

    final receiverOrder = <String>[];
    final rawOrder = j['receiverOrder'];
    if (rawOrder is List) {
      receiverOrder.addAll(rawOrder.map((e) => '$e'));
    }

    return Association(
      id: '${j['id'] ?? ''}',
      name: '${j['name'] ?? ''}',
      amount: (j['amount'] as num?)?.toDouble() ?? 0,
      startYear: (j['startYear'] as num?)?.toInt() ?? DateTime.now().year,
      startMonth: (j['startMonth'] as num?)?.toInt() ?? DateTime.now().month,
      monthsCount: (j['monthsCount'] as num?)?.toInt() ?? max(1, members.length),
      dueDay: (j['dueDay'] as num?)?.toInt() ?? 5,
      members: members,
      note: '${j['note'] ?? ''}',
      archived: j['archived'] == true,
      receiverOrder: receiverOrder,
      deliveries: deliveryMap,
      activity: activity,
    );
  }
}
