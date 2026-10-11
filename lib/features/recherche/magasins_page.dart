import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'fiche_marchand_page.dart';

class MagasinsPage extends StatefulWidget {
  const MagasinsPage({super.key});

  @override
  State<MagasinsPage> createState() => _MagasinsPageState();
}

class _MagasinsPageState extends State<MagasinsPage> {
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _marchands = [];
  List<Map<String, dynamic>> _marchandsFiltres = [];
  bool _enChargement = true;
  String? _erreur;
  String _recherche = '';

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    setState(() {
      _enChargement = true;
      _erreur = null;
    });
    try {
      final reponse = await supabase
          .from('merchants')
          .select('id, name, quarter, lat, lng, status')
          .eq('status', 'actif')
          .order('name');

      // On inclut aussi les marchands en periode d essai.
      final reponseEssai = await supabase
          .from('merchants')
          .select('id, name, quarter, lat, lng, status')
          .eq('status', 'essai')
          .order('name');

      final tous = [
        ...List<Map<String, dynamic>>.from(reponse),
        ...List<Map<String, dynamic>>.from(reponseEssai),
      ];
      tous.sort((a, b) =>
          (a['name'] as String).compareTo(b['name'] as String));

      if (!mounted) return;
      setState(() {
        _marchands = tous;
        _marchandsFiltres = tous;
        _enChargement = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erreur = "Erreur de chargement : $e";
        _enChargement = false;
      });
    }
  }

  void _filtrer(String texte) {
    final recherche = texte.trim().toLowerCase();
    setState(() {
      _recherche = recherche;
      if (recherche.isEmpty) {
        _marchandsFiltres = _marchands;
      } else {
        _marchandsFiltres = _marchands.where((m) {
          final nom = (m['name'] ?? '').toString().toLowerCase();
          final quartier = (m['quarter'] ?? '').toString().toLowerCase();
          return nom.contains(recherche) || quartier.contains(recherche);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Magasins"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _charger,
            tooltip: "Actualiser",
          ),
        ],
      ),
      body: _enChargement
          ? const Center(child: CircularProgressIndicator())
          : _erreur != null
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_erreur!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _charger,
                child: const Text("Réessayer"),
              ),
            ],
          ),
        ),
      )
          : Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: const InputDecoration(
                hintText: "Rechercher par nom ou quartier...",
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: _filtrer,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              _marchandsFiltres.length.toString() +
                  " magasin(s) trouve(s)",
              style: const TextStyle(
                  color: Colors.grey, fontSize: 12),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _marchandsFiltres.isEmpty
                ? Center(
              child: Text(
                _recherche.isEmpty
                    ? "Aucun magasin disponible pour le moment."
                    : "Aucun magasin ne correspond à cette recherche.",
                textAlign: TextAlign.center,
                style:
                const TextStyle(color: Colors.grey),
              ),
            )
                : RefreshIndicator(
              onRefresh: _charger,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12),
                itemCount: _marchandsFiltres.length,
                itemBuilder: (context, index) {
                  final m = _marchandsFiltres[index];
                  final nom =
                      m['name']?.toString() ?? '';
                  final quartier =
                      m['quarter']?.toString() ?? '';
                  final aPosition =
                      m['lat'] != null && m['lng'] != null;
                  final statut =
                      m['status']?.toString() ?? 'essai';

                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                        const Color(0xFF1F3A5F)
                            .withOpacity(0.1),
                        child: Text(
                          nom.isNotEmpty
                              ? nom[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1F3A5F),
                          ),
                        ),
                      ),
                      title: Text(
                        nom,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold),
                      ),
                      subtitle: Row(
                        children: [
                          const Icon(Icons.location_on,
                              size: 14,
                              color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            quartier,
                            style: const TextStyle(
                                fontSize: 13),
                          ),
                          if (!aPosition) ...[
                            const SizedBox(width: 8),
                            const Icon(
                                Icons.location_off,
                                size: 14,
                                color: Colors.grey),
                          ],
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (statut == 'essai')
                            Container(
                              padding:
                              const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.orange
                                    .withOpacity(0.15),
                                borderRadius:
                                BorderRadius.circular(
                                    12),
                              ),
                              child: const Text(
                                "essai",
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.orange),
                              ),
                            ),
                          const SizedBox(width: 4),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                FicheMarchandPage(
                                  marchandId:
                                  m['id'].toString(),
                                  marchandNom: nom,
                                  quartier: quartier,
                                  lat: m['lat'] != null
                                      ? (m['lat'] as num)
                                      .toDouble()
                                      : null,
                                  lng: m['lng'] != null
                                      ? (m['lng'] as num)
                                      .toDouble()
                                      : null,
                                ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}