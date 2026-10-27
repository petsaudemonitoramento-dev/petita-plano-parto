import 'dart:async';
import 'package:flutter/material.dart';
import '../../config/app_routes.dart';
import '../../config/app_theme.dart';
import '../../models/birth_plan_answer.dart';
import '../../models/birth_plan_question.dart';
import '../../models/chat_message.dart';
import '../../services/birth_plan_flow_service.dart';
import '../../services/birth_plan_explanations.dart';
import '../../services/chatbot_service.dart';
import '../../services/faq_search_service.dart';
import '../../services/storage_service.dart';
import '../../services/supabase_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _storage = StorageService();
  final _online = SupabaseService();
  late final ChatbotService _chatbot;

  List<ChatMessage> _messages = [];
  List<BirthPlanQuestion> _questions = [];
  List<BirthPlanAnswer> _answers = [];
  int _currentQuestion = -1;
  bool _loading = true;
  bool _petitaSearching = false;
  int _typingDots = 1;
  Timer? _typingTimer;
  _QuestionDialogResult? _pendingUbsQuestion;
  final Set<String> _multiSelection = <String>{};

  @override
  void initState() {
    super.initState();
    _chatbot = ChatbotService(FaqSearchService());
    _init();
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _setPetitaSearching(bool value) {
    _typingTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _petitaSearching = value;
      _typingDots = 1;
    });
    if (value) {
      _typingTimer = Timer.periodic(const Duration(milliseconds: 430), (_) {
        if (mounted) {
          setState(() => _typingDots = _typingDots == 3 ? 1 : _typingDots + 1);
          _scrollToBottom();
        }
      });
    }
    _scrollToBottom();
  }

  Future<void> _init() async {
    _questions = await BirthPlanFlowService().loadQuestions();
    _answers = await _storage.loadAnswers();
    _messages = [_chatbot.welcome()];
    if (mounted) setState(() => _loading = false);
    _scrollToBottom();
  }

  double get _progress {
    if (_questions.isEmpty || _currentQuestion < 0) return 0;
    final value = (_currentQuestion + 1) / _questions.length;
    return value.clamp(0, 1).toDouble();
  }

  String get _currentSectionName {
    if (_currentQuestion < 0 || _questions.isEmpty) return 'Conversa com a Petita';
    return _questions[_currentQuestion].section;
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
    await Future.delayed(const Duration(milliseconds: 160));

    if (text == 'Montar meu plano') {
      _startPlanFlow();
      return;
    }
    if (text == 'Criar cadastro local' || text == 'Abrir cadastro' || text == 'Perfil da gestante') {
      Navigator.pushNamed(context, AppRoutes.profile);
      return;
    }
    if (text == 'Enviar dúvida à UBS' || text == 'Ainda tenho dúvida') {
      _askUbsQuestion();
      return;
    }
    if (text == 'Resposta satisfatória' || text == 'Essa resposta ajudou') {
      _pendingUbsQuestion = null;
      setState(() => _messages.add(const ChatMessage(
            text: 'Que bom! Fico feliz em ajudar. Se surgir outra dúvida, pode me chamar novamente.',
            isUser: false,
            options: ['Montar meu plano', 'Ver meu plano'],
          )));
      _scrollToBottom();
      return;
    }
    if (text == 'Enviar para Equipe UBS') {
      await _submitPendingUbsQuestion();
      return;
    }
    if (text == 'Ver meu plano') {
      Navigator.pushNamed(context, AppRoutes.summary);
      return;
    }
    if (text == 'Minhas dúvidas') {
      Navigator.pushNamed(context, AppRoutes.myQuestions);
      return;
    }

    _setPetitaSearching(true);
    try {
      final reply = await _chatbot.respond(text);
      if (!mounted) return;
      setState(() => _messages.add(reply));
    } finally {
      _setPetitaSearching(false);
    }
    _scrollToBottom();
  }

  void _startPlanFlow() {
    _currentQuestion = 0;
    _answers.clear();
    _multiSelection.clear();
    _storage.clearAnswers();
    setState(() {
      _messages.add(const ChatMessage(
        text: 'Perfeito! 💗 Vamos construir seu Plano de Parto em formato de conversa. Vou te fazer perguntas simples e registrar suas preferências para gerar o documento final em uma página.',
        isUser: false,
      ));
    });
    _showCurrentQuestion();
  }

  IconData _sectionIcon(String section) {
    final s = section.toLowerCase();
    if (s.contains('gestante')) return Icons.badge_outlined;
    if (s.contains('ubs')) return Icons.local_hospital_outlined;
    if (s.contains('acompanhante')) return Icons.favorite_border;
    if (s.contains('trabalho')) return Icons.directions_walk_outlined;
    if (s.contains('alívio') || s.contains('dor')) return Icons.spa_outlined;
    if (s.contains('nascimento')) return Icons.child_care_outlined;
    if (s.contains('bebê')) return Icons.baby_changing_station_outlined;
    if (s.contains('cesárea')) return Icons.medical_services_outlined;
    if (s.contains('observ')) return Icons.chat_bubble_outline;
    return Icons.auto_awesome_outlined;
  }

  void _showCurrentQuestion() {
    final q = _questions[_currentQuestion];
    _multiSelection.clear();
    final options = q.multiple ? [...q.options, 'Concluir seleção'] : [...q.options];
    if (BirthPlanExplanations.forQuestion(q.id) != null) {
      options.add('Quero entender melhor');
    }
    final intro = _introForQuestion(q);
    setState(() {
      if (intro.isNotEmpty && (_currentQuestion == 0 || _questions[_currentQuestion - 1].section != q.section)) {
        _messages.add(ChatMessage(text: intro, isUser: false));
      }
      _messages.add(ChatMessage(
        text: q.question,
        isUser: false,
        options: options,
      ));
    });
    _scrollToBottom();
  }

  String _introForQuestion(BirthPlanQuestion q) {
    final section = q.section.toLowerCase();
    if (q.id == 'nome_gestante') return 'Vamos começar com seus dados básicos para identificar o plano.';
    if (q.id == 'ubs_referencia') return 'Agora me diga sua UBS de referência. Se ela estiver na lista oficial, as dúvidas poderão ser vinculadas à equipe correta.';
    if (section.contains('acompanhante')) return 'Agora vamos falar sobre quem você gostaria que estivesse com você no momento do parto.';
    if (section.contains('trabalho')) return 'Vamos registrar suas preferências para o trabalho de parto, sempre respeitando a avaliação da equipe de saúde.';
    if (section.contains('alívio')) return 'Existem diferentes formas de aliviar a dor. Marque as opções que você gostaria de ter disponíveis.';
    if (section.contains('nascimento')) return 'Agora vamos falar sobre o momento do nascimento e suas preferências principais.';
    if (section.contains('bebê')) return 'Vamos registrar cuidados importantes com o bebê logo após o nascimento.';
    if (section.contains('cesárea')) return 'Caso uma cesárea seja necessária, também podemos registrar suas preferências.';
    if (section.contains('observ')) return 'Para finalizar, você pode deixar uma observação com sua voz e seus desejos.';
    return '';
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
            text: 'Pronto! 💗 Seu Plano de Parto foi construído com sucesso. Agora você pode visualizar, editar ou gerar o PDF no modelo oficial.',
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
    final canProceed = await _ensurePatientCanAskUbsQuestion();
    if (!canProceed) return;

    final onlineCategories = await _online.listKnowledgeCategories();
    final categoryNames = onlineCategories.map((item) => item.name).where((name) => name.trim().isNotEmpty).toList();
    final result = await showDialog<_QuestionDialogResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _QuestionToUbsDialog(categories: categoryNames),
    );
    if (result == null) return;

    _pendingUbsQuestion = result;
    final hasRiskAlert = result.risk == 'high' || result.warningSigns.isNotEmpty;

    setState(() {
      _messages.add(ChatMessage(text: result.question, isUser: true));
      if (hasRiskAlert) {
        _messages.add(const ChatMessage(
          text: 'Atenção: pelos sinais informados, este canal não substitui atendimento presencial. Se você estiver com sintomas importantes ou insegura, procure uma maternidade, pronto atendimento ou serviço de urgência.',
          isUser: false,
        ));
      }
    });

    _setPetitaSearching(true);
    try {
      final reply = await _chatbot.respond(result.question, category: result.category);
      final answerText = reply.text.contains('Ainda não encontrei uma resposta segura')
          ? 'Eu não encontrei uma resposta suficientemente segura na minha base validada para essa dúvida. Posso encaminhar sua pergunta, de forma anônima, para a Equipe UBS vinculada ao seu perfil.'
          : '${reply.text}\n\nEssa resposta foi satisfatória para você?';

      if (!mounted) return;
      setState(() => _messages.add(ChatMessage(
            text: answerText,
            isUser: false,
            options: const ['Resposta satisfatória', 'Enviar para Equipe UBS'],
          )));
    } finally {
      _setPetitaSearching(false);
    }
    _scrollToBottom();
  }

  Future<bool> _ensurePatientCanAskUbsQuestion() async {
    if (!_online.isLoggedIn) {
      await _showAccessRequiredDialog(
        title: 'Cadastro necessário',
        message:
            'Para enviar uma dúvida à Equipe UBS, a paciente precisa estar cadastrada e conectada com e-mail e senha.\n\nVocê ainda pode conversar com a Petita, montar seu Plano de Parto e gerar o PDF offline, mas o envio de dúvidas para a UBS só funciona com cadastro online.',
      );
      return false;
    }

    final status = await _online.checkConnection();
    if (!status.connected) {
      await _showAccessRequiredDialog(
        title: 'Conexão necessária',
        message:
            'Para enviar uma dúvida à Equipe UBS, o app precisa estar online.\n\nVerifique sua internet e tente novamente. Em caso de urgência ou sinais de alerta, procure uma maternidade, pronto atendimento ou serviço de urgência.',
      );
      return false;
    }

    try {
      final profile = await _online.loadOnlineProfile();
      if (profile == null || profile.role != 'patient') {
        await _showAccessRequiredDialog(
          title: 'Conta de paciente necessária',
          message:
              'O envio de dúvidas é exclusivo para contas de paciente/gestante cadastradas.\n\nEntre com o e-mail e a senha da gestante no Perfil para continuar.',
        );
        return false;
      }
      return true;
    } catch (_) {
      await _showAccessRequiredDialog(
        title: 'Não foi possível confirmar o cadastro',
        message:
            'Não consegui confirmar seu cadastro online agora. Entre novamente com e-mail e senha no Perfil e tente enviar a dúvida depois.',
      );
      return false;
    }
  }

  Future<void> _showAccessRequiredDialog({required String title, required String message}) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Entendi')),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, AppRoutes.profile);
            },
            child: const Text('Ir para Perfil'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitPendingUbsQuestion() async {
    final pending = _pendingUbsQuestion;
    if (pending == null) {
      setState(() => _messages.add(const ChatMessage(
            text: 'Digite sua dúvida primeiro para que eu tente responder com a base da Petita antes de encaminhar para a UBS.',
            isUser: false,
            options: ['Enviar dúvida à UBS'],
          )));
      _scrollToBottom();
      return;
    }

    final profile = await _storage.loadProfile();
    final onlineProfile = await _online.loadOnlineProfile().catchError((_) => null);
    final activeProfile = onlineProfile ?? profile;

    if (!_online.isLoggedIn) {
      setState(() => _messages.add(const ChatMessage(
            text: 'Para enviar uma dúvida à UBS, você precisa estar conectada em uma conta online usando e-mail e senha. Mesmo sem login, você ainda pode montar, editar e gerar seu Plano de Parto offline.',
            isUser: false,
            options: ['Perfil da gestante', 'Montar meu plano'],
          )));
      _scrollToBottom();
      return;
    }

    final ubsCode = activeProfile?.ubsCode;
    if (ubsCode == null || ubsCode.isEmpty) {
      setState(() => _messages.add(const ChatMessage(
            text: 'Antes de enviar uma dúvida, selecione uma UBS oficial no seu perfil. Se você digitou uma UBS manualmente, ela aparece no PDF, mas as dúvidas não podem ser encaminhadas para a Equipe UBS.',
            isUser: false,
            options: ['Abrir cadastro', 'Montar meu plano'],
          )));
      _scrollToBottom();
      return;
    }

    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _ConfirmAnonymousSendDialog(),
    );
    if (accepted != true) return;

    try {
      final data = await _online.submitPatientQuestion(
        ubsCode: ubsCode,
        category: pending.category,
        questionText: pending.question,
        selfRiskLevel: pending.risk,
        warningSigns: pending.warningSigns,
        urgencyAcknowledged: pending.urgencyAcknowledged,
        expectedResponseNoticeAccepted: true,
      );
      final publicCode = data['public_code']?.toString() ?? 's/código';
      _pendingUbsQuestion = null;
      setState(() => _messages.add(ChatMessage(
            text: 'Sua dúvida foi enviada de forma anonimizada para a Equipe UBS.\n\nCódigo da dúvida: $publicCode\n\nA equipe verá a dúvida, a UBS vinculada, a autopercepção de risco e os sinais informados, mas não verá seu nome, e-mail ou outros dados pessoais.',
            isUser: false,
            options: const ['Minhas dúvidas', 'Montar meu plano', 'Ver meu plano'],
          )));
    } catch (e) {
      setState(() => _messages.add(ChatMessage(
            text: 'Não foi possível enviar sua dúvida agora. Verifique sua internet e tente novamente. Em caso de urgência, procure imediatamente um serviço de saúde.\n\nDetalhe técnico: $e',
            isUser: false,
            options: const ['Sinais de atenção', 'Montar meu plano'],
          )));
    }
    _scrollToBottom();
  }

  Future<void> _showManualUbsWarning() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('UBS fora da lista oficial'),
        content: const Text(
          'Você pode digitar o nome da sua UBS para que ele apareça no Plano de Parto gerado.\n\n'
          'Mas, se você não selecionar uma UBS oficial da lista, as dúvidas enviadas pelo chat não poderão ser encaminhadas nem respondidas pela Equipe UBS.\n\n'
          'A funcionalidade de dúvidas depende de uma UBS oficial cadastrada para preservar a organização Multi UBS do sistema.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Entendi')),
        ],
      ),
    );
  }

  Future<void> _handleOption(String option) async {
    if (option == 'Quero entender melhor' && _currentQuestion >= 0) {
      final explanation = BirthPlanExplanations.forQuestion(_questions[_currentQuestion].id);
      if (explanation != null) {
        setState(() {
          _messages.add(const ChatMessage(text: 'Quero entender melhor', isUser: true));
          _messages.add(ChatMessage(
            text: '$explanation\n\nAgora você pode escolher a opção que combina mais com o que deseja. Se ainda tiver dúvidas, converse com a equipe de saúde.',
            isUser: false,
            options: _questions[_currentQuestion].multiple
                ? [..._questions[_currentQuestion].options, 'Concluir seleção', 'Quero entender melhor']
                : [..._questions[_currentQuestion].options, 'Quero entender melhor'],
          ));
        });
        _scrollToBottom();
      }
      return;
    }
    if (option == 'Ver meu plano') {
      Navigator.pushNamed(context, AppRoutes.summary);
      return;
    }
    if (option == 'Minhas dúvidas') {
      Navigator.pushNamed(context, AppRoutes.myQuestions);
      return;
    }
    if (option == 'Perfil da gestante' || option == 'Abrir cadastro' || option == 'Criar cadastro local') {
      Navigator.pushNamed(context, AppRoutes.profile);
      return;
    }

    if (_currentQuestion >= 0 && !_questions[_currentQuestion].multiple) {
      final current = _questions[_currentQuestion];
      if (current.id == 'ubs_referencia' && option == 'Outra UBS') {
        await _showManualUbsWarning();
        setState(() {
          _messages.add(const ChatMessage(text: 'Outra UBS', isUser: true));
          _messages.add(const ChatMessage(
            text: 'Sem problema. Digite o nome da sua UBS de referência no campo de mensagem para registrar no plano.\n\nImportante: como ela não foi selecionada da lista oficial, ela aparecerá no PDF, mas as dúvidas não poderão ser respondidas pela Equipe UBS via chat até que uma UBS oficial seja vinculada ao seu perfil.',
            isUser: false,
          ));
        });
        _scrollToBottom();
        return;
      }
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
    final activeOptionsIndex = _messages.lastIndexWhere((message) => !message.isUser);
    return Scaffold(
      backgroundColor: const Color(0xFFFFFAFB),
      body: SafeArea(
        child: Column(
          children: [
            _ChatHeader(
              progress: _progress,
              currentSection: _currentSectionName,
              inPlanFlow: _currentQuestion >= 0,
              currentStep: _currentQuestion >= 0 ? _currentQuestion + 1 : 0,
              totalSteps: _questions.length,
            ),
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                itemCount: _messages.length + (_petitaSearching ? 1 : 0),
                itemBuilder: (context, index) {
                  if (_petitaSearching && index == _messages.length) {
                    return _PetitaTypingBubble(dotCount: _typingDots);
                  }
                  final msg = _messages[index];
                  return Column(crossAxisAlignment: msg.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start, children: [
                    _PetitaChatBubble(text: msg.text, isUser: msg.isUser),
                    if (!msg.isUser && msg.options.isNotEmpty && index == activeOptionsIndex)
                      Padding(
                        padding: const EdgeInsets.only(left: 40, top: 4, bottom: 8),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: msg.options.map((o) {
                            final isSelected = _currentQuestion >= 0 && _questions[_currentQuestion].multiple && _multiSelection.contains(o);
                            final isFinish = o == 'Concluir seleção';
                            final isHelp = o == 'Quero entender melhor';
                            return _ChoicePill(
                              label: o,
                              icon: isHelp ? Icons.lightbulb_outline_rounded : (isFinish ? Icons.check_circle_outline : _optionIcon(o)),
                              selected: isSelected,
                              primary: isFinish,
                              help: isHelp,
                              onTap: () => _handleOption(o),
                            );
                          }).toList(),
                        ),
                      ),
                  ]);
                },
              ),
            ),
            _ChatInput(controller: _controller, onSend: () => _send()),
          ],
        ),
      ),
    );
  }

  IconData _optionIcon(String label) {
    final s = label.toLowerCase();
    if (s.contains('plano')) return Icons.description_outlined;
    if (s.contains('dúvida') || s.contains('pergunta')) return Icons.chat_bubble_outline;
    if (s.contains('sinais') || s.contains('atenção')) return Icons.warning_amber_rounded;
    if (s.contains('ubs')) return Icons.local_hospital_outlined;
    if (s.contains('esposo') || s.contains('parceiro')) return Icons.favorite_border;
    if (s.contains('mãe')) return Icons.person_outline;
    if (s.contains('doula')) return Icons.volunteer_activism_outlined;
    if (s.contains('familiar')) return Icons.groups_outlined;
    if (s.contains('não')) return Icons.person_off_outlined;
    return Icons.radio_button_unchecked;
  }
}

