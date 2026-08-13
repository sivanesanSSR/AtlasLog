enum PaymentMode { cash, upi, card, other }

class Payment {
  final String id;
  final String memberId;
  final double amount;
  final DateTime date;
  final PaymentMode mode;

  Payment({
    required this.id,
    required this.memberId,
    required this.amount,
    required this.date,
    required this.mode,
  });

  factory Payment.fromJson(Map<String, dynamic> json) {
    return Payment(
      id: json['id'] as String,
      memberId: json['member_id'] as String,
      amount: (json['amount'] as num).toDouble(),
      date: DateTime.parse(json['date'] as String),
      mode: PaymentMode.values.firstWhere(
        (m) => m.name == json['mode'],
        orElse: () => PaymentMode.other,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'member_id': memberId,
      'amount': amount,
      'date': date.toIso8601String(),
      'mode': mode.name,
    };
  }
}
