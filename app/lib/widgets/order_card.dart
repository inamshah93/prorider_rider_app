import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:velo_core/velo_core.dart';

import 'status_chip.dart';

class OrderCard extends StatelessWidget {
  const OrderCard({
    super.key,
    required this.order,
    this.onTap,
    this.selectable = false,
    this.selected = false,
    this.onSelected,
    this.commissionRate,
  });

  final Map<String, dynamic> order;
  final VoidCallback? onTap;
  final bool selectable;
  final bool selected;
  final ValueChanged<bool>? onSelected;
  final double? commissionRate;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final ref = order['order_reference_number']?.toString() ?? '—';
    final status = order['order_status']?.toString() ?? '';
    final cod = order['cod_amount']?.toString() ?? '0';
    final city = order['target_city']?.toString() ?? '—';
    final customer = order['customer_name']?.toString() ?? '—';
    final deliveryCharge = JsonNum.parseDouble(order['delivery_charge']);
    final expectedCommission = deliveryCharge != null && commissionRate != null
        ? (deliveryCharge * commissionRate!).round()
        : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap ?? () => context.push('/orders/${order['id']}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (selectable && onSelected != null)
                    Checkbox(
                      value: selected,
                      onChanged: (v) => onSelected!(v ?? false),
                    ),
                  Expanded(
                    child: Text(ref, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  ),
                  StatusChip(status: status),
                ],
              ),
              const SizedBox(height: 8),
              Text(customer, style: TextStyle(color: colors.onSurfaceVariant)),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.location_on_outlined, size: 16, color: colors.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Expanded(child: Text(city, style: TextStyle(color: colors.onSurfaceVariant))),
                  Text('COD ₨ $cod', style: TextStyle(color: colors.primary, fontWeight: FontWeight.bold)),
                ],
              ),
              if (deliveryCharge != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.local_shipping_outlined, size: 16, color: colors.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text('Delivery ₨ ${deliveryCharge.toStringAsFixed(0)}', style: TextStyle(color: colors.onSurfaceVariant)),
                    if (expectedCommission != null) ...[
                      const SizedBox(width: 12),
                      Text(
                        'Commission ~₨ $expectedCommission',
                        style: TextStyle(color: colors.secondary, fontWeight: FontWeight.w600, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
