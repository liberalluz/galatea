import 'package:flutter/foundation.dart';

import 'notation.dart';

/// The notation selection shared across the app (`REQ-036`).
///
/// The chart page owns the KK / DJ / IPA switch and the detail page reads
/// the same selection, so the symbol the user picked on the chart is the
/// symbol the detail page shows — the mapping row, the top-bar circles and
/// the pronunciation line all follow it. The controller lives at the shell
/// level because both pages are separate routes; a page-local state would
/// be lost on the way from the chart to the detail page.
///
/// KK is the default (`REQ-003`).
class NotationController extends ChangeNotifier {
  Notation _notation = Notation.kk;

  /// The currently selected notation.
  Notation get notation => _notation;

  /// Selects [notation] and notifies the listeners. Selecting the active
  /// notation again does not notify.
  void select(Notation notation) {
    if (_notation == notation) {
      return;
    }
    _notation = notation;
    notifyListeners();
  }
}
