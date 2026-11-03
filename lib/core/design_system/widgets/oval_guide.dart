import 'package:flutter/material.dart';

/// Dims everything outside an oval face guide, with a thin outline on the
/// oval. Purely visual; the camera preview sits underneath.
class OvalGuide extends StatelessWidget {
  const OvalGuide(
      {super.key, this.widthFactor = 0.66, this.heightFactor = 0.5});

  /// Oval size as fractions of the available width and height.
  final double widthFactor;
  final double heightFactor;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _OvalGuidePainter(
        widthFactor: widthFactor,
        heightFactor: heightFactor,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _OvalGuidePainter extends CustomPainter {
  const _OvalGuidePainter({
    required this.widthFactor,
    required this.heightFactor,
  });

  final double widthFactor;
  final double heightFactor;

  @override
  void paint(Canvas canvas, Size size) {
    final oval = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: size.width * widthFactor,
      height: size.height * heightFactor,
    );
    final mask = Path()
      ..addRect(Offset.zero & size)
      ..addOval(oval)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(mask, Paint()..color = const Color(0x8C000000));
    canvas.drawOval(
      oval,
      Paint()
        ..color = const Color(0xE6FFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(_OvalGuidePainter oldDelegate) =>
      oldDelegate.widthFactor != widthFactor ||
      oldDelegate.heightFactor != heightFactor;
}
