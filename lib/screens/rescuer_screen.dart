import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// --- MODELS ---
class TargetNode {
  final String id;
  double angle; // Radians
  double distance; // 0.0 to 1.0
  final String status;
  final int heartRate;
  final int battery;
  Offset? currentOffset; // Cached for painting

  TargetNode({
    required this.id,
    required this.angle,
    required this.distance,
    required this.status,
    required this.heartRate,
    required this.battery,
  });
}

// --- MAIN SCREEN ---
class RescuerScreen extends StatefulWidget {
  const RescuerScreen({super.key});

  @override
  State<RescuerScreen> createState() => _RescuerScreenState();
}

class _RescuerScreenState extends State<RescuerScreen> with TickerProviderStateMixin {
  // Animation Controllers
  late AnimationController _radarController;
  late AnimationController _pulseController;
  late AnimationController _driftController;
  
  // State
  final ScrollController _terminalScroll = ScrollController();
  final List<String> _logs = [];
  String? _selectedTargetId;
  
  // Mock Data
  final List<TargetNode> _targets = [
    TargetNode(id: 'V-104', angle: 0.5, distance: 0.4, status: 'CRITICAL', heartRate: 140, battery: 12),
    TargetNode(id: 'V-209', angle: 3.8, distance: 0.7, status: 'STABLE', heartRate: 85, battery: 45),
    TargetNode(id: 'V-003', angle: 5.2, distance: 0.3, status: 'UNKNOWN', heartRate: 0, battery: 5),
    TargetNode(id: 'GHOST-X', angle: 1.2, distance: 0.8, status: 'HOSTILE', heartRate: 180, battery: 99),
  ];

  @override
  void initState() {
    super.initState();
    
    // 1. Radar Sweep (Continuous)
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    // 2. UI Pulse (Breathing)
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    // 3. Target Drift (Simulates organic movement)
    _driftController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);

