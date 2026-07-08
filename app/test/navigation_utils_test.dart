import 'package:flutter_test/flutter_test.dart';
import 'package:prorider_rider_app/utils/navigation.dart';

void main() {
  test('builds google navigation and fallback web URL', () {
    const lat = 31.5204;
    const lng = 74.3587;

    final native = NavigationUtils.googleNavigationUri(lat: lat, lng: lng);
    final web = NavigationUtils.webDirectionsUri(lat: lat, lng: lng);

    expect(native.toString(), 'google.navigation:q=$lat,$lng');
    expect(web.toString(), 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
  });
}

