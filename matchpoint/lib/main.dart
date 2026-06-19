 import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'providers/app_provider.dart';
import 'router/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await initializeDateFormatting('pt_BR');
  runApp(const MatchPointApp());
}

class MatchPointApp extends StatefulWidget {
  const MatchPointApp({super.key});

  @override
  State<MatchPointApp> createState() => _MatchPointAppState();
}

class _MatchPointAppState extends State<MatchPointApp> {
  late final AppProvider _provider;
  late final GoRouter _router;
  static final _theme = _buildTheme();

  @override
  void initState() {
    super.initState();
    _provider = AppProvider()..init();
    _router = buildRouter(_provider);
  }

  @override
  void dispose() {
    _provider.dispose();
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _provider,
      child: MaterialApp.router(
        title: 'MatchPoint UFBA',
        routerConfig: _router,
        theme: _theme,
      ),
    );
  }
}

ThemeData _buildTheme() {
  const primary = Color(0xFF2563EB);
  const slate900 = Color(0xFF0F172A);
  const slate50 = Color(0xFFF8FAFC);
  const slate200 = Color(0xFFE2E8F0);
  const slate100 = Color(0xFFF1F5F9);

  final base = ColorScheme.fromSeed(
    seedColor: primary,
    surface: Colors.white,
    brightness: Brightness.light,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: base,
    scaffoldBackgroundColor: slate50,
    textTheme: GoogleFonts.interTextTheme(),

    // AppBar
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: GoogleFonts.inter(
        color: slate900,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
      iconTheme: const IconThemeData(color: slate900),
    ),

    // Cards
    cardTheme: CardThemeData(
      elevation: 0,
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: slate200),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    ),

    // Inputs
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: slate100,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFEF4444)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:
            const BorderSide(color: Color(0xFFEF4444), width: 2),
      ),
    ),

    // Filled buttons
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        textStyle: GoogleFonts.inter(
            fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),

    // Outlined buttons
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        side: const BorderSide(color: slate200),
        textStyle: GoogleFonts.inter(
            fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),

    // Chips
    chipTheme: ChipThemeData(
      backgroundColor: slate100,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20)),
      side: BorderSide.none,
    ),

    // Bottom nav
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      indicatorColor: primary.withValues(alpha: 0.1),
      labelTextStyle: WidgetStateProperty.all(
        GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600),
      ),
    ),

    // Dividers
    dividerTheme: const DividerThemeData(
      color: slate200,
      space: 1,
    ),
  );
}
