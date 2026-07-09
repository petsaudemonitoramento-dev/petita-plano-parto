import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../models/ubs_question.dart';
import '../../services/storage_service.dart';
import '../../widgets/section_card.dart';

class UbsTeamScreen extends StatefulWidget {
  const UbsTeamScreen({super.key});

  @override
  State<UbsTeamScreen> createState() => _UbsTeamScreenState();
}

class _UbsTeamScreenState extends State<UbsTeamScreen> {
  final _storage = StorageService();
  List<UbsQuestion> _questions = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await _storage.loadUbsQuestions();
    if (mounted) setState(() => _questions = items.reversed.toList());
  }

  Future<void> _answer(UbsQuestion q) async {
    final controller = TextEditingController(text: q.answer ?? '');
    final answer = await showDialog<String>(context: context, builder: (context) => AlertDialog(
      title: const Text('Responder dúvida'),
      content: TextField(controller: controller, maxLines: 5, decoration: const InputDecoration(hintText: 'Resposta da equipe UBS...')),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')), ElevatedButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Salvar'))],
    ));
    if (answer == null || answer.trim().isEmpty) return;
    await _storage.answerUbsQuestion(q.id, answer.trim());
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Equipe UBS')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
              Text('Painel local da Equipe UBS', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.petDarkBlue)),
              SizedBox(height: 8),
              Text('Protótipo para demonstrar o fluxo futuro online: pacientes enviam dúvidas não urgentes e a equipe responde sem visualizar nome, CPF ou telefone.'),
            ])),
            if (_questions.isEmpty)
              const SectionCard(child: Text('Nenhuma dúvida registrada ainda. No chat, toque em "Enviar dúvida à UBS" para testar.')),
            ..._questions.map((q) => SectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.person_off_outlined, color: AppColors.primaryPink),
                const SizedBox(width: 8),
                Expanded(child: Text(q.anonymousUserId, style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.petDarkBlue))),
                Chip(label: Text(q.answered ? 'respondida' : 'pendente'), backgroundColor: q.answered ? const Color(0xFFE6F5EA) : AppColors.softPink),
              ]),
              const SizedBox(height: 8),
              Text(q.question),
              if (q.answered) ...[
                const Divider(),
                Text('Resposta: ${q.answer}', style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
              const SizedBox(height: 10),
              Align(alignment: Alignment.centerRight, child: ElevatedButton.icon(onPressed: () => _answer(q), icon: const Icon(Icons.reply), label: Text(q.answered ? 'Editar resposta' : 'Responder'))),
            ]))),
          ]),
        ),
      ),
    );
  }
}
