import 'package:flutter/material.dart';
import 'package:fretboard_theory/fretboard_theory.dart';

import '../app/theme.dart';

/// A dot on the fretboard. Fret 0 is drawn beside the nut.
class FretMarker {
  const FretMarker(this.position, {this.label, this.color, this.textColor});
  final FretPosition position;
  final String? label;
  final Color? color;
  final Color? textColor;
}

/// Horizontal, tab-style fretboard: nut on the left, lowest string at the
/// bottom. Shows frets [firstFret]..[lastFret] with markers and optional
/// muted strings; mirrors for left-handed players.
class FretboardView extends StatelessWidget {
  const FretboardView({
    super.key,
    required this.instrument,
    this.firstFret = 0,
    this.lastFret = 12,
    this.markers = const [],
    this.mutedStrings = const {},
    this.leftHanded = false,
    this.dimStringsExcept,
    this.stringSpacing = 26,
    this.compact = false,
  });

  /// A window around one chord: the open position when it fits in the
  /// first five frets, otherwise four frets from just below the lowest one.
  factory FretboardView.chord(
    ChordVoicing v, {
    Key? key,
    bool leftHanded = false,
    bool showNames = false,
    Accidentals accidentals = Accidentals.sharps,
    double stringSpacing = 22,
    bool compact = true,
  }) {
    final int first;
    final int last;
    if (v.highestFret <= 5) {
      first = 0;
      last = 5;
    } else {
      first = v.lowestFret - 1;
      last = first + 4;
    }
    return FretboardView(
      key: key,
      instrument: v.instrument,
      firstFret: first,
      lastFret: last,
      leftHanded: leftHanded,
      stringSpacing: stringSpacing,
      compact: compact,
      mutedStrings: {
        for (var s = 0; s < v.frets.length; s++)
          if (v.frets[s] == null) s,
      },
      markers: [
        for (final p in v.positions)
          FretMarker(
            p,
            label: showNames
                ? v.instrument.pitchAt(p).pitchClass.name(accidentals)
                : null,
            color: p.string == v.rootString ? markerColor : stringColor,
            textColor: markerText,
          ),
      ],
    );
  }

  final Instrument instrument;
  final int firstFret;
  final int lastFret;
  final List<FretMarker> markers;
  final Set<int> mutedStrings;
  final bool leftHanded;

  /// When set, every other string is drawn faded.
  final int? dimStringsExcept;
  final double stringSpacing;

  /// Smaller fret numbers, tighter margins.
  final bool compact;

  double get height =>
      instrument.stringCount * stringSpacing + (compact ? 22 : 30);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: 'fretboard, frets $firstFret to $lastFret',
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(
          painter: _FretboardPainter(
            instrument: instrument,
            firstFret: firstFret,
            lastFret: lastFret,
            markers: markers,
            muted: mutedStrings,
            leftHanded: leftHanded,
            dimExcept: dimStringsExcept,
            compact: compact,
            labelColor: scheme.onSurfaceVariant,
            labelStyle:
                Theme.of(context).textTheme.labelMedium ?? const TextStyle(),
          ),
        ),
      ),
    );
  }
}

class _FretboardPainter extends CustomPainter {
  _FretboardPainter({
    required this.instrument,
    required this.firstFret,
    required this.lastFret,
    required this.markers,
    required this.muted,
    required this.leftHanded,
    required this.dimExcept,
    required this.compact,
    required this.labelColor,
    required this.labelStyle,
  });

  final Instrument instrument;
  final int firstFret;
  final int lastFret;
  final List<FretMarker> markers;
  final Set<int> muted;
  final bool leftHanded;
  final int? dimExcept;
  final bool compact;
  final Color labelColor;

  /// Base style (for the font family); size and color are overridden.
  final TextStyle labelStyle;

  static const _inlays = {3, 5, 7, 9, 15, 17, 19, 21};
  static const _doubleInlays = {12, 24};

  @override
  void paint(Canvas canvas, Size size) {
    final n = instrument.stringCount;
    final numberBand = compact ? 18.0 : 24.0;
    final nutBand = size.height * 0 + (compact ? 22.0 : 28.0); // open-note area
    final boardTop = 4.0;
    final boardBottom = size.height - numberBand;
    final boardHeight = boardBottom - boardTop;
    final stringGap = boardHeight / n;
    final frets = lastFret - firstFret; // number of fret cells
    final showNut = firstFret == 0;
    final boardLeft = nutBand;
    final boardRight = size.width - 2;
    final cell = (boardRight - boardLeft) / (showNut ? frets : frets + 1);

    if (leftHanded) {
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
    }

    // Fret line x for fret number f (line at the far side of cell f).
    double fretX(int f) {
      if (showNut) return boardLeft + (f - firstFret) * cell;
      // Without a nut there is a partial cell for fret `firstFret`.
      return boardLeft + (f - firstFret + 1) * cell;
    }

    // Center x of the cell for fret f (fret 0 = in the nut band).
    double cellX(int f) {
      if (f == 0) return boardLeft - nutBand / 2;
      if (f == firstFret && !showNut) return boardLeft + cell / 2;
      return fretX(f) - cell / 2;
    }

    // y for string index (0 = lowest = bottom).
    double stringY(int s) => boardBottom - (s + 0.5) * stringGap;

    // Wood.
    final leftEdge = showNut ? boardLeft : boardLeft;
    final board = Rect.fromLTRB(leftEdge, boardTop, boardRight, boardBottom);
    canvas.drawRRect(
      RRect.fromRectAndRadius(board, const Radius.circular(3)),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [fretboardWood, fretboardWoodDark],
        ).createShader(board),
    );

