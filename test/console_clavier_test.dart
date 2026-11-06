// Console shell : un clic dans la zone noire lui donne le clavier, les touches partent vers le serveur.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liste_de_courses/ecrans/administration_serveur.dart';
import 'package:xterm/xterm.dart';

void main() {
  testWidgets('console shell : clic puis frappe', (tester) async {
    PageShell.ouvrirAuto = false;
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final tape = StringBuffer();
    ConsoleShell.instance.terminal.onOutput = tape.write;
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: PageShell())));
    await tester.pumpAndSettle();
    // Le clavier part ailleurs (comme après un clic sur un bouton), puis revient par un clic dans la zone noire
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    await tester.tap(find.byType(TerminalView));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(tape.toString(), contains('a'));
    expect(tape.toString(), contains('\r'));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  });
}
