import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'fiche_marchand_page.dart';
import '../../core/cache_hors_ligne.dart';

const String _cleMoinsCher = 'prix_moins_chers';

class MoinsCherPage extends StatefulWidget {
  const MoinsCherPage({super.key});

  @override
  State<MoinsCherPage> createState() => _MoinsCherPageState();
}

class _MoinsCherPageState extends State<MoinsCherPage> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _resultats = [];
  bool _enChargement = true;
  String? _erreur;
  bool _horsLigne = false;
  String? _dateCache;

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
      final prix = await supabase
          .from('prices')
          .select(
          'id, amount_da, created_at, product_id, merchant_id, products!inner(name_fr, name_ar, unit, active), merchants(id, name, quarter, lat, lng)')
          .eq('products.active', true)
          .order('created_at', ascending: false);

      final Map<int, Map<String, dynamic>> moinsCherParProduit = {};

      for (final ligne in prix) {
        final idProduit = ligne['product_id'] as int;
        final montant = (ligne['amount_da'] as num).toDouble();

        if (!moinsCherParProduit.containsKey(idProduit)) {
          moinsCherParProduit[idProduit] = ligne;
        } else {
          final montantActuel =
          (moinsCherParProduit[idProduit]!['amount_da'] as num).toDouble();
          if (montant < montantActuel) {
            moinsCherParProduit[idProduit] = ligne;
          }
        }
      }

      final liste = moinsCherParProduit.values.toList();
      liste.sort((a, b) => (a['products']['name_fr'] as String)
          .compareTo(b['products']['name_fr'] as String));

      await sauvegarderCache(_cleMoinsCher, liste);

      if (!mounted) return;
      setState(() {
        _resultats = liste;
        _horsLigne = false;
        _dateCache = null;
        _enChargement = false;
      });
    } catch (e) {
      final cache = await lireCache(_cleMoinsCher);

      if (!mounted) return;

      if (cache != null) {
        final liste = List<Map<String, dynamic>>.from(cache['donnees']);
        setState(() {
          _resultats = liste;
          _horsLigne = true;
          _dateCache = cache['date'];
          _enChargement = false;
        });
      } else {
        setState(() {
          _erreur = "Erreur de chargement : $e";
          _enChargement = false;
        });
      }
    }
  }

  String _texteDelai(String dateTexte) {
    final date = DateTime.parse(dateTexte);
    final difference = DateTime.now().difference(date);
    if (difference.inHours < 1) return "il y a moins d'une heure";
    if (difference.inHours < 24) return "il y a ${difference.inHours} h";
    if (difference.inDays < 7) return "il y a ${difference.inDays} j";
    return "il y a plus d'une semaine";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Prix les moins chers"),
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
          : _resultats.isEmpty
          ? const Center(
          child: Text("Aucun prix disponible pour le moment."))
          : RefreshIndicator(
        onRefresh: _charger,
        child: Column(
          children: [
            if (_horsLigne)
              Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3CD),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.wifi_off, size: 18, color: Color(0xFF856404)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Hors ligne - prix du " +
                            (_dateCache != null ? texteDateCache(_dateCache!) : ""),
                        style: const TextStyle(color: Color(0xFF856404), fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _resultats.length,
                itemBuilder: (context, index) {
                  final ligne = _resultats[index];
                  final produit = ligne['products'];
                  final marchand = ligne['merchants'];
                  return Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      title: Row(
                        mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              produit['name_fr'],
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1F3A5F),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              "${ligne['amount_da']} DA",
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.storefront,
                                  size: 14, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text(
                                marchand['name'],
                                style: const TextStyle(
                                    color: Colors.grey, fontSize: 13),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.location_on,
                                  size: 14, color: Colors.grey),
                              const SizedBox(width: 2),
                              Text(
                                marchand['quarter'],
                                style: const TextStyle(
                                    color: Colors.grey, fontSize: 13),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(Icons.access_time,
                                  size: 14, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text(
                                _texteDelai(ligne['created_at']),
                                style: const TextStyle(
                                    color: Colors.grey, fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => FicheMarchandPage(
                              marchandId: marchand['id'],
                              marchandNom: marchand['name'],
                              quartier: marchand['quarter'],
                              lat: marchand['lat'] != null
                                  ? (marchand['lat'] as num).toDouble()
                                  : null,
                              lng: marchand['lng'] != null
                                  ? (marchand['lng'] as num).toDouble()
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
          ],
        ),
      ),
    );
  }
}