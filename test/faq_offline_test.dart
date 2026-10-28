import 'package:flutter_test/flutter_test.dart';
import 'package:plano_parto_pet_saude/services/chatbot_service.dart';
import 'package:plano_parto_pet_saude/services/faq_search_service.dart';

import 'support/offline_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(resetOfflineState);

  test('bundled FAQ is usable without initializing a remote client', () async {
    final service = FaqSearchService();
    final items = await service.loadFaq();
    expect(items, isNotEmpty);
    expect(items.map((item) => item.id).toSet(), hasLength(items.length));
    final match = await service.search(items.first.question);
    expect(match, isNotNull);
    expect(items.any((item) => item.answer == match!.answer), isTrue);
  });

  test('blank and unknown synthetic queries have no fabricated FAQ match',
      () async {
    final service = FaqSearchService();
    expect(await service.search('   '), isNull);
    expect(await service.search('ZZZSINTETICO999'), isNull);
  });

  test(
      'chatbot keeps a safe fallback when neither local nor remote answer is available',
      () async {
    final reply =
        await ChatbotService(FaqSearchService()).respond('ZZZSINTETICO999');
    expect(reply.isUser, isFalse);
    expect(reply.text, contains('não encontro uma informação confiável'));
    expect(reply.options, contains('Criar cadastro local'));
  });
}
