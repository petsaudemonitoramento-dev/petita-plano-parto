abstract class AuthTransport {
  Future<Map<String, dynamic>> call(String action, Map<String, dynamic> body);
}

class InstitutionalAuthException implements Exception {
  final int status;
  const InstitutionalAuthException(this.status);
  @override
  String toString() => switch (status) {
        401 => 'Sessão expirada ou dados de acesso inválidos. Entre novamente.',
        403 => 'A conta não tem autorização para esta operação.',
        429 => 'Muitas tentativas. Aguarde antes de tentar novamente.',
        _ =>
          'Não foi possível concluir a operação. Seus dados locais foram mantidos.',
      };
}
