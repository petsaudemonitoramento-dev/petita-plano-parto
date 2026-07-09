class ChatMessage {
  const ChatMessage({
    required this.text,
    required this.isUser,
    this.options = const [],
  });

  final String text;
  final bool isUser;
  final List<String> options;
}