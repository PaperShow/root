enum MemberStatus {
  active, // Has an account and is part of the group
  invited, // Invited (by account or email), hasn't accepted yet
  placeholder, // Name-only member (not linked to any account)
}

class GroupMember {
  final String id;
  final String name;
  final String? uid;
  final String? email;
  final String? username;
  final MemberStatus status;

  const GroupMember({
    required this.id,
    required this.name,
    this.uid,
    this.email,
    this.username,
    this.status = MemberStatus.placeholder,
  });

  bool get isLinked => uid != null && status == MemberStatus.active;

  GroupMember copyWith({
    String? name,
    String? uid,
    String? email,
    String? username,
    MemberStatus? status,
    bool clearEmail = false,
    bool clearUid = false,
  }) {
    return GroupMember(
      id: id,
      name: name ?? this.name,
      uid: clearUid ? null : (uid ?? this.uid),
      email: clearEmail ? null : (email ?? this.email),
      username: username ?? this.username,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'uid': uid,
      'email': email,
      'username': username,
      'status': status.name,
    };
  }

  factory GroupMember.fromMap(Map<String, dynamic> map) {
    return GroupMember(
      id: map['id'] as String,
      name: map['name'] as String? ?? 'Member',
      uid: map['uid'] as String?,
      email: map['email'] as String?,
      username: map['username'] as String?,
      status: MemberStatus.values.firstWhere(
        (s) => s.name == map['status'],
        orElse: () => MemberStatus.placeholder,
      ),
    );
  }

  /// Member id used for legacy groups that stored members as plain names.
  static String legacyIdFor(String name) => name == 'You' ? localSelfId : 'n:$name';

  /// Id of the current user inside groups that only live on this device.
  static const String localSelfId = 'me';
}

class GroupExpense {
  final String id;
  final String groupId;
  final String title;
  final double amount;
  final String paidBy; // Member id of the person who paid
  final List<String> splitAmong; // Member ids of people who share the expense
  final DateTime date;
  final String? note;
  final bool isSettlement; // A repayment between two members, not a shared bill
  final String? createdBy;

  const GroupExpense({
    required this.id,
    required this.groupId,
    required this.title,
    required this.amount,
    required this.paidBy,
    required this.splitAmong,
    required this.date,
    this.note,
    this.isSettlement = false,
    this.createdBy,
  });

  double get sharePerPerson =>
      splitAmong.isNotEmpty ? amount / splitAmong.length : 0.0;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'groupId': groupId,
      'title': title,
      'amount': amount,
      'paidBy': paidBy,
      'splitAmong': splitAmong,
      'date': date.toIso8601String(),
      'note': note,
      'isSettlement': isSettlement,
      'createdBy': createdBy,
      'v': 2,
    };
  }

  factory GroupExpense.fromMap(Map<String, dynamic> map) {
    // v1 stored member names instead of member ids
    final isLegacy = map['v'] == null;
    String toId(String raw) => isLegacy ? GroupMember.legacyIdFor(raw) : raw;
    return GroupExpense(
      id: map['id'] as String,
      groupId: map['groupId'] as String,
      title: map['title'] as String,
      amount: (map['amount'] as num).toDouble(),
      paidBy: toId(map['paidBy'] as String),
      splitAmong: (map['splitAmong'] as List<dynamic>?)
              ?.map((e) => toId(e.toString()))
              .toList() ??
          [],
      date: DateTime.tryParse(map['date'] as String? ?? '') ?? DateTime.now(),
      note: map['note'] as String?,
      isSettlement: map['isSettlement'] as bool? ?? false,
      createdBy: map['createdBy'] as String?,
    );
  }
}

class SplitGroup {
  final String id;
  final String name;
  final String icon;
  final List<GroupMember> members;
  final DateTime createdAt;
  final String? createdBy;
  final List<String> admins;

  const SplitGroup({
    required this.id,
    required this.name,
    this.icon = '👥',
    required this.members,
    required this.createdAt,
    this.createdBy,
    this.admins = const [],
  });

  GroupMember? memberById(String id) {
    for (final m in members) {
      if (m.id == id) return m;
    }
    return null;
  }

  GroupMember? memberByUid(String uid) {
    for (final m in members) {
      if (m.uid == uid) return m;
    }
    return null;
  }

  String nameOf(String memberId) => memberById(memberId)?.name ?? 'Former member';

  bool isAdmin(String? uid) => uid != null && (admins.contains(uid) || createdBy == uid);

  // Derived arrays that Firestore queries and security rules rely on
  List<String> get memberUids => members
      .where((m) => m.status == MemberStatus.active && m.uid != null)
      .map((m) => m.uid!)
      .toList();

  List<String> get invitedUids => members
      .where((m) => m.status == MemberStatus.invited && m.uid != null)
      .map((m) => m.uid!)
      .toList();

  List<String> get invitedEmails => members
      .where((m) => m.status == MemberStatus.invited && m.uid == null && m.email != null)
      .map((m) => m.email!.toLowerCase())
      .toList();

  SplitGroup copyWith({
    String? name,
    String? icon,
    List<GroupMember>? members,
    List<String>? admins,
  }) {
    return SplitGroup(
      id: id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      members: members ?? this.members,
      createdAt: createdAt,
      createdBy: createdBy,
      admins: admins ?? this.admins,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'members': members.map((m) => m.toMap()).toList(),
      'memberUids': memberUids,
      'invitedUids': invitedUids,
      'invitedEmails': invitedEmails,
      'admins': admins,
      'createdBy': createdBy,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory SplitGroup.fromMap(Map<String, dynamic> map) {
    final rawMembers = map['members'] as List<dynamic>? ?? const ['You'];
    return SplitGroup(
      id: map['id'] as String,
      name: map['name'] as String,
      icon: map['icon'] as String? ?? '👥',
      members: rawMembers.map((m) {
        if (m is Map) return GroupMember.fromMap(Map<String, dynamic>.from(m));
        // v1 stored members as plain names
        final name = m.toString();
        return GroupMember(id: GroupMember.legacyIdFor(name), name: name);
      }).toList(),
      createdAt:
          DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
      createdBy: map['createdBy'] as String?,
      admins: (map['admins'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
    );
  }
}

/// A single "from pays to" instruction produced by simplifying group balances.
class SettlementSuggestion {
  final String fromId;
  final String toId;
  final double amount;

  const SettlementSuggestion({
    required this.fromId,
    required this.toId,
    required this.amount,
  });
}
