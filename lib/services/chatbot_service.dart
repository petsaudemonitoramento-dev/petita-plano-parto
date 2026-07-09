import '../models/chat_message.dart';
import 'faq_search_service.dart';

class ChatbotService {
  ChatbotService(this._faqSearchService);

  final FaqSearchService _faqSearchService;

  ChatMessage welcome() {
    return ChatMessage(
      isUser: false,
      text: 'Olá! Eu sou a Petita 💗\nVou te ajudar a tirar dúvidas sobre o Plano de Parto e montar seu plano passo a passo.',
      options: const ['Montar meu plano', 'O que é plano de parto?', 'Sinais de atenção', 'Enviar dúvida à UBS'],
    );
  }

  Future<ChatMessage> respond(String userText) async {
    final lower = userText.toLowerCase();
    if (lower.contains('montar')) {
      return ChatMessage(
        isUser: false,
        text: 'Vamos montar seu plano juntas. Toque em "Montar meu plano" para iniciar o fluxo guiado.',
        options: const ['Montar meu plano'],
      );
    }
    if (lower.contains('ubs') || lower.contains('profissional')) {
      return ChatMessage(
        isUser: false,
        text: 'Posso registrar uma dúvida não urgente para a Equipe UBS. Esse canal não substitui atendimento e não deve ser usado em urgências.',
        options: const ['Enviar dúvida à UBS', 'Sinais de atenção'],
      );
    }
    final faq = await _faqSearchService.search(userText);
    if (faq == null) {
      return ChatMessage(
        isUser: false,
        text: 'Ainda não encontrei uma resposta segura na minha base validada. Você pode reformular a pergunta ou enviar uma dúvida não urgente à Equipe UBS.',
        options: const ['Enviar dúvida à UBS', 'Sinais de atenção', 'Montar meu plano'],
      );
    }
    return ChatMessage(
      isUser: false,
      text: faq.answer,
      options: const ['Essa resposta ajudou', 'Ainda tenho dúvida', 'Montar meu plano'],
    );
  }
}
