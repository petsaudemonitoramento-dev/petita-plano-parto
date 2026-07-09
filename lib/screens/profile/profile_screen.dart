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
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final units = await UbsService().loadOfficialUnits();
    final profile = await _storage.loadProfile();
    if (!mounted) return;
    setState(() {
      _officialUnits = units;
      _profile = profile;
      _selectedUbsCode = profile?.ubsCode;
      _nameController.text = profile?.name ?? '';
      _emailController.text = profile?.email ?? '';
      if (profile?.ubsCode == null && profile?.ubsName != null) {
        _customUbsController.text = profile!.ubsName!;
      }
      _loading = false;
    });
  }

  Future<void> _save() async {
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
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cadastro local salvo. Na versão online, esses dados poderão ser sincronizados com Supabase.')));
  }

  Future<void> _clear() async {
    await _storage.clearProfile();
    if (!mounted) return;
    setState(() {
      _profile = null;
      _nameController.clear();
      _emailController.clear();
      _customUbsController.clear();
      _selectedUbsCode = null;
    });
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
            SectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
              Text('Cadastro local/offline', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.petDarkBlue)),
              SizedBox(height: 8),
              Text('Este cadastro prepara o app para login online futuro. Mesmo sem internet, a gestante poderá montar, editar e gerar o Plano de Parto no aparelho.'),
            ])),
            SectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Nome da gestante')),
              const SizedBox(height: 12),
              TextField(controller: _emailController, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'E-mail')),
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
                onPressed: () => setState(() => _selectedUbsCode = null),
                icon: const Icon(Icons.edit_location_alt_outlined),
                label: const Text('Minha UBS não está na lista / digitar manualmente'),
              ),
              if (_selectedUbsCode == null) ...[
                const SizedBox(height: 8),
                TextField(controller: _customUbsController, decoration: const InputDecoration(labelText: 'Digite a UBS de referência')),
              ],
            ])),
            AppButton(label: 'Salvar cadastro local', icon: Icons.save_outlined, onPressed: _save),
            const SizedBox(height: 10),
            AppButton(label: 'Limpar cadastro local', icon: Icons.delete_outline, outlined: true, onPressed: _clear),
            if (_profile != null)
              SectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Perfil salvo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.primaryPink)),
                const SizedBox(height: 8),
                Text('Nome: ${_profile!.name}'),
                Text('E-mail: ${_profile!.email}'),
                Text("UBS: ${_profile!.ubsName ?? _profile!.ubsCode ?? 'Não informada'}"),
                const SizedBox(height: 8),
                const Text('Funcionalidades online como recuperação de conta, sincronização e envio de dúvidas à UBS serão ativadas na integração com Supabase.'),
              ])),
          ]),
        ),
      ),
    );
  }
}
