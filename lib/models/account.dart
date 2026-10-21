class CustomerProfile {
  const CustomerProfile({
    required this.name,
    required this.email,
    required this.phone,
  });

  final String name;
  final String email;
  final String phone;

  factory CustomerProfile.fromJson(Map<String, dynamic> json) {
    return CustomerProfile(
      name: (json['name'] ?? json['full_name'] ?? 'Urban Tanker customer').toString(),
      email: (json['email'] ?? '').toString(),
      phone: (json['phone'] ?? json['phone_e164'] ?? '').toString(),
    );
  }
}

class AccountRecord {
  const AccountRecord(this.data);

  final Map<String, dynamic> data;

  String get id => (data['id'] ?? '').toString();
  String get title => (data['title'] ??
          data['label'] ??
          data['name'] ??
          data['subject'] ??
          data['code'] ??
          data['reference'] ??
          'Record')
      .toString();
  String get detail => (data['message'] ??
          data['address'] ??
          data['description'] ??
          data['status'] ??
          data['discount_value'] ??
          '')
      .toString();
  String get status => (data['status'] ?? '').toString();
}

class CustomerUsage {
  const CustomerUsage({
    required this.deliveries,
    required this.totalSpend,
    required this.averageAmount,
  });

  final int deliveries;
  final double totalSpend;
  final double averageAmount;

  factory CustomerUsage.fromJson(Map<String, dynamic> json) {
    return CustomerUsage(
      deliveries: (json['deliveries'] as num?)?.toInt() ?? 0,
      totalSpend: (json['totalSpend'] as num?)?.toDouble() ?? 0,
      averageAmount: (json['averageAmount'] as num?)?.toDouble() ?? 0,
    );
  }
}
