import 'package:flutter_test/flutter_test.dart';
import 'package:plano_parto_pet_saude/models/treatment_preferences.dart';
import 'package:plano_parto_pet_saude/services/chatbot_service.dart';
import 'package:plano_parto_pet_saude/services/faq_search_service.dart';

void main() {
  const choices = {'Ela/dela':'feminine','Ele/dele':'masculine','Elu/delu':'inclusive','Prefiro que usem meu nome':'neutral','':'neutral','outra forma':'neutral'};
  for (final entry in choices.entries) {
    test('explicit treatment selection: ${entry.key}', () {
      final value = TreatmentPreferences(pronouns: entry.key, conversationScope: 'guest');
      final restored = TreatmentPreferences.fromJson(value.toJson());
      expect(restored.conversationScope, 'guest');
      expect(restored.address(neutral: 'neutral', feminine: 'feminine', masculine: 'masculine', inclusive: 'inclusive'), entry.value);
    });
  }
  test('greeting respects selection, with no default gender', () {
    final bot = ChatbotService(FaqSearchService());
    expect(bot.welcome().text, contains('Que bom ter você aqui'));
    expect(bot.welcome(treatment: const TreatmentPreferences(pronouns: 'Ela/dela')).text, contains('bem-vinda'));
    expect(bot.welcome(treatment: const TreatmentPreferences(pronouns: 'Ele/dele')).text, contains('bem-vindo'));
  });
}
