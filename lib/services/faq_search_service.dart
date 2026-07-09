import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/faq_item.dart';

class FaqSearchService {
  List<FaqItem>? _cache;

  Future<List<FaqItem>> loadFaq() async {
    if (_cache != null) return _cache!;
    final raw = await rootBundle.loadString('assets/data/faq.json');
    final data = jsonDecode(raw) as List<dynamic>;
    _cache = data.map((item) => FaqItem.fromJson(item as Map<String, dynamic>)).toList();
    return _cache!;
  }

  Future<FaqItem?> search(String input) async {
    final faq = await loadFaq();
    final text = _normalize(input);
    FaqItem? best;
    int bestScore = 0;
    for (final item in faq) {
      var score = 0;
      for (final keyword in item.keywords) {
        if (text.contains(_normalize(keyword))) score += keyword.length;
      }
      if (text.contains(_normalize(item.question))) score += 20;
      if (score > bestScore) {
        bestScore = score;
        best = item;
      }
    }
    return bestScore >= 4 ? best : null;
  }

  String _normalize(String value) {
    return value.toLowerCase()
        .replaceAll('á', 'a').replaceAll('à', 'a').replaceAll('ã', 'a').replaceAll('â', 'a')
        .replaceAll('é', 'e').replaceAll('ê', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o').replaceAll('õ', 'o').replaceAll('ô', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ç', 'c');
  }
}
