bool isChennaiLocation({
  String? address,
  double? latitude,
  double? longitude,
}) {
  if (latitude != null && longitude != null) {
    return latitude >= 12.75 &&
        latitude <= 13.35 &&
        longitude >= 79.85 &&
        longitude <= 80.45;
  }
  final value = (address ?? '').toLowerCase();
  return value.contains('chennai') ||
      value.contains('madras') ||
      value.contains('tambaram') ||
      value.contains('avadi') ||
      value.contains('ambattur') ||
      value.contains('velachery') ||
      value.contains('adyar') ||
      value.contains('t nagar') ||
      value.contains('perambur') ||
      value.contains('sholinganallur');
}
