import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:vibration/vibration.dart';
// import 'package:ghostsignal/screens/safety_check_screen.dart'; // Uncomment in real app
// import 'package:ghostsignal/services/siren_service.dart';      // Uncomment in real app

// --- MOCK SERVICES FOR DEMO ---
class SafetyCheckScreen extends StatelessWidget {
  final String triggerCause;
  const SafetyCheckScreen({super.key, required this.triggerCause});
  @override Widget build(BuildContext context) => const Scaffold(backgroundColor: Colors.black, body: Center(child: Text("SAFETY CHECK", style: TextStyle(color: Colors.green))));
}
class SirenService {
  void startSiren() { print("WEE-WOO-WEE-WOO"); }
  void stopSiren() { print("Siren Silenced"); }
}
// ------------------------------

class CountdownScreen extends StatefulWidget {
  final String triggerCause;
  const CountdownScreen({super.key, this.triggerCause = "Manual"});

  @override
  State<CountdownScreen> createState() => _CountdownScreenState();
}

class _CountdownScreenState extends State<CountdownScreen> with TickerProviderStateMixin {
  // Logic
  late int _timeLeft;
  late int _totalTime;
  Timer? _timer;
  final SirenService _siren = SirenService();
  
  // Animation Controllers
  late AnimationController _pulseController;  // The background strobe
  late AnimationController _abortController;  // The "Hold to Cancel" progress
  late AnimationController _shakeController;  // Text shake effect

