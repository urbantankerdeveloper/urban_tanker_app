class BookingServiceForm {
  const BookingServiceForm({
    required this.serviceName,
    required this.quantityLabel,
    required this.quantityHint,
    required this.detailsLabel,
    required this.detailsHint,
  });

  final String serviceName;
  final String quantityLabel;
  final String quantityHint;
  final String detailsLabel;
  final String detailsHint;

  static BookingServiceForm forService(String serviceId) {
    return switch (serviceId) {
      'water_tanker' => const BookingServiceForm(
          serviceName: 'Water tanker',
          quantityLabel: 'Delivery capacity (litres)',
          quantityHint: 'For example, 5,000 litres',
          detailsLabel: 'Water delivery details',
          detailsHint: 'Optional delivery details.',
        ),
      'sewage_tanker' => const BookingServiceForm(
          serviceName: 'Sewage tanker',
          quantityLabel: 'Tank capacity or volume',
          quantityHint: 'Approximate volume is fine',
          detailsLabel: 'Waste type and collection details',
          detailsHint:
              'Describe the waste type, collection point, and access requirements.',
        ),
      'tank_cleaning' => const BookingServiceForm(
          serviceName: 'Tank cleaning',
          quantityLabel: 'Tank size or number of tanks',
          quantityHint: 'For example, 2 rooftop tanks',
          detailsLabel: 'Tank type and cleaning requirements',
          detailsHint:
              'Describe the tank type, size, and access or cleaning requirements.',
        ),
      'borewell_service' => const BookingServiceForm(
          serviceName: 'Borewell service',
          quantityLabel: 'Borewell depth (if known)',
          quantityHint: 'Approximate depth in feet or metres',
          detailsLabel: 'Borewell issue and service needs',
          detailsHint:
              'Describe the borewell issue and any site access requirements.',
        ),
      _ => const BookingServiceForm(
          serviceName: 'Other service',
          quantityLabel: 'Quantity or capacity',
          quantityHint: 'Enter the quantity or capacity if applicable',
          detailsLabel: 'Service requirements',
          detailsHint:
              'Describe the work and any special requirements for this service.',
        ),
    };
  }
}