class _ChatHeader extends StatelessWidget {
  const _ChatHeader({
    required this.progress,
    required this.currentSection,
    required this.inPlanFlow,
    required this.currentStep,
    required this.totalSteps,
  });

  final double progress;
  final String currentSection;
  final bool inPlanFlow;
  final int currentStep;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.background,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 5))],
      ),
      child: Column(children: [
        Row(children: [
          InkWell(
            onTap: () => Navigator.pop(context),
            borderRadius: BorderRadius.circular(18),
            child: const Padding(padding: EdgeInsets.all(8), child: Icon(Icons.arrow_back, color: AppColors.primaryPink)),
          ),
          Container(padding: const EdgeInsets.all(3), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: AppColors.primaryPink.withOpacity(0.14), blurRadius: 12)]), child: CircleAvatar(radius: 19, backgroundColor: AppColors.softPink, child: ClipOval(child: Image.asset('assets/images/petita.png', fit: BoxFit.cover)))),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Petita', style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.petDarkBlue, fontSize: 17)),
              Text('Assistente PET Saúde', style: TextStyle(color: AppColors.textPrimary, fontSize: 12)),
            ]),
          ),
          IconButton(onPressed: () => Navigator.pushNamed(context, AppRoutes.profile), icon: const Icon(Icons.person_outline, color: AppColors.petDarkBlue)),
        ]),
        if (inPlanFlow) ...[
          const SizedBox(height: 10),
          Row(children: [
            Text(currentSection, style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.petDarkBlue)),
            const Spacer(),
            Text('$currentStep/$totalSteps', style: const TextStyle(fontSize: 12, color: AppColors.primaryPink, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: AppColors.softPink,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryPink),
            ),
          ),
        ],
      ]),
    );
  }
}

