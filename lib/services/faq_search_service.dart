import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/faq_item.dart';
import 'neon_api_client.dart';
import 'institutional/runtime.dart';

class FaqSearchService {
  FaqSearchService({this.onlineBudget = const Duration(milliseconds: 600), this.api});
  final Duration onlineBudget;
  final NeonApiClient? api;
  List<FaqItem>? _cache;

  Future<List<FaqItem>> loadFaq() async {
    if (_cache != null) return _cache!;
    final raw = await rootBundle.loadString('assets/data/faq.json');
    final data = jsonDecode(raw) as List<dynamic>;
    _cache = data.map((item) => FaqItem.fromJson(item as Map<String, dynamic>)).toList();
    return _cache!;
  }

  Future<FaqItem?> search(String input, {String? category}) async {
    final local = await _searchLocal(input);
    final onlineCurated = await _searchOnlineCurated(input)
        .timeout(onlineBudget, onTimeout: () => null);
    // Do not contact the retired Supabase or invent document-based answers.
    return _better(local, onlineCurated);
  }

  FaqItem? _better(FaqItem? a, FaqItem? b) {
    if (a == null) return b;
    if (b == null) return a;
    return b.keywords.length >= a.keywords.length ? b : a;
  }

  Future<FaqItem?> _searchLocal(String input) async {
    final faq = await loadFaq();
    final text = _normalize(input);
    FaqItem? best;
    int bestScore = 0;
    for (final item in faq) {
      final score = _scoreItem(text, item.question, item.keywords, item.answer);
      if (score > bestScore) {
        bestScore = score;
        best = item;
      }
    }
    return bestScore >= 4 ? best : null;
  }

  Future<FaqItem?> _searchOnlineCurated(String input) async {
    try {
      final client = api ?? InstitutionalRuntime.instance?.api;
      if (client == null) return null;
      final text = _normalize(input);
      final kb = await client.listKnowledge();
      FaqItem? best;
      int bestScore = 0;
      for (final json in kb) {
        final keywords = List<String>.from(json['keywords'] as List? ?? const []);
        final score = _scoreItem(
          text,
          json['question'] as String? ?? '',
          keywords,
          json['answer'] as String? ?? '',
        );
        if (score > bestScore) {
          bestScore = score;
          best = FaqItem(
            id: json['id']?.toString() ?? 'online_kb',
            category: json['category'] as String? ?? 'Base da Petita',
            question: json['question'] as String? ?? '',
            keywords: keywords,
            answer: json['answer'] as String? ?? '',
            riskLevel: json['risk_level'] as String? ?? 'baixo',
          );
        }
      }
      return bestScore >= 4 ? best : null;
    } catch (_) {
      return null;
    }
  }

  int _scoreItem(String normalizedInput, String question, List<String> keywords, String answer) {
    var score = 0;
    for (final keyword in keywords) {
      final normalizedKeyword = _normalize(keyword);
      if (normalizedKeyword.isNotEmpty && normalizedInput.contains(normalizedKeyword)) {
        score += normalizedKeyword.length;
      }
    }
    if (_normalize(question).isNotEmpty && normalizedInput.contains(_normalize(question))) {
      score += 20;
    }
    final answerText = _normalize(answer);
    for (final word in _keywordsFromInput(normalizedInput)) {
      if (word.length >= 4 && answerText.contains(word)) score += 2;
    }
    return score;
  }

  List<String> _keywordsFromInput(String input) {
    return _normalize(input)
        .split(RegExp(r'[^a-z0-9]+'))
        .where((word) => word.length >= 4)
        .toSet()
        .toList();
  }

  String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('à', 'a')
        .replaceAll('ã', 'a')
        .replaceAll('â', 'a')
        .replaceAll('é', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('õ', 'o')
        .replaceAll('ô', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ç', 'c');
  }
}