  @override
  void initState() {
    super.initState();
    _totalTime = (widget.triggerCause == "Voice") ? 5 : 15;
    _timeLeft = _totalTime;
    
    // 1. Strobe Light Animation (Heartbeat speed)
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    // 2. Abort Button Logic
    _abortController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000), // 2 seconds to cancel
    )..addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _cancel();
      }
    });

    // 3. Shake/Glitch Effect
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    )..repeat(reverse: true);

    _startEmergencySequence();
  }

  void _startEmergencySequence() {
    _siren.startSiren();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      
      setState(() {
        if (_timeLeft > 0) {
          _timeLeft--;
          
          // ESCALATION LOGIC: Speed up animations as time drops
          if (_timeLeft <= 5) {
            _pulseController.duration = const Duration(milliseconds: 300); // Panic mode
            _pulseController.repeat(reverse: true);
            HapticFeedback.heavyImpact(); // Heavy thud every second
          } else if (_timeLeft <= 10) {
             _pulseController.duration = const Duration(milliseconds: 600);
             _pulseController.repeat(reverse: true);
             HapticFeedback.mediumImpact();
          }
          
        } else {
          _triggerSOS();
        }
      });
    });
  }

  void _triggerSOS() {
    _timer?.cancel();
    Vibration.cancel(); // Stop vibrating
    // Navigate to next screen
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => SafetyCheckScreen(triggerCause: widget.triggerCause)),
    );
  }

  void _onAbortDown(TapDownDetails details) {
    _abortController.forward();
    HapticFeedback.selectionClick();
  }

  void _onAbortUp(TapUpDetails details) {
    if (_abortController.status != AnimationStatus.completed) {
      _abortController.reverse();
    }
  }

  void _onAbortCancel() {
    _abortController.reverse();
  }

  void _cancel() {
    _timer?.cancel();
    _siren.stopSiren();
    Vibration.cancel();
    HapticFeedback.vibrate();
    
    // Smooth exit
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    _abortController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        alignment: Alignment.center,
        children: [
          // 1. DYNAMIC STROBE BACKGROUND
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              // Color shifts from Dark Red to Bright Red
              Color strobeColor = Color.lerp(
                const Color(0xFF220000), 
                const Color(0xFFB71C1C), 
                _pulseController.value
              )!;
              
              return Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1.2 + (_pulseController.value * 0.2), // Radius expands
                    colors: [strobeColor, Colors.black],
                    stops: const [0.2, 1.0],
                  ),
                ),
              );
            },
          ),
          
          // 2. DANGER STRIPES OVERLAY (Subtle texture)
          Positioned.fill(
            child: Opacity(
              opacity: 0.1,
              child: RepeatingLinearGradient(
                 begin: Alignment.topLeft,
                 end: Alignment.bottomRight,
                 colors: const [Colors.transparent, Colors.transparent, Colors.black, Colors.black],
                 stops: const [0, 0.9, 0.9, 1],
              ),
            ),
          ),

          // 3. MAIN CONTENT
          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // HEADER
                Column(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 60),
                    const SizedBox(height: 10),
                    _buildGlitchText("EMERGENCY PROTOCOL"),
                    Text(
                      "TRIGGER: ${widget.triggerCause.toUpperCase()}", 
                      style: const TextStyle(color: Colors.white54, fontFamily: 'monospace')
                    ),
                  ],
                ),

                // GIANT COUNTDOWN
                _buildCountdownDial(),

                // ABORT MECHANISM
                _buildAbortButton(),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildCountdownDial() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Outer pulsing rings
        ...List.generate(3, (index) {
          return AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              double opacity = (1 - _pulseController.value) * (1 / (index + 1));
              return Container(
                width: 200 + (index * 30.0) * _pulseController.value,
                height: 200 + (index * 30.0) * _pulseController.value,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.red.withOpacity(opacity), width: 2),
                ),
              );
            },
          );
        }),
        
        // The Percent Indicator
        CircularPercentIndicator(
          radius: 100.0,
          lineWidth: 12.0,
          percent: _timeLeft / _totalTime,
          circularStrokeCap: CircularStrokeCap.round,
          backgroundColor: Colors.white10,
          progressColor: _timeLeft <= 3 ? Colors.white : Colors.redAccent, // Turns white hot at end
          animation: true,
          animateFromLastPercent: true,
          center: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
               Text(
                "$_timeLeft",
                style: const TextStyle(
                  fontSize: 80, 
                  fontWeight: FontWeight.w900, 
                  color: Colors.white, 
                  fontFamily: 'monospace',
                  height: 1.0,
                ),
              ),
              const Text("SECONDS", style: TextStyle(color: Colors.white54, fontSize: 10, letterSpacing: 2))
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAbortButton() {
    return Column(
      children: [
        const Text("MISTAKE? HOLD TO ABORT", style: TextStyle(color: Colors.white38, letterSpacing: 1, fontSize: 10)),
        const SizedBox(height: 10),
        GestureDetector(
          onTapDown: _onAbortDown,
          onTapUp: _onAbortUp,
          onTapCancel: _onAbortCancel,
          child: AnimatedBuilder(
            animation: _abortController,
            builder: (context, child) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  // Base Button
                  Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white10,
                      border: Border.all(color: Colors.white30),
                    ),
                    child: const Icon(Icons.close, color: Colors.white, size: 30),
                  ),
                  
                  // Filling Indicator
                  SizedBox(
                    width: 80, height: 80,
                    child: CircularProgressIndicator(
                      value: _abortController.value,
                      strokeWidth: 4,
                      valueColor: const AlwaysStoppedAnimation(Colors.greenAccent),
                    ),
                  ),
                  
                  // Glow Effect when holding
                  if (_abortController.isAnimating)
                    Container(
                      width: 90, height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: Colors.greenAccent.withOpacity(0.5), blurRadius: 20, spreadRadius: 2)
                        ]
                      ),
                    )
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildGlitchText(String text) {
    return AnimatedBuilder(
      animation: _shakeController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_timeLeft < 5 ? sin(_shakeController.value * 10) * 2 : 0, 0), // Shake only near end
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white, 
              fontSize: 24, 
              fontWeight: FontWeight.black, 
              letterSpacing: 3
            ),
          ),
        );
      },
    );
  }
}

// Utility for stripes
class RepeatingLinearGradient extends ImageShader {
  RepeatingLinearGradient({
    required Alignment begin,
    required Alignment end,
    required List<Color> colors,
    required List<double> stops,
  }) : super(
          Image.asset('assets/stripes.png').image, // Fallback or use CustomPainter for real stripes
          TileMode.repeated,
          TileMode.repeated,
          Float64List.fromList([]),
        ); 
}
