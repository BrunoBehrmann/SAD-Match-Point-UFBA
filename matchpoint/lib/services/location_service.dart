import 'dart:math';
import 'package:geolocator/geolocator.dart';

class LocationService {
  static const double _raioCheckInMetros = 500.0;

  Future<bool> verificarPermissao() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }

  Future<Position?> getPosicaoAtual() async {
    final temPermissao = await verificarPermissao();
    if (!temPermissao) return null;
    return Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ));
  }

  Future<bool> dentroDoRaio({
    required double latEvento,
    required double lonEvento,
  }) async {
    final pos = await getPosicaoAtual();
    if (pos == null) return false;

    final distancia = _haversine(
      pos.latitude, pos.longitude, latEvento, lonEvento,
    );
    return distancia <= _raioCheckInMetros;
  }

  double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371000.0;
    final dLat = _rad(lat2 - lat1);
    final dLon = _rad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_rad(lat1)) * cos(_rad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    return R * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  double _rad(double deg) => deg * pi / 180;
}
