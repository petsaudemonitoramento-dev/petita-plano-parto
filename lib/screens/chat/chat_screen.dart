import 'dart:async';
import 'package:flutter/material.dart';
import '../../config/app_routes.dart';
import '../../config/app_theme.dart';
import '../../models/birth_plan_answer.dart';
import '../../models/birth_plan_question.dart';
import '../../models/chat_message.dart';
import '../../models/treatment_preferences.dart';
import '../../services/birth_plan_flow_service.dart';
import '../../services/gestational_age_service.dart';
import '../../services/birth_plan_explanations.dart';
import '../../services/chatbot_service.dart';
import '../../services/faq_search_service.dart';
import '../../services/storage_service.dart';
import '../../services/supabase_service.dart';

enum _PlanStartChoice { resume, restart, summary }

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
  bool _answering = false;
  bool _textInputEnabled = true;
  bool _awaitingPronouns = false;
  bool _pronounCustomInput = false;
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

  bool get _weeksCalculatedAutomatically => _answers.any((answer) =>
      answer.questionId == 'semanas_gestacao' &&
      answer.values.isNotEmpty &&
      answer.values.first.contains('(estimativa em '));

  int get _visibleTotalSteps => _questions.length - (_weeksCalculatedAutomatically ? 1 : 0);

  int get _visibleCurrentStep {
    if (_currentQuestion < 0) return 0;
    return _currentQuestion + 1 -
        (_weeksCalculatedAutomatically && _currentQuestion > 2 ? 1 : 0);
  }

  double get _progress {
    if (_questions.isEmpty || _currentQuestion < 0) return 0;
    return (_visibleCurrentStep / _visibleTotalSteps).clamp(0, 1).toDouble();
  }

  String get _currentSectionName {
    if (_currentQuestion < 0 || _questions.isEmpty) return 'Conversa com a Petita';
    return _questions[_currentQuestion].section;
  }

  Future<void> _send([String? override]) async {
    if (_petitaSearching || _answering) return;
    final text = (override ?? _controller.text).trim();
    if (text.isEmpty) return;
    if (!_textInputEnabled && override == null) return;
    _controller.clear();

    if (_awaitingPronouns) {
      if (!_pronounCustomInput) return;
      await _savePronouns(text);
      return;
    }

    if (_currentQuestion >= 0) {
      final question = _questions[_currentQuestion];
      if (question.id == 'dpp' && GestationalAgeService.parseDpp(text) == null) {
        _controller.text = text;
        setState(() => _messages.add(const ChatMessage(
          text: 'Essa data não parece válida. Digite sua DPP no formato dia/mês/ano, por exemplo 18/11/2026.',
          isUser: false,
        )));
        _scrollToBottom();
        return;
      }
      final q = _questions[_currentQuestion];
      if (q.multiple) {
        final values = {..._multiSelection, text}.toList();
        setState(() => _messages.add(ChatMessage(text: values.join(', '), isUser: true)));
        await _answerCurrentQuestion(values);
      } else {
        setState(() => _messages.add(ChatMessage(text: text, isUser: true)));
        await _answerCurrentQuestion([text]);
      }
      return;
    }

    setState(() => _messages.add(ChatMessage(text: text, isUser: true)));
    await Future.delayed(const Duration(milliseconds: 160));
    if (!mounted || ModalRoute.of(context)?.isCurrent == false) return;

    if (text == 'Montar meu plano') {
      await _startPlanFlow();
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
      await Future.delayed(const Duration(milliseconds: 480));
      if (!mounted) return;
      setState(() => _messages.add(reply));
    } finally {
      _setPetitaSearching(false);
    }
    _scrollToBottom();
  }

  Future<void> _startPlanFlow() async {
    // A versão anterior retomava silenciosamente a primeira pergunta não
    // respondida. Quem tocava em "Montar meu plano" via "Etapa 10 de 31"
    // sem saber que suas respostas antigas ainda estavam salvas no navegador.
    final saved = await _storage.loadAnswers();
    if (!mounted) return;

    var answers = saved;
    var restarting = false;
    if (saved.isNotEmpty) {
      final answeredIds = saved.map((answer) => answer.questionId).toSet();
      final completed = _questions.every((q) => answeredIds.contains(q.id));
      final choice = await showDialog<_PlanStartChoice>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Encontramos um plano salvo'),
          content: Text(
            'Este dispositivo tem ${saved.length} resposta(s) armazenada(s). '
            'Você pode continuar de onde parou ou começar um novo plano.\n\n'
            'Começar de novo apagará as respostas e os pronomes deste plano '
            'salvos neste dispositivo, mas não apagará seu perfil nem seu aceite.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, _PlanStartChoice.restart),
              child: const Text('Começar novo plano'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(
                dialogContext,
                completed ? _PlanStartChoice.summary : _PlanStartChoice.resume,
              ),
              child: Text(completed ? 'Ver plano salvo' : 'Continuar meu plano'),
            ),
          ],
        ),
      );
      if (!mounted || choice == null) return;
      if (choice == _PlanStartChoice.summary) {
        Navigator.pushNamed(context, AppRoutes.summary);
        return;
      }
      if (choice == _PlanStartChoice.restart) {
        await _storage.clearAnswers();
        answers = [];
        restarting = true;
      }
    }

    if (!mounted) return;
    _answers = answers;
    final answeredIds = _answers.map((answer) => answer.questionId).toSet();
    final next = _questions.indexWhere((question) => !answeredIds.contains(question.id));
    _currentQuestion = next < 0 ? 0 : next;
    _multiSelection.clear();
    _awaitingPronouns = false;
    _pronounCustomInput = false;
    _textInputEnabled = false;
    _controller.clear();
    setState(() {
      if (restarting) _messages = [_chatbot.welcome()];
      _messages.add(ChatMessage(
        text: restarting
            ? 'Vamos criar um novo Plano de Parto! 💜 As respostas do plano anterior foram apagadas deste dispositivo.'
            : 'Que bom que vamos construir esse plano! 💜 Aqui você pode pensar nas suas preferências com tranquilidade. Não existe resposta certa ou errada: o importante é que suas escolhas sejam ouvidas. Se algum termo parecer difícil, toque em “Quero entender melhor”.',
        isUser: false,
      ));
    });
    await _showCurrentQuestion();
  }

  Future<void> _showCurrentQuestion() async {
    if (_currentQuestion < 0 || _currentQuestion >= _questions.length) return;
    _setPetitaSearching(true);
    await Future.delayed(const Duration(milliseconds: 520));
    if (!mounted || _currentQuestion < 0 || _currentQuestion >= _questions.length) return;
    _setPetitaSearching(false);
    final q = _questions[_currentQuestion];
    _multiSelection.clear();
    final options = q.multiple ? [...q.options, 'Concluir seleção'] : [...q.options];
    if (q.options.isNotEmpty) options.add('Escrever minha resposta');
    if (BirthPlanExplanations.forQuestion(q.id) != null) {
      options.add('Quero entender melhor');
    }
    final intro = _introForQuestion(q);
    setState(() {
      _textInputEnabled = q.options.isEmpty || q.id == 'nome_gestante' || q.id == 'observacoes_finais';
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
    if (q.id == 'nome_gestante') return 'Que bom ter você aqui! 💜 Vamos começar com calma. Primeiro, me conte algumas informações para identificar seu plano.';
    if (q.id == 'ubs_referencia') return 'Obrigada por compartilhar essas informações comigo. 💗 Agora vamos identificar a UBS que acompanha você. Se não souber, tudo bem: podemos conversar sobre isso.';
    if (section.contains('acompanhante')) return 'Você merece se sentir acolhida e acompanhada. 💜 Vamos conversar sobre quem você gostaria de ter ao seu lado nesse momento.';
    if (section.contains('trabalho')) return 'Cada parto tem seu próprio ritmo, e suas preferências importam. 🌷 Vamos conhecer algumas possibilidades para o trabalho de parto, sempre considerando sua segurança e a avaliação da equipe.';
    if (section.contains('alívio')) return 'É natural ter dúvidas sobre as sensações do parto. 💗 Existem formas diferentes de buscar conforto e aliviar a dor. Vou ajudar você a conhecer essas opções.';
    if (section.contains('nascimento')) return 'Estamos chegando a uma parte muito especial: o nascimento. 💜 Vamos registrar o que é importante para você nesse momento.';
    if (section.contains('bebê')) return 'Agora vamos pensar nos primeiros momentos com seu bebê. 🌷 Vou explicar as opções para que você possa fazer escolhas informadas.';
    if (section.contains('cesárea')) return 'Mesmo quando uma cesárea é necessária, sua voz continua sendo importante. 💜 Vamos conversar sobre as preferências que podem ser consideradas com segurança.';
    if (section.contains('observ')) return 'Você chegou até aqui! 💗 Antes de terminar, há algo que gostaria que a equipe soubesse sobre seus desejos, preocupações ou necessidades?';
    return '';
  }

  void _showPronounsPrompt() {
    setState(() {
      _awaitingPronouns = true;
      _pronounCustomInput = false;
      _textInputEnabled = false;
      _messages.add(const ChatMessage(
        text: 'Antes de continuar: como você prefere que a Petita e a equipe se refiram a você? 💜\n\n'
            'Pronomes são palavras usadas no lugar do nome de alguém. '
            'Exemplos: “Ela escolheu”, “Ele escolheu”, “Elu escolheu”. '
            '“Elu” é uma forma neutra usada por algumas pessoas. '
            'Você também pode pedir que usem apenas seu nome ou não informar. '
            'Sua escolha é opcional e não muda seus cuidados de saúde.',
        isUser: false,
        options: [
          'Ela/dela',
          'Ele/dele',
          'Elu/delu',
          'Prefiro que usem meu nome',
          'Quero escrever outra forma',
          'Prefiro não informar',
        ],
      ));
    });
    _scrollToBottom();
  }

  Future<void> _savePronouns(String pronouns) async {
    await _storage.saveTreatmentPreferences(
      TreatmentPreferences(pronouns: pronouns),
    );
    if (!mounted) return;
    setState(() {
      _messages.add(ChatMessage(
        text: pronouns.isEmpty ? 'Prefiro não informar' : pronouns,
        isUser: true,
      ));
      _awaitingPronouns = false;
      _pronounCustomInput = false;
      _textInputEnabled = false;
    });
    await _showCurrentQuestion();
  }

  Future<void> _answerCurrentQuestion(List<String> values) async {
    if (_answering || _currentQuestion < 0) return;
    final q = _questions[_currentQuestion];
    final cleaned = values.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (cleaned.isEmpty) return;
    _answering = true;
    try {
      _answers.removeWhere((a) => a.questionId == q.id);
      _answers.add(BirthPlanAnswer(questionId: q.id, values: cleaned));
      String? gestationalEstimate;
      if (q.id == 'dpp') {
        gestationalEstimate = GestationalAgeService.estimate(cleaned.first);
        _answers.removeWhere((a) => a.questionId == 'semanas_gestacao');
        if (gestationalEstimate != null) {
          _answers.add(BirthPlanAnswer(
            questionId: 'semanas_gestacao',
            values: [gestationalEstimate],
          ));
        }
      }
      await _storage.saveAnswers(_answers);
      if (!mounted) return;

      _currentQuestion++;
      if (q.id == 'dpp' && gestationalEstimate != null &&
          _currentQuestion < _questions.length &&
          _questions[_currentQuestion].id == 'semanas_gestacao') {
        _currentQuestion++;
      }
      if (q.id == 'nome_gestante' &&
          await _storage.loadTreatmentPreferences() == null) {
        _showPronounsPrompt();
        return;
      }
      if (_currentQuestion >= _questions.length) {
        setState(() => _messages.add(const ChatMessage(
            text: 'Você conseguiu! 💜 Obrigada por compartilhar suas escolhas comigo. Seu Plano de Parto está pronto para ser revisado com calma. Você pode conferir as respostas, conversar com a equipe de saúde e gerar o PDF quando quiser.',
            isUser: false,
            options: ['Ver meu plano'],
          )));
        _currentQuestion = -1;
        _multiSelection.clear();
        _textInputEnabled = true;
        _scrollToBottom();
      } else {
        await _showCurrentQuestion();
      }
    } finally {
      _answering = false;
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
            text: 'Sua dúvida foi encaminhada à UBS vinculada ao seu perfil.\n\nCódigo da dúvida: $publicCode\n\nSeus dados cadastrais não são exibidos à equipe, mas evite informações identificáveis no texto. A UBS pode ou não responder, sem prazo definido. Caso precise de atendimento, procure a unidade presencialmente.',
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
    if (_petitaSearching || _answering) return;
    if (_awaitingPronouns) {
      if (option == 'Quero escrever outra forma') {
        setState(() {
          _pronounCustomInput = true;
          _textInputEnabled = true;
          _messages.add(const ChatMessage(
            text: 'Escreva como prefere ser tratada ou tratado. Por exemplo: “Use apenas meu nome”.',
            isUser: false,
          ));
        });
        _scrollToBottom();
        return;
      }
      await _savePronouns(option == 'Prefiro não informar' ? '' : option);
      return;
    }
    if (_currentQuestion >= 0 &&
        _questions[_currentQuestion].allowOther &&
        (option == 'Outro' || option == 'Outra preferência' || option == 'Outra posição')) {
      setState(() {
        _textInputEnabled = true;
        _messages.add(const ChatMessage(
          text: 'Pode explicar sua outra preferência com suas próprias palavras. Só seguirei após o envio.',
          isUser: false,
        ));
      });
      _scrollToBottom();
      return;
    }
    if (option == 'Escrever minha resposta' && _currentQuestion >= 0) {
      setState(() {
        _textInputEnabled = true;
        _messages.add(const ChatMessage(
          text: 'Pode escrever sua resposta no campo abaixo. Só avançarei depois que você enviar.',
          isUser: false,
        ));
      });
      _scrollToBottom();
      return;
    }
    if (option == 'Quero entender melhor' && _currentQuestion >= 0) {
      final explanation = BirthPlanExplanations.forQuestion(_questions[_currentQuestion].id);
      if (explanation != null) {
        setState(() {
          _messages.add(const ChatMessage(text: 'Quero entender melhor', isUser: true));
          _messages.add(ChatMessage(
            text: '$explanation\n\nAgora você pode escolher a opção que combina mais com o que deseja. Se ainda tiver dúvidas, converse com a equipe de saúde.',
            isUser: false,
            options: _questions[_currentQuestion].multiple
                ? [..._questions[_currentQuestion].options, 'Concluir seleção', 'Escrever minha resposta', 'Quero entender melhor']
                : [..._questions[_currentQuestion].options, 'Escrever minha resposta', 'Quero entender melhor'],
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
      if (current.allowOther && option == 'Sim, vou descrever') {
        setState(() {
          _textInputEnabled = true;
          _messages.add(ChatMessage(text: option, isUser: true));
          _messages.add(const ChatMessage(
            text: 'Digite sua resposta no campo de mensagem para registrar no plano.',
            isUser: false,
          ));
        });
        _scrollToBottom();
        return;
      }
      if (current.id == 'ubs_referencia' && option == 'Outra UBS') {
        await _showManualUbsWarning();
        if (!mounted) return;
        setState(() {
          _textInputEnabled = true;
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
          setState(() => _messages.add(ChatMessage(
                text: 'Selecione pelo menos uma opção ou toque em “Escrever minha resposta”.',
                isUser: false,
                options: [..._questions[_currentQuestion].options, 'Concluir seleção', 'Escrever minha resposta',
                  if (BirthPlanExplanations.forQuestion(_questions[_currentQuestion].id) != null)
                    'Quero entender melhor'],
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
      backgroundColor: const Color(0xFFF9F6FF),
      body: SafeArea(
        child: Column(
          children: [
            _ChatHeader(
              progress: _progress,
              currentSection: _currentSectionName,
              inPlanFlow: _currentQuestion >= 0,
              currentStep: _visibleCurrentStep,
              totalSteps: _visibleTotalSteps,
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
                        padding: const EdgeInsets.only(left: 10, top: 8, bottom: 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: msg.options.map((o) {
                            final isSelected = _currentQuestion >= 0 && _questions[_currentQuestion].multiple && _multiSelection.contains(o);
                            final isFinish = o == 'Concluir seleção';
                            final isHelp = o == 'Quero entender melhor';
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _ChoicePill(
                                label: o,
                                icon: isHelp ? Icons.lightbulb_outline_rounded : (isFinish ? Icons.check_circle_outline : _optionIcon(o)),
                                selected: isSelected,
                                primary: isFinish,
                                help: isHelp,
                                onTap: () => _handleOption(o),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                  ]);
                },
              ),
            ),
            _ChatInput(
              controller: _controller,
              enabled: _textInputEnabled,
              onSend: () => _send(),
            ),
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF6332AB), Color(0xFFAB53D8), Color(0xFFE56BAC)]),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha((255 * 0.04).round()), blurRadius: 12, offset: const Offset(0, 5))],
      ),
      child: Column(children: [
        Row(children: [
          InkWell(
            onTap: () => Navigator.pop(context),
            borderRadius: BorderRadius.circular(18),
            child: const Padding(padding: EdgeInsets.all(8), child: Icon(Icons.arrow_back, color: Colors.white)),
          ),
          Container(padding: const EdgeInsets.all(3), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: AppColors.primaryPink.withAlpha((255 * 0.14).round()), blurRadius: 12)]), child: CircleAvatar(radius: 19, backgroundColor: AppColors.softPink, child: ClipOval(child: Image.asset('assets/images/petita.png', fit: BoxFit.cover)))),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Petita', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 19)),
              Text('Com você em cada escolha 💗', style: TextStyle(color: Colors.white, fontSize: 12)),
            ]),
          ),
          IconButton(onPressed: () => Navigator.pushNamed(context, AppRoutes.profile), icon: const Icon(Icons.person_outline, color: Colors.white)),
        ]),
        if (inPlanFlow) ...[
          const SizedBox(height: 10),
          Row(children: [
            Flexible(child: Text(currentSection, style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white), overflow: TextOverflow.ellipsis)),
            const Spacer(),
            Text('Etapa $currentStep de $totalSteps', style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
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
      constraints: const BoxConstraints(maxWidth: 360),
      padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 16),
      decoration: BoxDecoration(
        color: isUser ? const Color(0xFF8741C6) : Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(20),
          topRight: const Radius.circular(20),
          bottomLeft: Radius.circular(isUser ? 20 : 6),
          bottomRight: Radius.circular(isUser ? 6 : 20),
        ),
        border: isUser ? null : Border.all(color: const Color(0xFFEDE3F8)),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha((255 * 0.04).round()), blurRadius: 8, offset: const Offset(0, 3))],
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
  final bool help;

  @override
  Widget build(BuildContext context) {
    final filled = selected || primary;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          color: filled ? AppColors.primaryPink : (help ? const Color(0xFFFFF0DC) : Colors.white),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: help ? const Color(0xFFE6A34E) : AppColors.primaryPink.withAlpha((255 * 0.7).round())),
          boxShadow: [BoxShadow(color: Colors.black.withAlpha((255 * 0.025).round()), blurRadius: 6, offset: const Offset(0, 3))],
        ),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width - 36),
        child: Row(mainAxisSize: MainAxisSize.max, children: [
          Icon(icon, size: 20, color: filled ? Colors.white : (help ? const Color(0xFF8B5D1D) : AppColors.primaryPink)),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              label,
              softWrap: true,
              overflow: TextOverflow.visible,
              style: TextStyle(fontSize: 15, color: filled ? Colors.white : (help ? const Color(0xFF8B5D1D) : AppColors.petDarkBlue), fontWeight: FontWeight.w700),
            ),
          ),
        ]),
      ),
    );
  }
}

class _ChatInput extends StatelessWidget {
  const _ChatInput({required this.controller, required this.enabled, required this.onSend});
  final TextEditingController controller;
  final bool enabled;
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
                enabled: enabled,
                minLines: 1,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: enabled ? 'Digite sua mensagem...' : 'Escolha uma opção ou toque em “Escrever minha resposta”',
                ),
                onSubmitted: (_) => onSend(),
              ),
            ),
            const SizedBox(width: 8),
            FloatingActionButton.small(
              onPressed: enabled ? onSend : null,
              backgroundColor: enabled ? AppColors.primaryPink : Colors.grey,
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
          const SizedBox(height: 4),
          const Text(
            'Desenvolvedor: Lucca Araújo',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10, color: Color(0xFF777777)),
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
              border: Border.all(color: AppColors.primaryPink.withAlpha((255 * 0.35).round())),
            ),
            child: const Text(
              'A equipe da sua UBS verá apenas o código e o conteúdo da dúvida, sem seus dados cadastrais ou seu plano completo. Evite colocar nome, telefone, endereço, CPF ou outros dados que possam identificá-la no texto.',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 12),
          CheckboxListTile(
            value: _anonymousAck,
            onChanged: (v) => setState(() => _anonymousAck = v ?? false),
            title: const Text('Entendi que meus dados de cadastro não serão exibidos à equipe, mas o texto que escrevo pode revelar minha identidade.'),
          ),
          CheckboxListTile(
            value: _responseAck,
            onChanged: (v) => setState(() => _responseAck = v ?? false),
            title: const Text('Entendi que a equipe não tem compromisso de responder por este canal e não há prazo de resposta. Em caso de urgência, procurarei atendimento presencial.'),
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

  bool get _canSend => _questionController.text.trim().isNotEmpty && _urgencyAck && _risk != 'high' && _warningSigns.isEmpty;

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
                border: Border.all(color: AppColors.primaryPink.withAlpha((255 * 0.35).round())),
              ),
              child: const Text(
                'Este canal é educativo e não funciona como plantão ou atendimento de urgência. A equipe não tem obrigação de responder por este canal. Para dúvida urgente ou sinais de alerta, procure pessoalmente sua UBS, uma maternidade, UPA ou serviço de urgência.',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _category,
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
            RadioGroup<String>(
              groupValue: _risk,
              onChanged: (value) => setState(() => _risk = value ?? _risk),
              child: Column(children: [
                RadioListTile<String>(value: 'low', title: const Text('Baixo risco'), subtitle: const Text('Dúvida geral, educativa ou sobre Plano de Parto.')),
                RadioListTile<String>(value: 'medium', title: const Text('Médio risco'), subtitle: const Text('Estou preocupada, mas sem sinais de urgência.')),
                RadioListTile<String>(value: 'high', title: const Text('Alto risco'), subtitle: const Text('Tenho sintomas importantes ou insegurança sobre procurar atendimento.')),
              ]),
            ),
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
                child: const Text('Atenção: você marcou alto risco ou sinal de alerta. Não é possível enviar essa dúvida por aqui. Procure atendimento presencial imediatamente na UBS, maternidade, UPA ou serviço de urgência, conforme a situação.', style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.petDarkBlue)),
              ),
            CheckboxListTile(value: _urgencyAck, onChanged: (v) => setState(() => _urgencyAck = v ?? false), title: const Text('Entendi que dúvidas urgentes e sinais de alerta exigem atendimento presencial e não serão encaminhados por este canal.')),
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
