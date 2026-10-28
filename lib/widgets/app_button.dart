import 'package:flutter/material.dart';

class AppButton extends StatelessWidget {
  const AppButton({super.key, required this.label, required this.onPressed, this.icon, this.outlined = false});
  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final child = Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 8)],
      Flexible(child: Text(label, textAlign: TextAlign.center)),
    ]);
    return outlined ? OutlinedButton(onPressed: onPressed, child: child) : ElevatedButton(onPressed: onPressed, child: child);
  }
}
