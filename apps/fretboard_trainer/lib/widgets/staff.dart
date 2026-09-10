import 'package:flutter/material.dart';
import 'package:fretboard_theory/fretboard_theory.dart';

import 'svg_path.dart';

enum Clef { treble, bass }

/// A five-line staff with one note. Guitar and bass are both written an
/// octave above where they sound, so the sounding [pitch] is raised an
/// octave before it is placed.
class StaffView extends StatelessWidget {
  const StaffView({
    super.key,
    required this.pitch,
    required this.clef,
    this.accidentals = Accidentals.sharps,
    this.height = 120,
    this.color,
  });

  factory StaffView.forInstrument(
    Pitch pitch,
    Instrument instrument, {
    Accidentals accidentals = Accidentals.sharps,
    double height = 120,
    Color? color,
  }) => StaffView(
    pitch: pitch,
    clef: instrument.kind == InstrumentKind.bass ? Clef.bass : Clef.treble,
    accidentals: accidentals,
    height: height,
    color: color,
  );

  final Pitch pitch;
  final Clef clef;
  final Accidentals accidentals;
  final double height;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.onSurface;
    return Semantics(
      label: 'note ${pitch.name(accidentals)} on the ${clef.name} staff',
      child: SizedBox(
        height: height,
        width: height * 1.4,
        child: CustomPaint(
          painter: _StaffPainter(
            pitch: pitch,
            clef: clef,
            accidentals: accidentals,
            color: c,
            textStyle:
                Theme.of(context).textTheme.bodyMedium ?? const TextStyle(),
          ),
        ),
      ),
    );
  }
}

class _StaffPainter extends CustomPainter {
  _StaffPainter({
    required this.pitch,
    required this.clef,
    required this.accidentals,
    required this.color,
    required this.textStyle,
  });

  final Pitch pitch;
  final Clef clef;
  final Accidentals accidentals;
  final Color color;
  final TextStyle textStyle;

  static final _treble = parseSvgPath(trebleClefPath);

  @override
  void paint(Canvas canvas, Size size) {
    // The staff occupies the middle; room above and below for ledger lines.
    final space = size.height / 11;
    final top = size.height * 0.5 - 2 * space;
    final left = size.width * 0.06;
    final right = size.width * 0.94;
    final line = Paint()
      ..color = color
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    for (var i = 0; i < 5; i++) {
      final y = top + i * space;
      canvas.drawLine(Offset(left, y), Offset(right, y), line);
    }
    final bottomLine = top + 4 * space;

    // Bottom-line step: E4 for treble, G2 for bass.
    final bottomStep = clef == Clef.treble ? 4 * 7 + 2 : 2 * 7 + 4;
    _drawClef(canvas, top, space, left + space * 0.4);

    final written = pitch + 12;
    final step = written.staffStep(accidentals);
    final y = bottomLine - (step - bottomStep) * space / 2;
    final x = size.width * 0.66;
    final rx = space * 0.62, ry = space * 0.45;

    // Ledger lines.
    final ledger = Paint()
      ..color = color
      ..strokeWidth = 1.2;
    for (var s = bottomStep - 2; s >= step; s -= 2) {
      final ly = bottomLine - (s - bottomStep) * space / 2;
      canvas.drawLine(
        Offset(x - rx * 1.7, ly),
        Offset(x + rx * 1.7, ly),
        ledger,
      );
    }
    for (var s = bottomStep + 10; s <= step; s += 2) {
      final ly = bottomLine - (s - bottomStep) * space / 2;
      canvas.drawLine(
        Offset(x - rx * 1.7, ly),
        Offset(x + rx * 1.7, ly),
        ledger,
      );
    }

    // Notehead (slightly tilted oval) and stem.
    canvas.save();
    canvas.translate(x, y);
    canvas.rotate(-0.35);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: rx * 2, height: ry * 2),
      Paint()..color = color,
    );
    canvas.restore();
    final stemUp = step < bottomStep + 4;
    final stem = Paint()
      ..color = color
      ..strokeWidth = 1.4;
    if (stemUp) {
      canvas.drawLine(
        Offset(x + rx * 0.92, y - ry * 0.3),
        Offset(x + rx * 0.92, y - space * 3.2),
        stem,
      );
    } else {
      canvas.drawLine(
        Offset(x - rx * 0.92, y + ry * 0.3),
        Offset(x - rx * 0.92, y + space * 3.2),
        stem,
      );
    }

    // Accidental to the left of the head.
    final acc = written.spell(accidentals).accidentalGlyph;
    if (acc.isNotEmpty) {
      final tp = TextPainter(
        text: TextSpan(
          text: acc,
          style: textStyle.copyWith(
            color: color,
            fontSize: space * 2.1,
            fontWeight: FontWeight.w600,
            height: 1,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(x - rx - tp.width - space * 0.2, y - tp.height * 0.58),
      );
    }
  }

  void _drawClef(Canvas canvas, double top, double space, double x) {
    final fill = Paint()..color = color;
    if (clef == Clef.treble) {
      // Scale so the curl crosses the G line (second line from the bottom).
      final h = space * 7.4;
      final scale = h / trebleClefHeight;
      final gLine = top + 3 * space;
      canvas.save();
      canvas.translate(x, gLine - trebleClefGLine * h);
      canvas.scale(scale);
      canvas.drawPath(_treble, fill);
      canvas.restore();
      return;
    }
    // Bass clef: a curl starting on the F line, plus two dots around it.
    final fLine = top + space;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = space * 0.34
      ..strokeCap = StrokeCap.round;
    final p = Path()
      ..moveTo(x + space * 0.05, fLine + space * 0.05)
      ..cubicTo(
        x + space * 0.9,
        fLine - space * 1.3,
        x + space * 2.3,
        fLine - space * 0.2,
        x + space * 2.0,
        fLine + space * 1.0,
      )
      ..cubicTo(
        x + space * 1.7,
        fLine + space * 2.2,
        x + space * 0.6,
        fLine + space * 2.9,
        x - space * 0.1,
        fLine + space * 3.2,
      );
    canvas.drawPath(p, stroke);
    canvas.drawCircle(Offset(x + space * 0.25, fLine), space * 0.3, fill);
    canvas.drawCircle(
      Offset(x + space * 2.6, fLine - space * 0.5),
      space * 0.17,
      fill,
    );
    canvas.drawCircle(
      Offset(x + space * 2.6, fLine + space * 0.5),
      space * 0.17,
      fill,
    );
  }

  @override
  bool shouldRepaint(_StaffPainter old) =>
      old.pitch != pitch ||
      old.clef != clef ||
      old.accidentals != accidentals ||
      old.color != color ||
      old.textStyle != textStyle;
}
