import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Movimento suave da mascote. Respeita a preferência de movimento reduzido.
class PetitaAnimatedMascot extends StatefulWidget {
  const PetitaAnimatedMascot({super.key, this.size = 180});
  final double size;
  @override
  State<PetitaAnimatedMascot> createState() => _PetitaAnimatedMascotState();
}
class _PetitaAnimatedMascotState extends State<PetitaAnimatedMascot> with SingleTickerProviderStateMixin {
  late final AnimationController _motion;
  @override
  void initState() {
    super.initState();
    _motion = AnimationController(vsync: this, duration: const Duration(milliseconds: 5400))..repeat();
  }
  @override
  void dispose() { _motion.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return SizedBox(
      width: widget.size + 32, height: widget.size + 34,
      child: AnimatedBuilder(
        animation: _motion,
        builder: (context, child) {
          final t = reduceMotion ? 0.0 : _motion.value;
          final breathing = reduceMotion ? 0.0 : math.sin(t * 2 * math.pi);
          final accent = reduceMotion ? 0.0 : math.sin(t * 2 * math.pi);
          return Stack(alignment: Alignment.center, children: [
            Container(
              width: widget.size + 14, height: widget.size + 14,
              decoration: BoxDecoration(shape: BoxShape.circle,
                gradient: RadialGradient(colors: [const Color(0xFFFFE5ED), const Color(0xFFFFF6F8).withOpacity(0.3)])),
            ),
            Positioned(left: 8, top: 22 + accent * 2,
              child: const Icon(Icons.auto_awesome, color: Color(0xFFF07899), size: 22)),
            Positioned(right: 6, bottom: 35 - accent * 2,
              child: const Icon(Icons.favorite, color: Color(0xFFF8A7BA), size: 17)),
            Transform.scale(scale: 1 + breathing * 0.004,
              child: Image.asset('assets/images/petita.png', width: widget.size, height: widget.size, fit: BoxFit.contain)),
          ]);
        },
      ),
    );
  }
}
