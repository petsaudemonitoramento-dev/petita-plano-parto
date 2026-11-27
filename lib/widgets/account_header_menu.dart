import 'package:flutter/material.dart';
import '../config/app_routes.dart';
import '../services/institutional/institutional_auth.dart';

/// Shared header account menu. Account identity is never obtained from local
/// clinical profile data. All logout paths gate the session immediately.
class AccountHeaderMenu extends StatelessWidget {
  const AccountHeaderMenu({super.key, required this.auth, this.professional = false,
    this.roleLabel, this.onManage, this.onRefresh, this.onEdit, this.color, this.busy = false});
  final InstitutionalAuth? auth;
  final bool professional, busy;
  final String? roleLabel;
  final VoidCallback? onManage, onRefresh, onEdit;
  final Color? color;

  static Future<void> signOut(BuildContext context, InstitutionalAuth auth) async {
    final accepted = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Sair da conta?'),
      content: const Text('Sua sessão será encerrada. Os dados do plano offline permanecem neste aparelho.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sair')),
      ],
    )) ?? false;
    if (!accepted || !context.mounted) return;
    var remoteFailed = false;
    try { await auth.logout(); } catch (_) { remoteFailed = true; }
    if (!context.mounted) return;
    if (remoteFailed) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sessão local encerrada. Não foi possível confirmar o encerramento remoto.')));
    }
    Navigator.pushNamedAndRemoveUntil(context, AppRoutes.home, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final session = auth;
    final connected = session?.signedIn == true;
    final name = session?.user?['name']?.toString().trim() ?? '';
    final email = session?.user?['email']?.toString() ?? '';
    return PopupMenuButton<String>(
      tooltip: 'Minha conta',
      enabled: !busy,
      icon: Icon(Icons.account_circle_outlined, color: color),
      constraints: const BoxConstraints(minWidth: 220, maxWidth: 310),
      onSelected: (action) {
        if (action == 'logout' && session != null) {
          signOut(context, session);
        } else if (action == 'refresh') {
          onRefresh?.call();
        } else if (action == 'edit') {
          if (onEdit != null) { onEdit!(); return; }
          Navigator.pushNamed(context, AppRoutes.profile, arguments: connected ? <String,String>{'name': name, 'email': email} : <String,String>{});
        } else if (action == 'manage') {
          if (onManage != null) { onManage!(); return; }
          Navigator.pushNamed(context, professional ? AppRoutes.professionalAccount : AppRoutes.institutional, arguments: connected ? 'manage' : 'login');
        }
      },
      itemBuilder: (_) => [
        if (connected) ...[
          PopupMenuItem<String>(enabled: false, height: 76, child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(name.isEmpty ? 'Minha conta' : name, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800)),
            if (email.isNotEmpty) Text(email, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
            if (roleLabel != null) Text(roleLabel!, style: const TextStyle(fontSize: 12)),
          ])),
          const PopupMenuDivider(),
        ],
        if (!professional) const PopupMenuItem(value: 'edit', child: ListTile(
          contentPadding: EdgeInsets.zero, leading: Icon(Icons.edit_outlined), title: Text('Editar perfil'))),
        PopupMenuItem(value: 'manage', child: ListTile(contentPadding: EdgeInsets.zero,
          leading: Icon(connected ? Icons.settings_outlined : Icons.login),
          title: Text(connected ? (professional ? 'Configurações da conta' : 'Conta e UBS') : 'Entrar ou criar conta'))),
        if (connected && onRefresh != null) const PopupMenuItem(value: 'refresh', child: ListTile(
          contentPadding: EdgeInsets.zero, leading: Icon(Icons.refresh), title: Text('Atualizar situação'))),
        if (connected) const PopupMenuItem(value: 'logout', child: ListTile(
          contentPadding: EdgeInsets.zero, leading: Icon(Icons.logout, color: Colors.redAccent), title: Text('Sair da conta'))),
      ],
    );
  }
}
