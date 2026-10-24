import 'package:flutter/material.dart';

class LocationPreview extends StatelessWidget {
  const LocationPreview({super.key, this.height = 120});
  final double height;

  @override
  Widget build(BuildContext context) => Container(
    height: height,
    decoration: BoxDecoration(color: const Color(0xFFE3F2FD), borderRadius: BorderRadius.circular(12)),
    child: const Center(child: Icon(Icons.location_on, size: 42, color: Color(0xFF1565C0))),
  );
}
