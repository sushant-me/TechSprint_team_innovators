import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

class MotionDetector {
  // CONFIGURATION
  // Drop Threshold: Near 0 means weightlessness (Free Fall)
  static const double freeFallThreshold = 3.0;
  // Impact Threshold: The sudden stop (The Crash)
  static const double impactThreshold = 20.0;

  StreamSubscription? _accelSubscription;
  bool _isMonitoring = false;
  bool _possibleFallDetected = false;
  Timer? _impactWindowTimer;

  // The function to call when Fall is CONFIRMED
  final VoidCallback onFallDetected;

  MotionDetector({required this.onFallDetected});

  void startMonitoring() {
    if (_isMonitoring) return;

    // Listen to the Raw Accelerometer (Includes Gravity)
    _accelSubscription = accelerometerEvents.listen((AccelerometerEvent event) {
      // Calculate total G-Force magnitude
      // Formula: √(x² + y² + z²)
      double gForce = sqrt(pow(event.x, 2) + pow(event.y, 2) + pow(event.z, 2));

      _analyzePhysics(gForce);
    });

    _isMonitoring = true;
    print("GHOST SIGNAL GRAVITY: Monitoring for falls...");
  }

  void _analyzePhysics(double gForce) {
    // STAGE 1: DETECT FREE FALL (The Drop)
    if (gForce < freeFallThreshold && !_possibleFallDetected) {
      print("GRAVITY: Free fall detected! ($gForce m/s²)");
      _possibleFallDetected = true;

      // We give the phone 1 second to hit the ground
      _impactWindowTimer?.cancel();
      _impactWindowTimer = Timer(const Duration(seconds: 1), () {
        // If 1 second passes and no impact, reset (False Alarm)
        _possibleFallDetected = false;
        print("GRAVITY: Reset (No impact detected).");
      });
    }

    // STAGE 2: DETECT IMPACT (The Crash)
    if (_possibleFallDetected && gForce > impactThreshold) {
      print("GRAVITY: IMPACT CONFIRMED! ($gForce m/s²)");

      // STOP everything and trigger alarm
      _possibleFallDetected = false;
      _impactWindowTimer?.cancel();
      stopMonitoring(); // Stop so we don't trigger twice

      onFallDetected(); // FIRE THE ALARM
    }
  }

  void stopMonitoring() {
    _accelSubscription?.cancel();
    _impactWindowTimer?.cancel();
    _isMonitoring = false;
  }
}
