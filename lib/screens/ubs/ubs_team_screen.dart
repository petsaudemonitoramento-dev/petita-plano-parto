import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../models/ubs_unit.dart';
import '../../services/ubs_service.dart';
import '../../widgets/section_card.dart';

class UbsTeamScreen extends StatefulWidget {
  const UbsTeamScreen({super.key});

  @override
  State<UbsTeamScreen> createState() => _UbsTeamScreenState();
}

class _UbsTeamScreenState extends State<UbsTeamScreen> {
  List<UbsUnit> _units = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final units = await UbsService().loadOfficialUnits();
    if (!mounted) return;
    setState(() {
      _units = units;
      _loading = false;
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
              Icon(Icons.construction_rounded, size: 76, color: AppColors.primaryPink),
              SizedBox(height: 12),
              Text('Acesso temporariamente indisponível', textAlign: TextAlign.center, style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900, color: AppColors.petDarkBlue)),
              SizedBox(height: 8),
              Text(
                'Estamos trabalhando nessa funcionalidade. Na versão online, profissionais vinculados a uma UBS cadastrada poderão responder apenas dúvidas de pacientes da própria UBS.',
                textAlign: TextAlign.center,
              ),
            ])),
            SectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('UBS oficiais preparadas para Multi UBS', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.primaryPink)),
              const SizedBox(height: 8),
              ..._units.map((u) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.local_hospital_outlined, color: AppColors.petBlue),
                    title: Text(u.name),
                    subtitle: Text('Código: ${u.code}'),
                  )),
            ])),
            const SectionCard(child: Text('Regra futura de acesso: profissional.ubs_code == dúvida.ubs_code. Assim, uma equipe UBS não visualiza dúvidas de pacientes de outra UBS.')),
          ]),
        ),
      ),
    );
  }
}
