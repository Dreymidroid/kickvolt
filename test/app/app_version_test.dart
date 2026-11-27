import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kickvolt/app/app_constants.dart';

void main() {
  test('AppConstants.appVersion equals pubspec.yaml version', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match = RegExp(
      r'^version:\s*(\S+)\s*$',
      multiLine: true,
    ).firstMatch(pubspec);
    expect(match, isNotNull, reason: 'pubspec.yaml must declare version:');
    expect(AppConstants.appVersion, match!.group(1));
  });
}
