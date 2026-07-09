import 'package:flutter/material.dart';
import '../config/app_theme.dart';

class OptionChipButton extends StatelessWidget {
  const OptionChipButton({super.key, required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8, bottom: 8),
      child: ActionChip(
        label: Text(label),
        onPressed: onTap,
        labelStyle: const TextStyle(color: AppColors.petDarkBlue, fontWeight: FontWeight.w700),
        backgroundColor: Colors.white,
        side: const BorderSide(color: AppColors.primaryPink),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );
  }
}
