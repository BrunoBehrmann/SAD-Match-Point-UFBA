import 'dart:convert';
import 'package:http/http.dart' as http;

class WeatherService {
  static const _baseUrl = 'https://api.openweathermap.org/data/2.5/forecast';
  final String apiKey;

  // Cache local: eventoId+dataHora → chanceChuva
  final Map<String, double> _cache = {};

  WeatherService(this.apiKey);

  // Janela máxima da API gratuita: 5 dias = 120 horas
  static const _maxHorasPrevisao = 120;

  /// Retorna chance de chuva de 0.0 a 100.0.
  /// Lança [WeatherForaDoAlcanceException] se o evento estiver além dos 5 dias
  /// cobertos pela API gratuita.
  /// Lança [Exception] se a API falhar (status ≠ 200 ou sem dados).
  Future<double> getChanceChuva({
    required double latitude,
    required double longitude,
    required DateTime dataHora,
    required String cacheKey,
  }) async {
    if (_cache.containsKey(cacheKey)) return _cache[cacheKey]!;

    // Rejeita antecipadamente se o evento estiver fora da janela de 5 dias
    final horasAteEvento =
        dataHora.toUtc().difference(DateTime.now().toUtc()).inHours;
    if (horasAteEvento > _maxHorasPrevisao) {
      throw WeatherForaDoAlcanceException(
          'Previsão indisponível: evento em $horasAteEvento h '
          '(máximo ${_maxHorasPrevisao}h pela API gratuita).');
    }

    final uri = Uri.parse('$_baseUrl?lat=$latitude&lon=$longitude'
        '&appid=$apiKey&units=metric&cnt=40');

    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception(
          'OpenWeatherMap retornou ${response.statusCode}: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final lista = data['list'] as List<dynamic>? ?? [];

    if (lista.isEmpty) {
      throw Exception('Nenhum dado de previsão disponível.');
    }

    // Média ponderada dos slots dentro de ±3h do evento (peso = 1/distância).
    // Evita resultado binário quando um único slot fica em 0 ou 1.
    double somaPopPeso = 0.0;
    double somaPeso = 0.0;

    for (final item in lista) {
      final dt = DateTime.fromMillisecondsSinceEpoch(
          (item['dt'] as int) * 1000,
          isUtc: true);
      final diffMin =
          (dt.difference(dataHora.toUtc()).inMinutes).abs();
      if (diffMin > 180) continue; // ignora slots além de 3h
      final pop = ((item['pop'] ?? 0.0) as num).toDouble();
      final peso = 1.0 / (diffMin + 1); // +1 evita divisão por zero
      somaPopPeso += pop * peso;
      somaPeso += peso;
    }

    // Fallback: slot mais próximo se nenhum estiver dentro de 3h
    if (somaPeso == 0) {
      int menorDiff = 999999;
      double melhorPop = 0.0;
      for (final item in lista) {
        final dt = DateTime.fromMillisecondsSinceEpoch(
            (item['dt'] as int) * 1000,
            isUtc: true);
        final diff = (dt.difference(dataHora.toUtc()).inMinutes).abs();
        if (diff < menorDiff) {
          menorDiff = diff;
          melhorPop = ((item['pop'] ?? 0.0) as num).toDouble();
        }
      }
      somaPopPeso = melhorPop;
      somaPeso = 1.0;
    }

    final melhorPop = (somaPopPeso / somaPeso) * 100;

    _cache[cacheKey] = melhorPop;
    return melhorPop;
  }
}

/// Lançada quando o evento está além dos 5 dias cobertos pela API gratuita.
class WeatherForaDoAlcanceException implements Exception {
  final String message;
  const WeatherForaDoAlcanceException(this.message);
  @override
  String toString() => message;
}
