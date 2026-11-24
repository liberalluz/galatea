import 'package:flutter/material.dart';

/// The centred square the normalized 0–1 model space maps into
/// (`REQ-008`, `REQ-009`, B32 mapping ruling): the letterform keeps its
/// proportions inside a wide card instead of stretching horizontally, and
/// the margins stay blank.
Rect _modelRect(Size size) {
  final side = size.shortestSide;
  return Rect.fromLTWH(
    (size.width - side) / 2,
    (size.height - side) / 2,
    side,
    side,
  );
}

/// Paints the handwritten model faintly, the pointer strokes in ink and,
/// while the stroke-order animation plays, the model strokes progressively
/// up to the playback progress (`REQ-009`, ADR-0003). All strokes are in
/// the normalized 0–1 square; the painter maps them into the centred
/// square of the canvas, so the model keeps its proportions.
class HandwritingPainter extends CustomPainter {
  HandwritingPainter({
    required this.model,
    required this.user,
    this.played = -1,
    this.fraction = 0,
    required this.inkColor,
    required this.modelColor,
  });

  final List<List<Offset>> model;
  final List<List<Offset>> user;
  final int played;
  final double fraction;
  final Color inkColor;
  final Color modelColor;

  @override
  void paint(Canvas canvas, Size size) {
    final modelPaint = Paint()
      ..color = modelColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final inkPaint = Paint()
      ..color = inkColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    Path polyline(List<Offset> stroke, [double until = 1]) {
      final path = Path();
      var total = 0.0;
      final rect = _modelRect(size);
      final scaled = [
        for (final p in stroke)
          Offset(rect.left + p.dx * rect.width, rect.top + p.dy * rect.height),
      ];
      for (var i = 1; i < scaled.length; i++) {
        total += (scaled[i] - scaled[i - 1]).distance;
      }
      var budget = until * total;
      for (var i = 0; i < scaled.length; i++) {
        if (i == 0) {
          path.moveTo(scaled[0].dx, scaled[0].dy);
          continue;
        }
        final segment = (scaled[i] - scaled[i - 1]).distance;
        if (segment <= budget || until >= 1) {
          budget -= segment;
          path.lineTo(scaled[i].dx, scaled[i].dy);
        } else {
          final t = budget / segment;
          final tip = Offset.lerp(scaled[i - 1], scaled[i], t) ?? scaled[i - 1];
          path.lineTo(tip.dx, tip.dy);
          break;
        }
      }
      return path;
    }

    // The faint complete model is the static preview (ux-flows empty state
    // of the stroke-order flow); the ink shows the playback progress.
    for (final stroke in model) {
      canvas.drawPath(polyline(stroke), modelPaint);
    }
    for (var i = 0; i < model.length; i++) {
      if (played < 0) {
        break;
      }
      if (i < played) {
        canvas.drawPath(polyline(model[i]), inkPaint);
      } else if (i == played) {
        canvas.drawPath(polyline(model[i], fraction), inkPaint);
        break;
      }
    }
    for (final stroke in user) {
      canvas.drawPath(polyline(stroke), inkPaint);
    }
  }

  @override
  bool shouldRepaint(HandwritingPainter oldDelegate) {
    return oldDelegate.model != model ||
        oldDelegate.user != user ||
        oldDelegate.played != played ||
        oldDelegate.fraction != fraction ||
        oldDelegate.inkColor != inkColor ||
        oldDelegate.modelColor != modelColor;
  }
}

/// The shared tracing canvas (`REQ-009` handwriting zone, `REQ-018`
/// writing task): captures pointer strokes in the normalized 0–1 square
/// over the model. The model is drawn faintly inside the area unless
/// [showModel] is false (the writing task keeps the area blank per the
/// ux-flows R18 empty state — the sample renders above instead).
///
/// Callers reach the captured strokes through a `GlobalKey` to
/// [TracingCanvasState] (`strokes`, `clear()`) and observe changes through
/// [onChanged].
class TracingCanvas extends StatefulWidget {
  const TracingCanvas({
    super.key,
    this.areaKey,
    required this.model,
    this.height = 200,
    this.showModel = true,
    this.playedStroke = -1,
    this.playFraction = 0,
    this.onChanged,
  });

  /// The key callers can find the area by (test and gesture targeting);
  /// lands on the sized box the strokes are normalized against.
  final Key? areaKey;

  /// The model strokes in the normalized 0–1 square.
  final List<List<Offset>> model;

  final double height;

  /// Whether the model renders faintly inside the area.
  final bool showModel;

  /// The stroke-order playback state (`REQ-009`): the index of the stroke
  /// currently playing, or -1 when not playing.
  final int playedStroke;

  /// The playback progress within [playedStroke], 0–1.
  final double playFraction;

  /// Fired after every stroke change with the current strokes.
  final void Function(List<List<Offset>> strokes)? onChanged;

  @override
  State<TracingCanvas> createState() => TracingCanvasState();
}

class TracingCanvasState extends State<TracingCanvas> {
  final List<List<Offset>> strokes = <List<Offset>>[];

  /// A copy of the captured strokes; callers treat it as read-only.
  List<List<Offset>> get captured => [
    for (final stroke in strokes) List<Offset>.of(stroke),
  ];

  void clear() {
    if (strokes.isEmpty) {
      return;
    }
    setState(strokes.clear);
    widget.onChanged?.call(captured);
  }

  void _startStroke(Offset localPosition) {
    setState(() {
      strokes.add([_normalized(localPosition)]);
    });
    widget.onChanged?.call(captured);
  }

  void _extendStroke(Offset localPosition) {
    if (strokes.isEmpty) {
      return;
    }
    final stroke = strokes.last;
    final point = _normalized(localPosition);
    // Skip jitter points that add no movement (a stroke of one dot cannot
    // render a polyline); the 1.5px threshold follows the detail zone.
    final box = context.findRenderObject()! as RenderBox;
    final scale = box.size.shortestSide;
    if ((point - stroke.last).distance * scale < 1.5) {
      return;
    }
    setState(() => stroke.add(point));
    widget.onChanged?.call(captured);
  }

  Offset _normalized(Offset localPosition) {
    final box = context.findRenderObject()! as RenderBox;
    // The pointer positions are normalized against the same centred square
    // the model is painted into, so the captured strokes land on the model
    // instead of drifting when the area is wider than it is tall.
    final rect = _modelRect(box.size);
    if (rect.width <= 0 || rect.height <= 0) {
      return Offset.zero;
    }
    return Offset(
      ((localPosition.dx - rect.left) / rect.width).clamp(0.0, 1.0),
      ((localPosition.dy - rect.top) / rect.height).clamp(0.0, 1.0),
    );
  }

  @override
  Widget build(BuildContext context) {
    final outline = Theme.of(context).colorScheme.outline;
    return GestureDetector(
      onPanStart: (details) => _startStroke(details.localPosition),
      onPanUpdate: (details) => _extendStroke(details.localPosition),
      child: SizedBox(
        key: widget.areaKey,
        height: widget.height,
        width: double.infinity,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: outline),
            borderRadius: BorderRadius.circular(8),
          ),
          child: CustomPaint(
            painter: HandwritingPainter(
              model: widget.showModel ? widget.model : const <List<Offset>>[],
              // A fresh copy per build so the painter's shouldRepaint
              // identity comparison sees in-place stroke mutations.
              user: captured,
              played: widget.playedStroke,
              fraction: widget.playFraction,
              inkColor: Theme.of(context).colorScheme.primary,
              modelColor: outline,
            ),
          ),
        ),
      ),
    );
  }
}
