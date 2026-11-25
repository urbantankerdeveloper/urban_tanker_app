Map<String, double> parseOptionalCoordinates(
  String latitude,
  String longitude,
) {
  final latitudeText = latitude.trim();
  final longitudeText = longitude.trim();
  if (latitudeText.isEmpty && longitudeText.isEmpty) return const {};
  if (latitudeText.isEmpty || longitudeText.isEmpty) {
    throw const FormatException('Enter both latitude and longitude.');
  }

  final latitudeValue = double.tryParse(latitudeText);
  final longitudeValue = double.tryParse(longitudeText);
  if (latitudeValue == null ||
      longitudeValue == null ||
      !latitudeValue.isFinite ||
      !longitudeValue.isFinite ||
      latitudeValue < -90 ||
      latitudeValue > 90 ||
      longitudeValue < -180 ||
      longitudeValue > 180) {
    throw const FormatException('Enter valid latitude and longitude values.');
  }
  return {'latitude': latitudeValue, 'longitude': longitudeValue};
}
