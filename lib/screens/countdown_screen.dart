import 'dart:async';
import 'package:flutter/material.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:vibration/vibration.dart';
import 'package:ghostsignal/screens/safety_check_screen.dart';
import 'package:ghostsignal/services/siren_service.dart';

class CountdownScreen extends StatefulWidget {
  final String triggerCause;
  const CountdownScreen({super.key, this.triggerCause = "Manual"});

  @override
  State<CountdownScreen> createState() => _CountdownScreenState();
}

class _CountdownScreenState extends State<CountdownScreen> with TickerProviderStateMixin {
  late int _timeLeft;
  late int _totalTime;
  Timer? _timer;
  final SirenService _siren = SirenService();
  
  // Animation for the pulsing background effect
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _totalTime = (widget.triggerCause == "Voice") ? 5 : 15;
    _timeLeft = _totalTime;
    
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _startTimer();
  }

  void _startTimer() {
    // Continuous vibration pattern for urgency
    Vibration.vibrate(pattern: [0, 500, 200, 500], repeat: 0);
    
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        if (_timeLeft > 0) {
          _timeLeft--;
        } else {
          _timer?.cancel();
          _goToSafetyCheck();
        }
      });
    });
  }

  void _goToSafetyCheck() {
    Vibration.cancel();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => SafetyCheckScreen(triggerCause: widget.triggerCause),
      ),
    );
  }

  void _cancel() {
    _timer?.cancel();
    Vibration.cancel();
    _siren.stopSiren();
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    Vibration.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Animated background for high urgency
      body: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  Color.lerp(Colors.red[900], Colors.black, _pulseController.value)!,
                  Colors.red[900]!,
                ],
                radius: 1.5,
              ),
            ),
            child: child,
          );
        },
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.warning_amber_rounded, size: 100, color: Colors.white),
              const SizedBox(height: 10),
              const Text(
                "EMERGENCY SIGNAL",
                style: TextStyle(
                  fontSize: 32,
                  color: Colors.white,
                  fontWeight: FontWeight.black,
                  letterSpacing: 2,
                ),
              ),
              Text(
                "DETECTED VIA: ${widget.triggerCause.toUpperCase()}",
                style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 50),

              CircularPercentIndicator(
                radius: 110.0,
                lineWidth: 15.0,
                animation: true,
                animateFromLastPercent: true,
                percent: _timeLeft / _totalTime,
                center: Text(
                  "$_timeLeft",
                  style: const TextStyle(
                    fontSize: 80,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                progressColor: _timeLeft <= 3 ? Colors.orange : Colors.white,
                backgroundColor: Colors.white10,
                circularStrokeCap: CircularStrokeCap.round,
              ),
              
              const SizedBox(height: 60),

              // IMPROVED: Hold to Cancel (Prevents accidental stop)
              GestureDetector(
                onLongPress: _cancel,
                child: Container(
                  width: 250,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(40),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      )
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      "HOLD TO CANCEL",
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 30),
              const Text(
                "SOS will trigger automatically",
                style: TextStyle(color: Colors.white54, fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
