import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ghost_signal/services/mesh_service.dart'; // Standardized package name

// --- DATA MODEL (Included for context) ---
/*
class MeshMessage {
  final String id;
  final String senderName;
  final String content;
  final int hops;
  final DateTime timestamp;
  final bool isEmergency;
  
  MeshMessage({
    required this.id, 
    required this.senderName, 
    required this.content, 
    this.hops = 0, 
    required this.timestamp,
    this.isEmergency = false
  });
}
*/

class MeshChatScreen extends StatefulWidget {
  final MeshService meshService;
  const MeshChatScreen({super.key, required this.meshService});

  @override
  State<MeshChatScreen> createState() => _MeshChatScreenState();
}

class _MeshChatScreenState extends State<MeshChatScreen> with TickerProviderStateMixin {
  // Logic
  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _myName = "Survivor";
  late StreamSubscription _chatSubscription;
  bool _isEmergencyChannel = false;
  
  // Animation Controllers
  late AnimationController _pulseController;
  late AnimationController _radarController;

  @override
  void initState() {
    super.initState();
    _loadName();
    
    // 1. Status Pulse (Breathing effect)
    _pulseController = AnimationController(
      vsync: this, 
      duration: const Duration(seconds: 2)
    )..repeat(reverse: true);

    // 2. Radar/Scanning Animation (For empty state)
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4)
    )..repeat();

    // 3. Listen to Stream
    _chatSubscription = widget.meshService.messageStream.listen((_) {
      if (mounted) setState(() {}); 
    });
  }

  void _loadName() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _myName = prefs.getString('my_name') ?? "Survivor");
  }

  void _sendMessage() {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    
    // Haptic Feedback
    if (_isEmergencyChannel) {
      HapticFeedback.heavyImpact();
    } else {
      HapticFeedback.lightImpact();
    }
    
    widget.meshService.broadcastChat(
      name: _myName,
      text: text,
      isEmergency: _isEmergencyChannel,
    );
    
    _msgCtrl.clear();
  }

  @override
  void dispose() {
    _chatSubscription.cancel();
    _msgCtrl.dispose();
    _scrollController.dispose();
    _pulseController.dispose();
    _radarController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Get messages and REVERSE them for the ListView (standard chat behavior)
    final messages = widget.meshService.chatMessages.reversed.toList();
    
    // Dynamic Colors
    final themeColor = _isEmergencyChannel ? const Color(0xFFFF2A2A) : const Color(0xFF00F0FF);
    final bgColor = const Color(0xFF020617);

    return Scaffold(
      backgroundColor: bgColor,
      // Tap outside to dismiss keyboard
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Stack(
          children: [
            // --- 1. TECH BACKGROUND ---
            Positioned.fill(
              child: CustomPaint(
                painter: TechGridPainter(
                  color: themeColor.withOpacity(0.05),
                  scanValue: _radarController.value
                ),
              ),
            ),

            // --- 2. MAIN CONTENT ---
            Column(
              children: [
                _buildAppBar(themeColor),
                _buildNetworkBanner(themeColor),
                
                // Chat Area
                Expanded(
                  child: messages.isEmpty 
                    ? _buildEmptyState(themeColor)
                    : ListView.builder(
                        controller: _scrollController,
                        reverse: true, // Critical for chat apps
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                        itemCount: messages.length,
                        physics: const BouncingScrollPhysics(),
                        itemBuilder: (ctx, i) => _buildMessageBubble(messages[i], themeColor),
                      ),
                ),

                // Input Area
                _buildInputArea(themeColor),
              ],
            ),
            
            // --- 3. EMERGENCY OVERLAY (Subtle Vignette) ---
            if (_isEmergencyChannel)
              IgnorePointer(
                child: AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Container(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: Alignment.center,
                          radius: 1.5,
                          colors: [
                            Colors.transparent,
                            Colors.red.withOpacity(0.1 * _pulseController.value)
                          ],
                          stops: const [0.6, 1.0]
                        )
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  // --- COMPONENT WIDGETS ---

  Widget _buildAppBar(Color themeColor) {
    return SafeArea(
      bottom: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: themeColor.withOpacity(0.1))),
          color: Colors.black.withOpacity(0.4),
        ),
        child: Row(
          children: [
            // Back Button
            InkWell(
              onTap: () => Navigator.pop(context),
              child: Icon(Icons.arrow_back_ios_new, color: themeColor, size: 20),
            ),
            const SizedBox(width: 16),
            
            // Title Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        _isEmergencyChannel ? "EMERGENCY_NET" : "GHOST_MESH_v1",
                        style: TextStyle(
                          color: themeColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                          fontFamily: "monospace" // Ensure you have a mono font or default
                        ),
                      ),
                      if (_isEmergencyChannel) ...[
                        const SizedBox(width: 8),
                        _buildBlinkingIcon(Icons.warning, Colors.red)
                      ]
                    ],
                  ),
                  Text(
                    "NODES: ${widget.meshService.activeNodes} | SIGNAL: STRONG",
                    style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10, fontFamily: "monospace"),
                  ),
                ],
              ),
            ),

            // Toggle Switch
            InkWell(
              onTap: () => setState(() => _isEmergencyChannel = !_isEmergencyChannel),
              borderRadius: BorderRadius.circular(4),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _isEmergencyChannel ? Colors.red.withOpacity(0.2) : Colors.transparent,
                  border: Border.all(color: _isEmergencyChannel ? Colors.red : Colors.grey.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _isEmergencyChannel ? "SOS ACTIVE" : "PUBLIC",
                  style: TextStyle(
                    color: _isEmergencyChannel ? Colors.red : Colors.grey,
                    fontSize: 10, 
                    fontWeight: FontWeight.bold
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNetworkBanner(Color themeColor) {
    return SizedBox(
      height: 2,
      child: LinearProgressIndicator(
        minHeight: 2,
        backgroundColor: Colors.transparent,
        valueColor: AlwaysStoppedAnimation<Color>(themeColor),
      ),
    );
  }

  Widget _buildEmptyState(Color themeColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _radarController,
            builder: (context, child) {
              return Container(
                width: 150, height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: themeColor.withOpacity(0.3)),
                  gradient: RadialGradient(
                    colors: [themeColor.withOpacity(0.1), Colors.transparent],
                    stops: [_radarController.value, _radarController.value + 0.1]
                  )
                ),
                child: Center(
                  child: Icon(Icons.radar, color: themeColor.withOpacity(0.5), size: 40),
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          Text(
            "SCANNING MESH FREQUENCIES...",
            style: TextStyle(color: themeColor.withOpacity(0.7), letterSpacing: 2, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(MeshMessage msg, Color themeColor) {
    final bool isMe = msg.senderName == _myName;
    final bool isAlert = msg.isEmergency;
    
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            // Header: Name + Hops
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isMe && isAlert) 
                  const Padding(
                    padding: EdgeInsets.only(right: 4),
                    child: Icon(Icons.report, color: Colors.red, size: 12),
                  ),
                Text(
                  isMe ? "YOU" : msg.senderName.toUpperCase(),
                  style: TextStyle(
                    color: isAlert ? Colors.redAccent : (isMe ? themeColor : Colors.grey),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(width: 6),
                if (!isMe)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white24),
                      borderRadius: BorderRadius.circular(2)
                    ),
                    child: Text(
                      msg.hops == 0 ? "DIRECT" : "${msg.hops} HOPS",
                      style: const TextStyle(color: Colors.white38, fontSize: 8),
                    ),
                  )
              ],
            ),
            
            const SizedBox(height: 4),

            // Message Body (Glassmorphism)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isMe 
                  ? themeColor.withOpacity(0.1) 
                  : (isAlert ? Colors.red.withOpacity(0.15) : const Color(0xFF1E293B)),
                border: Border(
                  left: isMe ? BorderSide.none : BorderSide(color: isAlert ? Colors.red : themeColor.withOpacity(0.3), width: 2),
                  right: isMe ? BorderSide(color: themeColor.withOpacity(0.5), width: 2) : BorderSide.none,
                  top: BorderSide(color: Colors.white.withOpacity(0.05)),
                  bottom: BorderSide(color: Colors.white.withOpacity(0.05)),
                ),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(4),
                  topRight: const Radius.circular(4),
                  bottomLeft: Radius.circular(isMe ? 4 : 0),
                  bottomRight: Radius.circular(isMe ? 0 : 4),
                ),
              ),
              child: Text(
                msg.content,
                style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
              ),
            ),
            
            // Timestamp
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _formatTime(msg.timestamp),
                style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 9),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea(Color themeColor) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.6),
            border: Border(top: BorderSide(color: themeColor.withOpacity(0.2))),
          ),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 45,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.white10)
                  ),
                  child: TextField(
                    controller: _msgCtrl,
                    style: const TextStyle(color: Colors.white),
                    cursorColor: themeColor,
                    decoration: InputDecoration(
                      hintText: _isEmergencyChannel ? "BROADCAST ALERT..." : "Enter command...",
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.2)),
                      border: InputBorder.none,
                      suffixIcon: _isEmergencyChannel ? const Icon(Icons.priority_high, color: Colors.red, size: 16) : null
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              
              // Tactical Send Button
              Container(
                height: 45, width: 45,
                decoration: BoxDecoration(
                  color: themeColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: themeColor.withOpacity(0.3))
                ),
                child: IconButton(
                  icon: Icon(Icons.send, color: themeColor, size: 20),
                  onPressed: _sendMessage,
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBlinkingIcon(IconData icon, Color color) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Opacity(
          opacity: 0.5 + (_pulseController.value * 0.5),
          child: Icon(icon, color: color, size: 16),
        );
      },
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inSeconds < 60) return "T-MINUS 00:00:${diff.inSeconds.toString().padLeft(2, '0')}";
    if (diff.inMinutes < 60) return "${diff.inMinutes} MIN AGO";
    return "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";
  }
}

// --- BACKGROUND PAINTER ---
class TechGridPainter extends CustomPainter {
  final Color color;
  final double scanValue;

  TechGridPainter({required this.color, required this.scanValue});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;

    // Draw Grid
    const double step = 40;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    // Draw Scanline
    final scanY = size.height * scanValue;
    final scanPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.transparent, color.withOpacity(0.5), Colors.transparent],
        stops: const [0.0, 0.5, 1.0]
      ).createShader(Rect.fromLTWH(0, scanY - 20, size.width, 40));
    
    canvas.drawRect(Rect.fromLTWH(0, scanY - 20, size.width, 40), scanPaint);
  }

  @override
  bool shouldRepaint(covariant TechGridPainter oldDelegate) => oldDelegate.scanValue != scanValue;
}
