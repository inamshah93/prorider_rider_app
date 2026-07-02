import 'package:flutter/material.dart';

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = _style(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12)),
    );
  }

  (String, Color) _style(String raw) {
    return switch (raw) {
      'ready_to_ship' => ('Pending', Colors.orange),
      'dispatched' => ('Pending', Colors.orange),
      'picked_up' => ('In Process', Colors.blue),
      'delivered' => ('Delivered', Colors.green),
      'cancelled' => ('Returned', Colors.red),
      _ => (raw.replaceAll('_', ' '), Colors.grey),
    };
  }
}
