import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/pet_repository.dart';
import 'l10n/app_localizations.dart';
import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const PetbookApp());
}

class PetbookApp extends StatefulWidget {
  const PetbookApp({super.key});

  @override
  State<PetbookApp> createState() => _PetbookAppState();
}

class _PetbookAppState extends State<PetbookApp> {
  Locale? _locale;
  bool _loaded = false;

  final PetRepository _repo = PetRepository();

  @override
  void initState() {
    super.initState();
    _loadAppData();
  }

  Future<void> _loadAppData() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString('app_locale');

    await _repo.loadPets();

    setState(() {
      _locale = (code == null) ? null : Locale(code);
      _loaded = true;
    });
  }

  Future<void> _setLocale(Locale? locale) async {
    final prefs = await SharedPreferences.getInstance();

    if (locale == null) {
      await prefs.remove('app_locale');
    } else {
      await prefs.setString('app_locale', locale.languageCode);
    }

    setState(() => _locale = locale);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Petbook',
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('el'),
      ],
      locale: _locale,
      theme: AppTheme.lightTheme,
      home: SplashScreen(
        repo: _repo,
        onChangeLocale: _setLocale,
        currentLocale: _locale,
      ),
    );
  }
}
