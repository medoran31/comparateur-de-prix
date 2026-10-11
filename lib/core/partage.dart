import 'package:share_plus/share_plus.dart';

/// Numero WhatsApp de l'organisateur AS3AR (abonnements, informations).
const String numeroWhatsAppAS3AR = '213771331792';

/// Lien de l'application.
///
/// A RENSEIGNER le jour ou l'application sera publiee sur le Play Store,
/// par exemple :
///   const String lienApplication =
///       'https://play.google.com/store/apps/details?id=dz.comparateur.comparateur_prix';
///
/// Tant qu'il est vide, le QR code et les partages invitent simplement a
/// decouvrir AS3AR (aucun lien mort n'est affiche).
const String lienApplication = '';

/// Texte de partage pour la fiche d'un marchand.
String messagePartageMarchand(String nom, String quartier) {
  final lien = lienApplication.isEmpty ? '' : '\n$lienApplication';
  return "Sur AS3AR, l'application qui compare les prix a Oran, "
      "retrouvez les prix de $nom ($quartier).$lien";
}

/// Texte de partage pour une liste de courses / un panier.
String messagePartagePanier(String resume) {
  final lien = lienApplication.isEmpty ? '' : '\n$lienApplication';
  return "Sur AS3AR, l'application qui compare les prix a Oran, "
      "voici le comparatif de mon panier :\n\n$resume$lien";
}

/// Contenu encode dans le QR code d'un marchand.
///
/// Si l'application est publiee, le QR pointe vers le lien de telechargement.
/// Sinon, il ouvre une conversation WhatsApp avec AS3AR afin de rester utile.
String contenuQrMarchand(String nom, String quartier) {
  if (lienApplication.isNotEmpty) {
    return '$lienApplication';
  }
  final texte = Uri.encodeComponent(
    "Bonjour, je decouvre AS3AR (comparateur de prix a Oran) chez $nom ($quartier).",
  );
  return 'https://wa.me/$numeroWhatsAppAS3AR?text=$texte';
}

/// Ouvre la feuille de partage du telephone (WhatsApp, Facebook, SMS...).
Future<void> partagerTexte(String texte, {String? sujet}) async {
  await SharePlus.instance.share(
    ShareParams(text: texte, subject: sujet),
  );
}
