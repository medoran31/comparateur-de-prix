// Test de fumee : verifie que l'ecran d'accueil s'affiche correctement.
//
// Ce test ne contacte pas le reseau : la page d'accueil est purement
// visuelle (l'initialisation de Supabase se fait dans main(), pas dans
// le widget MyApp).

import 'package:flutter_test/flutter_test.dart';

import 'package:comparateur_prix/main.dart';

void main() {
  testWidgets("L'accueil affiche le titre et les boutons principaux",
      (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    // Le titre de l'application.
    expect(find.text('AS3AR'), findsOneWidget);

    // Les boutons principaux sont presents.
    expect(find.text('Rechercher un produit'), findsOneWidget);
    expect(find.text('Prix les moins chers'), findsOneWidget);
    expect(find.text('Magasins'), findsOneWidget);
    expect(find.text('Liste de courses'), findsOneWidget);
    expect(find.text('Mes favoris'), findsOneWidget);
    expect(find.text('Espace marchand'), findsOneWidget);
  });
}
