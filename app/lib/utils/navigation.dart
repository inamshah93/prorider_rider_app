import 'dart:io';

import 'package:url_launcher/url_launcher.dart';

class NavigationUtils {
  NavigationUtils._();

  static Uri googleNavigationUri({required double lat, required double lng}) {
    // Android supports the native scheme in Google Maps.
    // https://developers.google.com/maps/documentation/urls/android-intents
    return Uri.parse('google.navigation:q=$lat,$lng');
  }

  static Uri webDirectionsUri({required double lat, required double lng}) {
    return Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
  }

  static Future<bool> openExternalNavigation({required double lat, required double lng}) async {
    final native = googleNavigationUri(lat: lat, lng: lng);
    final web = webDirectionsUri(lat: lat, lng: lng);

    if (Platform.isAndroid && await canLaunchUrl(native)) {
      return launchUrl(native, mode: LaunchMode.externalApplication);
    }

    if (await canLaunchUrl(web)) {
      return launchUrl(web, mode: LaunchMode.externalApplication);
    }

    return false;
  }
}

