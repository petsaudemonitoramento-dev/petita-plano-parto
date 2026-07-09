import 'package:flutter/material.dart';
import '../../config/app_info.dart';
import '../../config/app_theme.dart';
import '../../widgets/section_card.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sobre')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Image.asset('assets/images/pet_saude_logo.png', height: 120),
              const SizedBox(height: 16),
              SectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
                Text(AppInfo.appName, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.petDarkBlue)),
                SizedBox(height: 8),
                Text('A Petita é a assistente virtual do aplicativo, criada para tornar a experiência das gestantes mais acolhedora, amigável e acessível durante a construção do Plano de Parto.'),
              ])),
              SectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
                _AboutRow(label: 'Assistente', value: AppInfo.assistantName),
                _AboutRow(label: 'Versão', value: AppInfo.version),
                _AboutRow(label: 'Build', value: AppInfo.build),
                _AboutRow(label: 'Status', value: AppInfo.status),
                _AboutRow(label: 'Instituição', value: AppInfo.institution),
                _AboutRow(label: 'Desenvolvimento', value: AppInfo.developer),
                _AboutRow(label: 'Atualização', value: AppInfo.lastUpdate),
              ])),
            ],
          ),
        ),
      ),
    );
  }
}

class _AboutRow extends StatelessWidget {
  const _AboutRow({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 120, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.petDarkBlue))),
        Expanded(child: Text(value)),
      ]),
    );
  }
}
