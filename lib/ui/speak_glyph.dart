import 'package:flutter/material.dart';

/// The Mondom button's icon: filled lips with sound arcs, a one-colour echo
/// of the app icon, so the button needs no translated label.
class SpeakGlyph extends StatelessWidget {
  const SpeakGlyph({super.key, this.size = 36, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? IconTheme.of(context).color ?? Colors.white;
    return CustomPaint(
      size: Size(size, size * 0.45),
      painter: _SpeakGlyphPainter(c),
    );
  }
}

class _SpeakGlyphPainter extends CustomPainter {
  _SpeakGlyphPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // Lips take the left 72%, sound arcs the rest.
    final w = size.width * 0.72;
    final h = size.height;
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    // Upper lip: two peaks with the cupid's bow dip between them; its lower
    // edge rises slightly to the middle, leaving a slit above the lower lip.
    const m = 0.48; // mouth corners
    final upper = Path()
      ..moveTo(0, h * m)
      ..cubicTo(w * 0.12, h * 0.26, w * 0.26, h * 0.02, w * 0.37, h * 0.02)
      ..cubicTo(w * 0.44, h * 0.02, w * 0.47, h * 0.13, w * 0.5, h * 0.15)
      ..cubicTo(w * 0.53, h * 0.13, w * 0.56, h * 0.02, w * 0.63, h * 0.02)
      ..cubicTo(w * 0.74, h * 0.02, w * 0.88, h * 0.26, w, h * m)
      ..quadraticBezierTo(w * 0.5, h * 0.38, 0, h * m)
      ..close();
    canvas.drawPath(upper, fill);

    // Lower lip: fuller, rounded.
    final lower = Path()
      ..moveTo(w * 0.04, h * 0.55)
      ..quadraticBezierTo(w * 0.5, h * 0.6, w * 0.96, h * 0.55)
      ..cubicTo(w * 0.84, h * 1.0, w * 0.16, h * 1.0, w * 0.04, h * 0.55)
      ..close();
    canvas.drawPath(lower, fill);

    // Two sound arcs to the right, as in the app icon.
    final arc = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.05
      ..strokeCap = StrokeCap.round;
    final c = Offset(w * 0.86, h * 0.5);
    for (final r in [size.width * 0.17, size.width * 0.28]) {
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        -0.75,
        1.5,
        false,
        arc,
      );
    }
  }

  @override
  bool shouldRepaint(_SpeakGlyphPainter old) => old.color != color;
}