class _PetitaChatBubble extends StatelessWidget {
  const _PetitaChatBubble({required this.text, required this.isUser});
  final String text;
  final bool isUser;

  @override
  Widget build(BuildContext context) {
    final bubble = Container(
      constraints: const BoxConstraints(maxWidth: 330),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isUser ? AppColors.primaryPink.withOpacity(0.78) : Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(20),
          topRight: const Radius.circular(20),
          bottomLeft: Radius.circular(isUser ? 20 : 6),
          bottomRight: Radius.circular(isUser ? 6 : 20),
        ),
        border: isUser ? null : Border.all(color: AppColors.softPink),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Text(text, style: TextStyle(color: isUser ? Colors.white : AppColors.textPrimary, height: 1.28, fontWeight: isUser ? FontWeight.w700 : FontWeight.w500)),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            CircleAvatar(radius: 17, backgroundColor: AppColors.softPink, child: ClipOval(child: Image.asset('assets/images/petita.png', fit: BoxFit.cover))),
            const SizedBox(width: 8),
          ],
          Flexible(child: bubble),
        ],
      ),
    );
  }
}

class _PetitaTypingBubble extends StatelessWidget {
  const _PetitaTypingBubble({required this.dotCount});

  final int dotCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        CircleAvatar(
          radius: 17,
          backgroundColor: AppColors.softPink,
          child: ClipOval(child: Image.asset('assets/images/petita.png', fit: BoxFit.cover)),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomLeft: Radius.circular(6),
                bottomRight: Radius.circular(20),
              ),
              border: Border.all(color: AppColors.softPink),
            ),
            child: Text.rich(
              TextSpan(children: [
                const TextSpan(text: 'Petita está buscando uma resposta', style: TextStyle(fontWeight: FontWeight.w600)),
                TextSpan(
                  text: List.filled(dotCount, '.').join(),
                  style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.primaryPink),
                ),
              ]),
              softWrap: true,
            ),
          ),
        ),
      ]),
    );
  }
}

