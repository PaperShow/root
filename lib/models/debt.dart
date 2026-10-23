enum DebtType {
  lent, // I lent money to someone (they owe me)
  borrowed, // I borrowed money from someone (I owe them)
}

class DebtRepayment {
  final String id;
  final double amount;
  final DateTime date;
  final String? note;

  const DebtRepayment({
    required this.id,
    required this.amount,
    required this.date,
    this.note,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'date': date.toIso8601String(),
      'note': note,
    };
  }

  factory DebtRepayment.fromMap(Map<String, dynamic> map) {
    return DebtRepayment(
      id: map['id'] as String,
      amount: (map['amount'] as num).toDouble(),
      date: DateTime.tryParse(map['date'] as String? ?? '') ?? DateTime.now(),
      note: map['note'] as String?,
    );
  }
}

class DebtItem {
  final String id;
  final String personName;
  final double totalAmount;
  final double paidAmount;
  final DebtType type;
  final DateTime createdAt;
  final DateTime? dueDate;
  final String? note;
  final List<DebtRepayment> repayments;
  final bool isSettled;

  // Sharing: the record is stored from the owner's point of view.
  final String? ownerUid;
  final String? ownerName;
  final String? counterpartyUid;
  final String? counterpartyEmail;

  /// Whether the signed-in user created this record. Records shared with the
  /// user by someone else are shown with the name and direction flipped.
  final bool isOwnedByViewer;

  const DebtItem({
    required this.id,
    required this.personName,
    required this.totalAmount,
    this.paidAmount = 0.0,
    required this.type,
    required this.createdAt,
    this.dueDate,
    this.note,
    this.repayments = const [],
    this.isSettled = false,
    this.ownerUid,
    this.ownerName,
    this.counterpartyUid,
    this.counterpartyEmail,
    this.isOwnedByViewer = true,
  });

  bool get isLinkedToUser => counterpartyUid != null;
  bool get isPendingSignup => counterpartyUid == null && counterpartyEmail != null;

  List<String> get participants => [
        ?ownerUid,
        ?counterpartyUid,
      ];

  /// Returns this record as seen by [viewerUid].
  DebtItem forViewer(String? viewerUid) {
    if (viewerUid == null || ownerUid == null || ownerUid == viewerUid) {
      return _copy(isOwnedByViewer: true);
    }
    return _copy(
      personName: ownerName ?? 'Someone',
      type: type == DebtType.lent ? DebtType.borrowed : DebtType.lent,
      isOwnedByViewer: false,
    );
  }

  DebtItem _copy({String? personName, DebtType? type, required bool isOwnedByViewer}) {
    return DebtItem(
      id: id,
      personName: personName ?? this.personName,
      totalAmount: totalAmount,
      paidAmount: paidAmount,
      type: type ?? this.type,
      createdAt: createdAt,
      dueDate: dueDate,
      note: note,
      repayments: repayments,
      isSettled: isSettled,
      ownerUid: ownerUid,
      ownerName: ownerName,
      counterpartyUid: counterpartyUid,
      counterpartyEmail: counterpartyEmail,
      isOwnedByViewer: isOwnedByViewer,
    );
  }

  double get remainingAmount {
    final rem = totalAmount - paidAmount;
    return rem < 0 ? 0.0 : rem;
  }

  double get progressRatio =>
      totalAmount > 0 ? (paidAmount / totalAmount).clamp(0.0, 1.0) : 0.0;
  int get progressPercent => (progressRatio * 100).round();

  DebtItem copyWith({
    String? personName,
    double? totalAmount,
    double? paidAmount,
    DebtType? type,
    DateTime? dueDate,
    String? note,
    List<DebtRepayment>? repayments,
    bool? isSettled,
  }) {
    return DebtItem(
      id: id,
      personName: personName ?? this.personName,
      totalAmount: totalAmount ?? this.totalAmount,
      paidAmount: paidAmount ?? this.paidAmount,
      type: type ?? this.type,
      createdAt: createdAt,
      dueDate: dueDate ?? this.dueDate,
      note: note ?? this.note,
      repayments: repayments ?? this.repayments,
      isSettled: isSettled ?? this.isSettled,
      ownerUid: ownerUid,
      ownerName: ownerName,
      counterpartyUid: counterpartyUid,
      counterpartyEmail: counterpartyEmail,
      isOwnedByViewer: isOwnedByViewer,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'personName': personName,
      'totalAmount': totalAmount,
      'paidAmount': paidAmount,
      'type': type.name,
      'createdAt': createdAt.toIso8601String(),
      'dueDate': dueDate?.toIso8601String(),
      'note': note,
      'repayments': repayments.map((e) => e.toMap()).toList(),
      'isSettled': isSettled,
      'ownerUid': ownerUid,
      'ownerName': ownerName,
      'counterpartyUid': counterpartyUid,
      'counterpartyEmail': counterpartyEmail?.toLowerCase(),
      'participants': participants,
    };
  }

  factory DebtItem.fromMap(Map<String, dynamic> map) {
    final rawRepayments = map['repayments'] as List<dynamic>? ?? [];
    return DebtItem(
      id: map['id'] as String,
      personName: map['personName'] as String,
      totalAmount: (map['totalAmount'] as num).toDouble(),
      paidAmount: (map['paidAmount'] as num?)?.toDouble() ?? 0.0,
      type: (map['type'] as String?) == 'borrowed'
          ? DebtType.borrowed
          : DebtType.lent,
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
      dueDate: map['dueDate'] != null ? DateTime.tryParse(map['dueDate'] as String) : null,
      note: map['note'] as String?,
      repayments: rawRepayments
          .map((r) => DebtRepayment.fromMap(Map<String, dynamic>.from(r as Map)))
          .toList(),
      isSettled: map['isSettled'] as bool? ?? false,
      ownerUid: map['ownerUid'] as String?,
      ownerName: map['ownerName'] as String?,
      counterpartyUid: map['counterpartyUid'] as String?,
      counterpartyEmail: map['counterpartyEmail'] as String?,
    );
  }
}
