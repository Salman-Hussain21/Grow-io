// screens/chat_screen.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/growbot_service.dart';
import '../model/chat_message.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final GrowBotService _growbotService = GrowBotService();
  final TextEditingController _messageController = TextEditingController();
  final List<ChatMessage> _messages = [];
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadChatHistory();
    _addWelcomeMessage();
  }

  void _addWelcomeMessage() {
    if (_messages.isEmpty) {
      _addMessage(ChatMessage(
        id: 'welcome',
        text: 'Hi! I\'m GrowBot 🌱\n\nI can help you with plant care advice, watering tips, and problem solving. What would you like to know?',
        timestamp: DateTime.now(),
        isUser: false,
      ));
    }
  }

  Future<void> _loadChatHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final history = prefs.getStringList('chat_history') ?? [];

      setState(() {
        _messages.clear();
        for (final json in history) {
          try {
            final map = Map<String, dynamic>.from(jsonDecode(json));
            _messages.add(ChatMessage.fromMap(map));
          } catch (e) {
            print('Error loading message: $e');
          }
        }
      });

      _scrollToBottom();
    } catch (e) {
      print('Error loading chat history: $e');
    }
  }

  Future<void> _saveChatHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final history = _messages.map((msg) => jsonEncode(msg.toMap())).toList();
      await prefs.setStringList('chat_history', history);
    } catch (e) {
      print('Error saving chat history: $e');
    }
  }

  void _addMessage(ChatMessage message) {
    setState(() {
      _messages.add(message);
    });
    _saveChatHistory();
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isLoading) return;

    // Add user message
    final userMessage = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: text,
      timestamp: DateTime.now(),
      isUser: true,
    );
    _addMessage(userMessage);
    _messageController.clear();

    setState(() => _isLoading = true);

    try {
      // Get bot response
      final response = await _growbotService.getPlantResponse(text);

      // Add bot message
      final botMessage = ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: response,
        timestamp: DateTime.now(),
        isUser: false,
      );
      _addMessage(botMessage);
    } catch (e) {
      final errorMessage = ChatMessage(
        id: 'error_${DateTime.now().millisecondsSinceEpoch}',
        text: 'Sorry, I encountered an error. Please try again.',
        timestamp: DateTime.now(),
        isUser: false,
      );
      _addMessage(errorMessage);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _clearChat() async {
    setState(() {
      _messages.clear();
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('chat_history');
    _addWelcomeMessage();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GrowBot 🌱'),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        actions: [
          if (_messages.length > 1)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _clearChat,
              tooltip: 'Clear chat',
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return _buildMessageBubble(message);
              },
            ),
          ),
          _buildInputField(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!message.isUser)
            Container(
              margin: const EdgeInsets.only(right: 8, top: 4),
              child: CircleAvatar(
                backgroundColor: Colors.green[700],
                radius: 16,
                child: const Text('🌱', style: TextStyle(fontSize: 12)),
              ),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: message.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: message.isUser ? Colors.green[100] : Colors.grey[100],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    message.text,
                    style: TextStyle(
                      color: message.isUser ? Colors.green[900] : Colors.grey[900],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatTime(message.timestamp),
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
          if (message.isUser)
            Container(
              margin: const EdgeInsets.only(left: 8, top: 4),
              child: const CircleAvatar(
                backgroundColor: Colors.blue,
                radius: 16,
                child: Icon(Icons.person, size: 16, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInputField() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Ask about plant care...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: _isLoading
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : const Icon(Icons.send),
            onPressed: _isLoading ? null : _sendMessage,
            color: Colors.green[700],
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}