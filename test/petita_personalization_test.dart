import 'package:flutter_test/flutter_test.dart';
import 'package:plano_parto_pet_saude/models/chat_message.dart';
import 'package:plano_parto_pet_saude/services/chatbot_service.dart';
import 'package:plano_parto_pet_saude/services/faq_search_service.dart';

void main() {
  test('welcome uses only the current authenticated account first name', () {
    final message = ChatbotService(FaqSearchService()).welcome();
    expect(message.text, contains('Oi!'));
    expect(message.text, isNot(contains('juntas')));
    expect(message.textForAccount(signedIn: true, accountName: 'Alex Silva'), startsWith('Oi, Alex!'));
    expect(message.textForAccount(signedIn: false, accountName: 'Alex Silva'), message.text);
    expect(message.textForAccount(signedIn: true, accountName: 'alex@example.invalid'), message.text);
    expect(message.textForAccount(signedIn: true, accountName: '   '), message.text);
    expect(message.textForAccount(signedIn: true, accountName: 'João Lima'), startsWith('Oi, João!'));
    expect(message.options, contains('Minha conta'));
    expect(message.options, isNot(contains('Criar cadastro local')));
  });
  test('selective personalization leaves clinical or user text unchanged', () {
    const plain = ChatMessage(text: 'Procure atendimento presencial.', isUser: false);
    const own = ChatMessage(text: 'Minha resposta', isUser: true, addressByName: true);
    const success = ChatMessage(text: 'Você conseguiu!', isUser: false, addressByName: true);
    expect(plain.textForAccount(signedIn: true, accountName: 'Alex'), plain.text);
    expect(own.textForAccount(signedIn: true, accountName: 'Alex'), own.text);
    expect(success.textForAccount(signedIn: true, accountName: 'Alex'), 'Alex, você conseguiu!');
  });
}
