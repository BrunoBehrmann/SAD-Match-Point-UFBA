import 'package:flutter/material.dart';
import '../utils/viabilidade.dart';

class ViabilidadeBadge extends StatelessWidget {
  final double indice;
  const ViabilidadeBadge({super.key, required this.indice});

  @override
  Widget build(BuildContext context) {
    final nivel = classificarViabilidade(indice);
    final cor = corViabilidade(nivel);
    final label = labelViabilidade(nivel);

    final pct = (indice * 100).toStringAsFixed(0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: cor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$label · $pct%',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
