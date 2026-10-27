import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Anima a arte original da Petita, sem substituir o desenho.
class PetitaAnimatedMascot extends StatefulWidget {
  const PetitaAnimatedMascot({super.key, this.size = 180});
  final double size;
  @override
  State<PetitaAnimatedMascot> createState() => _PetitaAnimatedMascotState();
}

class _PetitaAnimatedMascotState extends State<PetitaAnimatedMascot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion;
  ui.Image? _art;

  @override
  void initState() {
    super.initState();
    _motion = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 5200),
    )..repeat();
    _loadArt();
  }

  Future<void> _loadArt() async {
    final data = await rootBundle.load('assets/images/petita.png');
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    if (mounted) {
      setState(() => _art = frame.image);
    } else {
      frame.image.dispose();
    }
    codec.dispose();
  }

  @override
  void dispose() {
    _motion.dispose();
    _art?.dispose();
    super.dispose();
  }

  double _blink(double t, double center) {
    final d = (t - center).abs();
    return d < 0.022 ? math.sin((1 - d / 0.022) * math.pi / 2) : 0;
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.of(context).disableAnimations;
    return SizedBox(
      width: widget.size + 32,
      height: widget.size + 34,
      child: AnimatedBuilder(
        animation: _motion,
        builder: (context, _) {
          final t = reduced ? 0.0 : _motion.value;
          final blink = reduced ? 0.0 :
              _blink(t, 0.42);
          // A imagem original já contém ambas as mãos.
          const stroke = 0.0;
          return Stack(alignment: Alignment.center, children: [
            Container(
              width: widget.size + 14,
              height: widget.size + 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  const Color(0xFFFFE5ED),
                  const Color(0xFFFFF6F8).withOpacity(0.3),
                ]),
              ),
            ),
            if (_art == null)
              Image.asset('assets/images/petita.png',
                  width: widget.size, height: widget.size, fit: BoxFit.contain)
            else
              CustomPaint(
                size: Size(widget.size, widget.size),
                painter: _PetitaMotionPainter(_art!, blink, stroke),
              ),
          ]);
        },
      ),
    );
  }
}

class _PetitaMotionPainter extends CustomPainter {
  _PetitaMotionPainter(this.image, this.blink, this.stroke);
  final ui.Image image;
  final double blink;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final full = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    canvas.drawImageRect(image, full, Offset.zero & size, Paint()..filterQuality = FilterQuality.high);

    // O recorte sobreposto da mão foi removido para evitar duplicação.
    // Uma animação articulada requer camadas reais.
    // Pálpebras no próprio visor; aparecem apenas durante a piscada.
    if (blink > 0.015) {
      final face = Paint()..color = const Color(0xFF25191F).withOpacity(blink * 0.98);
      for (final eye in [const Offset(0.367, 0.367), const Offset(0.593, 0.365)]) {
        final center = Offset(size.width * eye.dx, size.height * eye.dy);
        canvas.drawOval(Rect.fromCenter(
          center: center,
          width: size.width * 0.105,
          height: size.height * 0.125 * blink,
        ), face);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PetitaMotionPainter old) =>
      old.blink != blink || old.stroke != stroke || old.image != image;
}
