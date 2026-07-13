import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../models/support_document.dart';
import '../../models/ubs_unit.dart';
import '../../models/user_profile.dart';
import '../../services/supabase_service.dart';
import '../../services/ubs_service.dart';
import '../../widgets/app_button.dart';
import '../../widgets/section_card.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final _online = SupabaseService();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  final _cityController = TextEditingController(text: 'Campina Grande');
  final _newCategoryController = TextEditingController();
  final _docTitleController = TextEditingController();
  final _kbQuestionController = TextEditingController();
  final _kbKeywordsController = TextEditingController();
  final _kbAnswerController = TextEditingController();

  List<UbsUnit> _official = [];
  List<KnowledgeCategory> _categories = [];
  List<TeamAccessRequest> _teamRequests = [];
  List<SupportDocument> _documents = [];
  SupportStorageUsage _storageUsage = const SupportStorageUsage(
    usedBytes: 0,
    maxBytes: SupabaseService.supportStorageApplicationLimitBytes,
  );
  UserProfile? _profile;
  PlatformFile? _selectedFile;
  String? _selectedCategory;
  bool _loading = true;
  bool _busy = false;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _load();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_profile?.isAdmin == true && _documents.any((document) => document.isProcessing)) {
        _refreshDocumentsOnly();
      }
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _codeController.dispose();
    _cityController.dispose();
    _newCategoryController.dispose();
    _docTitleController.dispose();
    _kbQuestionController.dispose();
    _kbKeywordsController.dispose();
    _kbAnswerController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final official = await UbsService().loadOfficialUnits();
    UserProfile? profile;
    List<KnowledgeCategory> categories = [];
    List<TeamAccessRequest> teamRequests = [];
    List<SupportDocument> documents = [];
    var storageUsage = _storageUsage;
    try {
      profile = await _online.loadOnlineProfile();
      if (profile?.isAdmin == true) {
        categories = await _online.listKnowledgeCategories();
        teamRequests = await _online.listTeamAccessRequests();
        documents = await _online.listSupportDocuments();
        storageUsage = await _online.getSupportStorageUsage();
      }
    } catch (_) {
      profile = null;
    }
    if (categories.isEmpty) {
      categories = const [
        KnowledgeCategory(name: 'Plano de Parto', active: true),
        KnowledgeCategory(name: 'Sinais de atenção', active: true),
        KnowledgeCategory(name: 'Acompanhante e apoio', active: true),
        KnowledgeCategory(name: 'Trabalho de parto', active: true),
        KnowledgeCategory(name: 'Nascimento', active: true),
        KnowledgeCategory(name: 'Cuidados com o bebê', active: true),
        KnowledgeCategory(name: 'Cesárea', active: true),
        KnowledgeCategory(name: 'Pós-parto', active: true),
      ];
    }
    if (!mounted) return;
    setState(() {
      _official = official;
      _profile = profile;
      _categories = categories;
      _teamRequests = teamRequests;
      _documents = documents;
      _storageUsage = storageUsage;
      _selectedCategory ??= categories.isNotEmpty ? categories.first.name : 'Plano de Parto';
      _loading = false;
    });
  }

  Future<void> _refreshDocumentsOnly() async {
    try {
      final documents = await _online.listSupportDocuments();
      final usage = await _online.getSupportStorageUsage();
      if (!mounted) return;
      setState(() {
        _documents = documents;
        _storageUsage = usage;
      });
    } catch (_) {}
  }

  Future<void> _signIn() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Informe e-mail e senha.')));
      return;
    }
    setState(() => _busy = true);
    try {
      await _online.signIn(email: email, password: password);
      await _load();
      if (!mounted) return;
      if (_profile?.isAdmin != true) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Login realizado, mas esta conta não possui permissão de administrador.')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Não foi possível entrar: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signOut() async {
    await _online.signOut();
    await _load();
  }

  Future<void> _addUbsOnline() async {
    final name = _nameController.text.trim();
    final code = _codeController.text.trim().toUpperCase();
    if (name.isEmpty || code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Informe código e nome da UBS.')));
      return;
    }
    setState(() => _busy = true);
    try {
      await _online.createUbs(
        code: code,
        name: name,
        city: _cityController.text.trim().isEmpty ? 'Campina Grande' : _cityController.text.trim(),
      );
      _nameController.clear();
      _codeController.clear();
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('UBS cadastrada.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Não foi possível cadastrar UBS: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _decideRequest(TeamAccessRequest request, bool approve) async {
    setState(() => _busy = true);
    try {
      await _online.decideTeamAccessRequest(requestId: request.id, approve: approve);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(approve ? 'Solicitação aprovada.' : 'Solicitação recusada.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Não foi possível atualizar solicitação: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addCategory() async {
    final name = _newCategoryController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Informe o nome da categoria.')));
      return;
    }
    setState(() => _busy = true);
    try {
      await _online.addKnowledgeCategory(name: name);
      _newCategoryController.clear();
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Categoria cadastrada.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Não foi possível cadastrar categoria: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addKnowledgeOnline() async {
    final category = _selectedCategory ?? '';
    final question = _kbQuestionController.text.trim();
    final keywords = _kbKeywordsController.text
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();
    final answer = _kbAnswerController.text.trim();
    if (category.isEmpty || question.isEmpty || answer.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Informe categoria, pergunta e resposta.')));
      return;
    }
    setState(() => _busy = true);
    try {
      await _online.addKnowledgeBaseItem(category: category, question: question, keywords: keywords, answer: answer);
      _kbQuestionController.clear();
      _kbKeywordsController.clear();
      _kbAnswerController.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Resposta cadastrada na base da Petita.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Não foi possível cadastrar resposta: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickDocument() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'docx'],
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    if (file.size > SupabaseService.maxSupportFileBytes) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('O arquivo ultrapassa o limite de 20 MB.')));
      return;
    }
    setState(() {
      _selectedFile = file;
      if (_docTitleController.text.trim().isEmpty) {
        _docTitleController.text = file.name.replaceAll(RegExp(r'\.(pdf|docx)$', caseSensitive: false), '');
      }
    });
  }

  Future<void> _uploadDocument() async {
    final file = _selectedFile;
    final category = _selectedCategory;
    if (file == null || category == null || category.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecione um arquivo e uma categoria.')));
      return;
    }
    setState(() => _busy = true);
    try {
      await _online.uploadSupportDocument(
        title: _docTitleController.text.trim(),
        category: category,
        file: file,
      );
      _docTitleController.clear();
      setState(() => _selectedFile = null);
      await _refreshDocumentsOnly();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Documento anexado. A Petita está processando o conteúdo automaticamente.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Não foi possível anexar o documento: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removeDocument(SupportDocument document) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover documento'),
        content: Text('Remover "${document.title}"? O arquivo, os trechos e os vetores usados pela Petita serão apagados.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remover')),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busy = true);
    try {
      await _online.deleteSupportDocument(document.id);
      await _refreshDocumentsOnly();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Documento removido da base da Petita.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final isAdmin = _profile?.isAdmin == true;
    return Scaffold(
      appBar: AppBar(title: const Text('Administração')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Painel administrativo', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.petDarkBlue)),
              const SizedBox(height: 8),
              Text(isAdmin
                  ? 'Administrador conectado. As funções de cadastro e manutenção estão liberadas.'
                  : 'Esta área é restrita. Entre com e-mail e senha de uma conta administradora para acessar os cadastros do sistema.'),
            ])),
            if (!isAdmin) _loginCard(),
            if (isAdmin) ...[
              SectionCard(child: Row(children: [
                Expanded(child: Text('Conectado como ${_profile!.email}', style: const TextStyle(fontWeight: FontWeight.w700))),
                TextButton.icon(onPressed: _signOut, icon: const Icon(Icons.logout), label: const Text('Sair')),
              ])),
              _officialUbsCard(),
              _createUbsCard(),
              _teamRequestsCard(),
              _categoriesCard(),
              _knowledgeBaseCard(),
              _documentsCard(),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _loginCard() => SectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Entrar como administrador', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.primaryPink)),
        const SizedBox(height: 8),
        const Text('Somente contas com perfil de administrador conseguem visualizar e alterar cadastros internos.'),
        const SizedBox(height: 12),
        TextField(controller: _emailController, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'E-mail')),
        const SizedBox(height: 10),
        TextField(controller: _passwordController, obscureText: true, decoration: const InputDecoration(labelText: 'Senha')),
        const SizedBox(height: 10),
        AppButton(label: 'Entrar', icon: Icons.login, onPressed: _busy ? () {} : _signIn),
      ]));

  Widget _officialUbsCard() => SectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('UBS oficiais cadastradas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.primaryPink)),
        const SizedBox(height: 8),
        ..._official.map((unit) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.local_hospital_outlined, color: AppColors.petBlue),
              title: Text(unit.name),
              subtitle: Text('${unit.code} • ${unit.city}/${unit.state}'),
            )),
      ]));

  Widget _createUbsCard() => SectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Cadastrar nova UBS', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.primaryPink)),
        const SizedBox(height: 8),
        TextField(controller: _codeController, decoration: const InputDecoration(labelText: 'Código da UBS, ex: UBS-NOME-004')),
        const SizedBox(height: 10),
        TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Nome da UBS')),
        const SizedBox(height: 10),
        TextField(controller: _cityController, decoration: const InputDecoration(labelText: 'Cidade')),
        const SizedBox(height: 10),
        AppButton(label: 'Cadastrar UBS', icon: Icons.add_business_outlined, onPressed: _busy ? () {} : _addUbsOnline),
      ]));

  Widget _teamRequestsCard() => SectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Solicitações da Equipe UBS', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.primaryPink)),
        const SizedBox(height: 8),
        const Text('A profissional solicita acesso na área Equipe UBS. O administrador recebe a solicitação em lista e pode aceitar ou recusar.'),
        const SizedBox(height: 12),
        if (_teamRequests.isEmpty) const Text('Nenhuma solicitação pendente no momento.'),
        ..._teamRequests.map((request) => Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: AppColors.primaryPink.withOpacity(0.25))),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(request.name.isEmpty ? request.email : request.name, style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.petDarkBlue)),
                  Text(request.email),
                  Text('UBS solicitada: ${request.ubsCode}'),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: AppButton(label: 'Aceitar', icon: Icons.check_circle_outline, onPressed: _busy ? () {} : () => _decideRequest(request, true))),
                    const SizedBox(width: 8),
                    Expanded(child: AppButton(label: 'Recusar', icon: Icons.cancel_outlined, outlined: true, onPressed: _busy ? () {} : () => _decideRequest(request, false))),
                  ]),
                ]),
              ),
            )),
      ]));

  Widget _categoriesCard() => SectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Categorias da Petita', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.primaryPink)),
        const SizedBox(height: 8),
        const Text('As respostas e documentos usam as mesmas categorias disponíveis para a gestante. Cadastre uma nova categoria quando surgir outro assunto.'),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: _categories.map((category) => Chip(label: Text(category.name))).toList()),
        const SizedBox(height: 12),
        TextField(controller: _newCategoryController, decoration: const InputDecoration(labelText: 'Nova categoria')),
        const SizedBox(height: 10),
        AppButton(label: 'Cadastrar categoria', icon: Icons.category_outlined, onPressed: _busy ? () {} : _addCategory),
      ]));

  Widget _categoryDropdown({String label = 'Categoria vinculada'}) => DropdownButtonFormField<String>(
        value: _selectedCategory,
        isExpanded: true,
        items: _categories.map((category) => DropdownMenuItem(value: category.name, child: Text(category.name))).toList(),
        onChanged: (value) => setState(() => _selectedCategory = value),
        decoration: InputDecoration(labelText: label),
      );

  Widget _knowledgeBaseCard() => SectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Base da Petita', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.primaryPink)),
        const SizedBox(height: 8),
        const Text('Cadastre respostas fixas validadas. A Petita consulta essa base antes da busca semântica nos documentos.'),
        const SizedBox(height: 10),
        _categoryDropdown(),
        const SizedBox(height: 10),
        TextField(controller: _kbQuestionController, decoration: const InputDecoration(labelText: 'Pergunta padrão')),
        const SizedBox(height: 10),
        TextField(controller: _kbKeywordsController, decoration: const InputDecoration(labelText: 'Palavras-chave separadas por vírgula')),
        const SizedBox(height: 10),
        TextField(controller: _kbAnswerController, maxLines: 5, decoration: const InputDecoration(labelText: 'Resposta validada')),
        const SizedBox(height: 10),
        AppButton(label: 'Cadastrar resposta', icon: Icons.library_add_outlined, onPressed: _busy ? () {} : _addKnowledgeOnline),
      ]));

  Widget _documentsCard() => SectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Documentos de apoio', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.primaryPink)),
        const SizedBox(height: 8),
        const Text('Anexe PDF com texto selecionável ou DOCX. O sistema extrai o conteúdo, divide em trechos e cria a busca semântica automaticamente.'),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: Text('${_storageUsage.usedLabel} utilizados de ${_storageUsage.maxLabel}', style: const TextStyle(fontWeight: FontWeight.w800))),
          Text('${(_storageUsage.fraction * 100).toStringAsFixed(1)}%', style: const TextStyle(color: AppColors.primaryPink, fontWeight: FontWeight.w900)),
        ]),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: _storageUsage.fraction,
            minHeight: 10,
            backgroundColor: AppColors.softPink,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryPink),
          ),
        ),
        const SizedBox(height: 6),
        Text('${_storageUsage.remainingLabel} disponíveis no limite interno de 900 MB.', style: const TextStyle(fontSize: 12, color: AppColors.textPrimary)),
        const SizedBox(height: 16),
        _categoryDropdown(label: 'Categoria do documento'),
        const SizedBox(height: 10),
        TextField(controller: _docTitleController, decoration: const InputDecoration(labelText: 'Título do documento')),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _busy ? null : _pickDocument,
          icon: const Icon(Icons.attach_file),
          label: const Text('Selecionar PDF ou DOCX'),
        ),
        if (_selectedFile != null) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.softPink, borderRadius: BorderRadius.circular(14)),
            child: Text('${_selectedFile!.name} • ${(_selectedFile!.size / (1024 * 1024)).toStringAsFixed(1)} MB', style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
        const SizedBox(height: 10),
        AppButton(label: 'Anexar documento', icon: Icons.cloud_upload_outlined, onPressed: _busy ? () {} : _uploadDocument),
        const SizedBox(height: 8),
        const Text('Limite por arquivo: 20 MB. PDF escaneado ou sem texto selecionável será recusado durante o processamento.', style: TextStyle(fontSize: 12)),
        const Divider(height: 28),
        const Text('Documentos cadastrados', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.petDarkBlue)),
        const SizedBox(height: 8),
        if (_documents.isEmpty) const Text('Nenhum documento anexado.'),
        ..._documents.map(_documentTile),
      ]));

  Widget _documentTile(SupportDocument document) {
    final statusColor = document.isAvailable
        ? Colors.green
        : document.hasError
            ? Colors.red
            : AppColors.petOrange;
    final statusText = document.isAvailable
        ? 'Disponível para a Petita'
        : document.hasError
            ? 'Erro no processamento'
            : 'Processando';
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(top: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: statusColor.withOpacity(0.35))),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(document.mimeType == 'application/pdf' ? Icons.picture_as_pdf_outlined : Icons.description_outlined, color: AppColors.primaryPink),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(document.title, style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.petDarkBlue)),
              Text('${document.fileName} • ${document.formattedSize}'),
              Text('Categoria: ${document.category}'),
            ])),
            IconButton(
              tooltip: 'Remover documento',
              onPressed: _busy ? null : () => _removeDocument(document),
              icon: const Icon(Icons.delete_outline, color: Colors.red),
            ),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Icon(document.isAvailable ? Icons.check_circle_outline : document.hasError ? Icons.error_outline : Icons.hourglass_top_rounded, size: 18, color: statusColor),
            const SizedBox(width: 6),
            if (document.isProcessing)
              _ProcessingDots(prefix: statusText, color: statusColor)
            else
              Expanded(child: Text(statusText, style: TextStyle(fontWeight: FontWeight.w800, color: statusColor))),
          ]),
          if (document.isAvailable) Text('${document.chunkCount} trechos disponíveis para busca semântica.', style: const TextStyle(fontSize: 12)),
          if (document.hasError && document.processingError?.trim().isNotEmpty == true)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(document.processingError!, style: const TextStyle(fontSize: 12, color: Colors.red)),
            ),
        ]),
      ),
    );
  }
}

class _ProcessingDots extends StatefulWidget {
  const _ProcessingDots({required this.prefix, required this.color});
  final String prefix;
  final Color color;

  @override
  State<_ProcessingDots> createState() => _ProcessingDotsState();
}

class _ProcessingDotsState extends State<_ProcessingDots> {
  Timer? _timer;
  int _count = 1;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 450), (_) {
      if (mounted) setState(() => _count = _count == 3 ? 1 : _count + 1);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Text('${widget.prefix}${List.filled(_count, '.').join()}', style: TextStyle(fontWeight: FontWeight.w800, color: widget.color)),
    );
  }
}
