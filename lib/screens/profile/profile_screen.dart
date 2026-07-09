import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../models/ubs_unit.dart';
import '../../models/user_profile.dart';
import '../../services/storage_service.dart';
import '../../services/supabase_service.dart';
import '../../services/ubs_service.dart';
import '../../widgets/app_button.dart';
import '../../widgets/section_card.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _storage = StorageService();
  final _online = SupabaseService();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _customUbsController = TextEditingController();
  List<UbsUnit> _officialUnits = [];
  UserProfile? _profile;
  UserProfile? _onlineProfile;
  String? _selectedUbsCode;
  bool _manualUbsWarningShown = false;
  bool _loading = true;
  bool _busy = false;
  String _onlineMessage = 'Modo offline ativo. Faça login para sincronizar quando houver internet.';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final units = await UbsService().loadOfficialUnits();
    final profile = await _storage.loadProfile();
    UserProfile? onlineProfile;
    try {
      onlineProfile = await _online.loadOnlineProfile();
    } catch (_) {
      onlineProfile = null;
    }
    if (!mounted) return;
    final source = onlineProfile ?? profile;
    setState(() {
      _officialUnits = units;
      _profile = profile;
      _onlineProfile = onlineProfile;
      _selectedUbsCode = source?.ubsCode;
      _nameController.text = source?.name ?? '';
      _emailController.text = source?.email ?? '';
      if (source?.ubsCode == null && source?.ubsName != null) {
        _customUbsController.text = source!.ubsName!;
      }
      _onlineMessage = onlineProfile == null
          ? 'Você pode usar o cadastro local offline. Login online é necessário para sincronizar plano e enviar dúvidas à UBS.'
          : 'Conta online conectada como ${onlineProfile.role}. Dados sincronizados com Supabase.';
      _loading = false;
    });
  }

  Future<void> _saveLocal() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    if (name.isEmpty || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Informe nome e e-mail para preparar o cadastro local.')));
      return;
    }

    String? ubsCode = _selectedUbsCode;
    String? ubsName;
    if (ubsCode != null) {
      for (final unit in _officialUnits) {
        if (unit.code == ubsCode) {
          ubsName = unit.name;
          break;
        }
      }
    } else if (_customUbsController.text.trim().isNotEmpty) {
      ubsName = _customUbsController.text.trim();
    }

    final profile = UserProfile(
      id: _profile?.id ?? 'LOCAL-${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      email: email,
      role: 'patient',
      ubsCode: ubsCode,
      ubsName: ubsName,
      createdAt: _profile?.createdAt ?? DateTime.now(),
    );
    await _storage.saveProfile(profile);
    if (!mounted) return;
    setState(() => _profile = profile);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cadastro local salvo.')));
  }

  Future<void> _signUpOnline() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    if (name.isEmpty || email.isEmpty || password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Informe nome, e-mail e senha com pelo menos 6 caracteres.')));
      return;
    }
    setState(() => _busy = true);
    try {
      await _saveLocal();
      await _online.signUpPatient(name: name, email: email, password: password, ubsCode: _selectedUbsCode);
      if (_online.isLoggedIn) {
        await _online.updatePatientProfile(name: name, email: email, ubsCode: _selectedUbsCode);
      }
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cadastro online solicitado. Se o Supabase exigir confirmação de e-mail, confirme antes de entrar.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Não foi possível criar cadastro online: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signInOnline() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Informe e-mail e senha.')));
      return;
    }
    setState(() => _busy = true);
    try {
      await _online.signIn(email: email, password: password);
      final onlineProfile = await _online.loadOnlineProfile();
      if (onlineProfile != null) await _storage.saveProfile(onlineProfile);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Login online realizado.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Não foi possível entrar: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signOut() async {
    setState(() => _busy = true);
    try {
      await _online.signOut();
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Conta online desconectada. O modo offline continua disponível.')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _clear() async {
    await _storage.clearProfile();
    if (!mounted) return;
    setState(() {
      _profile = null;
      _nameController.clear();
      _emailController.clear();
      _passwordController.clear();
      _customUbsController.clear();
      _selectedUbsCode = null;
    });
  }

  Future<void> _showManualUbsWarning({bool force = false}) async {
    if (!mounted) return;
    if (!force && _manualUbsWarningShown) return;
    _manualUbsWarningShown = true;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('UBS fora da lista oficial'),
        content: const Text(
          'Você pode digitar o nome da sua UBS para que ele apareça no Plano de Parto gerado.\n\n'
          'Mas, se você não selecionar uma UBS oficial da lista, suas dúvidas não poderão ser encaminhadas nem respondidas pela Equipe UBS no chat de dúvidas.\n\n'
          'Para usar o envio de dúvidas no futuro, selecione uma UBS oficial cadastrada.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Entendi')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(title: const Text('Perfil da gestante')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Cadastro offline-first', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.petDarkBlue)),
              const SizedBox(height: 8),
              Text(_onlineMessage),
              const SizedBox(height: 8),
              const Text('Mesmo sem internet, a gestante consegue montar, editar e gerar o Plano de Parto. Com login, o plano pode ser sincronizado e dúvidas podem ser enviadas para a UBS.'),
            ])),
            SectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Nome da gestante')),
              const SizedBox(height: 12),
              TextField(controller: _emailController, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'E-mail')),
              const SizedBox(height: 12),
              TextField(controller: _passwordController, obscureText: true, decoration: const InputDecoration(labelText: 'Senha para login online')),
              const SizedBox(height: 16),
              const Text('UBS de referência oficial', style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.petDarkBlue)),
              const SizedBox(height: 8),
              ..._officialUnits.map((unit) => RadioListTile<String>(
                    value: unit.code,
                    groupValue: _selectedUbsCode,
                    activeColor: AppColors.primaryPink,
                    title: Text(unit.name),
                    subtitle: Text(unit.code),
                    onChanged: (value) => setState(() {
                      _selectedUbsCode = value;
                      _customUbsController.clear();
                    }),
                  )),
              TextButton.icon(
                onPressed: () async {
                  setState(() => _selectedUbsCode = null);
                  await _showManualUbsWarning(force: true);
                },
                icon: const Icon(Icons.edit_location_alt_outlined),
                label: const Text('Minha UBS não está na lista / digitar manualmente'),
              ),
              if (_selectedUbsCode == null) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _customUbsController,
                  decoration: const InputDecoration(labelText: 'Digite a UBS de referência'),
                  onTap: () { _showManualUbsWarning(); },
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E8),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.petOrange.withOpacity(0.55)),
                  ),
                  child: const Text(
                    'A UBS digitada aparecerá no Plano de Parto. Porém, dúvidas enviadas pelo chat só poderão ser respondidas quando a gestante estiver vinculada a uma UBS oficial da lista.',
                    style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.petDarkBlue),
                  ),
                ),
              ],
            ])),
            AppButton(label: 'Salvar cadastro offline', icon: Icons.save_outlined, onPressed: _saveLocal),
            const SizedBox(height: 10),
            AppButton(label: 'Criar cadastro online', icon: Icons.cloud_upload_outlined, onPressed: _busy ? () {} : _signUpOnline),
            const SizedBox(height: 10),
            AppButton(label: 'Entrar online', icon: Icons.login, outlined: true, onPressed: _busy ? () {} : _signInOnline),
            const SizedBox(height: 10),
            AppButton(label: 'Sair da conta online', icon: Icons.logout, outlined: true, onPressed: _busy ? () {} : _signOut),
            const SizedBox(height: 10),
            AppButton(label: 'Limpar cadastro local', icon: Icons.delete_outline, outlined: true, onPressed: _clear),
            if (_profile != null || _onlineProfile != null)
              SectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Perfil ativo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.primaryPink)),
                const SizedBox(height: 8),
                Text('Nome: ${(_onlineProfile ?? _profile)!.name}'),
                Text('E-mail: ${(_onlineProfile ?? _profile)!.email}'),
                Text('Perfil: ${(_onlineProfile ?? _profile)!.role}'),
                Text('UBS: ${(_onlineProfile ?? _profile)!.ubsName ?? (_onlineProfile ?? _profile)!.ubsCode ?? 'Não informada'}'),
              ])),
          ]),
        ),
      ),
    );
  }
}
