// Console shell : un clic dans la zone noire lui donne le clavier, les touches partent vers le serveur.
import 'package:flutter/gestures.dart';
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

    // Ctrl+C sans sélection : interruption envoyée au serveur
    tape.clear();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    expect(tape.toString(), '\x03');

    // Sélection à la souris puis Ctrl+C : copie dans le presse-papiers, rien n'est envoyé
    String? copie;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copie = (call.arguments as Map)['text'] as String?;
      return null;
    });
    ConsoleShell.instance.terminal.write('MQTT_HOTE_VPS=mqtt.emplettes.eu\r\n');
    await tester.pump();
    final zone = tester.getTopLeft(find.byType(TerminalView));
    final g = await tester.startGesture(zone + const Offset(12, 12), kind: PointerDeviceKind.mouse);
    await g.moveTo(zone + const Offset(300, 14));
    await g.up();
    await tester.pump();
    tape.clear();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(copie, contains('MQTT_HOTE_VPS'));
    expect(tape.toString(), isEmpty);
    expect(find.byType(Scrollbar), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  });
}
