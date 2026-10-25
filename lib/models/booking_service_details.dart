class BookingServiceDetails {
  const BookingServiceDetails({
    required this.serviceId,
    required this.quantity,
    required this.details,
    this.deliveryDate,
    this.location,
    this.latitude,
    this.longitude,
    this.phone,
    this.phoneVerificationChallengeId,
  });

  final String serviceId;
  final String quantity;
  final String details;
  final String? deliveryDate;
  final String? location;
  final double? latitude;
  final double? longitude;
  final String? phone;
  final String? phoneVerificationChallengeId;

  Map<String, dynamic> toJson() => {
        'serviceId': serviceId,
        'capacity': quantity.trim(),
        'details': details.trim(),
        if (deliveryDate != null && deliveryDate!.trim().isNotEmpty)
          'deliveryDate': deliveryDate!.trim(),
        if (location != null && location!.trim().isNotEmpty)
          'location': location!.trim(),
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (phone != null && phone!.trim().isNotEmpty) 'phone': phone!.trim(),
        if (phoneVerificationChallengeId != null)
          'phoneVerificationChallengeId': phoneVerificationChallengeId,
      };

  factory BookingServiceDetails.fromJson(Map<String, dynamic> json) {
    return BookingServiceDetails(
      serviceId: (json['serviceId'] ?? '').toString(),
      quantity: (json['capacity'] ?? json['quantity'] ?? '').toString(),
      details: (json['details'] ?? '').toString(),
      deliveryDate: json['deliveryDate']?.toString(),
      location: json['location']?.toString(),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      phone: json['phone']?.toString(),
      phoneVerificationChallengeId:
          json['phoneVerificationChallengeId']?.toString(),
    );
  }
}
