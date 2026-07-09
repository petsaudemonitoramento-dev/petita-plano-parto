import 'package:flutter/material.dart';
import '../../config/app_routes.dart';
import '../../config/app_theme.dart';
import '../../models/birth_plan_answer.dart';
import '../../models/birth_plan_question.dart';
import '../../models/chat_message.dart';
import '../../models/ubs_question.dart';
import '../../services/birth_plan_flow_service.dart';
import '../../services/chatbot_service.dart';
import '../../services/faq_search_service.dart';
import '../../services/storage_service.dart';
import '../../widgets/chat_bubble.dart';
import '../../widgets/option_chip.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _storage = StorageService();
  late final ChatbotService _chatbot;

  List<ChatMessage> _messages = [];
  List<BirthPlanQuestion> _questions = [];
  List<BirthPlanAnswer> _answers = [];
  int _currentQuestion = -1;
  bool _loading = true;
  final Set<String> _multiSelection = <String>{};

  @override
  void initState() {
    super.initState();
    _chatbot = ChatbotService(FaqSearchService());
    _init();
  }

  Future<void> _init() async {
    _questions = await BirthPlanFlowService().loadQuestions();
    _answers = await _storage.loadAnswers();
    _messages = [_chatbot.welcome()];
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _send([String? override]) async {
    final text = (override ?? _controller.text).trim();
    if (text.isEmpty) return;
    _controller.clear();

    if (_currentQuestion >= 0) {
      final q = _questions[_currentQuestion];
      if (q.multiple) {
        await _answerCurrentQuestion([text]);
      } else {
        setState(() => _messages.add(ChatMessage(text: text, isUser: true)));
        await _answerCurrentQuestion([text]);
      }
      return;
    }

    setState(() => _messages.add(ChatMessage(text: text, isUser: true)));
    await Future.delayed(const Duration(milliseconds: 150));

    if (text == 'Montar meu plano') {
      _startPlanFlow();
      return;
    }
    if (text == 'Enviar dúvida à UBS' || text == 'Ainda tenho dúvida') {
      _askUbsQuestion();
      return;
    }
    final reply = await _chatbot.respond(text);
    setState(() => _messages.add(reply));
    _scrollToBottom();
  }

  void _startPlanFlow() {
    _currentQuestion = 0;
    _answers.clear();
    _multiSelection.clear();
    _storage.clearAnswers();
    setState(() {
      _messages.add(const ChatMessage(
        text: 'Perfeito! Vamos montar seu Plano de Parto no modelo de uma página. Vou perguntar tudo que entra no documento final: dados, acompanhante, trabalho de parto, alívio da dor, nascimento, cuidados com o bebê, cesárea e observações finais.',
        isUser: false,
      ));
    });
    _showCurrentQuestion();
  }

  void _showCurrentQuestion() {
    final q = _questions[_currentQuestion];
    _multiSelection.clear();
    final options = q.multiple ? [...q.options, 'Concluir seleção'] : q.options;
    final instruction = q.multiple
        ? '\n\nVocê pode selecionar mais de uma opção. Quando terminar, toque em "Concluir seleção".'
        : q.options.isEmpty
            ? '\n\nDigite sua resposta no campo de mensagem.'
            : '';
    setState(() {
      _messages.add(ChatMessage(
        text: 'Etapa ${_currentQuestion + 1} de ${_questions.length} — ${q.section}\n${q.question}$instruction',
        isUser: false,
        options: options,
      ));
    });
    _scrollToBottom();
  }

  Future<void> _answerCurrentQuestion(List<String> values) async {
    final q = _questions[_currentQuestion];
    final cleaned = values.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (cleaned.isEmpty) return;

    _answers.removeWhere((a) => a.questionId == q.id);
    _answers.add(BirthPlanAnswer(questionId: q.id, values: cleaned));
    await _storage.saveAnswers(_answers);

    _currentQuestion++;
    if (_currentQuestion >= _questions.length) {
      setState(() => _messages.add(const ChatMessage(
            text: 'Pronto! Seu Plano de Parto foi construído com sucesso no modelo de uma página. Agora você pode visualizar, editar ou gerar o PDF.',
            isUser: false,
            options: ['Ver meu plano'],
          )));
      _currentQuestion = -1;
      _multiSelection.clear();
      _scrollToBottom();
    } else {
      _showCurrentQuestion();
    }
  }

  Future<void> _askUbsQuestion() async {
    final text = await showDialog<String>(
      context: context,
      builder: (context) {
        final dialogController = TextEditingController();
        return AlertDialog(
          title: const Text('Enviar dúvida à Equipe UBS'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Este canal é apenas para dúvidas não urgentes. Evite inserir nome, CPF, telefone ou informações que identifiquem você diretamente.'),
            const SizedBox(height: 12),
            TextField(controller: dialogController, maxLines: 4, decoration: const InputDecoration(hintText: 'Digite sua dúvida...')),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            ElevatedButton(onPressed: () => Navigator.pop(context, dialogController.text), child: const Text('Enviar')),
          ],
        );
      },
    );
    if (text == null || text.trim().isEmpty) return;
    await _storage.saveUbsQuestion(UbsQuestion(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      anonymousUserId: 'GES-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
      question: text.trim(),
      createdAt: DateTime.now(),
    ));
    setState(() => _messages.add(const ChatMessage(
          text: 'Sua dúvida foi registrada para a Equipe UBS como demonstração local. Em uma versão online, ela seria enviada com identificação reduzida para resposta profissional.',
          isUser: false,
        )));
  }

  void _handleOption(String option) {
    if (option == 'Ver meu plano') {
      Navigator.pushNamed(context, AppRoutes.summary);
      return;
    }

    if (_currentQuestion >= 0 && _questions[_currentQuestion].multiple) {
      if (option == 'Concluir seleção') {
        if (_multiSelection.isEmpty) {
          setState(() => _messages.add(const ChatMessage(
                text: 'Selecione pelo menos uma opção ou digite uma resposta no campo de mensagem.',
                isUser: false,
              )));
          _scrollToBottom();
          return;
        }
        setState(() => _messages.add(ChatMessage(text: _multiSelection.join(', '), isUser: true)));
        _answerCurrentQuestion(_multiSelection.toList());
        return;
      }
      setState(() {
        if (_multiSelection.contains(option)) {
          _multiSelection.remove(option);
          _messages.add(ChatMessage(text: 'Removido: $option', isUser: true));
        } else {
          _multiSelection.add(option);
          _messages.add(ChatMessage(text: 'Selecionado: $option', isUser: true));
        }
      });
      _scrollToBottom();
      return;
    }

    _send(option);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          CircleAvatar(backgroundColor: AppColors.softPink, child: Image.asset('assets/images/petita.png')),
          const SizedBox(width: 8),
          const Text('Petita • Assistente PET Saúde', style: TextStyle(fontSize: 16)),
        ]),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  ChatBubble(text: msg.text, isUser: msg.isUser),
                  if (!msg.isUser && msg.options.isNotEmpty)
                    Wrap(children: msg.options.map((o) => OptionChipButton(label: o, onTap: () => _handleOption(o))).toList()),
                ]);
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
              color: AppColors.background,
              child: Row(children: [
                Expanded(child: TextField(controller: _controller, decoration: const InputDecoration(hintText: 'Digite sua mensagem...'), onSubmitted: (_) => _send())),
                const SizedBox(width: 8),
                FloatingActionButton.small(onPressed: () => _send(), backgroundColor: AppColors.primaryPink, foregroundColor: Colors.white, child: const Icon(Icons.send)),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
