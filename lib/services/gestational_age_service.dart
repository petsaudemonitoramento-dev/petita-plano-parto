/// Calcula uma estimativa da idade gestacional a partir de DPP informada
/// para 40 semanas e da data local de preenchimento do plano.
///
/// Não substitui ultrassonografia, acompanhamento pré-natal ou avaliação clínica.
class GestationalAgeService {
  static DateTime? parseDpp(String value) {
    final match = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(value.trim());
    if (match == null) return null;
    final day = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final year = int.parse(match.group(3)!);
    if (year < 1900 || year > 2200) return null;
    final date = DateTime(year, month, day);
    if (date.day != day || date.month != month || date.year != year) return null;
    return date;
  }

  static String? estimate(String dppBr, {DateTime? onDate}) {
    final dpp = parseDpp(dppBr);
    if (dpp == null) return null;
    final now = onDate ?? DateTime.now();
    final reference = DateTime(now.year, now.month, now.day);
    // Date-only arithmetic in UTC avoids daylight-saving/time-zone edge cases.
    final daysToDue = DateTime.utc(dpp.year, dpp.month, dpp.day)
        .difference(DateTime.utc(reference.year, reference.month, reference.day))
        .inDays;
    final gestationalDays = 280 - daysToDue;
    // Reject implausible results rather than displaying false clinical certainty.
    if (gestationalDays < 0 || gestationalDays > 294) return null;
    final weeks = gestationalDays ~/ 7;
    final days = gestationalDays % 7;
    final dd = reference.day.toString().padLeft(2, '0');
    final mm = reference.month.toString().padLeft(2, '0');
    return '$weeks semanas e $days dias (estimativa em $dd/$mm/${reference.year})';
  }
}
