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

class _CountdownScreenState extends State<CountdownScreen> {
  late int _timeLeft;
  Timer? _timer;
  final SirenService _siren = SirenService();

  @override
  void initState() {
    super.initState();
    // Voice = Urgent (5s), Motion = Standard (15s)
    _timeLeft = (widget.triggerCause == "Voice") ? 5 : 15;
    _startTimer();
  }

  void _startTimer() {
    Vibration.vibrate(pattern: [500, 500], repeat: 1);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        if (_timeLeft > 0)
          _timeLeft--;
        else {
          _timer?.cancel();
          _goToSafetyCheck();
        }
      });
    });
  }

  void _goToSafetyCheck() {
    Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (context) =>
                SafetyCheckScreen(triggerCause: widget.triggerCause)));
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.red[900],
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.warning_amber_rounded,
                size: 80, color: Colors.white),
            const SizedBox(height: 20),
            Text("IMPACT DETECTED",
                style: const TextStyle(
                    fontSize: 28,
                    color: Colors.white,
                    fontWeight: FontWeight.bold)),
            Text("Cause: ${widget.triggerCause}",
                style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 40),

            CircularPercentIndicator(
              radius: 80.0,
              lineWidth: 12.0,
              percent: _timeLeft / ((widget.triggerCause == "Voice") ? 5 : 15),
              center: Text("$_timeLeft",
                  style: const TextStyle(
                      fontSize: 60,
                      color: Colors.white,
                      fontWeight: FontWeight.bold)),
              progressColor: Colors.white,
              backgroundColor: Colors.white24,
              circularStrokeCap: CircularStrokeCap.round,
            ),
            const SizedBox(height: 50),

            // FIXED: BIG BUTTON (NO SWIPE)
            SizedBox(
              width: 200,
              height: 70,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(35))),
                onPressed: _cancel,
                child: const Text("I AM SAFE",
                    style: TextStyle(
                        color: Colors.red,
                        fontSize: 22,
                        fontWeight: FontWeight.bold)),
              ),
            ),

            const SizedBox(height: 20),
            const Text("Do nothing to trigger SOS",
                style: TextStyle(color: Colors.white54)),
          ],
        ),
      ),
    );
  }
}
