import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../models/ubs_unit.dart';
import '../../models/user_profile.dart';
import '../../services/supabase_service.dart';
import '../../services/ubs_service.dart';
import '../../widgets/app_button.dart';
import '../../widgets/section_card.dart';

class UbsTeamScreen extends StatefulWidget {
  const UbsTeamScreen({super.key});

  @override
  State<UbsTeamScreen> createState() => _UbsTeamScreenState();
}

class _UbsTeamScreenState extends State<UbsTeamScreen> {
  final _online = SupabaseService();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _answerController = TextEditingController();
  List<UbsUnit> _units = [];
  String? _selectedUbsCode = 'UBS-EV-001';
  UserProfile? _profile;
  List<AnonymousQuestion> _questions = [];
  AnonymousQuestion? _selected;
  bool _loading = true;
  bool _busy = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      _units = await UbsService().loadOfficialUnits();
      final profile = await _online.loadOnlineProfile();
      List<AnonymousQuestion> questions = [];
      if (profile?.isUbsTeam == true) {
        questions = await _online.listTeamQuestions();
      }
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _questions = questions;
        _message = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _message = 'Não foi possível carregar a área da UBS: $e';
        _loading = false;
      });
    }
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Login realizado.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Não foi possível entrar: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signUpTeam() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final ubsCode = _selectedUbsCode;
    if (name.isEmpty || email.isEmpty || password.length < 6 || ubsCode == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Informe nome, e-mail, senha com pelo menos 6 caracteres e UBS.')));
      return;
    }
    setState(() => _busy = true);
    try {
      await _online.signUpUbsTeam(name: name, email: email, password: password, ubsCode: ubsCode);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Solicitação de acesso registrada. Após a liberação pelo administrador, entre novamente com e-mail e senha.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Não foi possível cadastrar equipe: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _respond() async {
    final selected = _selected;
    final text = _answerController.text.trim();
    if (selected == null || text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecione uma dúvida e escreva a resposta.')));
      return;
    }
    setState(() => _busy = true);
    try {
      await _online.respondToQuestion(questionId: selected.id, answerText: text);
      _answerController.clear();
      _selected = null;
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Resposta enviada para a paciente.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Não foi possível responder: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signOut() async {
    await _online.signOut();
    if (!mounted) return;
    setState(() {
      _profile = null;
      _questions = [];
      _selected = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(title: const Text('Equipe UBS')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SectionCard(child: Column(children: const [
              Icon(Icons.groups_2_outlined, size: 76, color: AppColors.primaryPink),
              SizedBox(height: 12),
              Text('Área da Equipe UBS', textAlign: TextAlign.center, style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900, color: AppColors.petDarkBlue)),
              SizedBox(height: 8),
              Text('As dúvidas são exibidas de forma anonimizada. A equipe não vê nome, e-mail, telefone, CPF, cartão SUS ou plano completo da paciente.', textAlign: TextAlign.center),
            ])),
            if (_message != null) SectionCard(child: Text(_message!, style: const TextStyle(color: AppColors.petOrange))),
            if (_profile == null) _loginCard(),
            if (_profile != null && !_profile!.isUbsTeam) _notTeamCard(),
            if (_profile?.isUbsTeam == true) _teamArea(),
          ]),
        ),
      ),
    );
  }

  Widget _ubsDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _selectedUbsCode,
      items: _units.map((unit) => DropdownMenuItem(value: unit.code, child: Text(unit.name))).toList(),
      onChanged: (value) => setState(() => _selectedUbsCode = value),
      decoration: const InputDecoration(labelText: 'UBS vinculada'),
    );
  }

  Widget _loginCard() {
    return SectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Entrar ou solicitar acesso da Equipe UBS', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.primaryPink)),
      const SizedBox(height: 8),
      const Text('Para acessar as dúvidas, a equipe deve entrar com e-mail e senha. Novas contas precisam ser liberadas por uma conta administradora e vinculadas à UBS correta.'),
      const SizedBox(height: 12),
      TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Nome da equipe/profissional')),
      const SizedBox(height: 10),
      TextField(controller: _emailController, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'E-mail')),
      const SizedBox(height: 10),
      TextField(controller: _passwordController, obscureText: true, decoration: const InputDecoration(labelText: 'Senha')),
      const SizedBox(height: 10),
      _ubsDropdown(),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: AppButton(label: 'Entrar', icon: Icons.login, onPressed: _busy ? () {} : _signIn)),
        const SizedBox(width: 10),
        Expanded(child: AppButton(label: 'Solicitar acesso', icon: Icons.person_add_alt_1_outlined, outlined: true, onPressed: _busy ? () {} : _signUpTeam)),
      ]),
    ]));
  }

  Widget _notTeamCard() {
    return SectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Icon(Icons.lock_outline, size: 54, color: AppColors.petOrange),
      const SizedBox(height: 8),
      Text('Conta conectada como ${_profile!.role}, mas esta área é exclusiva da Equipe UBS.'),
      const SizedBox(height: 12),
      const Text('Aguarde a liberação do administrador para acessar as dúvidas vinculadas à UBS.'),
      const SizedBox(height: 10),
      AppButton(label: 'Sair', icon: Icons.logout, outlined: true, onPressed: _signOut),
    ]));
  }

  Widget _teamArea() {
    return Column(children: [
      SectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('UBS vinculada: ${_profile!.ubsCode ?? 'não informada'}', style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.petDarkBlue)),
        const SizedBox(height: 8),
        const Text('Regra de acesso: esta equipe visualiza apenas dúvidas anonimizadas vinculadas à própria UBS.'),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: AppButton(label: 'Atualizar', icon: Icons.refresh, onPressed: _busy ? () {} : _load)),
          const SizedBox(width: 10),
          Expanded(child: AppButton(label: 'Sair', icon: Icons.logout, outlined: true, onPressed: _busy ? () {} : _signOut)),
        ]),
      ])),
      if (_questions.isEmpty) const SectionCard(child: Text('Nenhuma dúvida pendente para a sua UBS.')),
      ..._questions.map((q) => SectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${q.publicCode} • ${_riskLabel(q.selfRiskLevel)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.primaryPink)),
            const SizedBox(height: 6),
            Text('Categoria: ${q.category ?? 'Não informada'}'),
            Text('Sinais de alerta informados: ${q.hasWarningSigns ? q.warningSigns.join(', ') : 'nenhum'}'),
            Text('Enviada em: ${q.createdAt.day.toString().padLeft(2, '0')}/${q.createdAt.month.toString().padLeft(2, '0')}/${q.createdAt.year}'),
            const Divider(height: 20),
            Text(q.questionText, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            AppButton(label: 'Responder esta dúvida', icon: Icons.reply_outlined, onPressed: () => setState(() => _selected = q)),
          ]))),
      if (_selected != null)
        SectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Responder ${_selected!.publicCode}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.petDarkBlue)),
          const SizedBox(height: 8),
          TextField(controller: _answerController, maxLines: 5, decoration: const InputDecoration(labelText: 'Resposta da Equipe UBS')),
          const SizedBox(height: 10),
          AppButton(label: 'Enviar resposta', icon: Icons.send_outlined, onPressed: _busy ? () {} : _respond),
        ])),
    ]);
  }

  String _riskLabel(String risk) {
    switch (risk) {
      case 'high':
        return 'Alto risco informado pela paciente';
      case 'medium':
        return 'Médio risco informado pela paciente';
      default:
        return 'Baixo risco informado pela paciente';
    }
  }
}
