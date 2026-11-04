import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../../config/app_theme.dart';
import '../../models/birth_plan_answer.dart';
import '../../models/birth_plan_question.dart';
import '../../models/treatment_preferences.dart';
import '../../services/birth_plan_flow_service.dart';
import '../../services/pdf_service.dart';
import '../../services/storage_service.dart';
import '../../services/supabase_service.dart';
import '../../widgets/app_button.dart';
import '../../widgets/section_card.dart';

class BirthPlanSummaryScreen extends StatefulWidget {
  const BirthPlanSummaryScreen({super.key});

  @override
  State<BirthPlanSummaryScreen> createState() => _BirthPlanSummaryScreenState();
}

class _BirthPlanSummaryScreenState extends State<BirthPlanSummaryScreen> {
  final _storage = StorageService();
  final _online = SupabaseService();
  List<BirthPlanQuestion> _questions = [];
  List<BirthPlanAnswer> _answers = [];
  TreatmentPreferences? _treatment;
  bool _loading = true;
  bool _generatingPdf = false;
  final _consultationNotesController = TextEditingController();
  Set<String> _pendingForConsultation = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final questions = await BirthPlanFlowService().loadQuestions();
    final answers = await _storage.loadAnswers();
    final treatment = await _storage.loadTreatmentPreferences();
    final pending = await _storage.loadConsultationPending();
    final notes = await _storage.loadConsultationNotes();
    if (mounted) {
      setState(() {
        _questions = questions;
        _answers = answers;
        _treatment = treatment;
        _pendingForConsultation = pending;
        _consultationNotesController.text = notes;
        _loading = false;
      });
    }
  }

  Future<void> _generatePdf(BirthPlanPdfFormat format) async {
    if (_answers.isEmpty || _generatingPdf) return;
    setState(() => _generatingPdf = true);
    // Deixe o indicador visivel antes da etapa intensiva de criacao do PDF.
    await WidgetsBinding.instance.endOfFrame;
    try {
      final bytes = await PdfService().buildBirthPlanPdf(
        questions: _questions,
        answers: _answers,
        format: format,
        treatment: _treatment,
      );
      if (!mounted) return;
      setState(() => _generatingPdf = false);
      final filename = format == BirthPlanPdfFormat.resumoVisual
          ? 'plano_de_parto_resumo_pet_saude.pdf'
          : 'plano_de_parto_declaracao_pet_saude.pdf';
      await Printing.sharePdf(bytes: bytes, filename: filename);
    } on BirthPlanPdfTooLongException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível preparar o PDF. Suas respostas continuam salvas.')),
      );
    } finally {
      if (mounted) setState(() => _generatingPdf = false);
    }
  }
 


  @override
  void dispose() {
    _consultationNotesController.dispose();
    super.dispose();
  }

  Future<void> _answerDeferredQuestion(BirthPlanQuestion question) async {
    final selected = <String>{};
    final freeText = TextEditingController();
    try {
      final result = await showDialog<List<String>>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(builder: (ctx, refresh) {
          final typed = freeText.text.trim();
          final canSave = typed.isNotEmpty || selected.isNotEmpty;
          return AlertDialog(
            title: const Text('Responder com a profissional'),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(question.question, style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  ...question.options.map((option) => CheckboxListTile(
                    title: Text(option),
                    value: selected.contains(option),
                    controlAffinity: ListTileControlAffinity.leading,
                    onChanged: (value) => refresh(() {
                      if (question.multiple) {
                        if (value == true) { selected.add(option); } else { selected.remove(option); }
                      } else {
                        selected.clear();
                        if (value == true) selected.add(option);
                      }
                    }),
                  )),
                  const SizedBox(height: 12),
                  TextField(
                    controller: freeText,
                    maxLines: 3,
                    maxLength: 500,
                    onChanged: (_) => refresh(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Minha resposta escrita (opcional)',
                      hintText: 'Preencha durante ou depois da consulta',
                    ),
                  ),
                ],
              )),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
              FilledButton(
                onPressed: canSave ? () => Navigator.pop(ctx, [
                  ...selected,
                  if (typed.isNotEmpty) typed,
                ]) : null,
                child: const Text('Salvar minha escolha'),
              ),
            ],
          );
        }),
      );
      if (result == null || result.isEmpty) return;
      final updated = await _storage.loadAnswers();
      updated.removeWhere((a) => a.questionId == question.id);
      updated.add(BirthPlanAnswer(questionId: question.id, values: result));
      await _storage.saveAnswers(updated);
      await _storage.resolveQuestionForConsultation(question.id);
      await _load();
    } finally {
      freeText.dispose();
    }
  }

  Future<void> _saveConsultationNotes() async {
    await _storage.saveConsultationNotes(_consultationNotesController.text);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Dúvidas para a consulta salvas neste aparelho.')),
    );
  }

  Future<void> _shareConsultationGuide() async {
    if (_generatingPdf) return;
    // Salva o que estiver digitado antes de montar o roteiro.
    await _storage.saveConsultationNotes(_consultationNotesController.text);
    if (!mounted) return;
    setState(() => _generatingPdf = true);
    await WidgetsBinding.instance.endOfFrame;
    try {
      final bytes = await PdfService().buildConsultationGuidePdf(
        questions: _questions,
        pendingQuestionIds: _pendingForConsultation,
        notes: _consultationNotesController.text,
      );
      if (!mounted) return;
      setState(() => _generatingPdf = false);
      await Printing.sharePdf(bytes: bytes, filename: 'petita_assuntos_para_consulta.pdf');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível preparar o roteiro. Suas dúvidas permanecem salvas.')),
      );
    } finally {
      if (mounted) setState(() => _generatingPdf = false);
    }
  }

  Future<void> _editTreatment() async {
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Como prefere ser tratada ou tratado?'),
        children: [
          for (final value in [
            'Ela/dela', 'Ele/dele', 'Elu/delu',
            'Prefiro que usem meu nome', 'Quero escrever outra forma',
            'Prefiro não informar',
          ])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, value),
              child: Text(value),
            ),
        ],
      ),
    );
    if (choice == null || !mounted) return;
    var selection = choice == 'Prefiro não informar' ? '' : choice;
    if (choice == 'Quero escrever outra forma') {
      final field = TextEditingController(text: _treatment?.pronouns ?? '');
      try {
        final text = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Escreva sua preferência de tratamento'),
            content: TextField(
              controller: field,
              autofocus: true,
              maxLength: 120,
              decoration: const InputDecoration(hintText: 'Como você gostaria de ser chamada ou chamado?'),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
              FilledButton(onPressed: () => Navigator.pop(ctx, field.text.trim()), child: const Text('Salvar')),
            ],
          ),
        );
        if (text == null || text.trim().isEmpty) return;
        selection = text.trim();
      } finally {
        field.dispose();
      }
    }
    await _storage.saveTreatmentPreferences(
      TreatmentPreferences(pronouns: selection),
    );
    await _load();
  }

  Future<void> _setIncludeInPdf(bool value) async {
    final preference = _treatment;
    if (preference == null || !preference.hasPronouns) return;
    await _storage.saveTreatmentPreferences(
      preference.copyWith(includeInPdf: value),
    );
    await _load();
  }

  Future<void> _syncOnline() async {
    if (_answers.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sincronizar dados com o serviço online?'),
        content: const Text(
          'O envio incluirá dados do perfil e as respostas do Plano de Parto, '
          'que podem conter informações pessoais e de saúde. '
          'Você pode continuar utilizando a Petita offline sem sincronizar. '
          'Leia a Política de Privacidade antes de escolher.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Manter só neste dispositivo')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Confirmar envio')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final answerMap = {for (final a in _answers) a.questionId: a.values.join(', ')};
    final profile = await _storage.loadProfile();
    try {
      await _online.syncBirthPlan(
        patientName: answerMap['nome_gestante'] ?? profile?.name ?? 'Gestante',
        ubsCode: profile?.ubsCode,
        dppBr: answerMap['dpp'],
        companion: answerMap['acompanhante_principal'],
        answers: _answers,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Plano de Parto sincronizado com Supabase.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Não foi possível sincronizar agora. O plano continua salvo offline. Detalhe: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final answerMap = {for (final a in _answers) a.questionId: a.values.join(', ')};
    final resumoDados = [
      answerMap['nome_gestante'] ?? 'Nome não informado',
      answerMap['ubs_referencia'] ?? 'UBS não informada',
      "DPP ${answerMap['dpp'] ?? 'não informada'}",
    ].join(' • ');
    return Scaffold(
      appBar: AppBar(title: const Text('Meu Plano de Parto')),
      body: Stack(children: [SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Plano de Parto PET Saúde', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.petDarkBlue)),
              const SizedBox(height: 8),
              const Text('Resumo das preferências registradas pela gestante durante a conversa com a Petita.'),
              const SizedBox(height: 8),
              Text(resumoDados, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              const Text('As informações principais são mantidas offline no aparelho para não prejudicar a gestante sem internet.'),
              const SizedBox(height: 8),
              const Text('Escolha entre a declaração em texto corrido, com espaço para assinaturas, e o resumo visual por tópicos. Ambos incluem as logos da UFCG e do PET Saúde. Revise suas respostas antes de compartilhar.'),
            ])),
            if (_answers.isNotEmpty)
              SectionCard(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Como deseja ser chamada ou chamado?',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.petDarkBlue)),
                  const SizedBox(height: 8),
                  Text(_treatment?.hasPronouns == true
                    ? _treatment!.pronouns
                    : 'Não informado (opcional)'),
                  TextButton.icon(
                    onPressed: _editTreatment,
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Alterar minha preferência de tratamento'),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Incluir minha preferência de tratamento nos PDFs'),
                    subtitle: const Text('Opcional. A equipe só verá essa informação no documento se você autorizar.'),
                    value: (_treatment?.hasPronouns ?? false) && (_treatment?.includeInPdf ?? false),
                    onChanged: (_treatment?.hasPronouns ?? false) ? _setIncludeInPdf : null,
                  ),
                ],
              )),
            if (_answers.isEmpty)
              SectionCard(child: Column(children: [
                Image.asset('assets/images/petita.png', height: 150),
                const SizedBox(height: 10),
                const Text('Você ainda não construiu seu plano. Volte ao chat e toque em "Montar meu plano".', textAlign: TextAlign.center),
              ])),
            ..._questions.where((q) => answerMap.containsKey(q.id)).map((q) => SectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(q.section, style: const TextStyle(color: AppColors.primaryPink, fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 5),
              Text(q.question, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(answerMap[q.id] ?? 'Não informado', style: const TextStyle(color: AppColors.textPrimary)),
            ]))),

            SectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Para conversar no pré-natal',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.petDarkBlue)),
              const SizedBox(height: 6),
              const Text('Estas questões não foram respondidas e não serão registradas como preferências no Plano de Parto. Você pode retomá-las junto da profissional.'),
              if (_pendingForConsultation.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text('Nenhuma pergunta foi deixada em aberto para consulta.'),
                ),
              ..._questions.where((q) => _pendingForConsultation.contains(q.id)).map((q) =>
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(q.section, style: const TextStyle(color: AppColors.primaryPink, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Text(q.question, style: const TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: () => _answerDeferredQuestion(q),
                          icon: const Icon(Icons.edit_note),
                          label: const Text('Responder com a profissional'),
                        ),
                      ]),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text('Outras dúvidas que quero levar à consulta',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: _consultationNotesController,
                maxLines: 4,
                maxLength: 1500,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Escreva aqui. Este texto ficará apenas no seu aparelho.',
                ),
              ),
              const SizedBox(height: 6),
              AppButton(label: 'Salvar minhas dúvidas', icon: Icons.save_outlined,
                  onPressed: _saveConsultationNotes, outlined: true),
              const SizedBox(height: 10),
              AppButton(label: 'Gerar roteiro da próxima consulta', icon: Icons.picture_as_pdf_outlined,
                  outlined: true, onPressed: _shareConsultationGuide),
            ])),
            const SizedBox(height: 10),
            if (_answers.isNotEmpty)
              AppButton(label: 'Gerar PDF — declaração para assinatura', icon: Icons.picture_as_pdf, onPressed: () => _generatePdf(BirthPlanPdfFormat.declaracao)),
            const SizedBox(height: 10),
            if (_answers.isNotEmpty)
              AppButton(label: 'Gerar PDF — resumo visual e registro completo', icon: Icons.description_outlined, outlined: true, onPressed: () => _generatePdf(BirthPlanPdfFormat.resumoVisual)),
            const SizedBox(height: 10),
            if (_answers.isNotEmpty)
              AppButton(label: 'Sincronizar plano online', icon: Icons.cloud_upload_outlined, outlined: true, onPressed: _syncOnline),
            const SizedBox(height: 10),
            AppButton(label: 'Limpar plano local', outlined: true, icon: Icons.delete_outline, onPressed: () async { await _storage.clearAnswers(); await _load(); }),
          ]),
        ),
      ),
      if (_generatingPdf)
        Positioned.fill(
          child: AbsorbPointer(
            child: Container(
              color: Colors.white.withAlpha(235),
              child: const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                CircularProgressIndicator(),
                SizedBox(height: 20),
                Text('Preparando seu Plano de Parto...',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: AppColors.petDarkBlue)),
                SizedBox(height: 8),
                Text('Suas respostas estão salvas. Não precisa tocar novamente.',
                    textAlign: TextAlign.center),
              ])),
            ),
          ),
        ),
      ]),
    );
  }
}
