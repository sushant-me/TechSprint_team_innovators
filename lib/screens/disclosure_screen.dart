import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For Haptics
import 'package:shared_preferences/shared_preferences.dart';
// import 'package:ghost_signal/main.dart'; // UNCOMMENT THIS IN YOUR REAL APP

// ---------------------------------------------------------------------------
// 1. MAIN SCREEN
// ---------------------------------------------------------------------------

class DisclosureScreen extends StatefulWidget {
  const DisclosureScreen({super.key});

  @override
  State<DisclosureScreen> createState() => _DisclosureScreenState();
}

class _DisclosureScreenState extends State<DisclosureScreen> with TickerProviderStateMixin {
  // Animation Controllers
  late AnimationController _scanController;
  late AnimationController _pulseController;
  late AnimationController _radarController;
  
  // State
  bool _isUnlocked = false;
  double _dragValue = 0.0;
  final double _sliderWidth = 300.0;
  String _headerText = "X_X_X_X"; 
  
  // Data
  final List<Map<String, dynamic>> _items = [
    {
      "icon": Icons.sensors,
      "title": "SENSOR_FUSION",
      "desc": "Access granted to accelerometer & gyroscope for kinetic impact analysis."
    },
    {
      "icon": Icons.gps_fixed,
      "title": "GEOSPATIAL_LOCK",
      "desc": "Active triangulation of coordinates during emergency protocols."
    },
    {
      "icon": Icons.graphic_eq,
      "title": "SPECTRUM_ANALYSIS",
      "desc": "Background environmental audio processing for distress patterns."
    },
  ];

  @override
  void initState() {
    super.initState();
    
    // Scanline (Fast vertical sweep)
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    // Pulse (Breathing UI elements)
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    // Radar (Slow rotation)
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    // Start Text Decoding
    _decodeTitle();
  }

  void _decodeTitle() async {
    String target = "SYSTEM PROTOCOLS";
    String chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890!@#\$%^&*";
    Random r = Random();
    
    // Simulate complex decoding
    for (int i = 0; i < target.length * 4; i++) {
      await Future.delayed(const Duration(milliseconds: 40));
      if (!mounted) return;
      setState(() {
        _headerText = List.generate(target.length, (index) {
          if (index < i / 4) return target[index];
          return chars[r.nextInt(chars.length)];
        }).join();
      });
    }
  }

  void _onSlideUpdate(DragUpdateDetails details) {
    if (_isUnlocked) return;
    setState(() {
      _dragValue = (_dragValue + details.delta.dx).clamp(0.0, _sliderWidth - 60);
    });
  }

  void _onSlideEnd(DragEndDetails details) async {
    if (_isUnlocked) return;
    
    // Threshold to unlock (85% of width)
    if (_dragValue > _sliderWidth - 80) {
      _unlockSystem();
    } else {
      // Snap back animation
      setState(() => _dragValue = 0.0);
    }
  }

  void _unlockSystem() async {
    setState(() {
      _dragValue = _sliderWidth - 60;
      _isUnlocked = true;
    });
    
    HapticFeedback.heavyImpact();
    
    // Save state
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_accepted_terms', true);

    // Dramatic pause before navigation
    await Future.delayed(const Duration(milliseconds: 1200));
    
    if (!mounted) return;
    
    // NAVIGATION PLACEHOLDER - Replace with your actual route
    // Navigator.of(context).pushReplacement(PageRouteBuilder(...));
    print("NAVIGATE TO DASHBOARD");
  }

