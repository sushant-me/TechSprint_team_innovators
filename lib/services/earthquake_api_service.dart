import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart'; // For debugPrint

/// Comprehensive data model for a seismic event
class SeismicEvent {
  final double magnitude;
  final String place;
  final double depthKm;
  final DateTime time;
  final double distanceFromUserKm;
  final String source; // 'USGS', 'EMSC', or 'SIMULATION'

  SeismicEvent({
    required this.magnitude,
    required this.place,
    required this.depthKm,
    required this.time,
    required this.distanceFromUserKm,
    required this.source,
  });

  // Risk Calculation: Is this event dangerous enough to trigger the app?
  bool get isCritical => magnitude >= 5.0 || (magnitude >= 4.0 && distanceFromUserKm < 50);

  @override
  String toString() => "⚠️ MAG $magnitude | ${distanceFromUserKm.toStringAsFixed(1)}km away | Depth: ${depthKm}km";
}

class EarthquakeApiService {
  // --- CONFIGURATION ---
  static const String _usgsUrl = "https://earthquake.usgs.gov/fdsnws/event/1/query";
  static const int _searchRadiusKm = 200; // Search wide
  static const double _minMagnitude = 3.5; // Filter minor tremors
  static const Duration _cacheDuration = Duration(minutes: 5); 

  // --- STATE ---
  SeismicEvent? _cachedEvent;
  DateTime? _lastFetchTime;

  /// Main entry point.
  /// [simulate] : If true, returns a fake critical event for UI testing.
  Future<SeismicEvent?> verifyEarthquakeNearby({bool simulate = false}) async {
    // 1. SIMULATION MODE (For Dev/Demo)
    if (simulate) {
      debugPrint("⚡ SEISMIC: Simulating Critical Event...");
      return SeismicEvent(
        magnitude: 6.2, 
        place: "Simulated Epicenter, San Andreas", 
        depthKm: 12.5, 
        time: DateTime.now(), 
        distanceFromUserKm: 15.0, 
        source: 'SIMULATION'
      );
    }

    // 2. CACHE CHECK (The Fix: Check time, not just if event exists)
    if (_lastFetchTime != null && 
        DateTime.now().difference(_lastFetchTime!) < _cacheDuration) {
      debugPrint("⚡ SEISMIC: Using cached data (Last check: ${_lastFetchTime?.minute}m ago).");
      return _cachedEvent; 
    }

    try {
      // 3. PERMISSION & LOCATION CHECK
      // Note: Geolocator throws if permission denied. We handle this safely.
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint("❌ SEISMIC: Location services disabled.");
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }

      Position userPos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium // Save battery, we don't need meter precision
      );

      // 4. FETCH DATA
      var event = await _fetchFromUSGS(userPos);
      
      // 5. UPDATE CACHE (Even if null, so we don't spam API)
      _cachedEvent = event;
      _lastFetchTime = DateTime.now();
      
      return event;

    } catch (e) {
      debugPrint("❌ SEISMIC FAILURE: $e");
      return null;
    }
  }

  /// PRIMARY INTEL SOURCE: USGS
  Future<SeismicEvent?> _fetchFromUSGS(Position pos) async {
    // Look back 1 hour. Earthquakes are irrelevant if they happened yesterday.
    String startTime = DateTime.now().subtract(const Duration(hours: 1)).toIso8601String();
    
    final Uri uri = Uri.parse(_usgsUrl).replace(queryParameters: {
      'format': 'geojson',
      'starttime': startTime,
      'latitude': pos.latitude.toString(),
      'longitude': pos.longitude.toString(),
      'maxradiuskm': _searchRadiusKm.toString(),
      'minmagnitude': _minMagnitude.toString(),
      'orderby': 'magnitude', // Get the biggest threat first
      'limit': '1' 
    });

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List features = data['features'];

        if (features.isNotEmpty) {
          final props = features[0]['properties'];
          final geometry = features[0]['geometry'];
          final coords = geometry['coordinates']; // [long, lat, depth]

          // Calculate precise distance using Haversine formula (built-in to Geolocator)
          double dist = Geolocator.distanceBetween(
            pos.latitude, pos.longitude, 
            (coords[1] as num).toDouble(), 
            (coords[0] as num).toDouble()
          ) / 1000; // convert meters to km

          debugPrint("⚡ USGS: Earthquake found $dist km away.");

          return SeismicEvent(
            magnitude: (props['mag'] as num).toDouble(),
            place: props['place'] ?? "Unknown Location",
            time: DateTime.fromMillisecondsSinceEpoch(props['time']),
            depthKm: (coords[2] as num).toDouble(),
            distanceFromUserKm: dist,
            source: 'USGS',
          );
        } else {
          debugPrint("✅ USGS: No recent seismic activity in range.");
        }
      }
    } catch (e) {
      debugPrint("⚠️ USGS Connection Error: $e");
    }
    return null;
  }
}
