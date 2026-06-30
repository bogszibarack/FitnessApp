import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/api_config.dart';
import '../../services/apple_health_service.dart';
import '../main_shell.dart';
import 'login_screen.dart';

// ─── Konstansok ──────────────────────────────────────────────────────────────

const _kDark = Color(0xFF0D0D0D);
const _kBlue = Color(0xFF2979FF);
const _kGreen = Color(0xFF4CAF50);
const _kGrey = Color(0xFFE0E0E0);
const _kTextLight = Color(0xFF888888);

const _kMegyek = [
  'Bács-Kiskun', 'Baranya', 'Békés', 'Borsod-Abaúj-Zemplén',
  'Budapest', 'Csongrád-Csanád', 'Fejér', 'Győr-Moson-Sopron',
  'Hajdú-Bihar', 'Heves', 'Jász-Nagykun-Szolnok', 'Komárom-Esztergom',
  'Nógrád', 'Pest', 'Somogy', 'Szabolcs-Szatmár-Bereg',
  'Tolna', 'Vas', 'Veszprém', 'Zala',
];

const _kForrasok = [
  ('Influencer', Icons.person_outline),
  ('AI Kereső', Icons.psychology_outlined),
  ('Barátok / Rokonok', Icons.group_outlined),
  ('Google / Cikk', Icons.search_outlined),
  ('Instagram', Icons.camera_alt_outlined),
  ('App Store', Icons.store_outlined),
  ('TikTok', Icons.music_video_outlined),
  ('Egyéb', Icons.more_horiz_outlined),
];

