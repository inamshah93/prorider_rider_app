import 'dart:async';
import 'dart:io';

import 'package:geolocator/geolocator.dart';
import 'package:velo_core/velo_core.dart';

class LocationTracker {
  LocationTracker(this._api);

  final ApiClient _api;
  bool _running = false;
  StreamSubscription<Position>? _sub;

  Future<bool> _ensurePermission() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (Platform.isAndroid && permission == LocationPermission.whileInUse) {
      // Ask again; Android shows the "Allow all the time" option.
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.always || permission == LocationPermission.whileInUse;
  }

  Future<void> start() async {
    if (_running) return;
    final allowed = await _ensurePermission();
    if (!allowed) return;

    _running = true;
    await _sendCurrent(await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    ));

    // Prefer streaming updates; allows better route reconstruction.
    _sub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 25,
      ),
    ).listen((pos) => _sendCurrent(pos));
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
    _running = false;
  }

  Future<void> _sendCurrent(Position pos) async {
    try {
      await _api.put('/rider/location', data: {
        'lat': pos.latitude,
        'lng': pos.longitude,
        'recorded_at': pos.timestamp.toIso8601String(),
        if (pos.accuracy.isFinite) 'accuracy_m': pos.accuracy,
        if (pos.speed.isFinite) 'speed_mps': pos.speed,
        if (pos.heading.isFinite) 'heading_deg': pos.heading,
      });
    } catch (_) {
      // Ignore transient GPS/network errors.
    }
  }

  void dispose() => stop();
}
