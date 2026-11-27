import '../../widgets/local_persistence_feedback.dart';
import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../models/ubs_unit.dart';
import '../../models/user_profile.dart';
import '../../services/storage_service.dart';
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
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _customUbsController = TextEditingController();
  List<UbsUnit> _officialUnits = [];
  UserProfile? _profile;
  String? _selectedUbsCode;
  bool _manualUbsWarningShown = false;
  bool _loading = true;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() { _loading = true; _loadFailed = false; });
    List<UbsUnit> units;
    UserProfile? profile;
    try {
      units = await UbsService().loadOfficialUnits().timeout(const Duration(seconds: 10));
      profile = await _storage.loadProfile().timeout(const Duration(seconds: 10));
    } catch (_) {
      if (mounted) setState(() { _loading = false; _loadFailed = true; });
      return;
    }
    if (!mounted) return;
    final source = profile;
    final account = ModalRoute.of(context)?.settings.arguments;
    final accountData = account is Map<String, String> ? account : const <String, String>{};
    setState(() {
      _officialUnits = units;
      _profile = profile;
      _selectedUbsCode = source?.ubsCode;
      _nameController.text = source?.name ?? accountData['name'] ?? '';
      _emailController.text = source?.email ?? accountData['email'] ?? '';
      if (source == null && units.any((u) => u.code == accountData['ubsCode'])) {
        _selectedUbsCode = accountData['ubsCode'];
      }
      if (source?.ubsCode == null && source?.ubsName != null) {
        _customUbsController.text = source!.ubsName!;
      }
      _loading = false;
    });
  }

  Future<bool> _saveLocal() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    if (name.isEmpty || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Informe nome e e-mail para preparar o cadastro local.')));
      return false;
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
    if (!await confirmLocalChange(context, () => _storage.saveProfile(profile))) return false;
    if (!mounted) return false;
    setState(() => _profile = profile);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cadastro local salvo.')));
    return true;
  }

  Future<void> _clear() async {
    if (!await confirmLocalChange(context, () => _storage.clearProfile())) return;
    if (!mounted) return;
    setState(() {
      _profile = null;
      _nameController.clear();
      _emailController.clear();
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
    if (_loadFailed) return Scaffold(
      appBar: AppBar(title: const Text('Meu perfil')),
      body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(
        mainAxisSize: MainAxisSize.min, children: [
          const Text('Não conseguimos abrir seu cadastro neste aparelho. Seus dados não foram apagados.'),
          const SizedBox(height: 16),
          FilledButton(onPressed: _load, child: const Text('Tentar novamente')),
        ],
      ))),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Meus dados')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Dados do meu plano de parto', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.petDarkBlue)),
              const SizedBox(height: 8),
              const Text('Edite seu nome, e-mail de contato e UBS para o plano de parto. Estes dados ficam neste aparelho e podem ser usados sem internet. Alterar este e-mail não modifica o e-mail de login da conta online.'),
            ])),
            SectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Seu nome')),
              const SizedBox(height: 12),
              TextField(controller: _emailController, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'E-mail')),
              const SizedBox(height: 12),
              const Text('Você não precisa de uma senha para usar o plano neste aparelho.'),
              const SizedBox(height: 16),
              const Text('UBS de referência oficial', style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.petDarkBlue)),
              const SizedBox(height: 8),
              Material(
                type: MaterialType.transparency,
                child: RadioGroup<String>(
                  groupValue: _selectedUbsCode,
                  onChanged: (value) => setState(() {
                    _selectedUbsCode = value;
                    _customUbsController.clear();
                  }),
                  child: Column(children: [
                    ..._officialUnits.map((unit) => RadioListTile<String>(
                          value: unit.code,
                          activeColor: AppColors.primaryPink,
                          title: Text(unit.name),
                          subtitle: Text(unit.code),
                        )),
                  ]),
                ),
              ),
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
                    border: Border.all(color: AppColors.petOrange.withAlpha((255 * 0.55).round())),
                  ),
                  child: const Text(
                    'A UBS digitada aparecerá no Plano de Parto. Porém, dúvidas enviadas pelo chat só poderão ser respondidas quando houver vínculo aprovado com uma UBS oficial da lista.',
                    style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.petDarkBlue),
                  ),
                ),
              ],
            ])),
            AppButton(label: 'Salvar cadastro offline', icon: Icons.save_outlined, onPressed: _saveLocal),
            const SizedBox(height: 10),
            AppButton(label: 'Limpar cadastro local', icon: Icons.delete_outline, outlined: true, onPressed: _clear),
            if (_profile != null)
              SectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Perfil ativo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.primaryPink)),
                const SizedBox(height: 8),
                Text('Nome: ${_profile!.name}'),
                Text('E-mail: ${_profile!.email}'),
                Text('UBS: ${_profile!.ubsName ?? _profile!.ubsCode ?? 'Não informada'}'),
              ])),
          ]),
        ),
      ),
    );
  }
}
