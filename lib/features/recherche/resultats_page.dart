import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'fiche_marchand_page.dart';
import '../../core/fraicheur.dart';
import '../../core/partage.dart';

class ResultatsPage extends StatefulWidget {
  final int produitId;
  final String produitNom;

  const ResultatsPage({
    super.key,
    required this.produitId,
    required this.produitNom,
  });

  @override
  State<ResultatsPage> createState() => _ResultatsPageState();
}

class _ResultatsPageState extends State<ResultatsPage> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _resultats = [];
  bool _enChargement = true;
  String? _erreur;
  Position? _positionActuelle;
  String _tri = "prix";

  @override
  void initState() {
    super.initState();
    _chargerTout();
  }

  Future<void> _chargerTout() async {
    await _obtenirPosition();
    await _chargerPrix();
  }

  Future<void> _obtenirPosition() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      final serviceActive = await Geolocator.isLocationServiceEnabled();
      if (!serviceActive) {
        return;
      }
      final position = await Geolocator.getCurrentPosition();
      setState(() {
        _positionActuelle = position;
      });
    } catch (e) {
      // Pas de position disponible, ce n est pas bloquant.
    }
  }

  Future<void> _chargerPrix() async {
    try {
      final resultats = await supabase
          .from('prices')
          .select('id, amount_da, created_at, merchant_id, merchants(name, quarter, lat, lng)')
          .eq('product_id', widget.produitId)
          .order('created_at', ascending: false);

      final Map<String, Map<String, dynamic>> dernierPrixParMarchand = {};
      for (final ligne in resultats) {
        final idMarchand = ligne['merchant_id'] as String;
        if (!dernierPrixParMarchand.containsKey(idMarchand)) {
          dernierPrixParMarchand[idMarchand] = ligne;
        }
      }

      final liste = dernierPrixParMarchand.values.toList();
      _trierListe(liste);

      setState(() {
        _resultats = liste;
        _enChargement = false;
      });
    } catch (e) {
      setState(() {
        _erreur = "Erreur : " + e.toString();
        _enChargement = false;
      });
    }
  }

  double? _distanceVersMarchand(Map<String, dynamic> marchand) {
    if (_positionActuelle == null) return null;
    final lat = marchand['lat'];
    final lng = marchand['lng'];
    if (lat == null || lng == null) return null;
    return Geolocator.distanceBetween(
      _positionActuelle!.latitude,
      _positionActuelle!.longitude,
      (lat as num).toDouble(),
      (lng as num).toDouble(),
    );
  }

  void _trierListe(List<Map<String, dynamic>> liste) {
    if (_tri == "distance" && _positionActuelle != null) {
      liste.sort((a, b) {
        final da = _distanceVersMarchand(a['merchants']);
        final db = _distanceVersMarchand(b['merchants']);
        if (da == null && db == null) return 0;
        if (da == null) return 1;
        if (db == null) return -1;
        return da.compareTo(db);
      });
    } else {
      liste.sort((a, b) => (a['amount_da'] as num).compareTo(b['amount_da'] as num));
    }
  }

  void _changerTri(String nouveauTri) {
    setState(() {
      _tri = nouveauTri;
      _trierListe(_resultats);
    });
  }

  Future<void> _partagerResultats() async {
    final lignes = _resultats.map((l) {
      final marchand = l['merchants'];
      return "- ${marchand['name']} (${marchand['quarter']}) : ${l['amount_da']} DA";
    }).join('\n');
    final resume = "${widget.produitNom} :\n$lignes";
    await partagerTexte(
      messagePartagePanier(resume),
      sujet: widget.produitNom,
    );
  }

  String _texteDistance(double metres) {
    if (metres < 1000) {
      return metres.round().toString() + " m";
    }
    final km = metres / 1000;
    return km.toStringAsFixed(1) + " km";
  }

  @override
  Widget build(BuildContext context) {
    String? idMoinsCher;
    num? meilleurPrix;
    for (final ligne in _resultats) {
      final date = DateTime.parse(ligne['created_at']);
      final estRecent = DateTime.now().difference(date).inHours < 72;
      if (estRecent) {
        final montant = ligne['amount_da'] as num;
        if (meilleurPrix == null || montant < meilleurPrix) {
          meilleurPrix = montant;
          idMoinsCher = ligne['id'].toString();
        }
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.produitNom),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Partager',
            onPressed: _resultats.isEmpty ? null : _partagerResultats,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Text("Trier par : "),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text("Prix"),
                  selected: _tri == "prix",
                  onSelected: (_) => _changerTri("prix"),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text("Distance"),
                  selected: _tri == "distance",
                  onSelected: (_) => _changerTri("distance"),
                ),
              ],
            ),
          ),
          Expanded(
            child: _enChargement
                ? const Center(child: CircularProgressIndicator())
                : _erreur != null
                ? Center(child: Text(_erreur!))
                : _resultats.isEmpty
                ? const Center(child: Text("Aucun prix trouve pour ce produit pour le moment."))
                : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _resultats.length,
              itemBuilder: (context, index) {
                final ligne = _resultats[index];
                final marchand = ligne['merchants'];
                final estLeMoinsCher = ligne['id'].toString() == idMoinsCher;
                final distance = _distanceVersMarchand(marchand);

                var sousTitre = marchand['quarter'].toString();
                if (distance != null) {
                  sousTitre = sousTitre + " • " + _texteDistance(distance);
                }

                return Card(
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => FicheMarchandPage(
                            marchandId: ligne['merchant_id'],
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
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  marchand['name'],
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600, fontSize: 16),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  sousTitre,
                                  style: const TextStyle(
                                      fontSize: 13, color: Colors.grey),
                                ),
                                const SizedBox(height: 2),
                                LigneFraicheurPrix(ligne['created_at']),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                ligne['amount_da'].toString() + " DA",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: prixAncien(ligne['created_at'])
                                        ? Colors.grey
                                        : null),
                              ),
                              if (estLeMoinsCher)
                                const Padding(
                                  padding: EdgeInsets.only(top: 2),
                                  child: Text(
                                    "Le moins cher",
                                    style: TextStyle(
                                        color: Colors.green, fontSize: 12),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}