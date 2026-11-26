import 'package:flutter/material.dart';
import '../services/storage_service.dart';

void showLocalPersistenceError(BuildContext context) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(
    'Não foi possível confirmar a alteração neste aparelho. Tente novamente.',
  )));
}

Future<bool> confirmLocalChange(BuildContext context, Future<void> Function() change) async {
  try {
    await change();
    return true;
  } on LocalPersistenceException {
    if (context.mounted) showLocalPersistenceError(context);
    return false;
  }
}
