import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config/api_config.dart';
import 'screens/main_shell.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'services/sound_service.dart';
import 'theme/app_tema.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SoundService.instance.inicializalas();
  await TemaVezerlo.betoltes();

  // Mentett felhasználónév betöltése (ha volt már onboarding)
  final prefs = await SharedPreferences.getInstance();
  final savedName = prefs.getString('current_user_name');
  if (savedName != null && savedName.isNotEmpty) {
    ApiConfig.defaultUserName = savedName;
  }

  runApp(const FitnessApp());
}

class FitnessApp extends StatefulWidget {
  const FitnessApp({super.key});

  @override
  State<FitnessApp> createState() => _FitnessAppState();
}

class _FitnessAppState extends State<FitnessApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    // Rendszer módban az OS világos/sötét váltását is követjük.
    setState(() => AppSzinek.frissites());
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: TemaVezerlo.mod,
      builder: (context, mod, _) {
        AppSzinek.frissites();
        return MaterialApp(
          title: 'Flexio',
          debugShowCheckedModeBanner: false,
          theme: vilagosTema(),
          darkTheme: sotetTema(),
          themeMode: mod,
          home: const _SplashRouter(),
        );
      },
    );
  }
}

class _SplashRouter extends StatefulWidget {
  const _SplashRouter();

  @override
  State<_SplashRouter> createState() => _SplashRouterState();
}

class _SplashRouterState extends State<_SplashRouter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;

  Widget? _kovetkezo;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _scaleAnim = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut)
        .drive(Tween(begin: 0.5, end: 1.0));
    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn)
        .drive(Tween(begin: 0.0, end: 1.0));

    _ctrl.forward().then((_) async {
      // Meghatározzuk a következő képernyőt a splash után
      final prefs = await SharedPreferences.getInstance();
      final onboardingKesz = prefs.getBool('onboarding_complete') ?? false;
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      setState(() {
        _kovetkezo = onboardingKesz
            ? const MainShell()
            : const OnboardingScreen();
      });
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_kovetkezo != null) return _kovetkezo!;

    return Scaffold(
      backgroundColor: AppSzinek.felulet,
      body: Center(
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, _) => FadeTransition(
            opacity: _fadeAnim,
            child: ScaleTransition(
              scale: _scaleAnim,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/logo.png',
                    width: 90,
                    height: 90,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Flexio',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: AppSzinek.szoveg,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Lépj szintet!',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey.shade500,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
