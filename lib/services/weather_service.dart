import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

/// Simplified sky condition mapped from WMO weather codes.
enum WeatherKind {
  clear,
  partlyCloudy,
  cloudy,
  fog,
  drizzle,
  rain,
  snow,
  thunderstorm,
}

class WeatherSnapshot {
  const WeatherSnapshot({
    required this.tempC,
    required this.kind,
    required this.fetchedAt,
    required this.isStale,
  });

  final double tempC;
  final WeatherKind kind;
  final DateTime fetchedAt;

  /// True when this snapshot came from cache because the network failed.
  final bool isStale;
}

/// Current weather via Open-Meteo (free, no API key, no account — keeps the
/// no-login requirement). Uses dart:io directly — no HTTP package dependency.
/// Offline-tolerant: the last good result is cached and returned with
/// [WeatherSnapshot.isStale] when the network is unavailable.
class WeatherService {
  WeatherService({HttpClient Function()? clientFactory})
      : _clientFactory = clientFactory ?? HttpClient.new;

  final HttpClient Function() _clientFactory;

  static const _cacheKey = 'weather_cache_v1';
  static const _timeout = Duration(seconds: 8);

  Future<WeatherSnapshot?> fetch(double lat, double lon) async {
    try {
      final client = _clientFactory()..connectionTimeout = _timeout;
      try {
        final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
          'latitude': lat.toStringAsFixed(4),
          'longitude': lon.toStringAsFixed(4),
          'current': 'temperature_2m,weather_code',
        });
        final request = await client.getUrl(uri);
        final response = await request.close().timeout(_timeout);
        if (response.statusCode != 200) {
          throw HttpException('HTTP ${response.statusCode}', uri: uri);
        }
        final body = await response.transform(utf8.decoder).join();
        final json = jsonDecode(body) as Map<String, dynamic>;
        final current = json['current'] as Map<String, dynamic>;
        final snapshot = WeatherSnapshot(
          tempC: (current['temperature_2m'] as num).toDouble(),
          kind: kindFromWmo((current['weather_code'] as num).toInt()),
          fetchedAt: DateTime.now(),
          isStale: false,
        );
        await _saveCache(snapshot);
        return snapshot;
      } finally {
        client.close(force: true);
      }
    } catch (_) {
      return _loadCache();
    }
  }

  Future<void> _saveCache(WeatherSnapshot s) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _cacheKey,
      jsonEncode({
        'tempC': s.tempC,
        'kind': s.kind.index,
        'fetchedAt': s.fetchedAt.millisecondsSinceEpoch,
      }),
    );
  }

  Future<WeatherSnapshot?> _loadCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null) return null;
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return WeatherSnapshot(
        tempC: (m['tempC'] as num).toDouble(),
        kind: WeatherKind.values[(m['kind'] as num).toInt()],
        fetchedAt:
            DateTime.fromMillisecondsSinceEpoch((m['fetchedAt'] as num).toInt()),
        isStale: true,
      );
    } catch (_) {
      return null;
    }
  }

  /// WMO weather interpretation codes -> simplified kinds.
  static WeatherKind kindFromWmo(int code) {
    if (code == 0) return WeatherKind.clear;
    if (code <= 2) return WeatherKind.partlyCloudy;
    if (code == 3) return WeatherKind.cloudy;
    if (code == 45 || code == 48) return WeatherKind.fog;
    if (code >= 51 && code <= 57) return WeatherKind.drizzle;
    if ((code >= 61 && code <= 67) || (code >= 80 && code <= 82)) {
      return WeatherKind.rain;
    }
    if ((code >= 71 && code <= 77) || code == 85 || code == 86) {
      return WeatherKind.snow;
    }
    if (code >= 95) return WeatherKind.thunderstorm;
    return WeatherKind.cloudy;
  }
}
