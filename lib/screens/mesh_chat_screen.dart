import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ghostsignal/services/mesh_service.dart';

// --- DATA MODELS ---
// Ensure your MeshMessage model looks something like this:
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
  
  // Animation
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _loadName();
    
    // Status Pulse Animation
    _pulseController = AnimationController(
      vsync: this, 
      duration: const Duration(seconds: 2)
    )..repeat(reverse: true);

    // Listen to incoming mesh packets
    _chatSubscription = widget.meshService.messageStream.listen((_) {
      if (mounted) {
        setState(() {}); // Refresh list
        _scrollToBottom();
      }
    });
  }

  void _loadName() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _myName = prefs.getString('my_name') ?? "Survivor");
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      // Small delay to ensure render box is ready
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutQuad,
        );
      });
    }
  }

  void _sendMessage() {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    
    // Haptic Feedback based on urgency
    if (_isEmergencyChannel) {
      HapticFeedback.heavyImpact();
    } else {
      HapticFeedback.lightImpact();
    }
    
    widget.meshService.broadcastChat(
      name: _myName,
      text: text,
      isEmergency: _isEmergencyChannel, // Flag for high priority
    );
    
    _msgCtrl.clear();
    _scrollToBottom();
  }

  @override
  void dispose() {
    _chatSubscription.cancel();
    _msgCtrl.dispose();
    _scrollController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final messages = widget.meshService.chatMessages;
    final themeColor = _isEmergencyChannel ? const Color(0xFFFF2A2A) : const Color(0xFF00F0FF);
    final bgColor = const Color(0xFF020617);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: _buildAppBar(themeColor),
      body: Column(
        children: [
          // 1. Network Header
          _buildNetworkBanner(themeColor),
          
          // 2. Chat Area
          Expanded(
            child: Stack(
              children: [
                // Background Noise
                 Opacity(
                  opacity: 0.05,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment.center,
                        radius: 1.0,
                        colors: [themeColor, Colors.transparent],
                      )
                    ),
                  ),
                ),
                
                // Message List
                ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  itemCount: messages.length,
                  itemBuilder: (ctx, i) => _buildMessageBubble(messages[i], themeColor),
                ),
              ],
            ),
          ),

          // 3. Input Zone
          _buildInputArea(themeColor),
        ],
      ),
    );
  }

  // --- WIDGETS ---

  PreferredSizeWidget _buildAppBar(Color themeColor) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(color: Colors.black.withOpacity(0.5)),
        ),
      ),
      title: Row(
        children: [
          Icon(Icons.hub, color: themeColor, size: 20),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isEmergencyChannel ? "EMERGENCY_NET" : "GHOST_MESH_v1",
                style: TextStyle(
                  color: themeColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2
                ),
              ),
              Text(
                "NODES: ${widget.meshService.activeNodes} | LATENCY: ~45ms",
                style: const TextStyle(color: Colors.white38, fontSize: 10),
              ),
            ],
          ),
        ],
      ),
      actions: [
        // Channel Toggle
        Center(
          child: Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: InkWell(
              onTap: () => setState(() => _isEmergencyChannel = !_isEmergencyChannel),
              borderRadius: BorderRadius.circular(20),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _isEmergencyChannel ? Colors.red.withOpacity(0.2) : Colors.cyan.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: themeColor.withOpacity(0.5))
                ),
                child: Text(
                  _isEmergencyChannel ? "SOS ONLY" : "PUBLIC",
                  style: TextStyle(color: themeColor, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        )
      ],
    );
  }

  Widget _buildNetworkBanner(Color themeColor) {
    return Container(
      width: double.infinity,
      height: 2,
      child: LinearProgressIndicator(
        value: null, // Indeterminate loader for "Scanning" feel
        backgroundColor: Colors.transparent,
        valueColor: AlwaysStoppedAnimation<Color>(themeColor.withOpacity(0.2)),
      ),
    );
  }

  Widget _buildMessageBubble(MeshMessage msg, Color themeColor) {
    final bool isMe = msg.senderName == _myName;
    final bool isAlert = msg.isEmergency;
    
    // Dynamic Bubble Color
    Color bubbleBorder = isMe 
        ? themeColor.withOpacity(0.5) 
        : (isAlert ? Colors.redAccent : Colors.white12);
    Color bubbleBg = isMe 
        ? themeColor.withOpacity(0.05) 
        : (isAlert ? Colors.red.withOpacity(0.1) : const Color(0xFF1E293B));

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // Metadata Row (Sender + Hops)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isMe && isAlert) 
                const Padding(
                  padding: EdgeInsets.only(right: 5),
                  child: Icon(Icons.warning_amber_rounded, color: Colors.red, size: 12),
                ),
              Text(
                isMe ? "YOU" : msg.senderName.toUpperCase(),
                style: TextStyle(
                  color: isAlert ? Colors.redAccent : (isMe ? themeColor : Colors.grey),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1
                ),
              ),
              const SizedBox(width: 8),
              if (!isMe)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    border: Border.all(color: Colors.white12),
                    borderRadius: BorderRadius.circular(4)
                  ),
                  child: Text(
                    msg.hops == 0 ? "DIRECT" : "${msg.hops} HOPS",
                    style: const TextStyle(color: Colors.white38, fontSize: 8),
                  ),
                ),
            ],
          ),
          
          const SizedBox(height: 4),

          // Message Body
          Container(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: bubbleBg,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(12),
                topRight: const Radius.circular(12),
                bottomLeft: Radius.circular(isMe ? 12 : 2),
                bottomRight: Radius.circular(isMe ? 2 : 12),
              ),
              border: Border.all(color: bubbleBorder),
            ),
            child: Text(
              msg.content,
              style: const TextStyle(
                color: Colors.white, 
                height: 1.4,
                fontSize: 14
              ),
            ),
          ),
          
          const SizedBox(height: 4),
          
          // Time Calculation
          Text(
            _formatTime(msg.timestamp),
            style: const TextStyle(color: Colors.white24, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea(Color themeColor) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1121),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: Row(
        children: [
          // Animated Status Indicator
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Container(
                width: 10, height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: themeColor.withOpacity(_pulseController.value),
                  boxShadow: [BoxShadow(color: themeColor, blurRadius: 5 * _pulseController.value)]
                ),
              );
            },
          ),
          const SizedBox(width: 15),
          
          // Input Field
          Expanded(
            child: TextField(
              controller: _msgCtrl,
              style: const TextStyle(color: Colors.white),
              cursorColor: themeColor,
              decoration: InputDecoration(
                hintText: _isEmergencyChannel ? "BROADCAST ALERT..." : "Type message...",
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                isDense: true,
                border: InputBorder.none,
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          
          // Send Button
          IconButton(
            onPressed: _sendMessage,
            icon: Icon(Icons.send_rounded, color: themeColor),
          )
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 60) return "Just now";
    if (diff.inMinutes < 60) return "${diff.inMinutes}m ago";
    return "${diff.inHours}h ago";
  }
}
