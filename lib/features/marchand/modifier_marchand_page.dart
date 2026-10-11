import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ModifierMarchandPage extends StatefulWidget {
  final Map<String, dynamic> marchand;

  const ModifierMarchandPage({super.key, required this.marchand});

  @override
  State<ModifierMarchandPage> createState() => _ModifierMarchandPageState();
}

class _ModifierMarchandPageState extends State<ModifierMarchandPage> {
  final supabase = Supabase.instance.client;

  late final TextEditingController _nomController;
  late final TextEditingController _quartierController;
  late String _statut;
  DateTime? _finEssai;

  bool _enregistrement = false;

  final List<String> _statutsPossibles = ['essai', 'actif', 'suspendu'];

  @override
  void initState() {
    super.initState();

    _nomController = TextEditingController(
      text: widget.marchand['name']?.toString() ?? '',
    );
    _quartierController = TextEditingController(
      text: widget.marchand['quarter']?.toString() ?? '',
    );
    _statut = widget.marchand['status']?.toString() ?? 'essai';

    final trialEndTexte = widget.marchand['trial_end']?.toString();
    if (trialEndTexte != null && trialEndTexte.isNotEmpty) {
      _finEssai = DateTime.tryParse(trialEndTexte);
    }
  }

  @override
  void dispose() {
    _nomController.dispose();
    _quartierController.dispose();
    super.dispose();
  }

  Future<void> _choisirDate() async {
    final maintenant = DateTime.now();
    final choix = await showDatePicker(
      context: context,
      initialDate: _finEssai ?? maintenant.add(const Duration(days: 28)),
      firstDate: maintenant.subtract(const Duration(days: 365)),
      lastDate: maintenant.add(const Duration(days: 365 * 2)),
    );

    if (choix != null) {
      setState(() {
        _finEssai = choix;
      });
    }
  }

  Future<void> _enregistrer() async {
    final nom = _nomController.text.trim();
    final quartier = _quartierController.text.trim();

    if (nom.isEmpty || quartier.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Le nom et le quartier sont obligatoires.")),
      );
      return;
    }

    setState(() {
      _enregistrement = true;
    });

    try {
      final donnees = <String, dynamic>{
        'name': nom,
        'quarter': quartier,
        'status': _statut,
      };

      if (_finEssai != null) {
        donnees['trial_end'] = _finEssai!.toIso8601String().split('T')[0];
      }

      await supabase
          .from('merchants')
          .update(donnees)
          .eq('id', widget.marchand['id']);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Marchand mis a jour.")),
      );

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _enregistrement = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur : " + e.toString())),
      );
    }
  }

  String _texteDate(DateTime date) {
    final jour = date.day.toString().padLeft(2, '0');
    final mois = date.month.toString().padLeft(2, '0');
    return jour + "/" + mois + "/" + date.year.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Modifier le marchand")),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: ListView(
          children: [
            TextField(
              controller: _nomController,
              enabled: !_enregistrement,
              decoration: const InputDecoration(
                labelText: "Nom du commerce",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _quartierController,
              enabled: !_enregistrement,
              decoration: const InputDecoration(
                labelText: "Quartier",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _statut,
              decoration: const InputDecoration(
                labelText: "Statut",
                border: OutlineInputBorder(),
              ),
              items: _statutsPossibles.map((statut) {
                return DropdownMenuItem<String>(
                  value: statut,
                  child: Text(statut),
                );
              }).toList(),
              onChanged: _enregistrement
                  ? null
                  : (value) {
                if (value != null) {
                  setState(() {
                    _statut = value;
                  });
                }
              },
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text("Fin de la periode d'essai"),
              subtitle: Text(
                _finEssai != null ? _texteDate(_finEssai!) : "Non definie",
              ),
              trailing: const Icon(Icons.calendar_today),
              onTap: _enregistrement ? null : _choisirDate,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _enregistrement ? null : _enregistrer,
              icon: _enregistrement
                  ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
                  : const Icon(Icons.save),
              label: const Text("Enregistrer"),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                minimumSize: const Size.fromHeight(50),
              ),
            ),
          ],
        ),
      ),
    );
  }
}