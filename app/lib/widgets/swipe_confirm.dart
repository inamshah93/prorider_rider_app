import 'package:flutter/material.dart';
import 'package:velo_core/velo_core.dart';

class SwipeConfirm extends StatefulWidget {
  const SwipeConfirm({
    super.key,
    required this.label,
    required this.onComplete,
    this.color = AppTheme.primary,
  });

  final String label;
  final Future<void> Function() onComplete;
  final Color color;

  @override
  State<SwipeConfirm> createState() => _SwipeConfirmState();
}

class _SwipeConfirmState extends State<SwipeConfirm> {
  double _drag = 0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final max = c.maxWidth - 72;
      return Container(
        height: 72,
        decoration: BoxDecoration(
          color: widget.color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(36),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text(
              widget.label,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: widget.color.withValues(alpha: 0.85),
              ),
            ),
            Positioned(
              left: _drag.clamp(0, max),
              child: GestureDetector(
                onHorizontalDragUpdate: (d) => setState(() => _drag += d.delta.dx),
                onHorizontalDragEnd: (_) async {
                  if (_drag >= max * 0.85) await widget.onComplete();
                  setState(() => _drag = 0);
                },
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
                  child: const Icon(Icons.check, color: Colors.white, size: 32),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}
