String formatRecordDetails(
  Map<String, dynamic> data, {
  Set<String> excludeKeys = const {},
  bool includeIdentifiers = false,
  bool skipNullValues = false,
}) =>
    data.entries
        .where(
          (entry) =>
              !excludeKeys.contains(entry.key) &&
              (includeIdentifiers || !isRecordIdentifierKey(entry.key)) &&
              !(skipNullValues && entry.value == null),
        )
        .map(
          (entry) => '${recordFieldLabel(entry.key)}: '
              '${recordFieldValue(entry.value, includeIdentifiers: includeIdentifiers)}',
        )
        .join('\n');

bool isRecordIdentifierKey(String key) {
  final normalized = _normalizedRecordFieldKey(key);
  return normalized == 'id' || normalized.endsWith('_id');
}

String recordFieldLabel(String key) {
  final normalized = _normalizedRecordFieldKey(key);
  const customLabels = {
    'id': 'Record ID',
    'full_name': 'Name',
    'name': 'Name',
    'contact_name': 'Contact name',
    'business_name': 'Business name',
    'mobile_e164': 'Phone',
    'phone_e164': 'Phone',
    'mobile_number': 'Phone',
    'phone_number': 'Phone',
    'mobile': 'Phone',
    'phone': 'Phone',
    'is_active': 'Active',
    'active': 'Active',
    'is_online': 'Online',
    'is_default': 'Default',
    'verification': 'Approval status',
    'vendor_id': 'Vendor ID',
    'owner_profile_id': 'Owner profile ID',
    'registration_number': 'Registration number',
    'capacity_litres': 'Capacity (litres)',
    'licence_number': 'Licence number',
    'service_zone': 'Service area',
    'address_text': 'Location',
    'customer_type': 'Customer type',
    'quoted_amount_paise': 'Quoted amount (paise)',
    'created_at': 'Created at',
    'updated_at': 'Last updated',
    'created_by': 'Created by',
    'updated_by': 'Updated by',
    'metadata': 'Additional details',
  };
  final custom = customLabels[normalized];
  if (custom != null) return custom;

  if (!key.contains('_') &&
      !RegExp(r'[a-z0-9][A-Z]').hasMatch(key) &&
      key.trim().contains(' ')) {
    return key.trim();
  }

  const acronyms = {'api': 'API', 'e164': 'E.164', 'id': 'ID', 'otp': 'OTP'};
  return normalized
      .split('_')
      .where((word) => word.isNotEmpty)
      .toList()
      .asMap()
      .entries
      .map((entry) {
    final word = entry.value;
    return acronyms[word] ??
        (entry.key == 0
            ? '${word[0].toUpperCase()}${word.substring(1)}'
            : word);
  }).join(' ');
}

String _normalizedRecordFieldKey(String key) => key
    .replaceAllMapped(
      RegExp(r'([a-z0-9])([A-Z])'),
      (match) => '${match[1]}_${match[2]}',
    )
    .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')
    .toLowerCase();

String recordFieldValue(Object? value, {bool includeIdentifiers = false}) {
  if (value == null) return 'Not provided';
  if (value is bool) return value ? 'Yes' : 'No';
  if (value is Map) {
    final data = <String, dynamic>{
      for (final entry in value.entries) entry.key.toString(): entry.value,
    };
    return formatRecordDetails(
      data,
      includeIdentifiers: includeIdentifiers,
    ).replaceAll('\n', ', ');
  }
  if (value is Iterable) {
    return value
        .map((item) =>
            recordFieldValue(item, includeIdentifiers: includeIdentifiers))
        .join(', ');
  }
  return value.toString();
}
