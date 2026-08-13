class GymProfile {
  final String name;
  final String address;
  final String contact;
  final String? logoPath; // relative path within local storage, e.g. "gym_logo.jpg"

  GymProfile({
    required this.name,
    required this.address,
    required this.contact,
    this.logoPath,
  });

  factory GymProfile.fromJson(Map<String, dynamic> json) {
    return GymProfile(
      name: json['name'] as String,
      address: json['address'] as String,
      contact: json['contact'] as String,
      logoPath: json['logo_path'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'address': address,
      'contact': contact,
      'logo_path': logoPath,
    };
  }

  GymProfile copyWith({
    String? name,
    String? address,
    String? contact,
    String? logoPath,
    bool clearLogo = false,
  }) {
    return GymProfile(
      name: name ?? this.name,
      address: address ?? this.address,
      contact: contact ?? this.contact,
      logoPath: clearLogo ? null : (logoPath ?? this.logoPath),
    );
  }
}
