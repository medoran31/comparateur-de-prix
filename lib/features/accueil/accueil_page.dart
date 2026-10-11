import 'package:flutter/material.dart';

import '../recherche/recherche_page.dart';
import '../recherche/moins_cher_page.dart';
import '../recherche/magasins_page.dart';
import '../recherche/favoris_page.dart';
import '../liste_courses/liste_courses_page.dart';
import '../marchand/connexion_marchand_page.dart';

class AccueilPage extends StatelessWidget {
  const AccueilPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),
              const Icon(
                Icons.storefront,
                size: 80,
                color: Color(0xFF1F3A5F),
              ),
              const SizedBox(height: 16),
              const Text(
                'AS3AR',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F3A5F),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Comparateur de prix - Oran',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 40),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const RecherchePage(),
                    ),
                  );
                },
                icon: const Icon(Icons.search),
                label: const Text('Rechercher un produit'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(18),
                  backgroundColor: const Color(0xFF1F3A5F),
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle(fontSize: 16),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const MoinsCherPage(),
                    ),
                  );
                },
                icon: const Icon(Icons.trending_down),
                label: const Text('Prix les moins chers'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(18),
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle(fontSize: 16),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const MagasinsPage(),
                    ),
                  );
                },
                icon: const Icon(Icons.store),
                label: const Text('Magasins'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(18),
                  backgroundColor: const Color(0xFF2E7D32),
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle(fontSize: 16),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ListeCoursesPage(),
                    ),
                  );
                },
                icon: const Icon(Icons.shopping_cart_outlined),
                label: const Text('Liste de courses'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.all(18),
                  textStyle: const TextStyle(fontSize: 16),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const FavorisPage(),
                    ),
                  );
                },
                icon: const Icon(Icons.favorite_border),
                label: const Text('Mes favoris'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.all(18),
                  textStyle: const TextStyle(fontSize: 16),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ConnexionMarchandPage(),
                    ),
                  );
                },
                icon: const Icon(Icons.lock_outline),
                label: const Text('Espace marchand'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.all(18),
                  textStyle: const TextStyle(fontSize: 16),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}