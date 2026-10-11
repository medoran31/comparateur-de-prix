import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChangerCodeAdminPage extends StatefulWidget {
  const ChangerCodeAdminPage({super.key});

  @override
  State<ChangerCodeAdminPage> createState() => _ChangerCodeAdminPageState();
}

class _ChangerCodeAdminPageState extends State<ChangerCodeAdminPage> {
  final supabase = Supabase.instance.client;

  final _ancienCodeController = TextEditingController();
  final _nouveauCodeController = TextEditingController();
  final _confirmationController = TextEditingController();

  bool _enregistrement = false;
  String? _erreur;

  @override
  void dispose() {
    _ancienCodeController.dispose();
    _nouveauCodeController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  Future<void> _changerCode() async {
    final ancienCode = _ancienCodeController.text.trim();
    final nouveauCode = _nouveauCodeController.text.trim();
    final confirmation = _confirmationController.text.trim();

    setState(() {
      _erreur = null;
    });

    if (ancienCode.isEmpty || nouveauCode.isEmpty || confirmation.isEmpty) {
      setState(() {
        _erreur = "Merci de remplir tous les champs.";
      });
      return;
    }

    if (nouveauCode.length < 6) {
      setState(() {
        _erreur = "Le nouveau code doit avoir au moins 6 caracteres.";
      });
      return;
    }

    if (nouveauCode != confirmation) {
      setState(() {
        _erreur = "Le nouveau code et la confirmation ne correspondent pas.";
      });
      return;
    }

    if (nouveauCode == ancienCode) {
      setState(() {
        _erreur = "Le nouveau code doit etre different de l ancien.";
      });
      return;
    }

    setState(() {
      _enregistrement = true;
    });

    try {
      final utilisateur = supabase.auth.currentUser;
      if (utilisateur == null) {
        throw Exception("Vous n etes plus connecte.");
      }

      final email = utilisateur.email!;

      await supabase.auth.signInWithPassword(
        email: email,
        password: ancienCode,
      );

      await supabase.auth.updateUser(
        UserAttributes(password: nouveauCode),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Code change avec succes.")),
      );

      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;

      final message = e.toString().toLowerCase();
      String texteErreur;

      if (message.contains('invalid') ||
          message.contains('wrong') ||
          message.contains('credentials')) {
        texteErreur = "L ancien code est incorrect.";
      } else {
        texteErreur = "Erreur : " + e.toString();
      }

      setState(() {
        _erreur = texteErreur;
        _enregistrement = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Changer mon code")),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "Saisissez votre ancien code, puis choisissez un nouveau "
                  "code d au moins 6 caracteres.",
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _ancienCodeController,
              obscureText: true,
              enabled: !_enregistrement,
              decoration: const InputDecoration(
                labelText: "Ancien code",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nouveauCodeController,
              obscureText: true,
              enabled: !_enregistrement,
              decoration: const InputDecoration(
                labelText: "Nouveau code (6 caracteres minimum)",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirmationController,
              obscureText: true,
              enabled: !_enregistrement,
              decoration: const InputDecoration(
                labelText: "Confirmer le nouveau code",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            if (_erreur != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _erreur!,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),
            ElevatedButton.icon(
              onPressed: _enregistrement ? null : _changerCode,
              icon: _enregistrement
                  ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
                  : const Icon(Icons.lock_reset),
              label: const Text("Changer le code"),
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