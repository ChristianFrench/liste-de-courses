import 'package:flutter_test/flutter_test.dart';
import 'package:liste_de_courses/main.dart';

void main() {
  testWidgets('Affiche le nom de l\'application', (tester) async {
    await tester.pumpWidget(const ListeDeCoursesApp());
    expect(find.text('Liste de courses'), findsOneWidget);
  });
}
