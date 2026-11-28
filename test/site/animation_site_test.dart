// Image animée du mini site (docs/animation.webp), dessinée depuis animation_emplettes.dart.
// Ne s'exécute qu'à la demande : ANIMATION=1 flutter test --update-goldens test/site/animation_site_test.dart
// puis python3 outils/animation/assembler.py (qui efface les images intermédiaires).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'animation_emplettes.dart';

const imagesParSeconde = 20;

void main() {
  final actif = Platform.environment['ANIMATION'] == '1';
  if (!actif) {
    test('image animée du site (ANIMATION=1)', () {}, skip: true);
    return;
  }
  final n = (AnimationEmplettes.duree.inMilliseconds / 1000 * imagesParSeconde).round();
  for (var i = 0; i <= n; i++) {
    testWidgets('image $i', (tester) async {
      tester.view.physicalSize = const Size(540, 630);
      tester.view.devicePixelRatio = 1.5;
      addTearDown(tester.view.reset);
      AnimationEmplettes.instantEssai = i / n;
      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: RepaintBoundary(
            child: Padding(padding: const EdgeInsets.fromLTRB(10, 120, 40, 15), child: const AnimationEmplettes(hauteur: 200)),
          ),
        ),
      ));
      await tester.runAsync(() async {
        for (final f in imagesAnimationEmplettes) {
          await precacheImage(MemoryImage(octetsAnimation(f)), tester.element(find.byType(AnimationEmplettes)));
        }
      });
      await tester.pump();
      await expectLater(find.byType(RepaintBoundary), matchesGoldenFile('images/${i.toString().padLeft(3, '0')}.png'));
    });
  }
}