class _ChoicePill extends StatelessWidget {
  const _ChoicePill({required this.label, required this.icon, required this.onTap, this.selected = false, this.primary = false, this.help = false});
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool selected;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final filled = selected || primary;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        decoration: BoxDecoration(
          color: filled ? AppColors.primaryPink : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.primaryPink.withOpacity(0.7)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.025), blurRadius: 6, offset: const Offset(0, 3))],
        ),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width - 96),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 18, color: filled ? Colors.white : AppColors.primaryPink),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              label,
              softWrap: true,
              overflow: TextOverflow.visible,
              style: TextStyle(color: filled ? Colors.white : AppColors.primaryPink, fontWeight: FontWeight.w900),
            ),
          ),
        ]),
      ),
    );
  }
}

class _ChatInput extends StatelessWidget {
  const _ChatInput({required this.controller, required this.onSend});
  final TextEditingController controller;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
        color: AppColors.background,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                decoration: const InputDecoration(hintText: 'Digite sua mensagem...'),
                onSubmitted: (_) => onSend(),
              ),
            ),
            const SizedBox(width: 8),
            FloatingActionButton.small(
              onPressed: onSend,
              backgroundColor: AppColors.primaryPink,
              foregroundColor: Colors.white,
              child: const Icon(Icons.send),
            ),
          ]),
          const SizedBox(height: 6),
          const Text(
            'A Petita pode cometer erros. Confirme informações importantes com a equipe de saúde.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10.5, color: Color(0xFF777777), height: 1.2),
          ),
        ]),
      ),
    );
  }
}

