import 'dart:convert';
import 'package:http/http.dart' as http;

class GeocodingResult {
  final double lat;
  final double lng;
  final String displayName;

  const GeocodingResult({
    required this.lat,
    required this.lng,
    required this.displayName,
  });
}

class GeocodingService {
  Future<GeocodingResult?> buscarCoordenadas(String endereco) async {
    if (endereco.trim().isEmpty) return null;

    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': endereco,
      'format': 'json',
      'limit': '1',
      'accept-language': 'pt-BR',
    });

    try {
      final response = await http.get(uri, headers: {
        'User-Agent': 'MatchPointUFBA/1.0',
      });
      if (response.statusCode != 200) return null;

      final list = jsonDecode(response.body) as List<dynamic>;
      if (list.isEmpty) return null;

      final first = list.first as Map<String, dynamic>;
      return GeocodingResult(
        lat: double.parse(first['lat'] as String),
        lng: double.parse(first['lon'] as String),
        displayName: first['display_name'] as String,
      );
    } catch (_) {
      return null;
    }
  }
}
