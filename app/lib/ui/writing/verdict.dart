import 'package:flutter/material.dart';

/// The stroke-overlap threshold (`TC-QUIZ-004`; the ED-stage leniency
/// ux-flows R18 allows, recorded on the B15 card): a sampled user point
/// counts as covered when its shortest distance to the model polylines is
/// at most [kWritingRadius] of the glyph square, and the verdict is ✓
/// when at least [kWritingCoverage] of the sampled points are covered.
const double kWritingRadius = 0.09;
const double kWritingCoverage = 0.7;

/// Geometric comparisons are inclusive at the radius with a tiny epsilon
/// so a boundary stroke is not lost to floating-point noise (a 0.09
/// offset computed as a difference is 0.09000000000000002).
const double _kRadiusEpsilon = 1e-9;

/// The sampling step when densifying a user stroke: captured pan events
/// can be sparse (a straight drag gives two points), so the polyline is
/// interpolated at this step before sampling.
const double _kSampleStep = 0.02;

/// The ✓/× verdict for the writing task (`REQ-018`): a pure function of
/// the model strokes and the captured user strokes, both in the normalized
/// 0–1 square. The caller guards the empty-submit case (ux-flows R18
/// trace-first); an empty [userStrokes] throws.
bool writingVerdict(List<List<Offset>> model, List<List<Offset>> userStrokes) {
  if (userStrokes.isEmpty) {
    throw ArgumentError.value(userStrokes, 'userStrokes', 'must not be empty');
  }
  var covered = 0;
  var total = 0;
  for (final stroke in userStrokes) {
    for (final point in _densify(stroke)) {
      total += 1;
      if (_minDistanceToPolylines(point, model) <=
          kWritingRadius + _kRadiusEpsilon) {
        covered += 1;
      }
    }
  }
  if (total == 0) {
    return false;
  }
  return covered / total >= kWritingCoverage;
}

/// Interpolates a polyline at [_kSampleStep] so sparse captures are judged
/// on the shape they draw, not on how many events produced them.
Iterable<Offset> _densify(List<Offset> stroke) sync* {
  if (stroke.isEmpty) {
    return;
  }
  yield stroke.first;
  for (var i = 1; i < stroke.length; i++) {
    final a = stroke[i - 1];
    final b = stroke[i];
    final length = (b - a).distance;
    final steps = (length / _kSampleStep).floor();
    for (var s = 1; s <= steps; s++) {
      yield Offset.lerp(a, b, s / steps)!;
    }
    yield b;
  }
}

/// The shortest distance from [point] to every segment of every model
/// polyline, in the normalized square.
double _minDistanceToPolylines(Offset point, List<List<Offset>> model) {
  var best = double.infinity;
  for (final stroke in model) {
    for (var i = 1; i < stroke.length; i++) {
      best = _min(best, _distanceToSegment(point, stroke[i - 1], stroke[i]));
    }
  }
  return best;
}

double _distanceToSegment(Offset p, Offset a, Offset b) {
  final ab = b - a;
  final lengthSquared = ab.distanceSquared;
  if (lengthSquared == 0) {
    return (p - a).distance;
  }
  // Offset has no dot product; inline it for the projection parameter.
  final ap = p - a;
  final t = ((ap.dx * ab.dx + ap.dy * ab.dy) / lengthSquared).clamp(0.0, 1.0);
  return (p - (a + ab * t)).distance;
}

double _min(double a, double b) => a < b ? a : b;
