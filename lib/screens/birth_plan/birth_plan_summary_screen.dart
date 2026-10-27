import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../models/birth_plan_answer.dart';
import '../../models/birth_plan_question.dart';
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
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final questions = await BirthPlanFlowService().loadQuestions();
    final answers = await _storage.loadAnswers();
    if (mounted) {
      setState(() {
        _questions = questions;
        _answers = answers;
        _loading = false;
      });
    }
  }

  Future<void> _generatePdf(BirthPlanPdfFormat format) async {
    if (_answers.isEmpty) return;
    try {
      await PdfService().shareBirthPlanPdf(questions: _questions, answers: _answers, format: format);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Não foi possível gerar/compartilhar o PDF: $e')));
    }
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
      body: SafeArea(
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
            const SizedBox(height: 10),
            if (_answers.isNotEmpty)
              AppButton(label: 'Gerar PDF — declaração para assinatura', icon: Icons.picture_as_pdf, onPressed: () => _generatePdf(BirthPlanPdfFormat.declaracao)),
            const SizedBox(height: 10),
            if (_answers.isNotEmpty)
              AppButton(label: 'Gerar PDF — resumo visual (modelo antigo)', icon: Icons.description_outlined, outlined: true, onPressed: () => _generatePdf(BirthPlanPdfFormat.resumoVisual)),
            const SizedBox(height: 10),
            if (_answers.isNotEmpty)
              AppButton(label: 'Sincronizar plano online', icon: Icons.cloud_upload_outlined, outlined: true, onPressed: _syncOnline),
            const SizedBox(height: 10),
            AppButton(label: 'Limpar plano local', outlined: true, icon: Icons.delete_outline, onPressed: () async { await _storage.clearAnswers(); await _load(); }),
          ]),
        ),
      ),
    );
  }
}
