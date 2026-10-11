import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../main.dart';

class AjouterMarchandPage extends StatefulWidget {
  const AjouterMarchandPage({super.key});

  @override
  State<AjouterMarchandPage> createState() => _AjouterMarchandPageState();
}

class _AjouterMarchandPageState extends State<AjouterMarchandPage> {
  final supabase = Supabase.instance.client;

  final _identifiantController = TextEditingController();
  final _codeController = TextEditingController();
  final _nomController = TextEditingController();
  final _quartierController = TextEditingController();

  bool _enregistrement = false;

  @override
  void dispose() {
    _identifiantController.dispose();
    _codeController.dispose();
    _nomController.dispose();
    _quartierController.dispose();
    super.dispose();
  }

  Future<void> _creerMarchand() async {
    final identifiant = _identifiantController.text.trim().toUpperCase();
    final code = _codeController.text.trim();
    final nom = _nomController.text.trim();
    final quartier = _quartierController.text.trim();

    if (identifiant.isEmpty || code.isEmpty || nom.isEmpty || quartier.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Merci de remplir tous les champs.")),
      );
      return;
    }

    if (code.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Le code doit avoir au moins 6 caracteres.")),
      );
      return;
    }

    setState(() {
      _enregistrement = true;
    });

    // Un client Supabase temporaire et independant, pour ne jamais toucher
    // a la session de l'administrateur actuellement connecte.
    // authFlowType: implicit evite le besoin d'un stockage special.
    final clientTemporaire = SupabaseClient(
      supabaseUrl,
      supabaseAnonKey,
      authOptions: const AuthClientOptions(
        authFlowType: AuthFlowType.implicit,
      ),
    );

    try {
      final emailTechnique = identifiant + "@marchands.local";

      final resultatInscription = await clientTemporaire.auth.signUp(
        email: emailTechnique,
        password: code,
      );

      final nouvelUtilisateur = resultatInscription.user;

      if (nouvelUtilisateur == null) {
        throw Exception("La creation du compte a echoue.");
      }

      final nouvelUserId = nouvelUtilisateur.id;

      await supabase.from('user_roles').insert({
        'user_id': nouvelUserId,
        'role': 'marchand',
      });

      final finEssai = DateTime.now().add(const Duration(days: 28));
      final finEssaiTexte = finEssai.toIso8601String().split('T')[0];

      await supabase.from('merchants').insert({
        'user_id': nouvelUserId,
        'name': nom,
        'quarter': quartier,
        'phone': identifiant,
        'status': 'essai',
        'trial_end': finEssaiTexte,
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Marchand " + identifiant + " cree avec succes.")),
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
    } finally {
      await clientTemporaire.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Ajouter un marchand")),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: ListView(
          children: [
            const Text(
              "Creez un identifiant et un code pour un nouveau marchand. "
                  "Il pourra se connecter immediatement avec ces informations.",
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _identifiantController,
              textCapitalization: TextCapitalization.characters,
              enabled: !_enregistrement,
              decoration: const InputDecoration(
                labelText: "Identifiant",
                hintText: "Ex. KHOUDJA, RAHMA_USTO...",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _codeController,
              enabled: !_enregistrement,
              decoration: const InputDecoration(
                labelText: "Code (au moins 6 caracteres)",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
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
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _enregistrement ? null : _creerMarchand,
              icon: _enregistrement
                  ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
                  : const Icon(Icons.store),
              label: const Text("Creer le marchand"),
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