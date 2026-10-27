import '../models/chat_message.dart';
import 'faq_search_service.dart';

class ChatbotService {
  ChatbotService(this._faqSearchService);

  final FaqSearchService _faqSearchService;

  ChatMessage welcome() {
    return const ChatMessage(
      isUser: false,
      text: 'Oi! Que bom ter você aqui. 💜 Eu sou a Petita, e este é um espaço para conversar com calma sobre o seu parto.\n\nPodemos construir seu plano juntas, passo a passo. Se você tiver dúvidas ou não souber o que escolher, tudo bem: vou explicar com palavras simples. O que você gostaria de fazer primeiro?',
      options: ['Montar meu plano', 'Criar cadastro local', 'O que é plano de parto?', 'Sinais de atenção', 'Enviar dúvida à UBS'],
    );
  }

  Future<ChatMessage> respond(String userText, {String? category}) async {
    final lower = userText.toLowerCase();
    if (lower.contains('cadastro') || lower.contains('login') || lower.contains('entrar')) {
      return const ChatMessage(
        isUser: false,
        text: 'Claro! 💗 Você pode preencher seu perfil e guardar suas escolhas neste dispositivo, mesmo sem internet. Para enviar dúvidas não urgentes à equipe da UBS, será necessário entrar na sua conta e ter uma UBS vinculada.',
        options: ['Abrir cadastro', 'Montar meu plano'],
      );
    }
    if (lower.contains('montar')) {
      return const ChatMessage(
        isUser: false,
        text: 'Com carinho, vamos construir seu plano juntas. 💜 Vou explicar cada etapa e você escolhe o que faz sentido para você. Quando estiver pronta, toque em “Montar meu plano”.',
        options: ['Montar meu plano'],
      );
    }
    if (lower.contains('ubs') || lower.contains('profissional')) {
      return const ChatMessage(
        isUser: false,
        text: 'Se você quiser conversar com a equipe da sua UBS, posso ajudar com o encaminhamento de uma dúvida não urgente. 💗 Para isso, precisamos confirmar sua conta e sua UBS de referência. Em caso de sinais de alerta, procure atendimento presencial sem esperar uma resposta pelo aplicativo.',
        options: ['Enviar dúvida à UBS', 'Sinais de atenção'],
      );
    }
    final faq = await _faqSearchService.search(userText, category: category);
    if (faq == null) {
      return const ChatMessage(
        isUser: false,
        text: 'Quero te orientar com cuidado, por isso prefiro não arriscar uma resposta quando não encontro uma informação confiável. 💜 Podemos tentar escrever a dúvida de outro jeito ou encaminhá-la, sem seu nome, para a equipe da sua UBS. Se for algo urgente, procure atendimento presencial.',
        options: ['Sinais de atenção', 'Montar meu plano', 'Criar cadastro local'],
      );
    }
    return ChatMessage(
      isUser: false,
      text: 'Obrigada por trazer sua dúvida. 💗 Vou compartilhar o que encontrei nas orientações disponíveis:\n\n${faq.answer}\n\nEssa explicação ajudou? Se quiser, podemos conversar mais sobre o assunto.',
      options: const ['Essa resposta ajudou', 'Ainda tenho dúvida', 'Montar meu plano'],
    );
  }
}
