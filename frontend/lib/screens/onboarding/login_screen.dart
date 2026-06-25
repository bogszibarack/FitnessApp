import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/api_config.dart';
import '../main_shell.dart';

// ─── Helyi fiók keresés ──────────────────────────────────────────────────────

/// SharedPreferences-ből megkeresi a fiókot email vagy felhasználónév alapján.
/// Visszaadja a felhasználónevet, vagy null-t ha nem találja.
Future<String?> _helybentiBejelentkezes(String bemeneti, String jelszo) async {
  final prefs = await SharedPreferences.getInstance();
  final rawJson = prefs.getString('local_accounts') ?? '[]';
  final List<dynamic> fiokList = jsonDecode(rawJson) as List<dynamic>;

  for (final f in fiokList) {
    final fiok = f as Map<String, dynamic>;
    final email = (fiok['email'] as String).toLowerCase();
    final username = (fiok['username'] as String).toLowerCase();
    final savedPass = fiok['password'] as String? ?? '';

    final egyezik = email == bemeneti.toLowerCase() ||
        username == bemeneti.toLowerCase();

    if (egyezik) {
      // Ha a jelszó meg lett adva, ellenőrizzük — egyébként engedjük be
      if (savedPass.isEmpty || savedPass == jelszo) {
        return fiok['username'] as String;
      } else {
        return null; // Hibás jelszó
      }
    }
  }
  return null; // Nem található
}

const _kBlue = Color(0xFF2979FF);
const _kTextLight = Color(0xFF888888);

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _passVisible = false;
  bool _betoltes = false;

  late final AnimationController _animCtrl;
  late final Animation<Offset> _slideAnim;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _fadeAnim =
        CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  bool get _emailOk =>
      _emailCtrl.text.isNotEmpty && _emailCtrl.text.contains('@');
  bool get _passOk => _passCtrl.text.length >= 6;
  bool get _mindenOk => _emailOk && _passOk;

  Future<void> _bejelentkezes() async {
    if (!_mindenOk) return;
    setState(() => _betoltes = true);

    final bemeneti = _emailCtrl.text.trim();
    final jelszo = _passCtrl.text;

    try {
      // 1. Helyi ellenőrzés — backend-független, újraindítás után is működik
      final helybentiNev = await _helybentiBejelentkezes(bemeneti, jelszo);

      if (helybentiNev != null) {
        if (!mounted) return;
        await _sessionMentes(helybentiNev);
        return;
      }

      // 2. Backend hívás — ha a helyi nem találta meg
      final url = Uri.parse('${ApiConfig.baseUrl}/api/auth/login');
      final valasz = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'Username': bemeneti,
              'Password': jelszo,
            }),
          )
          .timeout(const Duration(seconds: 8));

      if (!mounted) return;

      if (valasz.statusCode == 200) {
        final json = jsonDecode(valasz.body) as Map<String, dynamic>;
        final userName = json['userName'] as String? ?? bemeneti;
        await _sessionMentes(userName);
      } else if (valasz.statusCode == 404) {
        _hibaUzenet(
            'Nem találtunk fiókot ezzel az adatokkal. Ellenőrizd az e-mail/jelszó párost, vagy regisztrálj!');
      } else {
        final json = jsonDecode(valasz.body) as Map<String, dynamic>;
        _hibaUzenet(json['error'] as String? ?? 'Sikertelen bejelentkezés.');
      }
    } catch (_) {
      // Backend nem elérhető — ha helyi sem volt találat, jelezzük
      if (!mounted) return;
      // Egy utolsó próba: helyi (jelszó nélkül)
      final helybentiNevFallback =
          await _helybentiBejelentkezes(bemeneti, '');
      if (helybentiNevFallback != null && mounted) {
        await _sessionMentes(helybentiNevFallback);
      } else if (mounted) {
        _hibaUzenet(
            'A szerver nem elérhető. Győződj meg róla, hogy a backend fut!');
      }
    } finally {
      if (mounted) setState(() => _betoltes = false);
    }
  }

  Future<void> _sessionMentes(String userName) async {
    ApiConfig.defaultUserName = userName;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);
    await prefs.setString('current_user_name', userName);
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
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              // Fejléc
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const Expanded(
                      child: Text(
                        'Bejelentkezés',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111111),
                        ),
                      ),
                    ),
                    const SizedBox(width: 44),
                  ],
                ),
              ),
              Expanded(
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: SlideTransition(
                    position: _slideAnim,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 28),
                          // Logo + cím
                          Center(
                            child: Column(
                              children: [
                                Image.asset(
                                  'assets/logo.png',
                                  width: 52,
                                  height: 52,
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Üdvözlünk vissza!',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF111111),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Jelentkezz be a fiókodba',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: _kTextLight,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 36),
                          // E-mail / felhasználónév mező
                          _buildMezo(
                            ctrl: _emailCtrl,
                            label: 'E-mail vagy felhasználónév',
                            hint: 'pelda@gmail.com',
                            isOk: _emailOk,
                            keyboardType: TextInputType.emailAddress,
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 4),
                          // Jelszó mező
                          _buildMezo(
                            ctrl: _passCtrl,
                            label: 'Jelszó',
                            hint: 'minimum 6 karakter',
                            isOk: _passOk,
                            obscure: !_passVisible,
                            suffixIcon: IconButton(
                              onPressed: () =>
                                  setState(() => _passVisible = !_passVisible),
                              icon: Icon(
                                _passVisible
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: _kTextLight,
                                size: 20,
                              ),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 28),
                          // Bejelentkezés gomb
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: ElevatedButton(
                              onPressed: (_mindenOk && !_betoltes)
                                  ? _bejelentkezes
                                  : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _kBlue,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor:
                                    const Color(0xFFE0E0E0),
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
                                      'Bejelentkezés',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          // Elválasztó
                          Row(
                            children: [
                              const Expanded(
                                  child: Divider(color: Color(0xFFEEEEEE))),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                child: Text(
                                  'Még nincs fiókod?',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: _kTextLight,
                                  ),
                                ),
                              ),
                              const Expanded(
                                  child: Divider(color: Color(0xFFEEEEEE))),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Regisztráció link
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: OutlinedButton(
                              onPressed: () => Navigator.of(context).pop(),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _kBlue,
                                side: const BorderSide(color: _kBlue),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: const Text(
                                'Regisztrálok',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMezo({
    required TextEditingController ctrl,
    required String label,
    required String hint,
    required bool isOk,
    bool obscure = false,
    TextInputType? keyboardType,
    Widget? suffixIcon,
    ValueChanged<String>? onChanged,
  }) {
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
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isOk ? const Color(0xFF4CAF50) : const Color(0xFFE0E0E0),
                width: isOk ? 1.5 : 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isOk ? const Color(0xFF4CAF50) : _kBlue,
                width: 1.5,
              ),
            ),
            suffixIcon: isOk
                ? const Padding(
                    padding: EdgeInsets.only(right: 12),
                    child: Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFF4CAF50),
                      size: 22,
                    ),
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