// ─── Fő képernyő ─────────────────────────────────────────────────────────────

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageCtrl = PageController();
  int _page = 0;

  // Regisztráció adatok
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _userCtrl = TextEditingController();
  bool _passVisible = false;

  // Mértékegységek
  String _sulyEgyseg = 'kg';
  String _tavolsagEgyseg = 'km';
  String _testmeretEgyseg = 'cm';

  // Profil
  final _sulyCtrl = TextEditingController();
  String? _valasztottMegye;

  // Felmérés
  String? _valasztottForras;

  // Feature showcase
  final _featurePageCtrl = PageController();
  int _featurePage = 0;

  bool _betoltes = false;

  @override
  void dispose() {
    _pageCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _userCtrl.dispose();
    _sulyCtrl.dispose();
    _featurePageCtrl.dispose();
    super.dispose();
  }

  void _kovetkezoLepesre() {
    if (_page < 7) {
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  void _kihagyasra() {
    _pageCtrl.animateToPage(
      7,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _regisztracioEllenorzes() async {
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;
    final user = _userCtrl.text.trim();

    if (email.isEmpty || pass.isEmpty || user.isEmpty) {
      _hibaUzenet('Kérjük töltsd ki az összes mezőt!');
      return;
    }
    if (!email.contains('@') || !email.contains('.')) {
      _hibaUzenet('Érvénytelen e-mail cím!');
      return;
    }
    if (pass.length < 6) {
      _hibaUzenet('A jelszó legalább 6 karakter legyen!');
      return;
    }
    if (user.length < 3) {
      _hibaUzenet('A felhasználónév legalább 3 karakter legyen!');
      return;
    }

    setState(() => _betoltes = true);
    try {
      // Helyi ellenőrzés (backend-újraindítás esetén is megbízható)
      final prefs = await SharedPreferences.getInstance();
      final rawJson = prefs.getString('local_accounts') ?? '[]';
      final List<dynamic> fiokList = jsonDecode(rawJson) as List<dynamic>;
      for (final f in fiokList) {
        final fiok = f as Map<String, dynamic>;
        if ((fiok['email'] as String).toLowerCase() == email.toLowerCase()) {
          _hibaUzenet('Ez az e-mail cím már foglalt. Próbálj bejelentkezni!');
          return;
        }
        if ((fiok['username'] as String).toLowerCase() == user.toLowerCase()) {
          _hibaUzenet('Ez a felhasználónév már foglalt. Válassz másikat!');
          return;
        }
      }

      // Backend ellenőrzés (ha elérhető)
      final emailUrl = Uri.parse(
          '${ApiConfig.baseUrl}/api/auth/check-email?email=${Uri.encodeComponent(email)}');
      final emailResp =
          await http.get(emailUrl).timeout(const Duration(seconds: 5));
      if (emailResp.statusCode == 200) {
        final json = jsonDecode(emailResp.body) as Map<String, dynamic>;
        if (json['occupied'] == true) {
          _hibaUzenet('Ez az e-mail cím már foglalt. Próbálj bejelentkezni!');
          return;
        }
      }
      final userUrl = Uri.parse(
          '${ApiConfig.baseUrl}/api/auth/check-username?username=${Uri.encodeComponent(user)}');
      final userResp =
          await http.get(userUrl).timeout(const Duration(seconds: 5));
      if (userResp.statusCode == 200) {
        final json = jsonDecode(userResp.body) as Map<String, dynamic>;
        if (json['occupied'] == true) {
          _hibaUzenet('Ez a felhasználónév már foglalt. Válassz másikat!');
          return;
        }
      }
    } catch (_) {
      // Backend nem elérhető — helyi ellenőrzés már megtörtént, folytatjuk
    } finally {
      if (mounted) setState(() => _betoltes = false);
    }

    _kovetkezoLepesre();
  }

  Future<void> _regisztracioKuldes() async {
    setState(() => _betoltes = true);

    final email = _emailCtrl.text.trim().toLowerCase();
    final username = _userCtrl.text.trim();
    final password = _passCtrl.text;

    // Helyi mentés MINDIG megtörténik — backend-független bejelentkezéshez
    await _helybentiMentes(email: email, username: username, password: password);

    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/api/auth/register-onboarding');
      final valasz = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'Email': email,
              'Password': password,
              'Username': username,
              'WeightUnit': _sulyEgyseg,
              'DistanceUnit': _tavolsagEgyseg,
              'MeasurementUnit': _testmeretEgyseg,
              'Weight': double.tryParse(_sulyCtrl.text) ?? 0,
              'County': _valasztottMegye ?? '',
              'Source': _valasztottForras ?? '',
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (valasz.statusCode == 200) {
        final json = jsonDecode(valasz.body) as Map<String, dynamic>;
        final userName = json['userName'] as String? ?? username;
        await _onboardingBefejezese(userName);
      } else if (valasz.statusCode == 409) {
        // Már létezik: beengedjük, az adatok megvannak helyileg
        await _onboardingBefejezese(username);
      } else {
        final json = jsonDecode(valasz.body) as Map<String, dynamic>;
        _hibaUzenet(json['error'] as String? ?? 'Hiba történt a regisztráció során.');
      }
    } catch (_) {
      // Backend nem elérhető — helyi adatokkal folytatjuk
      if (!mounted) return;
      await _onboardingBefejezese(username.isNotEmpty ? username : 'Felhasználó');
    } finally {
      if (mounted) setState(() => _betoltes = false);
    }
  }

  /// Regisztrált fiók helyi mentése SharedPreferences-be.
  /// Ez garantálja, hogy backend-újraindítás után is be lehessen lépni.
  Future<void> _helybentiMentes({
    required String email,
    required String username,
    required String password,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    // Meglévő fiókok beolvasása (JSON lista)
    final rawJson = prefs.getString('local_accounts') ?? '[]';
    final List<dynamic> fiokList = jsonDecode(rawJson) as List<dynamic>;

    // Duplikált email/username ellenőrzés
    final mar = fiokList.any((f) {
      final m = f as Map<String, dynamic>;
      return (m['email'] as String).toLowerCase() == email ||
          (m['username'] as String).toLowerCase() == username.toLowerCase();
    });
    if (!mar) {
      fiokList.add({
        'email': email,
        'username': username,
        'password': password,
      });
      await prefs.setString('local_accounts', jsonEncode(fiokList));
    }
  }

  Future<void> _onboardingBefejezese(String userName) async {
    ApiConfig.defaultUserName = userName;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);
    await prefs.setString('current_user_name', userName);
    await prefs.setString('weight_unit', _sulyEgyseg);
    await prefs.setString('distance_unit', _tavolsagEgyseg);
    await prefs.setString('measurement_unit', _testmeretEgyseg);
    if (_valasztottMegye != null) {
      await prefs.setString('county', _valasztottMegye!);
    }
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainShell()),
      (_) => false,
    );
  }

  void _hibaUzenet(String uzenet) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(uzenet),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _page == 0
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _page == 0 ? _kDark : Colors.white,
        body: Stack(
          children: [
            PageView(
              controller: _pageCtrl,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (i) => setState(() => _page = i),
              children: [
                _WelcomePage(
                  onRegisztracio: _kovetkezoLepesre,
                  onBejelentkezes: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const LoginScreen()),
                  ),
                ),
                _RegistrationPage(
                  emailCtrl: _emailCtrl,
                  passCtrl: _passCtrl,
                  userCtrl: _userCtrl,
                  passVisible: _passVisible,
                  onPassToggle: () =>
                      setState(() => _passVisible = !_passVisible),
                  onContinue: _regisztracioEllenorzes,
                  onSkip: _kihagyasra,
                ),
                _UnitsPage(
                  sulyEgyseg: _sulyEgyseg,
                  tavolsagEgyseg: _tavolsagEgyseg,
                  testmeretEgyseg: _testmeretEgyseg,
                  onSulyChange: (v) => setState(() => _sulyEgyseg = v),
                  onTavolsagChange: (v) => setState(() => _tavolsagEgyseg = v),
                  onTestmeretChange: (v) =>
                      setState(() => _testmeretEgyseg = v),
                  onContinue: _kovetkezoLepesre,
                  onSkip: _kihagyasra,
                ),
                _AppleHealthPage(
                  onEngedelyez: () async {
                    await AppleHealthService.instance.requestPermissions();
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('health_enabled', true);
                    _kovetkezoLepesre();
                  },
                  onKihagyas: _kovetkezoLepesre,
                ),
                _ProfilePage(
                  sulyCtrl: _sulyCtrl,
                  valasztottMegye: _valasztottMegye,
                  sulyEgyseg: _sulyEgyseg,
                  onMegyeChange: (v) => setState(() => _valasztottMegye = v),
                  onContinue: _kovetkezoLepesre,
                  onSkip: _kihagyasra,
                ),
                _SurveyPage(
                  valasztott: _valasztottForras,
                  onValaszt: (v) => setState(() => _valasztottForras = v),
                  onContinue: () {
                    if (_valasztottForras == null) {
                      _hibaUzenet('Válassz egyet a lehetőségek közül!');
                      return;
                    }
                    _kovetkezoLepesre();
                  },
                  onSkip: _kihagyasra,
                ),
                _FeaturesPage(
                  pageCtrl: _featurePageCtrl,
                  featurePage: _featurePage,
                  onPageChanged: (i) => setState(() => _featurePage = i),
                  onContinue: _kovetkezoLepesre,
                  onSkip: _kihagyasra,
                ),
                _SuccessPage(
                  betoltes: _betoltes,
                  onKezdes: _regisztracioKuldes,
                ),
              ],
            ),
            // Haladásjelző pontok (lépések 1-6, az üdvözlő és befejező nélkül)
            if (_page > 0 && _page < 7)
              Positioned(
                top: MediaQuery.of(context).padding.top + 12,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    6,
                    (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: (_page - 1) == i ? 20 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: (_page - 1) == i
                            ? _kBlue
                            : _kGrey,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Lap 1: Üdvözlő képernyő ─────────────────────────────────────────────────

class _WelcomePage extends StatefulWidget {
  final VoidCallback onRegisztracio;
  final VoidCallback onBejelentkezes;

  const _WelcomePage({
    required this.onRegisztracio,
    required this.onBejelentkezes,
  });

  @override
  State<_WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<_WelcomePage>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0D0D0D), Color(0xFF1A1A1A)],
        ),
      ),
      child: SafeArea(
        child: FadeTransition(
          opacity: _fade,
          child: SlideTransition(
            position: _slide,
            child: Column(
              children: [
                const Spacer(flex: 3),
                // Logo
                Image.asset(
                  'assets/logo.png',
                  width: 90,
                  height: 90,
                  color: Colors.white,
                  colorBlendMode: BlendMode.srcIn,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Flexio',
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Üdvözöl a Flexio!',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.55),
                    letterSpacing: 0.2,
                  ),
                ),
                const Spacer(flex: 3),
                // Gombok
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      _WelcomeBtn(
                        label: 'Regisztráció',
                        primary: true,
                        onTap: widget.onRegisztracio,
                      ),
                      const SizedBox(height: 12),
                      _WelcomeBtn(
                        label: 'Bejelentkezés',
                        primary: false,
                        onTap: widget.onBejelentkezes,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 36),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WelcomeBtn extends StatelessWidget {
  final String label;
  final bool primary;
  final VoidCallback onTap;

  const _WelcomeBtn({
    required this.label,
    required this.primary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          backgroundColor: primary ? _kBlue : Colors.white.withOpacity(0.1),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: primary
                ? BorderSide.none
                : BorderSide(color: Colors.white.withOpacity(0.2)),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ─── Lap 2: Regisztrációs űrlap ───────────────────────────────────────────────

class _RegistrationPage extends StatefulWidget {
  final TextEditingController emailCtrl;
  final TextEditingController passCtrl;
  final TextEditingController userCtrl;
  final bool passVisible;
  final VoidCallback onPassToggle;
  final Future<void> Function() onContinue;
  final VoidCallback onSkip;

  const _RegistrationPage({
    required this.emailCtrl,
    required this.passCtrl,
    required this.userCtrl,
    required this.passVisible,
    required this.onPassToggle,
    required this.onContinue,
    required this.onSkip,
  });

  @override
  State<_RegistrationPage> createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<_RegistrationPage> {
  bool get _emailOk =>
      widget.emailCtrl.text.isNotEmpty &&
      widget.emailCtrl.text.contains('@') &&
      widget.emailCtrl.text.contains('.');
  bool get _passOk => widget.passCtrl.text.length >= 6;
  bool get _userOk => widget.userCtrl.text.length >= 3;
  bool get _mindenOk => _emailOk && _passOk && _userOk;

  @override
  Widget build(BuildContext context) {
    return _StepScaffold(
      title: 'Regisztráció',
      onSkip: widget.onSkip,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 32),
            _ValidatedField(
              ctrl: widget.emailCtrl,
              label: 'E-mail',
              hint: 'pelda@gmail.com',
              isOk: _emailOk,
              keyboardType: TextInputType.emailAddress,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 4),
            _ValidatedField(
              ctrl: widget.passCtrl,
              label: 'Jelszó',
              hint: 'minimum 6 karakter',
              isOk: _passOk,
              obscure: !widget.passVisible,
              suffixIcon: IconButton(
                onPressed: widget.onPassToggle,
                icon: Icon(
                  widget.passVisible
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: _kTextLight,
                  size: 20,
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 4),
            _ValidatedField(
              ctrl: widget.userCtrl,
              label: 'Felhasználónév',
              hint: 'felhasznalonev',
              isOk: _userOk,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'A regisztrációval elfogadod az Általános Szerződési Feltételeket és az Adatvédelmi irányelveket.',
                style: TextStyle(
                  fontSize: 12,
                  color: _kTextLight,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 8),
            _ContinueButton(
              label: 'Tovább',
              enabled: _mindenOk,
              onTap: () => widget.onContinue(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ValidatedField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final String hint;
  final bool isOk;
  final bool obscure;
  final TextInputType? keyboardType;
  final Widget? suffixIcon;
  final ValueChanged<String>? onChanged;

  const _ValidatedField({
    required this.ctrl,
    required this.label,
    required this.hint,
    required this.isOk,
    this.obscure = false,
    this.keyboardType,
    this.suffixIcon,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6, top: 12),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF333333),
            ),
          ),
        ),
        TextFormField(
          controller: ctrl,
          obscureText: obscure,
          keyboardType: keyboardType,
          onChanged: onChanged,
          style: const TextStyle(fontSize: 15, color: Color(0xFF111111)),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: _kTextLight, fontSize: 14),
            filled: true,
            fillColor: const Color(0xFFF7F7F7),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isOk ? _kGreen : const Color(0xFFE0E0E0),
                width: isOk ? 1.5 : 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isOk ? _kGreen : _kBlue,
                width: 1.5,
              ),
            ),
            suffixIcon: isOk
                ? const Padding(
                    padding: EdgeInsets.only(right: 12),
                    child: Icon(Icons.check_circle_rounded,
                        color: _kGreen, size: 22),
                  )
                : suffixIcon,
            suffixIconConstraints:
                const BoxConstraints(minWidth: 44, minHeight: 44),
          ),
        ),
      ],
    );
  }
}

// ─── Lap 3: Mértékegységek ────────────────────────────────────────────────────

// ─── Lap 4: Apple Health ─────────────────────────────────────────────────────

class _AppleHealthPage extends StatefulWidget {
  final Future<void> Function() onEngedelyez;
  final VoidCallback onKihagyas;

  const _AppleHealthPage({
    required this.onEngedelyez,
    required this.onKihagyas,
  });

  @override
  State<_AppleHealthPage> createState() => _AppleHealthPageState();
}

class _AppleHealthPageState extends State<_AppleHealthPage>
    with SingleTickerProviderStateMixin {
  bool _betoltes = false;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    // iOS-on kívül automatikusan továbblépünk
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isIosPlatform()) {
        widget.onKihagyas();
      }
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  bool _isIosPlatform() {
    try {
      return Platform.isIOS || Platform.isMacOS;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Billentyűzet elrejtése ha az előző oldalról maradt fókusz
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.white,
        // Billentyűzet megjelenésekor a tartalom scrollolható legyen
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: Column(
            children: [
              // Kihagyás gomb — fix a tetején
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: widget.onKihagyas,
                    child: const Text(
                      'Kihagyás',
                      style: TextStyle(
                        color: _kTextLight,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
              // Scrollolható tartalom
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    children: [
                      const SizedBox(height: 16),
                      // Szív ikon
                      ScaleTransition(
                        scale: _pulseAnim,
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF0F0),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFF3B30).withOpacity(0.18),
                                blurRadius: 24,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Center(child: _HeartIcon()),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Apple Health',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF111111),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Engedélyezd az Apple Health hozzáférést, hogy a Flexio leolvassa és naplózza az edzéseidet, lépésszámodat és égetett kalóriáidat.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: _kTextLight,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 28),
                      _HealthFeatureRow(
                        icon: Icons.directions_walk_rounded,
                        color: const Color(0xFF34C759),
                        text: 'Lépésszám és megtett távolság',
                      ),
                      const SizedBox(height: 10),
                      _HealthFeatureRow(
                        icon: Icons.local_fire_department_rounded,
                        color: const Color(0xFFFF6D00),
                        text: 'Aktív kalória és mozgásidő',
                      ),
                      const SizedBox(height: 10),
                      _HealthFeatureRow(
                        icon: Icons.monitor_heart_outlined,
                        color: const Color(0xFFFF3B30),
                        text: 'Edzés- és testmérési adatok',
                      ),
                      const SizedBox(height: 10),
                      _HealthFeatureRow(
                        icon: Icons.restaurant_menu_rounded,
                        color: const Color(0xFF5AC8FA),
                        text: 'Elfogyasztott tápanyagok',
                      ),
                      const SizedBox(height: 32),
                      // Engedélyezés gomb
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: _betoltes
                              ? null
                              : () async {
                                  FocusScope.of(context).unfocus();
                                  setState(() => _betoltes = true);
                                  try {
                                    await widget.onEngedelyez();
                                  } finally {
                                    if (mounted) setState(() => _betoltes = false);
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _kBlue,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: _betoltes
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Apple Health engedélyezése',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Most nem gomb
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: TextButton(
                          onPressed: widget.onKihagyas,
                          style: TextButton.styleFrom(
                            backgroundColor: const Color(0xFFF2F2F2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            'Most nem',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF555555),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeartIcon extends StatelessWidget {
  const _HeartIcon();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(54, 54),
      painter: _HeartPainter(),
    );
  }
}

class _HeartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFF6B8A), Color(0xFFFF3B30)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    final path = Path();
    final cx = size.width / 2;
    final cy = size.height / 2;
    final w = size.width * 0.9;
    final h = size.height * 0.85;

    // Szív alakú görbe
    path.moveTo(cx, cy + h * 0.28);
    path.cubicTo(
      cx - w * 0.05, cy + h * 0.1,
      cx - w * 0.5, cy - h * 0.12,
      cx - w * 0.5, cy - h * 0.25,
    );
    path.cubicTo(
      cx - w * 0.5, cy - h * 0.52,
      cx - w * 0.1, cy - h * 0.52,
      cx, cy - h * 0.25,
    );
    path.cubicTo(
      cx + w * 0.1, cy - h * 0.52,
      cx + w * 0.5, cy - h * 0.52,
      cx + w * 0.5, cy - h * 0.25,
    );
    path.cubicTo(
      cx + w * 0.5, cy - h * 0.12,
      cx + w * 0.05, cy + h * 0.1,
      cx, cy + h * 0.28,
    );
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _HealthFeatureRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _HealthFeatureRow({
    required this.icon,
    required this.color,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF333333),
            ),
          ),
        ),
        Icon(Icons.check_circle_rounded, color: color, size: 18),
      ],
    );
  }
}

class _UnitsPage extends StatelessWidget {
  final String sulyEgyseg;
  final String tavolsagEgyseg;
  final String testmeretEgyseg;
  final ValueChanged<String> onSulyChange;
  final ValueChanged<String> onTavolsagChange;
  final ValueChanged<String> onTestmeretChange;
  final VoidCallback onContinue;
  final VoidCallback onSkip;

  const _UnitsPage({
    required this.sulyEgyseg,
    required this.tavolsagEgyseg,
    required this.testmeretEgyseg,
    required this.onSulyChange,
    required this.onTavolsagChange,
    required this.onTestmeretChange,
    required this.onContinue,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return _StepScaffold(
      title: 'Mértékegységek',
      onSkip: onSkip,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 32),
            _UnitToggle(
              label: 'Súly',
              options: const ['kg', 'lbs'],
              selected: sulyEgyseg,
              onChanged: onSulyChange,
            ),
            const SizedBox(height: 20),
            _UnitToggle(
              label: 'Távolság',
              options: const ['km', 'miles'],
              selected: tavolsagEgyseg,
              onChanged: onTavolsagChange,
            ),
            const SizedBox(height: 20),
            _UnitToggle(
              label: 'Testméretek',
              options: const ['cm', 'in'],
              selected: testmeretEgyseg,
              onChanged: onTestmeretChange,
            ),
            const Spacer(),
            _ContinueButton(label: 'Tovább', onTap: onContinue),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _UnitToggle extends StatelessWidget {
  final String label;
  final List<String> options;
  final String selected;
  final ValueChanged<String> onChanged;

  const _UnitToggle({
    required this.label,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _kTextLight,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFFF2F2F2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: options.map((opt) {
              final isSelected = opt == selected;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onChanged(opt),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(9),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              )
                            ]
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      opt,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w400,
                        color: isSelected
                            ? const Color(0xFF111111)
                            : _kTextLight,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

// ─── Lap 4: Profil adatok & Megye ─────────────────────────────────────────────

class _ProfilePage extends StatelessWidget {
  final TextEditingController sulyCtrl;
  final String? valasztottMegye;
  final String sulyEgyseg;
  final ValueChanged<String?> onMegyeChange;
  final VoidCallback onContinue;
  final VoidCallback onSkip;

  const _ProfilePage({
    required this.sulyCtrl,
    required this.valasztottMegye,
    required this.sulyEgyseg,
    required this.onMegyeChange,
    required this.onContinue,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return _StepScaffold(
      title: 'Profil adatok',
      onSkip: onSkip,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 32),
            // Testsúly input
            const Text(
              'Testsúlyod',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF333333),
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: sulyCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(fontSize: 15, color: Color(0xFF111111)),
              decoration: InputDecoration(
                hintText: '70',
                hintStyle: TextStyle(color: _kTextLight, fontSize: 14),
                filled: true,
                fillColor: const Color(0xFFF7F7F7),
                suffixText: sulyEgyseg,
                suffixStyle: const TextStyle(
                  fontSize: 14,
                  color: _kTextLight,
                  fontWeight: FontWeight.w600,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _kBlue, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Megye választó
            const Text(
              'Megye (közösségi feedhez)',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF333333),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF7F7F7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE0E0E0)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: valasztottMegye,
                  hint: Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: Text(
                      'Válassz megyét...',
                      style: TextStyle(color: _kTextLight, fontSize: 14),
                    ),
                  ),
                  isExpanded: true,
                  borderRadius: BorderRadius.circular(12),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  items: _kMegyek
                      .map(
                        (m) => DropdownMenuItem(
                          value: m,
                          child: Text(
                            m,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF111111),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: onMegyeChange,
                ),
              ),
            ),
            const Spacer(),
            _ContinueButton(label: 'Tovább', onTap: onContinue),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ─── Lap 5: Felmérés ──────────────────────────────────────────────────────────

class _SurveyPage extends StatelessWidget {
  final String? valasztott;
  final ValueChanged<String> onValaszt;
  final VoidCallback onContinue;
  final VoidCallback onSkip;

  const _SurveyPage({
    required this.valasztott,
    required this.onValaszt,
    required this.onContinue,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return _StepScaffold(
      title: '',
      onSkip: onSkip,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            const Text(
              'Hogyan hallottál\nrólunk?',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111111),
                height: 1.2,
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.separated(
                itemCount: _kForrasok.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (ctx, i) {
                  final (nev, ikon) = _kForrasok[i];
                  final selected = valasztott == nev;
                  return GestureDetector(
                    onTap: () => onValaszt(nev),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: selected ? _kBlue : const Color(0xFFE5E5E5),
                          width: selected ? 2 : 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          )
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(ikon,
                              size: 20,
                              color:
                                  selected ? _kBlue : const Color(0xFF555555)),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              nev,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: selected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: selected
                                    ? _kBlue
                                    : const Color(0xFF222222),
                              ),
                            ),
                          ),
                          if (selected)
                            const Icon(Icons.check_rounded,
                                color: _kBlue, size: 20),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            _ContinueButton(
              label: 'Tovább',
              enabled: valasztott != null,
              onTap: onContinue,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ─── Lap 6: Funkciók bemutatása ───────────────────────────────────────────────

class _FeaturesPage extends StatelessWidget {
  final PageController pageCtrl;
  final int featurePage;
  final ValueChanged<int> onPageChanged;
  final VoidCallback onContinue;
  final VoidCallback onSkip;

  const _FeaturesPage({
    required this.pageCtrl,
    required this.featurePage,
    required this.onPageChanged,
    required this.onContinue,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return _StepScaffold(
      title: '',
      onSkip: onSkip,
      child: Column(
        children: [
          const SizedBox(height: 16),
          Expanded(
            child: PageView(
              controller: pageCtrl,
              onPageChanged: onPageChanged,
              children: const [
                _FeatureSlide(
                  title: 'Edzések naplózása',
                  subtitle:
                      'Egyszerűen rögzítsd minden szeted, súlyodat és ismétlésed. Kövesd nyomon a fejlődésedet minden egyes alkalommal.',
                  illustration: _WorkoutIllustration(),
                ),
                _FeatureSlide(
                  title: 'Fejlődés követése',
                  subtitle:
                      'Mélyreható elemzések és grafikonok segítenek megérteni, mennyit fejlődtél az idők során.',
                  illustration: _ProgressIllustration(),
                ),
              ],
            ),
          ),
          // Al-lap indikátor
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              2,
              (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: featurePage == i ? 20 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: featurePage == i
                      ? _kBlue
                      : _kGrey,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _ContinueButton(
              label: featurePage == 1 ? 'Befejezés' : 'Tovább',
              onTap: featurePage == 1
                  ? onContinue
                  : () => pageCtrl.nextPage(
                        duration: const Duration(milliseconds: 350),
                        curve: Curves.easeInOut,
                      ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _FeatureSlide extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget illustration;

  const _FeatureSlide({
    required this.title,
    required this.subtitle,
    required this.illustration,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111111),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: _kTextLight,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FF),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFE8ECFF)),
              ),
              padding: const EdgeInsets.all(24),
              child: illustration,
            ),
          ),
        ],
      ),
    );
  }
}

// Edzés naplózás illusztráció
class _WorkoutIllustration extends StatelessWidget {
  const _WorkoutIllustration();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.fitness_center_rounded, size: 48, color: _kBlue),
        const SizedBox(height: 20),
        _ExRow(label: 'Fekvenyomás', weight: '80 kg', reps: '10 ism.', done: true),
        const SizedBox(height: 8),
        _ExRow(label: 'Guggolás', weight: '100 kg', reps: '8 ism.', done: true),
        const SizedBox(height: 8),
        _ExRow(label: 'Húzódzkodás', weight: 'TT', reps: '12 ism.', done: false),
      ],
    );
  }
}

class _ExRow extends StatelessWidget {
  final String label;
  final String weight;
  final String reps;
  final bool done;

  const _ExRow({
    required this.label,
    required this.weight,
    required this.reps,
    required this.done,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: done ? const Color(0xFFEDF7ED) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: done ? _kGreen.withOpacity(0.3) : const Color(0xFFEEEEEE),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF222222))),
          ),
          Text(weight,
              style: TextStyle(
                  fontSize: 12,
                  color: done ? _kGreen : _kTextLight,
                  fontWeight: FontWeight.w500)),
          const SizedBox(width: 8),
          Text(reps,
              style: const TextStyle(fontSize: 12, color: _kTextLight)),
          const SizedBox(width: 8),
          Icon(done ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
              size: 18, color: done ? _kGreen : _kTextLight),
        ],
      ),
    );
  }
}

// Progresszió illusztráció
class _ProgressIllustration extends StatelessWidget {
  const _ProgressIllustration();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          '82 kg',
          style: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.w800,
            color: _kBlue,
          ),
        ),
        const Text(
          'Fekvenyomás – max súly',
          style: TextStyle(fontSize: 13, color: _kTextLight),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 100,
          child: CustomPaint(
            size: const Size(double.infinity, 100),
            painter: _ChartPainter(),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _ChipStat(label: 'Jan', value: '60 kg'),
            _ChipStat(label: 'Márc', value: '72 kg'),
            _ChipStat(label: 'Jún', value: '82 kg'),
          ],
        ),
      ],
    );
  }
}

class _ChipStat extends StatelessWidget {
  final String label;
  final String value;

  const _ChipStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF222222))),
        Text(label,
            style: const TextStyle(fontSize: 11, color: _kTextLight)),
      ],
    );
  }
}

