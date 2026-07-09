import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/ubs_unit.dart';

class UbsService {
  Future<List<UbsUnit>> loadOfficialUnits() async {
    final raw = await rootBundle.loadString('assets/data/ubs.json');
    final data = jsonDecode(raw) as List<dynamic>;
    return data.map((item) => UbsUnit.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<UbsUnit?> findByCode(String code) async {
    final items = await loadOfficialUnits();
    for (final item in items) {
      if (item.code == code) return item;
    }
    return null;
  }
}
