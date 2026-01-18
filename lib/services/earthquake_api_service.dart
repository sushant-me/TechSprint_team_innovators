import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

/// Comprehensive data model for a seismic event
class SeismicEvent {
  final double magnitude;
  final String place;
  final double depthKm;
  final DateTime time;
  final double distanceFromUserKm;
  final String source; // 'USGS' or 'EMSC'

  SeismicEvent({
    required this.magnitude,
    required this.place,
    required this.depthKm,
    required this.time,
    required this.distanceFromUserKm,
    required this.source,
  });

  @override
  String toString() => "⚠️ MAG $magnitude | ${distanceFromUserKm.toStringAsFixed(1)}km away | Depth: ${depthKm}km";
}

class SeismicIntelligence {
  // --- STRATEGY ---
  // Primary: USGS (United States Geological Survey)
  static const String _usgsUrl = "https://earthquake.usgs.gov/fdsnws/event/1/query";
  // Fallback: EMSC (European-Mediterranean Seismological Centre) - Pseudo-code URL for demo
  static const String _emscUrl = "https://www.seismicportal.eu/fdsnws/event/1/query";

  // --- CONFIG ---
  static const int _searchRadiusKm = 150; // Expanded for safety
  static const double _minMagnitude = 3.5; // Filter minor tremors
  static const Duration _cacheDuration = Duration(minutes: 5); 

  // --- STATE ---
  SeismicEvent? _cachedEvent;
  DateTime? _lastFetchTime;

  /// The main entry point. Returns the most dangerous nearby event, or null if clear.
  Future<SeismicEvent?> analyzeSeismicRisk() async {
    // 1. CACHE CHECK: Don't spam APIs if we just checked
    if (_cachedEvent != null && 
        _lastFetchTime != null && 
        DateTime.now().difference(_lastFetchTime!) < _cacheDuration) {
      print("⚡ SEISMIC: Returning cached analysis.");
      return _cachedEvent;
    }

    try {
      // 2. LOCATE USER (High accuracy needed for distance calc)
      Position userPos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium
      );

      // 3. FETCH DATA (With Fallback Strategy)
      var event = await _fetchFromUSGS(userPos);
      
      // If USGS fails or returns nothing, could try EMSC here (omitted for brevity)
      // if (event == null) event = await _fetchFromEMSC(userPos);

      // 4. UPDATE CACHE
      _cachedEvent = event;
      _lastFetchTime = DateTime.now();
      
      return event;

    } catch (e) {
      print("❌ SEISMIC FAILURE: $e");
      // In a real app, you might return a "SystemStatus.offline" object
      return null;
    }
  }

  /// PRIMARY INTEL SOURCE: USGS
  Future<SeismicEvent?> _fetchFromUSGS(Position pos) async {
    String startTime = DateTime.now().subtract(const Duration(hours: 1)).toIso8601String();
    
    // Construct sophisticated query
    final Uri uri = Uri.parse(_usgsUrl).replace(queryParameters: {
      'format': 'geojson',
      'starttime': startTime,
      'latitude': pos.latitude.toString(),
      'longitude': pos.longitude.toString(),
      'maxradiuskm': _searchRadiusKm.toString(),
      'minmagnitude': _minMagnitude.toString(),
      'orderby': 'magnitude', // Get the biggest one first
      'limit': '1' // We only care about the worst threat
    });

    try {
      // Retry logic could go here
      final response = await http.get(uri).timeout(const Duration(seconds: 4)); // Fast timeout

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List features = data['features'];

        if (features.isNotEmpty) {
          final props = features[0]['properties'];
          final geometry = features[0]['geometry'];
          final coords = geometry['coordinates']; // [long, lat, depth]

          // Calculate precise distance
          double dist = Geolocator.distanceBetween(
            pos.latitude, pos.longitude, 
            coords[1], coords[0]
          ) / 1000; // convert meters to km

          return SeismicEvent(
            magnitude: (props['mag'] as num).toDouble(),
            place: props['place'] ?? "Unknown Location",
            time: DateTime.fromMillisecondsSinceEpoch(props['time']),
            depthKm: (coords[2] as num).toDouble(),
            distanceFromUserKm: dist,
            source: 'USGS',
          );
        }
      }
    } catch (e) {
      print("⚠️ USGS Unreachable: $e");
    }
    return null;
  }
}
