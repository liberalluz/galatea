import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:galatea/ui/theme/tokens.dart';

void main() {
  test('the spacing and width tokens carry the design spec values', () {
    expect(AppTokens.spaceGroup, 24);
    expect(AppTokens.spaceItem, 12);
    expect(AppTokens.spaceLabel, 16);
    expect(AppTokens.labelColumnWidth, 62);
  });

  test('the type tokens carry the 20/14/14/12 scale', () {
    expect(AppTokens.typePage.fontSize, 20);
    expect(AppTokens.typePage.fontWeight, FontWeight.w600);
    expect(AppTokens.typeGroup.fontSize, 14);
    expect(AppTokens.typeGroup.fontWeight, FontWeight.w600);
    expect(AppTokens.typeBody.fontSize, 14);
    expect(AppTokens.typeBody.fontWeight, FontWeight.w400);
    expect(AppTokens.typeHint.fontSize, 12);
    expect(AppTokens.typeHint.fontWeight, FontWeight.w400);
  });
}
