import 'dart:math';
import 'package:flutter/material.dart';

// Pesos: Quórum 20% / Clima 45% / Confiabilidade 35%
// taxaFaltaMedia == null quando não há confirmados: confiabilidade excluída do cálculo.
double calcularViabilidade({
  required int confirmados,
  required int minimo,
  required double chanceChuva,
  double? taxaFaltaMedia,
}) {
  final fatorQuorum = minimo > 0 ? min(confirmados / minimo, 1.0) : 1.0;
  final fatorClima = 1.0 - (chanceChuva / 100);
  if (taxaFaltaMedia == null) {
    return (fatorQuorum * 0.20) + (fatorClima * 0.45);
  }
  final fatorConfiabilidade = 1.0 - taxaFaltaMedia;
  return (fatorQuorum * 0.20) + (fatorClima * 0.45) + (fatorConfiabilidade * 0.35);
}

enum NivelViabilidade { alta, media, baixa }

NivelViabilidade classificarViabilidade(double indice) {
  if (indice >= 0.70) return NivelViabilidade.alta;
  if (indice >= 0.40) return NivelViabilidade.media;
  return NivelViabilidade.baixa;
}

String labelViabilidade(NivelViabilidade nivel) => switch (nivel) {
      NivelViabilidade.alta => 'Alta',
      NivelViabilidade.media => 'Méd.',
      NivelViabilidade.baixa => 'Baixa',
    };

Color corViabilidade(NivelViabilidade nivel) => switch (nivel) {
      NivelViabilidade.alta => const Color(0xFF2E7D32),
      NivelViabilidade.media => const Color(0xFFF9A825),
      NivelViabilidade.baixa => const Color(0xFFC62828),
    };

// Ranking: 70% confiabilidade + 30% comparecimento relativo
double calcularPontuacaoRanking(double taxaConfiabilidade, int totalComparecimentos, int maxComparecimentos) {
  final fatorVolume = maxComparecimentos > 0 ? totalComparecimentos / maxComparecimentos : 0.0;
  return (taxaConfiabilidade * 0.70) + (fatorVolume * 0.30);
}
