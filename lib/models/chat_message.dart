class ChatMessage {
  const ChatMessage({
    required this.text,
    required this.isUser,
    this.options = const [],
    this.addressByName = false,
  });

  final String text;
  final bool isUser;
  final List<String> options;
  final bool addressByName;

  // Account name is presentation-only and never stored in the message.
  String textForAccount({required bool signedIn, Object? accountName}) {
    if (isUser || !addressByName || !signedIn || accountName is! String) return text;
    final name = accountName.trim().split(RegExp(r'\s+')).first;
    if (name.isEmpty || name.length > 48 || name.contains('@') || RegExp(r'[0-9]').hasMatch(name)) return text;
    if (text.startsWith('Oi!')) return 'Oi, $name!${text.substring(3)}';
    if (text.isEmpty) return text;
    return '$name, ${text[0].toLowerCase()}${text.substring(1)}';
  }
}
