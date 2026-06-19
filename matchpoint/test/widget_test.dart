import 'package:flutter_test/flutter_test.dart';
import 'package:matchpoint/utils/viabilidade.dart';

void main() {
  test('calcularViabilidade retorna 1.0 com condições ideais', () {
    final resultado = calcularViabilidade(
      confirmados: 10,
      minimo: 5,
      chanceChuva: 0,
      taxaFaltaMedia: 0,
    );
    expect(resultado, 1.0);
  });

  test('calcularViabilidade com quórum parcial', () {
    final resultado = calcularViabilidade(
      confirmados: 2,
      minimo: 10,
      chanceChuva: 0,
      taxaFaltaMedia: 0,
    );
    // fatorQuorum = 0.2, fatorClima = 1.0, fatorConfiabilidade = 1.0
    // 0.2*0.20 + 1.0*0.45 + 1.0*0.35 = 0.04 + 0.45 + 0.35 = 0.84
    expect(resultado, closeTo(0.84, 0.001));
  });

  test('calcularViabilidade sem confirmados (taxaFaltaMedia null)', () {
    // Sem confirmados: apenas quórum + clima (max 65%)
    final resultado = calcularViabilidade(
      confirmados: 0,
      minimo: 5,
      chanceChuva: 0,
      taxaFaltaMedia: null,
    );
    // fatorQuorum = 0, fatorClima = 1.0 → 0*0.20 + 1.0*0.45 = 0.45
    expect(resultado, closeTo(0.45, 0.001));
  });

  test('classificarViabilidade classifica corretamente', () {
    expect(classificarViabilidade(0.75), NivelViabilidade.alta);
    expect(classificarViabilidade(0.50), NivelViabilidade.media);
    expect(classificarViabilidade(0.30), NivelViabilidade.baixa);
  });
}