    _addLog("SYSTEM_BOOT_SEQUENCE_INITIATED...");
    _addLog("LOADING_TACTICAL_OVERLAY... OK");
    _addLog("CONNECTING_TO_MESH... CONNECTED");
  }

  void _addLog(String msg) {
    if (!mounted) return;
    setState(() {
      _logs.add("[${DateTime.now().hour.toString().padLeft(2,'0')}:${DateTime.now().minute.toString().padLeft(2,'0')}:${DateTime.now().second.toString().padLeft(2,'0')}] $msg");
      if (_logs.length > 50) _logs.removeAt(0);
    });
    // Auto-scroll
    Future.delayed(const Duration(milliseconds: 50), () {
      if (_terminalScroll.hasClients) {
        _terminalScroll.animateTo(_terminalScroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  void _selectTarget(TargetNode target) {
    HapticFeedback.selectionClick();
    setState(() => _selectedTargetId = target.id);
    _addLog("TARGET_LOCK: ${target.id} [${(target.distance * 100).toInt()}M]");
  }

  @override
  void dispose() {
    _radarController.dispose();
    _pulseController.dispose();
    _driftController.dispose();
    _terminalScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Tactical Palette
    const Color hudColor = Color(0xFF00F0FF); // Cyan
    const Color alertColor = Color(0xFFFF2A2A); // Red
    const Color bgDark = Color(0xFF050A10); // Deep Blue/Black

    return Scaffold(
      backgroundColor: bgDark,
      body: Stack(
        children: [
          // 1. Hex Grid Background
          Positioned.fill(
            child: CustomPaint(painter: HexGridPainter(color: hudColor.withOpacity(0.05))),
          ),

          SafeArea(
            child: Column(
              children: [
                // 2. Compass Header
                _buildCompassHeader(hudColor),
                
                // 3. Radar Visualizer
                Expanded(
                  flex: 6,
                  child: LayoutBuilder(builder: (context, constraints) {
                    final size = math.min(constraints.maxWidth, constraints.maxHeight);
                    
                    return GestureDetector(
                      onTapUp: (details) {
                        // Simple "clear selection" on background tap
                        if (_selectedTargetId != null) {
                           setState(() => _selectedTargetId = null);
                           HapticFeedback.lightImpact();
                        }
                      },
                      child: Container(
                        color: Colors.transparent, // Hit test area
                        alignment: Alignment.center,
                        child: AnimatedBuilder(
                          animation: Listenable.merge([_radarController, _driftController]),
                          builder: (context, child) {
                            return CustomPaint(
                              size: Size(size, size),
                              painter: TacticalRadarPainter(
                                sweepValue: _radarController.value,
                                driftValue: _driftController.value,
                                targets: _targets,
                                selectedId: _selectedTargetId,
                                color: hudColor,
                                alertColor: alertColor,
                                onTargetTap: _selectTarget, // Callback logic handled in painter hit test? No, easier to do logic below or simplified.
                                // NOTE: CustomPainter HitTest is complex. For this demo, we use gesture detector above or simple distance check?
                                // Let's use a simpler Stack approach for interactivity + Painter for visuals.
                              ),
                              // Interactive Overlay for Targets
                              child: SizedBox(
                                width: size,
                                height: size,
                                child: Stack(
                                  children: _buildInteractiveTargets(size, hudColor, alertColor),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  }),
                ),

                // 4. Terminal & Stats Panel
                Expanded(
                  flex: 3,
                  child: _buildBottomConsole(hudColor, alertColor),
                ),
              ],
            ),
          ),
          
          // 5. Vignette & CRT Scanlines
          IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  radius: 1.5,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
                  stops: const [0.6, 1.0],
                ),
              ),
              child: CustomPaint(painter: ScanlinePainter()),
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGET BUILDERS ---

  Widget _buildCompassHeader(Color color) {
    return Container(
      height: 60,
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: color.withOpacity(0.3))),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black.withOpacity(0.8), Colors.transparent]
        )
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Scrolling Compass Tape (Simulated)
          OverflowBox(
            maxWidth: double.infinity,
            child: AnimatedBuilder(
              animation: _driftController,
              builder: (context, _) {
                // Simulate head turning
                double offset = math.sin(_driftController.value * math.pi) * 50; 
                return Transform.translate(
                  offset: Offset(offset, 0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(20, (i) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: Text(
                        "${i * 15}°", 
                        style: TextStyle(color: color.withOpacity(0.5), fontSize: 10, fontFamily: 'monospace'),
                      ),
                    )),
                  ),
                );
              }
            ),
          ),
          // Center Indicator
          Container(
            width: 2, height: 20,
            color: Colors.redAccent,
          ),
          Positioned(
            top: 5,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              color: Colors.black,
              child: const Icon(Icons.arrow_drop_down, color: Colors.redAccent, size: 15),
            ),
          )
        ],
      ),
    );
  }

  List<Widget> _buildInteractiveTargets(double size, Color color, Color alertColor) {
    final center = size / 2;
    final radius = size / 2;
    
    return _targets.map((target) {
      // Calculate position with drift
      // driftFactor adds a small wobble to the angle
      double drift = math.sin(_driftController.value * 2 * math.pi + target.hashCode) * 0.05;
      double effectiveAngle = target.angle + drift;
      
      double x = center + (radius * target.distance * math.cos(effectiveAngle - math.pi/2));
      double y = center + (radius * target.distance * math.sin(effectiveAngle - math.pi/2));
      
      // Check if this target is currently "swept" by the radar
      // The radar sweep is 0..1 (0..2pi).
      double sweepAngle = _radarController.value * 2 * math.pi;
      // Normalize target angle to 0..2pi
      double normTarget = (effectiveAngle - math.pi/2) % (2 * math.pi);
      if (normTarget < 0) normTarget += 2 * math.pi;
      
      // Simple logic: Highlight if close to sweep
      // bool isSwept = (normTarget - sweepAngle).abs() < 0.5;

      bool isSelected = _selectedTargetId == target.id;
      Color tColor = target.status == 'CRITICAL' || target.status == 'HOSTILE' ? alertColor : color;

      return Positioned(
        left: x - 20,
        top: y - 20,
        child: GestureDetector(
          onTap: () => _selectTarget(target),
          child: Container(
            width: 40, height: 40,
            color: Colors.transparent, // Hit box
            alignment: Alignment.center,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: isSelected ? 30 : 10,
              height: isSelected ? 30 : 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? Colors.transparent : tColor,
                border: isSelected ? Border.all(color: tColor, width: 2) : null,
                boxShadow: isSelected ? [BoxShadow(color: tColor, blurRadius: 10, spreadRadius: 2)] : [],
              ),
              child: isSelected ? Center(child: Container(width: 4, height: 4, color: tColor)) : null,
            ),
          ),
        ),
      );
    }).toList();
  }

  Widget _buildBottomConsole(Color color, Color alertColor) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        border: Border(top: BorderSide(color: color.withOpacity(0.3), width: 1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. TERMINAL
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.terminal, size: 14, color: color.withOpacity(0.7)),
                      const SizedBox(width: 6),
                      Text("EVENT_LOG", style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2)),
                    ],
                  ),
                  const Divider(color: Colors.white10),
                  Expanded(
                    child: ShaderMask(
                      shaderCallback: (bounds) {
                        return const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.white],
                          stops: [0.0, 0.2],
                        ).createShader(bounds);
                      },
                      blendMode: BlendMode.dstIn,
                      child: ListView.builder(
                        controller: _terminalScroll,
                        itemCount: _logs.length,
                        physics: const BouncingScrollPhysics(),
                        itemBuilder: (context, i) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2.0),
                            child: Text(
                              _logs[i],
                              style: TextStyle(
                                fontFamily: "monospace",
                                fontSize: 10,
                                color: _logs[i].contains("LOCK") ? alertColor : color.withOpacity(0.7)
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          VerticalDivider(color: color.withOpacity(0.2), width: 1),

          // 2. DETAIL PANEL
          Expanded(
            flex: 1,
            child: _selectedTargetId == null 
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.radar, color: color.withOpacity(0.2), size: 40),
                      const SizedBox(height: 10),
                      Text("SCANNING...", style: TextStyle(color: color.withOpacity(0.5), fontSize: 10, letterSpacing: 2)),
                    ],
                  ),
                )
              : _buildTargetDetails(color, alertColor),
          ),
        ],
      ),
    );
  }

  Widget _buildTargetDetails(Color color, Color alertColor) {
    final target = _targets.firstWhere((t) => t.id == _selectedTargetId);
    final isCrit = target.status == 'CRITICAL' || target.status == 'HOSTILE';
    final activeColor = isCrit ? alertColor : color;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("ID: ${target.id}", style: TextStyle(color: activeColor, fontWeight: FontWeight.bold, fontSize: 16)),
              Container(
                width: 8, height: 8,
                decoration: BoxDecoration(color: activeColor, shape: BoxShape.circle, boxShadow: [BoxShadow(color: activeColor, blurRadius: 5)]),
              )
            ],
          ),
          const SizedBox(height: 10),
          
          // Stats Grid
          _statRow("STATUS", target.status, activeColor),
          _statRow("DIST", "${(target.distance * 100).toInt()} M", color),
          _statRow("BPM", "${target.heartRate}", target.heartRate > 120 ? alertColor : color),
          _statRow("PWR", "${target.battery}%", target.battery < 20 ? Colors.orange : color),
          
          const Spacer(),
          
          // Action Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: activeColor),
                backgroundColor: activeColor.withOpacity(0.1),
              ),
              onPressed: () {
                HapticFeedback.heavyImpact();
                _addLog("PING SENT TO ${target.id}");
              },
              child: Text("PING SIGNAL", style: TextStyle(color: activeColor, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }

  Widget _statRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10)),
          Text(value, style: TextStyle(color: color, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

// --- PAINTERS (THE WOW FACTOR) ---

class TacticalRadarPainter extends CustomPainter {
  final double sweepValue;
  final double driftValue;
  final List<TargetNode> targets;
  final String? selectedId;
  final Color color;
  final Color alertColor;

  TacticalRadarPainter({
    required this.sweepValue,
    required this.driftValue,
    required this.targets,
    required this.selectedId,
    required this.color,
    required this.alertColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    
    final paintGrid = Paint()
      ..color = color.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // 1. Draw Concentric Circles (Range Rings)
    for (var i = 1; i <= 3; i++) {
      canvas.drawCircle(center, radius * (i / 3), paintGrid);
      // Distance Text
      final textSpan = TextSpan(
        text: "${(i * 33).toInt()}M",
        style: TextStyle(color: color.withOpacity(0.4), fontSize: 8),
      );
      final textPainter = TextPainter(text: textSpan, textDirection: TextDirection.ltr);
      textPainter.layout();
      textPainter.paint(canvas, Offset(center.dx + 2, center.dy - (radius * (i / 3)) - 10));
    }

    // 2. Draw Crosshairs
    canvas.drawLine(Offset(center.dx - radius, center.dy), Offset(center.dx + radius, center.dy), paintGrid);
    canvas.drawLine(Offset(center.dx, center.dy - radius), Offset(center.dx, center.dy + radius), paintGrid);

    // 3. Draw Radar Sweep (Gradient Sector)
    final sweepAngle = sweepValue * 2 * math.pi;
    
    final Paint sweepPaint = Paint()
      ..shader = SweepGradient(
        center: Alignment.center,
        startAngle: 0.0,
        endAngle: math.pi * 2, // Full circle gradient mapping
        colors: [Colors.transparent, color.withOpacity(0.0), color.withOpacity(0.6), Colors.transparent],
        stops: const [0.0, 0.75, 1.0, 1.0], // Hard edge at end
        transform: GradientRotation(sweepAngle - math.pi / 2), // Rotate the gradient
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    // Draw the actual filled arc (The beam)
    canvas.drawCircle(center, radius, sweepPaint);

    // 4. Draw Selected Target HUD Overlay (Locking Brackets)
    if (selectedId != null) {
      final target = targets.firstWhere((t) => t.id == selectedId);
      // Recalculate drift position for the painter line
      double drift = math.sin(driftValue * 2 * math.pi + target.hashCode) * 0.05;
      double effectiveAngle = target.angle + drift;
      
      double x = center.dx + (radius * target.distance * math.cos(effectiveAngle - math.pi/2));
      double y = center.dy + (radius * target.distance * math.sin(effectiveAngle - math.pi/2));
      
      final Paint lockPaint = Paint()
        ..color = target.status == 'CRITICAL' || target.status == 'HOSTILE' ? alertColor : color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
        
      // Draw Line from Center
      final path = Path();
      path.moveTo(center.dx, center.dy);
      path.lineTo(x, y);
      canvas.drawPath(path, lockPaint..color = lockPaint.color.withOpacity(0.3));

      // Draw Coordinates Text
      final coords = "X:${x.toInt()} Y:${y.toInt()}";
      final tp = TextPainter(text: TextSpan(text: coords, style: TextStyle(color: lockPaint.color, fontSize: 9, fontWeight: FontWeight.bold)), textDirection: TextDirection.ltr);
      tp.layout();
      tp.paint(canvas, Offset(x + 15, y - 15));
    }
  }

  @override
  bool shouldRepaint(covariant TacticalRadarPainter oldDelegate) => true; // Always animate
}

class HexGridPainter extends CustomPainter {
  final Color color;
  HexGridPainter({required this.color});
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..strokeWidth = 1;
    const double hexSize = 40;
    const double height = hexSize * 2;
    final double vertSpacing = height * 0.75;
    final double horizSpacing = math.sqrt(3) * hexSize;

    for (double y = 0; y < size.height + height; y += vertSpacing) {
      for (double x = 0; x < size.width + horizSpacing; x += horizSpacing) {
        bool offsetRow = (y ~/ vertSpacing) % 2 == 1;
        double actualX = offsetRow ? x + horizSpacing / 2 : x;
        _drawHex(canvas, Offset(actualX, y), hexSize, paint);
      }
    }
  }

  void _drawHex(Canvas canvas, Offset center, double size, Paint paint) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      double angle = (60 * i - 30) * (math.pi / 180);
      double x = center.dx + size * math.cos(angle);
      double y = center.dy + size * math.sin(angle);
      if (i == 0) path.moveTo(x, y);
      else path.lineTo(x, y);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class ScanlinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(0.02);
    for (double i = 0; i < size.height; i += 4) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }
  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
