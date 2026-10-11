import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'features/accueil/accueil_page.dart';

const String supabaseUrl = 'https://nvmnmpnmbdomyaunrtuf.supabase.co';
const String supabaseAnonKey =
    'sb_publishable_mIyB9YM896c4j4iqMyIveg_iRN8jtVO';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AS3AR',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1F3A5F),
        ),
        // Fond general de l'application : bleu tres clair (au lieu du blanc).
        scaffoldBackgroundColor: const Color(0xFFEEF4FF),
        useMaterial3: true,
      ),
      home: const AccueilPage(),
    );
  }
}