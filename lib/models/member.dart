enum MemberStatus { active, expiringSoon, expired }

class Member {
  final String id;
  final String memberCode;
  final String name;
  final String mobile;
  final String planId;
  final DateTime startDate;
  final DateTime endDate;
  final double amountPaid;
  final double amountDue;
  final DateTime updatedAt;
  final String? photoPath; // relative path within local storage, e.g. "member_photos/<uuid>.jpg"

  Member({
    required this.id,
    required this.memberCode,
    required this.name,
    required this.mobile,
    required this.planId,
    required this.startDate,
    required this.endDate,
    required this.amountPaid,
    required this.amountDue,
    required this.updatedAt,
    this.photoPath,
  });

  bool get isPaid => amountDue <= 0;

  /// Status is always computed live from endDate, never stored as a fixed value.
  MemberStatus get status {
    final daysLeft = endDate.difference(DateTime.now()).inDays;
    if (daysLeft < 0) return MemberStatus.expired;
    if (daysLeft <= 3) return MemberStatus.expiringSoon;
    return MemberStatus.active;
  }

  factory Member.fromJson(Map<String, dynamic> json) {
    return Member(
      id: json['id'] as String,
      memberCode: json['member_code'] as String,
      name: json['name'] as String,
      mobile: json['mobile'] as String,
      planId: json['plan_id'] as String,
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: DateTime.parse(json['end_date'] as String),
      amountPaid: (json['amount_paid'] as num).toDouble(),
      amountDue: (json['amount_due'] as num).toDouble(),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      photoPath: json['photo_path'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'member_code': memberCode,
      'name': name,
      'mobile': mobile,
      'plan_id': planId,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'amount_paid': amountPaid,
      'amount_due': amountDue,
      'updated_at': updatedAt.toIso8601String(),
      'photo_path': photoPath,
    };
  }

  Member copyWith({
    String? name,
    String? mobile,
    String? planId,
    DateTime? startDate,
    DateTime? endDate,
    double? amountPaid,
    double? amountDue,
    String? photoPath,
    bool clearPhoto = false,
  }) {
    return Member(
      id: id,
      memberCode: memberCode,
      name: name ?? this.name,
      mobile: mobile ?? this.mobile,
      planId: planId ?? this.planId,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      amountPaid: amountPaid ?? this.amountPaid,
      amountDue: amountDue ?? this.amountDue,
      updatedAt: DateTime.now(),
      photoPath: clearPhoto ? null : (photoPath ?? this.photoPath),
    );
  }
}