    // Inlays.
    final inlay = Paint()..color = inlayColor.withValues(alpha: 0.55);
    final r = (stringGap * 0.22).clamp(3.0, 6.0);
    for (var f = firstFret == 0 ? 1 : firstFret; f <= lastFret; f++) {
      final x = cellX(f);
      final midY = (boardTop + boardBottom) / 2;
      if (_doubleInlays.contains(f)) {
        canvas.drawCircle(Offset(x, midY - stringGap), r, inlay);
        canvas.drawCircle(Offset(x, midY + stringGap), r, inlay);
      } else if (_inlays.contains(f)) {
        canvas.drawCircle(Offset(x, midY), r, inlay);
      }
    }

    // Fret wires and nut.
    final wire = Paint()
      ..color = fretWire
      ..strokeWidth = 2;
    final firstLine = showNut ? 1 : firstFret;
    for (var f = firstLine; f <= lastFret; f++) {
      final x = fretX(f);
      canvas.drawLine(Offset(x, boardTop), Offset(x, boardBottom), wire);
    }
    if (showNut) {
      canvas.drawRect(
        Rect.fromLTRB(boardLeft - 4, boardTop, boardLeft + 1, boardBottom),
        Paint()..color = nutColor,
      );
    }

    // Strings.
    for (var s = 0; s < n; s++) {
      final y = stringY(s);
      final dim = dimExcept != null && dimExcept != s;
      final p = Paint()
        ..color = stringColor.withValues(alpha: dim ? 0.25 : 0.95)
        ..strokeWidth = 1.0 + (n - 1 - s) * (compact ? 0.35 : 0.5);
      canvas.drawLine(Offset(boardLeft, y), Offset(boardRight, y), p);
    }

    // Fret numbers.
    final numberStyle = labelStyle.copyWith(
      color: labelColor,
      fontSize: compact ? 10 : 12,
      fontWeight: FontWeight.w600,
    );
    for (var f = firstFret; f <= lastFret; f++) {
      if (f == 0) continue;
      final show = compact
          ? (f == firstFret || _inlays.contains(f) || _doubleInlays.contains(f))
          : true;
      if (!show) continue;
      _text(
        canvas,
        '$f',
        numberStyle,
        Offset(cellX(f), boardBottom + numberBand / 2),
      );
    }

    // Muted strings.
    final xStyle = labelStyle.copyWith(
      color: labelColor,
      fontSize: compact ? 12 : 14,
      fontWeight: FontWeight.w700,
    );
    for (final s in muted) {
      if (s >= n) continue;
      _text(canvas, '×', xStyle, Offset(cellX(0), stringY(s)));
    }

    // Markers.
    final radius = (stringGap * 0.42).clamp(7.0, 13.0).clamp(0.0, cell * 0.44);
    for (final m in markers) {
      final p = m.position;
      if (p.string >= n) continue;
      if (p.fret != 0 && (p.fret < firstFret || p.fret > lastFret)) continue;
      if (p.fret == 0 && !showNut) continue;
      final c = Offset(cellX(p.fret), stringY(p.string));
      final fill = Paint()..color = m.color ?? markerColor;
      canvas.drawCircle(c, radius, fill);
      canvas.drawCircle(
        c,
        radius,
        Paint()
          ..color = markerText.withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
      if (m.label != null) {
        _text(
          canvas,
          m.label!,
          labelStyle.copyWith(
            color: m.textColor ?? markerText,
            fontSize: radius * (m.label!.length > 1 ? 0.95 : 1.15),
            fontWeight: FontWeight.w700,
          ),
          c,
        );
      }
    }
  }

  void _text(Canvas canvas, String s, TextStyle style, Offset center) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    if (leftHanded) {
      // Un-mirror the glyphs.
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.scale(-1, 1);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    } else {
      tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(_FretboardPainter old) =>
      old.instrument != instrument ||
      old.firstFret != firstFret ||
      old.lastFret != lastFret ||
      old.markers != markers ||
      old.muted != muted ||
      old.leftHanded != leftHanded ||
      old.dimExcept != dimExcept ||
      old.compact != compact ||
      old.labelColor != labelColor ||
      old.labelStyle != labelStyle;
}
