import 'package:flutter/material.dart';
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
  List<MeshMessage> _messages = [];
  String _myName = "Unknown";

  @override
  void initState() {
    super.initState();
    _loadName();
    // Subscribe to Chat Updates
    _messages = widget.meshService.chatMessages; // Load existing
    // NOTE: In a real app, we'd set the callback in main and pass stream,
    // but for this hackathon structure, we rely on the service state.
  }

  void _loadName() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _myName = prefs.getString('my_name') ?? "Survivor");
  }

  void _sendMessage() {
    if (_msgCtrl.text.trim().isEmpty) return;
    widget.meshService.broadcastChat(
        name: _myName,
        text: _msgCtrl.text.trim(),
        enableRelay: true // Default to relay for Earthquake Chat
        );
    _msgCtrl.clear();
    setState(() => _messages = widget.meshService.chatMessages);
  }

  @override
  Widget build(BuildContext context) {
    // Refresh periodically or use StreamBuilder in full version.
    // Here we assume setState triggers from parent or manual refresh.
    _messages = widget.meshService.chatMessages;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text("BLACKOUT CHAT",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh, color: Colors.cyan),
              onPressed: () => setState(() {}))
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            color: Colors.white10,
            child: Row(children: const [
              Icon(Icons.bluetooth, color: Colors.blueAccent),
              SizedBox(width: 10),
              Expanded(
                  child: Text(
                      "Connected to Mesh Network. Messages will hop to nearby devices.",
                      style: TextStyle(color: Colors.white54, fontSize: 12)))
            ]),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (ctx, i) {
                final msg = _messages[i];
                final isMe = msg.senderName == "Me";
                return Align(
                  alignment:
                      isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 5),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: isMe
                            ? Colors.cyan.withOpacity(0.2)
                            : Colors.white10,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                            color: isMe ? Colors.cyanAccent : Colors.white24)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!isMe)
                          Text(msg.senderName,
                              style: const TextStyle(
                                  color: Colors.cyanAccent,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold)),
                        Text(msg.content,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 16)),
                        const SizedBox(height: 5),
                        Text("${msg.extra} • ${msg.hops} hops",
                            style: const TextStyle(
                                color: Colors.white30, fontSize: 10))
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                        hintText: "Type message...",
                        hintStyle: const TextStyle(color: Colors.white30),
                        filled: true,
                        fillColor: Colors.white10,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide: BorderSide.none)),
                  ),
                ),
                const SizedBox(width: 10),
                FloatingActionButton(
                  backgroundColor: Colors.cyan,
                  onPressed: _sendMessage,
                  child: const Icon(Icons.send, color: Colors.white),
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}