class _ChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final points = [
      Offset(0, size.height * 0.8),
      Offset(size.width * 0.15, size.height * 0.7),
      Offset(size.width * 0.28, size.height * 0.65),
      Offset(size.width * 0.42, size.height * 0.55),
      Offset(size.width * 0.55, size.height * 0.5),
      Offset(size.width * 0.65, size.height * 0.35),
      Offset(size.width * 0.78, size.height * 0.25),
      Offset(size.width, size.height * 0.1),
    ];

    // Kitöltés
    final fillPath = Path()..moveTo(points.first.dx, size.height);
    for (int i = 0; i < points.length - 1; i++) {
      final cp1 = Offset(
        (points[i].dx + points[i + 1].dx) / 2,
        points[i].dy,
      );
      final cp2 = Offset(
        (points[i].dx + points[i + 1].dx) / 2,
        points[i + 1].dy,
      );
      fillPath.cubicTo(
          cp1.dx, cp1.dy, cp2.dx, cp2.dy, points[i + 1].dx, points[i + 1].dy);
    }
    fillPath
      ..lineTo(points.last.dx, size.height)
      ..close();

    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _kBlue.withOpacity(0.25),
            _kBlue.withOpacity(0.0),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    // Vonal
    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 0; i < points.length - 1; i++) {
      final cp1 = Offset(
        (points[i].dx + points[i + 1].dx) / 2,
        points[i].dy,
      );
      final cp2 = Offset(
        (points[i].dx + points[i + 1].dx) / 2,
        points[i + 1].dy,
      );
      linePath.cubicTo(
          cp1.dx, cp1.dy, cp2.dx, cp2.dy, points[i + 1].dx, points[i + 1].dy);
    }
    canvas.drawPath(
      linePath,
      Paint()
        ..color = _kBlue
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    // Pontok
    for (final p in points) {
      canvas.drawCircle(
        p,
        4,
        Paint()..color = _kBlue,
      );
      canvas.drawCircle(
        p,
        2.5,
        Paint()..color = Colors.white,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── Lap 7: Befejezés ────────────────────────────────────────────────────────

class _SuccessPage extends StatefulWidget {
  final bool betoltes;
  final VoidCallback onKezdes;

  const _SuccessPage({required this.betoltes, required this.onKezdes});

  @override
  State<_SuccessPage> createState() => _SuccessPageState();
}

class _SuccessPageState extends State<_SuccessPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    Future.delayed(const Duration(milliseconds: 200), _ctrl.forward);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(flex: 2),
              FadeTransition(
                opacity: _fade,
                child: ScaleTransition(
                  scale: _scale,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: _kGreen,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: _kGreen.withOpacity(0.35),
                          blurRadius: 28,
                          offset: const Offset(0, 8),
                        )
                      ],
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 56,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              FadeTransition(
                opacity: _fade,
                child: const Column(
                  children: [
                    Text(
                      'Készen állsz!',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111111),
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'A Flexio készen áll rá, hogy segítsen elérni a céljaidat. Kezdjük el!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        color: _kTextLight,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(flex: 3),
              _ContinueButton(
                label: widget.betoltes ? '' : 'Kezdés!',
                onTap: widget.betoltes ? () {} : widget.onKezdes,
                loading: widget.betoltes,
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Közös segéd widgetek ─────────────────────────────────────────────────────

class _StepScaffold extends StatelessWidget {
  final String title;
  final VoidCallback onSkip;
  final Widget child;

  const _StepScaffold({
    required this.title,
    required this.onSkip,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Felső sáv
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  if (title.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111111),
                        ),
                      ),
                    ),
                  const Spacer(),
                  TextButton(
                    onPressed: onSkip,
                    child: const Text(
                      'Kihagyás',
                      style: TextStyle(
                        color: _kTextLight,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

class _ContinueButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool enabled;
  final bool loading;

  const _ContinueButton({
    required this.label,
    required this.onTap,
    this.enabled = true,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        child: ElevatedButton(
          onPressed: (enabled && !loading) ? onTap : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: enabled ? _kBlue : _kGrey,
            foregroundColor: Colors.white,
            disabledBackgroundColor: _kGrey,
            disabledForegroundColor: _kTextLight,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
      ),
    );
  }
}
