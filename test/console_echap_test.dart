import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liste_de_courses/ecrans/administration_serveur.dart';
import 'package:liste_de_courses/main.dart';
import 'package:xterm/xterm.dart';

void main() {
  testWidgets('console shell : Échap va au serveur', (tester) async {
    PageShell.ouvrirAuto = false;
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final tape = StringBuffer();
    ConsoleShell.instance.terminal.onOutput = tape.write;
    await tester.pumpWidget(const ListeDeCoursesApp(accueil: Scaffold(body: PageShell())));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TerminalView));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    print('sortie=${tape.toString().codeUnits} lignes=${ConsoleShell.instance.terminal.viewHeight}');
    expect(tape.toString(), contains('\x1b'));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  });
}
