import 'package:flutter/material.dart';

class LocationPreview extends StatelessWidget {
  const LocationPreview({
    super.key,
    this.height = 120,
    this.latitude,
    this.longitude,
  });

  final double height;
  final double? latitude;
  final double? longitude;

  @override
  Widget build(BuildContext context) {
    final hasCoordinates = latitude != null && longitude != null;
    final label = hasCoordinates
        ? 'Ubicación capturada: ${latitude!.toStringAsFixed(5)}, ${longitude!.toStringAsFixed(5)}'
        : 'Ubicación no capturada';
    return Semantics(
      label: label,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFFE3F2FD),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                hasCoordinates ? Icons.location_on : Icons.location_off_outlined,
                size: 42,
                color: const Color(0xFF1565C0),
              ),
              const SizedBox(height: 8),
              Text(
                hasCoordinates ? 'Ubicación capturada' : 'Sin ubicación capturada',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                hasCoordinates
                    ? 'Lat: ${latitude!.toStringAsFixed(5)}, Lng: ${longitude!.toStringAsFixed(5)}'
                    : 'Captura tu ubicación actual. Sin coordenadas no se podrán sugerir entidades territoriales.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
