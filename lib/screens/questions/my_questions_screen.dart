import 'package:flutter/material.dart';
import '../../config/app_routes.dart';
import '../../config/app_theme.dart';
import '../../models/patient_question_history.dart';
import '../../services/supabase_service.dart';
import '../../widgets/app_button.dart';
import '../../widgets/section_card.dart';

class MyQuestionsScreen extends StatefulWidget {
  const MyQuestionsScreen({super.key});

  @override
  State<MyQuestionsScreen> createState() => _MyQuestionsScreenState();
}

class _MyQuestionsScreenState extends State<MyQuestionsScreen> {
  final _online = SupabaseService();
  List<PatientQuestionHistory> _questions = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final questions = await _online.listMyQuestions();
      if (!mounted) return;
      setState(() => _questions = questions);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Minhas dúvidas')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              SectionCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Respostas da Equipe UBS', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: AppColors.petDarkBlue)),
                  const SizedBox(height: 8),
                  const Text('Aqui você acompanha as dúvidas encaminhadas de forma anônima e lê as respostas enviadas pela sua UBS.'),
                  const SizedBox(height: 10),
                  AppButton(label: 'Atualizar', icon: Icons.refresh, outlined: true, onPressed: _load),
                ]),
              ),
              if (_loading)
                const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator())),
              if (!_loading && _error != null)
                SectionCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Não foi possível carregar', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.red)),
                    const SizedBox(height: 8),
                    Text(_error!),
                    const SizedBox(height: 12),
                    AppButton(label: 'Ir para Perfil', icon: Icons.person_outline, onPressed: () => Navigator.pushNamed(context, AppRoutes.profile)),
                  ]),
                ),
              if (!_loading && _error == null && _questions.isEmpty)
                const SectionCard(
                  child: Text('Você ainda não encaminhou dúvidas para a Equipe UBS.'),
                ),
              if (!_loading && _error == null) ..._questions.map(_questionCard),
            ],
          ),
        ),
      ),
    );
  }

  Widget _questionCard(PatientQuestionHistory question) {
    final answered = question.isAnswered;
    final color = answered ? Colors.green : AppColors.petOrange;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: color.withOpacity(0.35))),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _openQuestion(question),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(answered ? Icons.mark_chat_read_outlined : Icons.schedule_outlined, color: color),
              const SizedBox(width: 8),
              Expanded(child: Text(answered ? 'Resposta disponível' : 'Enviada para a UBS', style: TextStyle(fontWeight: FontWeight.w900, color: color))),
              Text(question.publicCode, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 8),
            Text(question.questionText, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('${question.category} • ${_formatDate(question.createdAt)}', style: const TextStyle(fontSize: 12, color: AppColors.textPrimary)),
          ]),
        ),
      ),
    );
  }

  Future<void> _openQuestion(PatientQuestionHistory question) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(question.publicCode),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Minha dúvida', style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.petDarkBlue)),
              const SizedBox(height: 6),
              Text(question.questionText),
              const Divider(height: 28),
              Text(question.isAnswered ? 'Resposta da Equipe UBS' : 'Aguardando resposta da Equipe UBS', style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.primaryPink)),
              const SizedBox(height: 6),
              Text(question.isAnswered
                  ? question.answerText!
                  : 'A resposta não é imediata e depende da disponibilidade da UBS.'),
              if (question.answeredAt != null) ...[
                const SizedBox(height: 12),
                Text('Respondida em ${_formatDate(question.answeredAt!)}', style: const TextStyle(fontSize: 12)),
              ],
            ]),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fechar'))],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }
}
