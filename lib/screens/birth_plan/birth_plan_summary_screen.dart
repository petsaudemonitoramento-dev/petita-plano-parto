import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../models/birth_plan_answer.dart';
import '../../models/birth_plan_question.dart';
import '../../services/birth_plan_flow_service.dart';
import '../../services/pdf_service.dart';
import '../../services/storage_service.dart';
import '../../widgets/app_button.dart';
import '../../widgets/section_card.dart';

class BirthPlanSummaryScreen extends StatefulWidget {
  const BirthPlanSummaryScreen({super.key});

  @override
  State<BirthPlanSummaryScreen> createState() => _BirthPlanSummaryScreenState();
}

class _BirthPlanSummaryScreenState extends State<BirthPlanSummaryScreen> {
  final _storage = StorageService();
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

  Future<void> _generatePdf() async {
    try {
      await PdfService().shareBirthPlanPdf(questions: _questions, answers: _answers);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Não foi possível gerar/compartilhar o PDF: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final answerMap = {for (final a in _answers) a.questionId: a.values.join(', ')};
    return Scaffold(
      appBar: AppBar(title: const Text('Meu Plano de Parto')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
              Text('Plano de Parto PET Saúde', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.petDarkBlue)),
              SizedBox(height: 8),
              Text('Resumo das preferências registradas pela gestante durante a conversa com a Petita.'),
              SizedBox(height: 8),
              Text('Dados de demonstração: Laís Vitória de Sousa • UBS Estação Velha • DPP 18/11/2026', style: TextStyle(fontWeight: FontWeight.w700)),
            ])),
            if (_answers.isEmpty)
              SectionCard(child: Column(children: [
                Image.asset('assets/images/petita.png', height: 150),
                const SizedBox(height: 10),
                const Text('Você ainda não construiu seu plano. Volte ao chat e toque em "Montar meu plano".', textAlign: TextAlign.center),
              ])),
            ..._questions.map((q) => SectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(q.section, style: const TextStyle(color: AppColors.primaryPink, fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 5),
              Text(q.question, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(answerMap[q.id] ?? 'Não informado', style: const TextStyle(color: AppColors.textPrimary)),
            ]))),
            const SizedBox(height: 10),
            AppButton(label: 'Gerar PDF no modelo oficial', icon: Icons.picture_as_pdf, onPressed: _generatePdf),
            const SizedBox(height: 10),
            AppButton(label: 'Limpar plano local', outlined: true, icon: Icons.delete_outline, onPressed: () async { await _storage.clearAnswers(); await _load(); }),
          ]),
        ),
      ),
    );
  }
}
