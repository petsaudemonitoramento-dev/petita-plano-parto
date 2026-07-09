import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../models/knowledge_document.dart';
import '../../models/ubs_unit.dart';
import '../../services/storage_service.dart';
import '../../services/ubs_service.dart';
import '../../widgets/app_button.dart';
import '../../widgets/section_card.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final _storage = StorageService();
  final _nameController = TextEditingController();
  final _cityController = TextEditingController(text: 'Campina Grande');
  final _docTitleController = TextEditingController();
  final _docDescriptionController = TextEditingController();

  List<UbsUnit> _official = [];
  List<UbsUnit> _custom = [];
  List<KnowledgeDocument> _documents = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final official = await UbsService().loadOfficialUnits();
    final custom = await _storage.loadCustomUbsUnits();
    final documents = await _storage.loadKnowledgeDocuments();
    if (!mounted) return;
    setState(() {
      _official = official;
      _custom = custom;
      _documents = documents;
      _loading = false;
    });
  }

  Future<void> _addUbs() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Informe o nome da UBS.')));
      return;
    }
    final code = 'UBS-CUSTOM-${DateTime.now().millisecondsSinceEpoch}';
    await _storage.addCustomUbsUnit(UbsUnit(
      code: code,
      name: name,
      city: _cityController.text.trim().isEmpty ? 'Campina Grande' : _cityController.text.trim(),
      state: 'PB',
      active: true,
    ));
    _nameController.clear();
    await _load();
  }

  Future<void> _addDocument() async {
    final title = _docTitleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Informe o título do documento.')));
      return;
    }
    await _storage.addKnowledgeDocument(KnowledgeDocument(
      id: 'DOC-${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      description: _docDescriptionController.text.trim().isEmpty ? 'Documento preparado para base de conhecimento da Petita.' : _docDescriptionController.text.trim(),
      sourceType: 'local_metadata_only',
      createdAt: DateTime.now(),
    ));
    _docTitleController.clear();
    _docDescriptionController.clear();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(title: const Text('Administração')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
              Text('Painel administrativo preparado', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.petDarkBlue)),
              SizedBox(height: 8),
              Text('Nesta versão offline, o painel simula cadastros locais. Na versão online, esta área será conectada ao Supabase para cadastrar UBS, equipes, documentos e base validada da Petita.'),
            ])),
            SectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('UBS oficiais iniciais', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.primaryPink)),
              const SizedBox(height: 8),
              ..._official.map((u) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.local_hospital_outlined, color: AppColors.petBlue),
                    title: Text(u.name),
                    subtitle: Text('${u.code} • ${u.city}/${u.state}'),
                  )),
            ])),
            SectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Cadastrar nova UBS', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.primaryPink)),
              const SizedBox(height: 8),
              const Text('Demonstração local. Na versão online, o administrador poderá criar, editar, ativar/desativar UBS no banco Supabase.'),
              const SizedBox(height: 12),
              TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Nome da UBS')),
              const SizedBox(height: 10),
              TextField(controller: _cityController, decoration: const InputDecoration(labelText: 'Cidade')),
              const SizedBox(height: 10),
              AppButton(label: 'Cadastrar UBS local', icon: Icons.add_business_outlined, onPressed: _addUbs),
              if (_custom.isNotEmpty) ...[
                const Divider(height: 24),
                const Text('UBS cadastradas localmente', style: TextStyle(fontWeight: FontWeight.w900)),
                ..._custom.map((u) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.business_outlined, color: AppColors.primaryPink),
                      title: Text(u.name),
                      subtitle: Text(u.code),
                    )),
              ],
            ])),
            SectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Documentos para base da Petita', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.primaryPink)),
              const SizedBox(height: 8),
              const Text('Registro demonstrativo. Na versão online, o upload real será feito no Supabase Storage e as respostas validadas alimentarão a base fixa/expandida do chatbot.'),
              const SizedBox(height: 12),
              TextField(controller: _docTitleController, decoration: const InputDecoration(labelText: 'Título do documento')),
              const SizedBox(height: 10),
              TextField(controller: _docDescriptionController, maxLines: 3, decoration: const InputDecoration(labelText: 'Descrição / uso na base de conhecimento')),
              const SizedBox(height: 10),
              AppButton(label: 'Registrar documento local', icon: Icons.upload_file_outlined, onPressed: _addDocument),
              if (_documents.isNotEmpty) ...[
                const Divider(height: 24),
                const Text('Documentos registrados localmente', style: TextStyle(fontWeight: FontWeight.w900)),
                ..._documents.map((d) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.description_outlined, color: AppColors.petBlue),
                      title: Text(d.title),
                      subtitle: Text(d.description),
                    )),
              ],
            ])),
          ]),
        ),
      ),
    );
  }
}
