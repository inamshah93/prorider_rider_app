import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:velo_core/velo_core.dart';

class LocationTracker {
  LocationTracker(this._api);

  final ApiClient _api;
  Timer? _timer;
  bool _running = false;

  Future<bool> _ensurePermission() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.always || permission == LocationPermission.whileInUse;
  }

  Future<void> start() async {
    if (_running) return;
    final allowed = await _ensurePermission();
    if (!allowed) return;

    _running = true;
    await _sendCurrent();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _sendCurrent());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _running = false;
  }

  Future<void> _sendCurrent() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      await _api.put('/rider/location', data: {
        'lat': pos.latitude,
        'lng': pos.longitude,
      });
    } catch (_) {
      // Ignore transient GPS/network errors.
    }
  }

  void dispose() => stop();
}
