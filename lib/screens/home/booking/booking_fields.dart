import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/design_system/design_system.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../services/friendly_error.dart';
import '../../../services/service_area.dart';
import 'map_location_picker.dart';

String dateOnly(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

class BookingServiceFields {
  BookingServiceFields({
    required String quantity,
    String details = '',
    String location = '',
    String deliveryDate = '',
    String waterType = '',
    String tankerCount = '',
    this.latitude,
    this.longitude,
  })  : quantity = TextEditingController(text: quantity),
        waterType = TextEditingController(text: waterType),
        tankerCount = TextEditingController(text: tankerCount),
        details = TextEditingController(text: details),
        location = TextEditingController(text: location),
        deliveryDate = TextEditingController(text: deliveryDate);

  final TextEditingController quantity;
  final TextEditingController waterType;
  final TextEditingController tankerCount;
  final TextEditingController details;
  final TextEditingController location;
  final TextEditingController deliveryDate;
  double? latitude;
  double? longitude;

  void dispose() {
    quantity.dispose();
    waterType.dispose();
    tankerCount.dispose();
    details.dispose();
    location.dispose();
    deliveryDate.dispose();
  }
}

class ServiceDropdownField extends StatelessWidget {
  const ServiceDropdownField({
    super.key,
    required this.controller,
    required this.label,
    required this.options,
    required this.emptyMessage,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final List<String> options;
  final String emptyMessage;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = options.contains(controller.text) ? controller.text : null;
    return DropdownButtonFormField<String>(
      initialValue: selected,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        helperText: options.isEmpty ? emptyMessage : null,
      ),
      items: options
          .map((option) => DropdownMenuItem<String>(
                value: option,
                child: Text(option),
              ))
          .toList(growable: false),
      onChanged: options.isEmpty
          ? null
          : (value) {
              controller.text = value ?? '';
              onChanged(value);
            },
      validator: (value) => options.isEmpty
          ? emptyMessage
          : value == null || value.trim().isEmpty
              ? 'Select $label.'
              : null,
    );
  }
}

class DeliveryLocationField extends StatelessWidget {
  const DeliveryLocationField({
    super.key,
    required this.fields,
    required this.onChanged,
  });

  final BookingServiceFields fields;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: fields.location,
        maxLength: 200,
        decoration: InputDecoration(
          labelText: 'Delivery location',
          helperText: fields.latitude == null
              ? 'Chennai addresses only'
              : 'Chennai location selected',
          prefixIcon: IconButton(
            tooltip: 'Choose delivery location',
            onPressed: () async {
              final coordinate = await showDialog<LatLng>(
                context: context,
                builder: (context) => MapLocationPicker(
                  latitude: fields.latitude,
                  longitude: fields.longitude,
                ),
              );
              if (coordinate == null) return;
              fields.latitude = coordinate.latitude;
              fields.longitude = coordinate.longitude;
              onChanged();
            },
            icon: const Icon(Icons.map_outlined),
          ),
          suffixIcon: IconButton(
            tooltip: 'Use current location',
            onPressed: () async {
              try {
                if (!await Geolocator.isLocationServiceEnabled()) {
                  if (!context.mounted) return;
                  await showAppPermissionDialog(
                    context,
                    message:
                        'Turn on location services to use your current location.',
                    onOpenSettings: () {
                      unawaited(Geolocator.openLocationSettings());
                    },
                  );
                  return;
                }
                var permission = await Geolocator.checkPermission();
                if (permission == LocationPermission.denied) {
                  permission = await Geolocator.requestPermission();
                }
                if (permission == LocationPermission.deniedForever) {
                  if (!context.mounted) return;
                  await showAppPermissionDialog(
                    context,
                    message:
                        'Allow location access in device settings to use your current location.',
                    onOpenSettings: () {
                      unawaited(Geolocator.openAppSettings());
                    },
                  );
                  return;
                }
                if (permission == LocationPermission.denied) {
                  if (context.mounted) {
                    showAppSnack(context,
                        'Location permission is needed to use your current location.');
                  }
                  return;
                }
                final position = await Geolocator.getCurrentPosition();
                if (!isChennaiLocation(
                  latitude: position.latitude,
                  longitude: position.longitude,
                )) {
                  throw const FormatException(
                    'This location is undeliverable. Select a location inside Chennai.',
                  );
                }
                fields.latitude = position.latitude;
                fields.longitude = position.longitude;
                onChanged();
              } catch (error) {
                if (context.mounted) {
                  showAppSnack(
                    context,
                    friendlyError(error),
                    variant: AppSnackVariant.error,
                  );
                }
              }
            },
            icon: const Icon(Icons.my_location_outlined),
          ),
          errorMaxLines: 2,
        ),
        validator: (value) {
          final text = value?.trim() ?? '';
          if (text.length < 3) return 'Enter a delivery location.';
          if (!isChennaiLocation(
            address: text,
            latitude: fields.latitude,
            longitude: fields.longitude,
          )) {
            return 'This location is undeliverable. Choose Chennai.';
          }
          return null;
        },
        onChanged: (_) {
          fields.latitude = null;
          fields.longitude = null;
          onChanged();
        },
      );
}

class DeliveryDateField extends StatelessWidget {
  const DeliveryDateField({
    super.key,
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: controller,
        readOnly: true,
        onTap: () async {
          final now = DateTime.now();
          final firstDate = DateTime(now.year, now.month, now.day)
              .add(const Duration(days: 1));
          final picked = await showDatePicker(
            context: context,
            initialDate: DateTime.tryParse(controller.text) ?? firstDate,
            firstDate: firstDate,
            lastDate: firstDate.add(const Duration(days: 365)),
          );
          if (picked != null) {
            controller.text = dateOnly(picked);
            onChanged();
          }
        },
        decoration: const InputDecoration(
          labelText: 'Delivery date',
          suffixIcon: Icon(Icons.calendar_today_outlined),
        ),
        validator: (value) {
          final selected = DateTime.tryParse(value?.trim() ?? '');
          final today = DateTime.now();
          final firstDate = DateTime(today.year, today.month, today.day)
              .add(const Duration(days: 1));
          return selected == null || selected.isBefore(firstDate)
              ? 'Choose a future delivery date.'
              : null;
        },
      );
}
