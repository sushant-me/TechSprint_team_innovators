import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

class EarthquakeApiService {
  static const String _baseUrl =
      "https://earthquake.usgs.gov/fdsnws/event/1/query";

  Future<bool> verifyEarthquakeNearby() async {
    try {
      Position pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.low);
      String startTime =
          DateTime.now().subtract(const Duration(hours: 1)).toIso8601String();

      // Check for > Mag 3.0 within 100km in last hour
      String url =
          "$_baseUrl?format=geojson&starttime=$startTime&latitude=${pos.latitude}&longitude=${pos.longitude}&maxradiuskm=100&minmagnitude=3.0";

      final response =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List features = data['features'];
        return features.isNotEmpty;
      }
    } catch (e) {
      print("API ERROR: $e");
    }
    return false;
  }
}