class _QuestionDialogResult {
  const _QuestionDialogResult({
    required this.category,
    required this.question,
    required this.risk,
    required this.warningSigns,
    required this.urgencyAcknowledged,
    required this.expectedResponseNoticeAccepted,
  });

  final String category;
  final String question;
  final String risk;
  final List<String> warningSigns;
  final bool urgencyAcknowledged;
  final bool expectedResponseNoticeAccepted;
}


class _ConfirmAnonymousSendDialog extends StatefulWidget {
  const _ConfirmAnonymousSendDialog();

  @override
  State<_ConfirmAnonymousSendDialog> createState() => _ConfirmAnonymousSendDialogState();
}

class _ConfirmAnonymousSendDialogState extends State<_ConfirmAnonymousSendDialog> {
  bool _anonymousAck = false;
  bool _responseAck = false;

  bool get _canSend => _anonymousAck && _responseAck;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Enviar para a Equipe UBS'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.softPink,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.primaryPink.withOpacity(0.35)),
            ),
            child: const Text(
              'Sua dúvida será encaminhada de forma anônima. A Equipe UBS não verá seu nome, e-mail, telefone, CPF, cartão SUS ou plano completo.',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 12),
          CheckboxListTile(
            value: _anonymousAck,
            onChanged: (v) => setState(() => _anonymousAck = v ?? false),
            title: const Text('Entendi que a dúvida será enviada de forma anônima.'),
          ),
          CheckboxListTile(
            value: _responseAck,
            onChanged: (v) => setState(() => _responseAck = v ?? false),
            title: const Text('Entendi que a resposta não é imediata e depende da disponibilidade da UBS.'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
        FilledButton(onPressed: _canSend ? () => Navigator.pop(context, true) : null, child: const Text('Enviar')),
      ],
    );
  }
}

