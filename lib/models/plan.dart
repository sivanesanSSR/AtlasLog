class Plan {
  final String id;
  final String name; // e.g. "1 Month", "3 Month", "Personal Training"
  final int durationMonths; // 0 for non-duration-based plans if ever needed
  final double price;

  Plan({
    required this.id,
    required this.name,
    required this.durationMonths,
    required this.price,
  });

  factory Plan.fromJson(Map<String, dynamic> json) {
    return Plan(
      id: json['id'] as String,
      name: json['name'] as String,
      durationMonths: json['duration_months'] as int,
      price: (json['price'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'duration_months': durationMonths,
      'price': price,
    };
  }

  Plan copyWith({
    String? name,
    int? durationMonths,
    double? price,
  }) {
    return Plan(
      id: id,
      name: name ?? this.name,
      durationMonths: durationMonths ?? this.durationMonths,
      price: price ?? this.price,
    );
  }
}
