import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

// --- DATA MODEL ---
class FallEvent {
  final double impactForce;
  final DateTime time;
  final String confidence; // "High", "Medium"

  FallEvent(this.impactForce, this.time, this.confidence);
}

class GravityGuard {
  // --- CONFIGURATION (Physics Constants) ---
  static const double _gravity = 9.81;
  
  // 1. Free Fall: Near 0g (User is falling)
  static const double _threshFreeFall = 2.0; 
  
  // 2. Impact: Sudden stop (Phone hits ground)
  static const double _threshImpact = 18.0; 
  
  // 3. Immobility: User isn't moving after fall
  static const double _threshMotionless = 1.5; 
  static const int _immobilityDurationSec = 3;

  // --- STATE ---
  StreamSubscription? _accelSubscription;
  final StreamController<double> _telemetryController = StreamController.broadcast();
  final StreamController<FallEvent> _fallController = StreamController.broadcast();

  // Public Streams (Connect your UI here!)
  Stream<double> get liveGForce => _telemetryController.stream;
  Stream<FallEvent> get onFallConfirmed => _fallController.stream;

  // Logic Flags
  bool _isArmed = false;
  bool _possibleFreeFall = false;
  DateTime? _freeFallTime;
  Timer? _immobilityTimer;

  /// Starts the Physics Engine
  void armSystem() {
    if (_isArmed) return;
    _isArmed = true;

    // We use UserAccelerometer to ignore constant gravity, 
    // OR standard Accelerometer to detect Free Fall (where G goes to 0).
    // Standard Accelerometer is BEST for Free Fall detection.
    _accelSubscription = accelerometerEvents.listen((event) {
      _processPhysicsFrame(event);
    });
    
    debugPrint("🛡️ GRAVITY GUARD: ARMING SYSTEM...");
  }

  void _processPhysicsFrame(AccelerometerEvent event) {
    // 1. Calculate Magnitude (Total G-Force)
    // Formula: √(x² + y² + z²)
    double rawG = sqrt(pow(event.x, 2) + pow(event.y, 2) + pow(event.z, 2));

    // 2. Telemetry Stream (For UI "Seismograph")
    // We limit updates to prevent UI lag
    _telemetryController.add(rawG);

    // --- PHASE 1: FREE FALL DETECTION ---
    if (rawG < _threshFreeFall) {
      if (!_possibleFreeFall) {
        _possibleFreeFall = true;
        _freeFallTime = DateTime.now();
        debugPrint("📉 PHYSICS: Weightlessness Detected (Free Fall)");
      }
    }

    // --- PHASE 2: IMPACT DETECTION ---
    if (_possibleFreeFall) {
      // Check if this impact happened within 1 second of free fall
      if (DateTime.now().difference(_freeFallTime!).inMilliseconds > 1000) {
        _possibleFreeFall = false; // Too long, probably just handling the phone
        return;
      }

      if (rawG > _threshImpact) {
        debugPrint("💥 PHYSICS: High Impact Detected ($rawG m/s²)");
        _initiateImmobilityCheck(rawG);
        _possibleFreeFall = false; // Reset for next time
      }
    }
  }

  // --- PHASE 3: IMMOBILITY CHECK (The "Wow" Factor) ---
  // If the user picks up the phone immediately, it was likely a drop, not a fall.
  // If the sensor stays flat/quiet, the user might be unconscious.
  void _initiateImmobilityCheck(double impactForce) {
    debugPrint("⏳ PHYSICS: Verifying Immobility...");
    
    // Cancel any existing check
    _immobilityTimer?.cancel();
    
    // Pause briefly to let the physics settle (bouncing phone)
    Future.delayed(const Duration(seconds: 1), () {
      
      // Monitor for 3 seconds
      List<double> postCrashValues = [];
      StreamSubscription? motionMonitor;
      
      motionMonitor = accelerometerEvents.listen((e) {
         double g = sqrt(pow(e.x, 2) + pow(e.y, 2) + pow(e.z, 2));
         postCrashValues.add(g);
      });

      _immobilityTimer = Timer(Duration(seconds: _immobilityDurationSec), () {
        motionMonitor?.cancel();
        _analyzePostCrashMotion(postCrashValues, impactForce);
      });
    });
  }

  void _analyzePostCrashMotion(List<double> values, double originalImpact) {
    if (values.isEmpty) return;

    // Calculate Variance (How much is it moving?)
    // In a resting state (on floor), G should be stable ~9.8
    double sum = values.reduce((a, b) => a + b);
    double avg = sum / values.length;
    
    // Calculate Deviation
    double variance = values.map((v) => pow(v - avg, 2)).reduce((a, b) => a + b) / values.length;
    
    debugPrint("📊 POST-CRASH VARIANCE: $variance");

    if (variance < _threshMotionless) {
      // LOW VARIANCE = Victim is not moving
      debugPrint("🚨 FALL CONFIRMED: Victim is stationary.");
      _fallController.add(FallEvent(originalImpact, DateTime.now(), "High"));
    } else {
      // HIGH VARIANCE = User picked up the phone / walked away
      debugPrint("✅ FALSE ALARM: User resumed motion.");
    }
  }

  void disarm() {
    _isArmed = false;
    _accelSubscription?.cancel();
    _immobilityTimer?.cancel();
    _telemetryController.close();
    _fallController.close();
    debugPrint("🛡️ GRAVITY GUARD: DISARMED");
  }
}