  @override
  void dispose() {
    _scanController.dispose();
    _pulseController.dispose();
    _radarController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Cyberpunk Color Palette
    final primaryColor = _isUnlocked ? Colors.cyanAccent : const Color(0xFFFF2A68); // Neon Red/Pink
    final bgColor = const Color(0xFF050505);

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          // 1. ANIMATED RADAR BACKGROUND (Custom Painter)
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _radarController,
              builder: (context, child) {
                return CustomPaint(
                  painter: RadarGridPainter(
                    angle: _radarController.value * 2 * pi,
                    color: primaryColor.withOpacity(0.15),
                  ),
                );
              },
            ),
          ),

          // 2. FLOATING DATA PARTICLES
          Positioned.fill(
             child: const ParticleField(),
          ),

          // 3. SCANLINE OVERLAY (CRT Effect)
          AnimatedBuilder(
            animation: _scanController,
            builder: (context, child) {
              return Positioned(
                top: MediaQuery.of(context).size.height * _scanController.value,
                left: 0, right: 0,
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        primaryColor.withOpacity(0.5),
                        Colors.transparent
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                    boxShadow: [
                      BoxShadow(color: primaryColor.withOpacity(0.4), blurRadius: 20, spreadRadius: 1)
                    ],
                  ),
                ),
              );
            },
          ),

          // 4. MAIN UI CONTENT
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- HEADER ---
                  Row(
                    children: [
                      Icon(Icons.security, color: primaryColor, size: 28),
                      const SizedBox(width: 12),
                      GlitchText(
                        text: _headerText,
                        color: Colors.white,
                        size: 20,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 1,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [primaryColor, Colors.transparent]),
                    ),
                  ),
                  
                  const SizedBox(height: 30),

                  // --- LIST ITEMS ---
                  Expanded(
                    child: ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      itemCount: _items.length,
                      itemBuilder: (ctx, i) => _buildHoloCard(_items[i], i, primaryColor),
                    ),
                  ),
                  
                  // --- FOOTER ---
                  Center(
                    child: Text(
                      "INITIALIZING THIS PROTOCOL GRANTS HARDWARE LEVEL ACCESS",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.4), 
                        fontSize: 10, 
                        fontFamily: "monospace",
                        letterSpacing: 1.5
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // --- SLIDER ---
                  _buildTacticalSlider(primaryColor),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHoloCard(Map<String, dynamic> item, int index, Color color) {
    return TweenAnimationBuilder(
      duration: Duration(milliseconds: 600 + (index * 200)),
      tween: Tween<double>(begin: 0, end: 1),
      curve: Curves.easeOutBack,
      builder: (context, double val, child) {
        return Transform.translate(
          offset: Offset(50 * (1 - val), 0), // Slide in from right
          child: Opacity(
            opacity: val.clamp(0.0, 1.0),
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 24),
        child: Stack(
          children: [
            // Glowing border container
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF0A0A0A),
                border: Border(
                  left: BorderSide(color: color, width: 3),
                  bottom: BorderSide(color: Colors.white.withOpacity(0.1), width: 1),
                ),
                boxShadow: [
                  BoxShadow(color: color.withOpacity(0.05), blurRadius: 15, offset: const Offset(5, 5))
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(item['icon'], color: color.withOpacity(0.8), size: 24),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['title'], 
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9), 
                            fontWeight: FontWeight.bold, 
                            fontFamily: "monospace",
                            letterSpacing: 1.1
                          )
                        ),
                        const SizedBox(height: 6),
                        Text(
                          item['desc'], 
                          style: TextStyle(color: Colors.grey[500], fontSize: 13, height: 1.4)
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),
            // Decorative corner tick
            Positioned(
              top: 0, right: 0,
              child: Container(
                width: 10, height: 10,
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: color, width: 2),
                    right: BorderSide(color: color, width: 2),
                  )
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildTacticalSlider(Color primaryColor) {
    return Center(
      child: Container(
        width: _sliderWidth,
        height: 64,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: _isUnlocked ? primaryColor : Colors.white12),
          boxShadow: [
            if (_isUnlocked) BoxShadow(color: primaryColor.withOpacity(0.6), blurRadius: 30)
          ]
        ),
        child: Stack(
          children: [
            // Background Striped Pattern
            Positioned.fill(
              child: CustomPaint(
                painter: StripePatternPainter(color: Colors.white.withOpacity(0.03)),
              ),
            ),

            // Background Text with Pulse
            Center(
              child: AnimatedOpacity(
                opacity: _isUnlocked ? 0 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Text(
                      "SLIDE TO INITIALIZE >>",
                      style: TextStyle(
                        color: primaryColor.withOpacity(0.4 + (_pulseController.value * 0.4)),
                        letterSpacing: 3,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        fontFamily: "monospace"
                      ),
                    );
                  },
                ),
              ),
            ),
            
            // Success Text
            if (_isUnlocked)
              Center(
                child: GlitchText(
                  text: "ACCESS GRANTED",
                  color: Colors.black, // Dark text on bright background
                  size: 16,
                ),
              ),

            // The Handle
            AnimatedPositioned(
              duration: const Duration(milliseconds: 100),
              curve: Curves.easeOut,
              left: _dragValue,
              top: 4, bottom: 4,
              child: GestureDetector(
                onHorizontalDragUpdate: _onSlideUpdate,
                onHorizontalDragEnd: _onSlideEnd,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 56,
                  decoration: BoxDecoration(
                    color: primaryColor,
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: [
                      BoxShadow(color: primaryColor.withOpacity(0.5), blurRadius: 10, spreadRadius: 1)
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      _isUnlocked ? Icons.lock_open : Icons.chevron_right,
                      color: _isUnlocked ? Colors.black : Colors.white,
                      size: 28,
                    ),
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 2. HELPER WIDGETS & PAINTERS (The "Wow" Factor)
// ---------------------------------------------------------------------------

// A. Glitch Text Effect (Chromatic Aberration)
class GlitchText extends StatelessWidget {
  final String text;
  final Color color;
  final double size;

  const GlitchText({super.key, required this.text, required this.color, this.size = 20});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Cyan Offset
        Transform.translate(
          offset: const Offset(-1, -1),
          child: Text(text, style: TextStyle(color: Colors.cyanAccent.withOpacity(0.7), fontSize: size, fontFamily: "monospace", fontWeight: FontWeight.bold, letterSpacing: 2)),
        ),
        // Red Offset
        Transform.translate(
          offset: const Offset(1, 1),
          child: Text(text, style: TextStyle(color: Colors.redAccent.withOpacity(0.7), fontSize: size, fontFamily: "monospace", fontWeight: FontWeight.bold, letterSpacing: 2)),
        ),
        // Main Text
        Text(text, style: TextStyle(color: color, fontSize: size, fontFamily: "monospace", fontWeight: FontWeight.bold, letterSpacing: 2)),
      ],
    );
  }
}

// B. Radar Grid Background Painter
class RadarGridPainter extends CustomPainter {
  final double angle;
  final Color color;

  RadarGridPainter({required this.angle, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.height * 0.6;
    final Paint paint = Paint()
      ..color = color.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Draw concentric circles
    for (int i = 1; i <= 4; i++) {
      canvas.drawCircle(center, radius * (i / 4), paint);
    }

    // Draw crosshairs
    canvas.drawLine(Offset(center.dx - radius, center.dy), Offset(center.dx + radius, center.dy), paint);
    canvas.drawLine(Offset(center.dx, center.dy - radius), Offset(center.dx, center.dy + radius), paint);

    // Draw Sweep
    final Paint sweepPaint = Paint()
      ..shader = SweepGradient(
        center: Alignment.center,
        startAngle: 0.0,
        endAngle: pi * 2,
        colors: [Colors.transparent, color.withOpacity(0.3)],
        stops: const [0.5, 1.0],
        transform: GradientRotation(angle),
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, sweepPaint);
  }

  @override
  bool shouldRepaint(covariant RadarGridPainter oldDelegate) => oldDelegate.angle != angle;
}

// C. Background Stripe Pattern for Slider
class StripePatternPainter extends CustomPainter {
  final Color color;
  StripePatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..strokeWidth = 2;
    for (double i = 0; i < size.width; i += 10) {
      canvas.drawLine(Offset(i, size.height), Offset(i + 10, 0), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// D. Floating Particle Field
class ParticleField extends StatefulWidget {
  const ParticleField({super.key});
  @override
  State<ParticleField> createState() => _ParticleFieldState();
}

class _ParticleFieldState extends State<ParticleField> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<Particle> _particles = [];
  final Random _rng = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat();
    for(int i=0; i<30; i++) {
      _particles.add(Particle(_rng));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: ParticlePainter(_particles, _controller.value),
        );
      },
    );
  }
}

class Particle {
  double x = 0;
  double y = 0;
  double speed = 0;
  double opacity = 0;
  
  Particle(Random rng) {
    _reset(rng);
  }

  void _reset(Random rng) {
    x = rng.nextDouble();
    y = rng.nextDouble();
    speed = 0.001 + rng.nextDouble() * 0.002;
    opacity = 0.1 + rng.nextDouble() * 0.4;
  }

  void update() {
    y -= speed;
    if (y < 0) {
      y = 1.0;
      x = Random().nextDouble();
    }
  }
}

class ParticlePainter extends CustomPainter {
  final List<Particle> particles;
  final double animValue;

  ParticlePainter(this.particles, this.animValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white;
    for (var particle in particles) {
      particle.update(); // Update position
      paint.color = Colors.white.withOpacity(particle.opacity);
      canvas.drawCircle(Offset(particle.x * size.width, particle.y * size.height), 1.5, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
