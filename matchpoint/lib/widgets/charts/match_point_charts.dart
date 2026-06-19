import 'dart:math' as math;
import 'package:flutter/material.dart';

const List<Color> kChartPalette = [
  Color(0xFF2563EB),
  Color(0xFF10B981),
  Color(0xFFF59E0B),
  Color(0xFFEF4444),
  Color(0xFF8B5CF6),
  Color(0xFFF97316),
  Color(0xFF06B6D4),
  Color(0xFFEC4899),
];

class PieChartItem {
  final String label;
  final double value;
  final Color color;
  const PieChartItem(
      {required this.label, required this.value, required this.color});
}

/// Gráfico de pizza (donut) com legenda lateral.
class MpPieChart extends StatelessWidget {
  final List<PieChartItem> data;
  final double size;

  const MpPieChart({super.key, required this.data, this.size = 110});

  @override
  Widget build(BuildContext context) {
    final total = data.fold(0.0, (s, d) => s + d.value);
    if (total == 0) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text('Sem dados suficientes',
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _PiePainter(data: data, total: total),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: data.take(6).map((item) {
              final pct = (item.value / total * 100).round();
              return Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                          color: item.color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        item.label,
                        style: const TextStyle(
                            fontSize: 11.5, color: Color(0xFF475569)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$pct%',
                      style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A)),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _PiePainter extends CustomPainter {
  final List<PieChartItem> data;
  final double total;
  const _PiePainter({required this.data, required this.total});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    double startAngle = -math.pi / 2;
    for (final item in data) {
      final sweep = (item.value / total) * 2 * math.pi;
      canvas.drawArc(
        rect,
        startAngle + 0.04,
        math.max(sweep - 0.08, 0.001),
        true,
        Paint()
          ..color = item.color
          ..style = PaintingStyle.fill,
      );
      startAngle += sweep;
    }

    // Buraco interno do donut
    canvas.drawCircle(
      center,
      radius * 0.52,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant _PiePainter old) =>
      old.data != data || old.total != total;
}

/// Barra de progresso com label e valor, seguindo o design language do app.
class MpProgressBar extends StatelessWidget {
  final String label;
  final double value; // 0.0–1.0
  final Color color;
  final String? trailingText;

  const MpProgressBar({
    super.key,
    required this.label,
    required this.value,
    this.color = const Color(0xFF2563EB),
    this.trailingText,
  });

  @override
  Widget build(BuildContext context) {
    final pct = (value.clamp(0.0, 1.0) * 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF475569))),
            Text(
              trailingText ?? '$pct%',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: value.clamp(0.0, 1.0),
            backgroundColor: const Color(0xFFE2E8F0),
            color: color,
            minHeight: 7,
          ),
        ),
      ],
    );
  }
}

/// Mini card de métrica (ícone + valor + label).
class MpMetricCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final String value;
  final String label;

  const MpMetricCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.fromBorderSide(
              BorderSide(color: iconColor.withValues(alpha: 0.15))),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0F172A),
                height: 1,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: iconColor,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
}
