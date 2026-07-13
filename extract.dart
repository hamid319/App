import 'dart:developer' as developer;
import 'dart:io';

void main() {
  final file = File('lib/features/swipe/ui/swipe_screen.dart');
  final lines = file.readAsLinesSync();

  int cardStart = -1;
  int cardEnd = -1;
  int buttonStart = -1;

  for (int i = 0; i < lines.length; i++) {
    if (lines[i].contains('class TinderSwipeCardStack')) {
      cardStart = i;
    }
    if (lines[i].contains('// ACTION BUTTON WIDGET')) {
      cardEnd = i - 1;
      buttonStart = i + 2;
    }
    if (lines[i].contains('class _ActionButton ')) {
      buttonStart = i;
    }
  }

  int buttonEnd = lines.length;

  final cardFile = File('lib/features/swipe/widgets/swipe_card.dart');
  final cardContent = StringBuffer();
  cardContent.writeln("import 'package:flutter/material.dart';");
  cardContent.writeln("import 'dart:math' as math;");
  cardContent.writeln("import '../../../common/models/place_model.dart';");
  cardContent.writeln("import 'swipe_buttons.dart';\n");
  for (int i = cardStart; i < cardEnd; i++) {
    cardContent.writeln(lines[i].replaceAll('_ActionButton', 'ActionButton'));
  }
  cardFile.writeAsStringSync(cardContent.toString());

  final buttonFile = File('lib/features/swipe/widgets/swipe_buttons.dart');
  final buttonContent = StringBuffer();
  buttonContent.writeln("import 'package:flutter/material.dart';\n");
  for (int i = buttonStart; i < buttonEnd; i++) {
    buttonContent.writeln(lines[i].replaceAll('_ActionButton', 'ActionButton'));
  }
  buttonFile.writeAsStringSync(buttonContent.toString());

  final newScreenContent = StringBuffer();
  for (int i = 0; i < cardStart; i++) {
    newScreenContent.writeln(lines[i]);
  }
  file.writeAsStringSync(newScreenContent.toString());

  developer.log('Extraction successful');
}
