import 'package:flutter_test/flutter_test.dart';
import 'package:plano_parto_pet_saude/services/gestational_age_service.dart';

void main() {
  test('calcula estimativa de 37 semanas com DPP em 18/11/2026', () {
    expect(
      GestationalAgeService.estimate(
        '18/11/2026', onDate: DateTime(2026, 10, 28),
      ),
      '37 semanas e 0 dias (estimativa em 28/10/2026)',
    );
  });

  test('recusa datas inválidas e estimativas fora da faixa', () {
    expect(GestationalAgeService.parseDpp('31/02/2026'), isNull);
    expect(GestationalAgeService.parseDpp('18-11-2026'), isNull);
    expect(GestationalAgeService.estimate('18/11/2027', onDate: DateTime(2026, 10, 28)), isNull);
    expect(GestationalAgeService.estimate('01/01/2026', onDate: DateTime(2026, 10, 28)), isNull);
  });

  test('calcula atravessando virada de ano com dias corridos', () {
    expect(
      GestationalAgeService.estimate('21/01/2027', onDate: DateTime(2026, 12, 31)),
      '37 semanas e 0 dias (estimativa em 31/12/2026)',
    );
  });
}
