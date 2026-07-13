import '../models/chat_message.dart';
import 'faq_search_service.dart';

class ChatbotService {
  ChatbotService(this._faqSearchService);

  final FaqSearchService _faqSearchService;

  ChatMessage welcome() {
    return const ChatMessage(
      isUser: false,
      text: 'Olá! Eu sou a Petita 💗\nVou te ajudar a tirar dúvidas sobre o Plano de Parto, montar seu plano passo a passo e preparar seu cadastro local para acessar depois.',
      options: ['Montar meu plano', 'Criar cadastro local', 'O que é plano de parto?', 'Sinais de atenção', 'Enviar dúvida à UBS'],
    );
  }

  Future<ChatMessage> respond(String userText, {String? category}) async {
    final lower = userText.toLowerCase();
    if (lower.contains('cadastro') || lower.contains('login') || lower.contains('entrar')) {
      return const ChatMessage(
        isUser: false,
        text: 'O cadastro da gestante funciona offline e também pode ser conectado ao Supabase. Com login online, você poderá sincronizar o plano e enviar dúvidas não urgentes à UBS.',
        options: ['Abrir cadastro', 'Montar meu plano'],
      );
    }
    if (lower.contains('montar')) {
      return const ChatMessage(
        isUser: false,
        text: 'Vamos montar seu plano juntas. Toque em "Montar meu plano" para iniciar o fluxo guiado.',
        options: ['Montar meu plano'],
      );
    }
    if (lower.contains('ubs') || lower.contains('profissional')) {
      return const ChatMessage(
        isUser: false,
        text: 'O envio de dúvidas para a Equipe UBS está disponível para gestantes conectadas, com UBS oficial selecionada e aceite dos avisos de que este canal não é para urgências.',
        options: ['Enviar dúvida à UBS', 'Sinais de atenção'],
      );
    }
    final faq = await _faqSearchService.search(userText, category: category);
    if (faq == null) {
      return const ChatMessage(
        isUser: false,
        text: 'Ainda não encontrei uma resposta segura na minha base validada. Você pode reformular a pergunta ou encaminhar a dúvida, de forma anônima, para a Equipe UBS vinculada ao seu perfil.',
        options: ['Sinais de atenção', 'Montar meu plano', 'Criar cadastro local'],
      );
    }
    return ChatMessage(
      isUser: false,
      text: faq.answer,
      options: const ['Essa resposta ajudou', 'Ainda tenho dúvida', 'Montar meu plano'],
    );
  }
}
