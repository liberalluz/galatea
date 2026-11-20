import 'package:flutter_test/flutter_test.dart';
import 'package:galatea/ui/writing/verdict.dart';

/// B15 verdict contracts (`TC-QUIZ-004`): the stroke-overlap threshold is
/// the recorded sample-point coverage — a sampled user point is covered
/// when its shortest distance to the model polylines is at most 0.09 of
/// the glyph square, and the verdict is ✓ when at least 0.7 of the
/// sampled points are covered.
List<List<Offset>> hline() => [
  [const Offset(0.2, 0.5), const Offset(0.8, 0.5)],
];

List<List<Offset>> strokeAlong(Offset from, Offset to) => [
  [from, to],
];

void main() {
  test('a stroke along the model line is covered (✓)', () {
    expect(
      writingVerdict(
        hline(),
        strokeAlong(const Offset(0.25, 0.5), const Offset(0.75, 0.5)),
      ),
      isTrue,
    );
  });

  test('a stroke with small jitter stays covered (✓)', () {
    final jittered = [
      for (var i = 0; i <= 20; i++)
        Offset(0.25 + i * 0.025, 0.5 + (i.isEven ? 0.02 : -0.02)),
    ];
    expect(writingVerdict(hline(), [jittered]), isTrue);
  });

  test('a stroke offset beyond the radius fails (×)', () {
    expect(
      writingVerdict(
        hline(),
        strokeAlong(const Offset(0.25, 0.2), const Offset(0.75, 0.2)),
      ),
      isFalse,
    );
  });

  test('a shape far off the model fails (×)', () {
    expect(
      writingVerdict(
        hline(),
        strokeAlong(const Offset(0.1, 0.1), const Offset(0.1, 0.9)),
      ),
      isFalse,
    );
  });

  test('a stroke offset exactly the radius is covered (boundary)', () {
    // Every point of a horizontal stroke offset by 0.09 sits exactly on
    // the radius; the comparison is inclusive.
    expect(
      writingVerdict(
        hline(),
        strokeAlong(const Offset(0.25, 0.41), const Offset(0.75, 0.41)),
      ),
      isTrue,
    );
  });

  test('partial coverage below the threshold fails (×)', () {
    // A vertical stroke crosses the model line; only the crossing band is
    // covered, well below the 0.7 threshold.
    expect(
      writingVerdict(
        hline(),
        strokeAlong(const Offset(0.5, 0.1), const Offset(0.5, 0.9)),
      ),
      isFalse,
    );
  });
}
