import 'package:flutter/material.dart';

/// The design spec's design tokens (`design-spec.md`, Design token section,
/// 2026-11-24): the semantic names are fixed for the whole app, the values
/// come from the spec, and no screen re-declares them per surface. The About
/// page is the first landing point (`B35`); the chart, detail and practice
/// screens keep their literal values until they are next touched, so this
/// file grows by consumption rather than by a single app-wide restyle.
class AppTokens {
  const AppTokens._();

  /// `space-group` — the gap between two groups.
  static const double spaceGroup = 24;

  /// `space-item` — the gap between two rows of one group.
  static const double spaceItem = 12;

  /// `space-label` — the gap between the label column and the value column.
  static const double spaceLabel = 16;

  /// `width-label` — the fixed label column (mobile baseline, reused on the
  /// wide single column).
  static const double labelColumnWidth = 62;

  /// `type-page` 20/600 — page titles.
  static const TextStyle typePage = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.4,
  );

  /// `type-group` 14/600 — group titles.
  static const TextStyle typeGroup = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.4,
  );

  /// `type-body` 14/400 — body copy.
  static const TextStyle typeBody = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  /// `type-hint` 12/400 — supporting copy.
  static const TextStyle typeHint = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  /// `text-primary` — body copy and the label column. The 2026-11-24 ruling
  /// puts the label column on the primary colour: it carries the notation
  /// names (KK, DJ / IPA), so it is content, not a hint.
  static Color textPrimary(BuildContext context) =>
      Theme.of(context).colorScheme.onSurface;

  /// `text-secondary` — supporting copy only.
  static Color textSecondary(BuildContext context) =>
      Theme.of(context).colorScheme.onSurfaceVariant;

  /// `divider` — the 1px rule between groups and any other separator.
  static Color divider(BuildContext context) =>
      Theme.of(context).colorScheme.outlineVariant;

  /// `surface-muted` — the grey fill of muted strips and chips.
  static Color surfaceMuted(BuildContext context) =>
      Theme.of(context).colorScheme.surfaceContainerHighest;
}
