import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../config/app_theme.dart';

class TermsScreen extends StatefulWidget {
  const TermsScreen({super.key, required this.initialAsset, required this.title});
  final String initialAsset;
  final String title;

  @override
  State<TermsScreen> createState() => _TermsScreenState();
}

class _TermsScreenState extends State<TermsScreen> {
  late Future<String> _markdown;

  @override
  void initState() {
    super.initState();
    _markdown = rootBundle.loadString(widget.initialAsset);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: SafeArea(
        child: FutureBuilder<String>(
          future: _markdown,
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            return Markdown(
              data: snapshot.data!,
              padding: const EdgeInsets.all(20),
              styleSheet: MarkdownStyleSheet(
                h1: const TextStyle(color: AppColors.petDarkBlue, fontSize: 25, fontWeight: FontWeight.w900),
                h2: const TextStyle(color: AppColors.primaryPink, fontSize: 18, fontWeight: FontWeight.w800),
                p: const TextStyle(color: AppColors.textPrimary, height: 1.35),
              ),
            );
          },
        ),
      ),
    );
  }
}
