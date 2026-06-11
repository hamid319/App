import sys

with open('lib/features/swipe/ui/swipe_screen.dart', 'r') as f:
    lines = f.readlines()

card_start = -1
card_end = -1
button_start = -1
button_end = -1

for i, line in enumerate(lines):
    if 'class TinderSwipeCardStack' in line:
        card_start = i
    if '// ACTION BUTTON WIDGET' in line:
        card_end = i - 1
        button_start = i + 2
    if 'class _ActionButton ' in line:
        button_start = i

button_end = len(lines)

with open('lib/features/swipe/widgets/swipe_card.dart', 'w') as f:
    f.write("import 'package:flutter/material.dart';\n")
    f.write("import 'dart:math' as math;\n")
    f.write("import '../../../common/models/place_model.dart';\n")
    f.write("import 'swipe_buttons.dart';\n\n")
    for i in range(card_start, card_end):
        f.write(lines[i].replace('_ActionButton', 'ActionButton'))

with open('lib/features/swipe/widgets/swipe_buttons.dart', 'w') as f:
    f.write("import 'package:flutter/material.dart';\n\n")
    for i in range(button_start, button_end):
        f.write(lines[i].replace('_ActionButton', 'ActionButton'))

with open('lib/features/swipe/ui/swipe_screen.dart', 'w') as f:
    for i in range(0, card_start):
        f.write(lines[i])

print("Extraction successful")
