import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
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
  final _teamEmailController = TextEditingController();
  final _teamNameController = TextEditingController();
  final _docTitleController = TextEditingController();
  final _docDescriptionController = TextEditingController();
  final _kbCategoryController = TextEditingController(text: 'Plano de Parto');
  final _kbQuestionController = TextEditingController();
  final _kbKeywordsController = TextEditingController();
  final _kbAnswerController = TextEditingController();

  List<UbsUnit> _official = [];
  UserProfile? _profile;
  String? _selectedTeamUbsCode = 'UBS-EV-001';
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final official = await UbsService().loadOfficialUnits();
    UserProfile? profile;
    try {
      profile = await _online.loadOnlineProfile();
    } catch (_) {
      profile = null;
    }
    if (!mounted) return;
    setState(() {
      _official = official;
      _profile = profile;
      _loading = false;
      _selectedTeamUbsCode ??= official.isNotEmpty ? official.first.code : null;
    });
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
      await _online.createUbs(code: code, name: name, city: _cityController.text.trim().isEmpty ? 'Campina Grande' : _cityController.text.trim());
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

  Future<void> _approveTeam() async {
    final email = _teamEmailController.text.trim();
    final name = _teamNameController.text.trim();
    final ubsCode = _selectedTeamUbsCode;
    if (email.isEmpty || ubsCode == null || ubsCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Informe o e-mail da conta e a UBS vinculada.')));
      return;
    }
    setState(() => _busy = true);
    try {
      await _online.approveUbsTeamByEmail(email: email, name: name, ubsCode: ubsCode);
      _teamEmailController.clear();
      _teamNameController.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Conta liberada como Equipe UBS.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Não foi possível liberar Equipe UBS: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addKnowledgeOnline() async {
    final category = _kbCategoryController.text.trim();
    final question = _kbQuestionController.text.trim();
    final keywords = _kbKeywordsController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
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
              _approveTeamCard(),
              _knowledgeBaseCard(),
              _documentGuidanceCard(),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _loginCard() {
    return SectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
  }

  Widget _officialUbsCard() {
    return SectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('UBS oficiais cadastradas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.primaryPink)),
      const SizedBox(height: 8),
      ..._official.map((u) => ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.local_hospital_outlined, color: AppColors.petBlue),
            title: Text(u.name),
            subtitle: Text('${u.code} • ${u.city}/${u.state}'),
          )),
    ]));
  }

  Widget _createUbsCard() {
    return SectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
  }

  Widget _approveTeamCard() {
    return SectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Liberar acesso da Equipe UBS', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.primaryPink)),
      const SizedBox(height: 8),
      const Text('A equipe cria uma conta com e-mail e senha. Depois, o administrador informa o e-mail aqui e vincula essa conta à UBS correta.'),
      const SizedBox(height: 12),
      TextField(controller: _teamEmailController, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'E-mail da conta da equipe')),
      const SizedBox(height: 10),
      TextField(controller: _teamNameController, decoration: const InputDecoration(labelText: 'Nome da equipe/profissional')),
      const SizedBox(height: 10),
      DropdownButtonFormField<String>(
        value: _selectedTeamUbsCode,
        items: _official.map((unit) => DropdownMenuItem(value: unit.code, child: Text(unit.name))).toList(),
        onChanged: (value) => setState(() => _selectedTeamUbsCode = value),
        decoration: const InputDecoration(labelText: 'UBS vinculada'),
      ),
      const SizedBox(height: 10),
      AppButton(label: 'Liberar como Equipe UBS', icon: Icons.verified_user_outlined, onPressed: _busy ? () {} : _approveTeam),
    ]));
  }

  Widget _knowledgeBaseCard() {
    return SectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Base da Petita', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.primaryPink)),
      const SizedBox(height: 8),
      const Text('Cadastre perguntas, palavras-chave e respostas validadas. A Petita deve responder apenas com conteúdo aprovado pela equipe responsável.'),
      const SizedBox(height: 10),
      TextField(controller: _kbCategoryController, decoration: const InputDecoration(labelText: 'Categoria')),
      const SizedBox(height: 10),
      TextField(controller: _kbQuestionController, decoration: const InputDecoration(labelText: 'Pergunta padrão')),
      const SizedBox(height: 10),
      TextField(controller: _kbKeywordsController, decoration: const InputDecoration(labelText: 'Palavras-chave separadas por vírgula')),
      const SizedBox(height: 10),
      TextField(controller: _kbAnswerController, maxLines: 5, decoration: const InputDecoration(labelText: 'Resposta validada')),
      const SizedBox(height: 10),
      AppButton(label: 'Cadastrar resposta', icon: Icons.library_add_outlined, onPressed: _busy ? () {} : _addKnowledgeOnline),
    ]));
  }

  Widget _documentGuidanceCard() {
    return SectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Documentos de apoio', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.primaryPink)),
      const SizedBox(height: 8),
      const Text('Documentos técnicos e materiais de referência devem ser usados para elaborar respostas validadas. O cadastro da resposta final deve ser feito na Base da Petita.'),
      const SizedBox(height: 12),
      TextField(controller: _docTitleController, decoration: const InputDecoration(labelText: 'Título do documento de referência')),
      const SizedBox(height: 10),
      TextField(controller: _docDescriptionController, maxLines: 3, decoration: const InputDecoration(labelText: 'Observações internas sobre o documento')),
    ]));
  }
}
