import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MesPrixPage extends StatefulWidget {
  const MesPrixPage({super.key});

  @override
  State<MesPrixPage> createState() => _MesPrixPageState();
}

class _MesPrixPageState extends State<MesPrixPage> {
  final supabase = Supabase.instance.client;
  String? _marchandId;
  bool _enChargement = true;
  bool _enEnregistrement = false;
  String? _erreur;
  List<Map<String, dynamic>> _produits = [];
  final Map<int, TextEditingController> _controleurs = {};

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
      final userId = supabase.auth.currentUser!.id;

      final marchands = await supabase
          .from('merchants')
          .select('id')
          .eq('user_id', userId);

      if (marchands.isEmpty) {
        setState(() {
          _erreur = "Aucune fiche marchand trouvee pour ce compte.";
          _enChargement = false;
        });
        return;
      }

      _marchandId = marchands[0]['id'];

      final produits = await supabase
          .from('products')
          .select()
          .eq('active', true)
          .order('name_fr');

      final prix = await supabase
          .from('prices')
          .select('product_id, amount_da, created_at')
          .eq('merchant_id', _marchandId!)
          .order('created_at', ascending: false);

      final Map<int, dynamic> dernierPrixParProduit = {};
      for (final ligne in prix) {
        final idProduit = ligne['product_id'] as int;
        if (!dernierPrixParProduit.containsKey(idProduit)) {
          dernierPrixParProduit[idProduit] = ligne['amount_da'];
        }
      }

      _controleurs.clear();
      for (final produit in produits) {
        final id = produit['id'] as int;
        final prixActuel = dernierPrixParProduit[id];
        final texteInitial = prixActuel != null ? prixActuel.toString() : "";
        _controleurs[id] = TextEditingController(text: texteInitial);
      }

      setState(() {
        _produits = List<Map<String, dynamic>>.from(produits);
        _enChargement = false;
      });
    } catch (e) {
      setState(() {
        _erreur = "Erreur de chargement : " + e.toString();
        _enChargement = false;
      });
    }
  }

  Future<void> _toutConfirmer() async {
    setState(() {
      _enEnregistrement = true;
    });
    try {
      final lignes = <Map<String, dynamic>>[];
      for (final produit in _produits) {
        final id = produit['id'] as int;
        final controleur = _controleurs[id];
        if (controleur == null) continue;
        final texte = controleur.text.trim();
        if (texte.isEmpty) continue;
        final montant = num.tryParse(texte);
        if (montant == null || montant <= 0) continue;

        lignes.add({
          'merchant_id': _marchandId,
          'product_id': id,
          'amount_da': montant,
          'source': 'confirmation',
        });
      }

      if (lignes.isNotEmpty) {
        await supabase.from('prices').insert(lignes);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Vos prix ont ete confirmes.")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erreur : " + e.toString()),
            duration: const Duration(seconds: 10),
          ),
        );
      }
    } finally {
      setState(() {
        _enEnregistrement = false;
      });
    }
  }

  @override
  void dispose() {
    for (final c in _controleurs.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Mes prix")),
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
                child: const Text("Reessayer"),
              ),
            ],
          ),
        ),
      )
          : Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _produits.length,
              itemBuilder: (context, index) {
                final produit = _produits[index];
                final id = produit['id'] as int;
                return Card(
                  child: ListTile(
                    title: Text(produit['name_fr']),
                    subtitle: Text(produit['unit']),
                    trailing: SizedBox(
                      width: 110,
                      child: TextField(
                        controller: _controleurs[id],
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.right,
                        decoration: const InputDecoration(
                          suffixText: "DA",
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton.icon(
              onPressed: _enEnregistrement ? null : _toutConfirmer,
              icon: _enEnregistrement
                  ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
                  : const Icon(Icons.check),
              label: const Text("Tout confirmer"),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                minimumSize: const Size.fromHeight(50),
              ),
            ),
          ),
        ],
      ),
    );
  }
}