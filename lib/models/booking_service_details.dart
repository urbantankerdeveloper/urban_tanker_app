class BookingServiceDetails {
  const BookingServiceDetails({
    required this.serviceId,
    required this.quantity,
    required this.details,
  });

  final String serviceId;
  final String quantity;
  final String details;

  Map<String, String> toJson() => {
        'serviceId': serviceId,
        'capacity': quantity.trim(),
        'details': details.trim(),
      };

  factory BookingServiceDetails.fromJson(Map<String, dynamic> json) {
    return BookingServiceDetails(
      serviceId: (json['serviceId'] ?? '').toString(),
      quantity: (json['capacity'] ?? json['quantity'] ?? '').toString(),
      details: (json['details'] ?? '').toString(),
    );
  }
}
