import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ghostsignal/services/mesh_service.dart';

class MeshChatScreen extends StatefulWidget {
  final MeshService meshService;
  const MeshChatScreen({super.key, required this.meshService});

  @override
  State<MeshChatScreen> createState() => _MeshChatScreenState();
}

class _MeshChatScreenState extends State<MeshChatScreen> {
  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _myName = "Survivor";
  late StreamSubscription _chatSubscription;

  @override
  void initState() {
    super.initState();
    _loadName();
    
    // WOW FIX: Instead of manual refresh, listen to the service stream
    // Assuming meshService has a broadcast stream of messages
    _chatSubscription = widget.meshService.messageStream.listen((_) {
      if (mounted) {
        setState(() {});
        _scrollToBottom();
      }
    });
  }

  void _loadName() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _myName = prefs.getString('my_name') ?? "Survivor");
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 500),
          curve: Curves.outBack,
        );
      }
    });
  }

  void _sendMessage() {
    if (_msgCtrl.text.trim().isEmpty) return;
    
    HapticFeedback.mediumImpact(); // Tactical feel
    
    widget.meshService.broadcastChat(
      name: _myName,
      text: _msgCtrl.text.trim(),
      enableRelay: true,
    );
    
    _msgCtrl.clear();
    _scrollToBottom();
  }

  @override
  void dispose() {
    _chatSubscription.cancel();
    _msgCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final messages = widget.meshService.chatMessages;

    return Scaffold(
      backgroundColor: const Color(0xFF020617), // Deeper space black
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("MESH_TERMINAL_v1.0", 
              style: TextStyle(color: Colors.cyanAccent, fontSize: 18, fontWeight: FontWeight.black, letterSpacing: 2)),
            Text("NODES ACTIVE: ${widget.meshService.activeNodes}", 
              style: const TextStyle(color: Colors.white30, fontSize: 10)),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          _buildSignalIndicator(),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.cyan.withOpacity(0.05), Colors.transparent],
          ),
        ),
        child: Column(
          children: [
            _buildNetworkStatusBanner(),
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                itemCount: messages.length,
                itemBuilder: (ctx, i) {
                  return _buildMessageBubble(messages[i]);
                },
              ),
            ),
            _buildInputArea(),
          ],
        ),
      ),
    );
  }

  Widget _buildSignalIndicator() {
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Center(
        child: Container(
          width: 12,
          height: 12,
          decoration: const BoxDecoration(
            color: Colors.greenAccent,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: Colors.greenAccent, blurRadius: 10)],
          ),
        ),
      ),
    );
  }

  Widget _buildNetworkStatusBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      color: Colors.cyanAccent.withOpacity(0.1),
      child: Row(
        children: [
          const Icon(Icons.hub_outlined, color: Colors.cyanAccent, size: 16),
          const SizedBox(width: 8),
          const Expanded(
            child: Text("PROTOCOL: P2P_RELAY_ENABLED", 
              style: TextStyle(color: Colors.cyanAccent, fontSize: 10, fontWeight: FontWeight.bold)),
          ),
          Text("RSSI: -64dBm", style: TextStyle(color: Colors.cyanAccent.withOpacity(0.5), fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(MeshMessage msg) {
    final bool isMe = msg.senderName == _myName || msg.senderName == "Me";
    
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        max_width: MediaQuery.of(context).size.width * 0.75,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isMe ? Colors.cyanAccent.withOpacity(0.1) : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 0),
            bottomRight: Radius.circular(isMe ? 0 : 16),
          ),
          border: Border.all(color: isMe ? Colors.cyanAccent.withOpacity(0.3) : Colors.white10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(msg.senderName.toUpperCase(), 
                  style: TextStyle(color: isMe ? Colors.cyanAccent : Colors.white60, fontSize: 9, fontWeight: FontWeight.black)),
                const SizedBox(width: 8),
                Text("${msg.hops} HOPS", style: const TextStyle(color: Colors.white24, fontSize: 8)),
              ],
            ),
            const SizedBox(height: 6),
            Text(msg.content, style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.4)),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.bottomRight,
              child: Text(msg.extra, style: const TextStyle(color: Colors.white24, fontSize: 9)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        border: Border(top: BorderSide(color: Colors.cyanAccent.withOpacity(0.1))),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _msgCtrl,
              style: const TextStyle(color: Colors.white, fontFamily: 'monospace'),
              decoration: InputDecoration(
                hintText: ">_ SECURE_ENTRY",
                hintStyle: const TextStyle(color: Colors.white24),
                filled: true,
                fillColor: Colors.black,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white10)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.cyanAccent)),
              ),
            ),
          ),
          const SizedBox(width: 15),
          FloatingActionButton.small(
            backgroundColor: Colors.cyanAccent,
            onPressed: _sendMessage,
            child: const Icon(Icons.bolt, color: Colors.black),
          ),
        ],
      ),
    );
  }
}