class _QuestionToUbsDialog extends StatefulWidget {
  const _QuestionToUbsDialog({required this.categories});

  final List<String> categories;

  @override
  State<_QuestionToUbsDialog> createState() => _QuestionToUbsDialogState();
}

class _QuestionToUbsDialogState extends State<_QuestionToUbsDialog> {
  final _questionController = TextEditingController();
  String _category = 'Plano de Parto';
  String _risk = 'low';
  bool _urgencyAck = false;
  final Set<String> _warningSigns = <String>{};

  static const _warnings = <String>[
    'Sangramento vaginal',
    'Perda de líquido pela vagina',
    'Dor de cabeça intensa ou visão turva',
    'Dor abdominal forte',
    'Febre',
    'Falta de ar importante',
    'Desmaio ou convulsão',
    'Pressão alta',
    'Diminuição dos movimentos do bebê',
  ];

  bool get _canSend => _questionController.text.trim().isNotEmpty && _urgencyAck;

  @override
  void initState() {
    super.initState();
    if (widget.categories.isNotEmpty) _category = widget.categories.first;
  }

  @override
  Widget build(BuildContext context) {
    final highRisk = _risk == 'high' || _warningSigns.isNotEmpty;
    return AlertDialog(
      title: const Text('Verificar dúvida'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.softPink,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.primaryPink.withOpacity(0.35)),
              ),
              child: const Text(
                'Este canal não é atendimento de urgência. As respostas dependem da disponibilidade da UBS e podem não ser imediatas. Em caso de sinais de alerta, procure uma maternidade, pronto atendimento ou serviço de urgência.',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              value: _category,
              items: (widget.categories.isEmpty
                      ? const ['Plano de Parto', 'Sinais de atenção', 'Trabalho de parto', 'Nascimento', 'Cuidados com o bebê', 'Pós-parto', 'Outros']
                      : widget.categories)
                  .map((category) => DropdownMenuItem(value: category, child: Text(category)))
                  .toList(),
              onChanged: (value) => setState(() => _category = value ?? _category),
              decoration: const InputDecoration(labelText: 'Categoria da dúvida'),
            ),
            const SizedBox(height: 12),
            TextField(controller: _questionController, maxLines: 4, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'Digite sua dúvida')),
            const SizedBox(height: 12),
            const Text('Como você classifica sua dúvida?', style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.petDarkBlue)),
            RadioListTile<String>(value: 'low', groupValue: _risk, onChanged: (v) => setState(() => _risk = v ?? 'low'), title: const Text('Baixo risco'), subtitle: const Text('Dúvida geral, educativa ou sobre Plano de Parto.')),
            RadioListTile<String>(value: 'medium', groupValue: _risk, onChanged: (v) => setState(() => _risk = v ?? 'medium'), title: const Text('Médio risco'), subtitle: const Text('Estou preocupada, mas sem sinais de urgência.')),
            RadioListTile<String>(value: 'high', groupValue: _risk, onChanged: (v) => setState(() => _risk = v ?? 'high'), title: const Text('Alto risco'), subtitle: const Text('Tenho sintomas importantes ou insegurança sobre procurar atendimento.')),
            const SizedBox(height: 8),
            const Text('Você apresenta algum destes sinais agora?', style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.petDarkBlue)),
            ..._warnings.map((warning) => CheckboxListTile(
                  value: _warningSigns.contains(warning),
                  dense: true,
                  onChanged: (value) => setState(() {
                    if (value == true) {
                      _warningSigns.add(warning);
                    } else {
                      _warningSigns.remove(warning);
                    }
                  }),
                  title: Text(warning),
                )),
            if (highRisk)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFFFFF3E8), borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.petOrange)),
                child: const Text('Atenção: se você marcou alto risco ou algum sinal de alerta, este canal pode não ser adequado. Procure atendimento presencial imediatamente se precisar de avaliação rápida.', style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.petDarkBlue)),
              ),
            CheckboxListTile(value: _urgencyAck, onChanged: (v) => setState(() => _urgencyAck = v ?? false), title: const Text('Entendi que este canal não é para urgências.')),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: _canSend
              ? () => Navigator.pop(
                    context,
                    _QuestionDialogResult(category: _category, question: _questionController.text.trim(), risk: _risk, warningSigns: _warningSigns.toList(), urgencyAcknowledged: _urgencyAck, expectedResponseNoticeAccepted: false),
                  )
              : null,
          child: const Text('Continuar'),
        ),
      ],
    );
  }
}
