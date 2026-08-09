import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/auth_service.dart';
import '../../services/local_store.dart';
import '../main_shell.dart';
import 'reset_password_screen.dart';

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
  bool _loading = false;

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

  bool get _emailOk => _emailCtrl.text.trim().length >= 3;
  bool get _passOk => _passCtrl.text.length >= 6;
  bool get _mindenOk => _emailOk && _passOk;

  Future<void> _bejelentkezes() async {
    if (!_mindenOk) return;
    setState(() => _loading = true);

    final bemeneti = _emailCtrl.text.trim();
    final jelszo = _passCtrl.text;

    try {
      final session = await AuthService.instance.login(bemeneti, jelszo);
      if (!mounted) return;
      await LocalStore.instance.setSession(
        session.userName,
        accessToken: session.accessToken,
        refreshToken: session.refreshToken,
      );
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainShell()),
        (_) => false,
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 401) {
        _hibaUzenet('Hibás jelszó.');
      } else if (e.statusCode == 404) {
        _hibaUzenet(
            'Nem találtunk fiókot ezzel az adatokkal. Ellenőrizd az e-mail/jelszó párost, vagy regisztrálj!');
      } else {
        _hibaUzenet(e.errorMessage ?? 'Sikertelen bejelentkezés.');
      }
    } catch (_) {
      if (mounted) {
        _hibaUzenet(
            'A szerver nem elérhető. Ellenőrizd az internetkapcsolatot!');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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

  void _sikerUzenet(String uzenet) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(uzenet),
        backgroundColor: const Color(0xFF2E7D32),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _jelszoEmlekezteto() async {
    final emailCtrl = TextEditingController(text: _emailCtrl.text.trim());
    final email = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Jelszó emlékeztető'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Add meg a regisztrált e-mail címed. Új ideiglenes jelszót küldünk rá — a régi jelszó biztonsági okból nem állítható vissza.',
                style: TextStyle(fontSize: 13, height: 1.35),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'E-mail',
                  hintText: 'pelda@gmail.com',
                  filled: true,
                  fillColor: const Color(0xFFF7F7F7),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Mégse'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, emailCtrl.text.trim()),
              style: FilledButton.styleFrom(backgroundColor: _kBlue),
              child: const Text('Küldés'),
            ),
          ],
        );
      },
    );
    emailCtrl.dispose();
    if (email == null || email.isEmpty || !mounted) return;

    setState(() => _loading = true);
    try {
      final msg = await AuthService.instance.forgotPassword(email);
      if (!mounted) return;
      _sikerUzenet(msg);
      if (_emailCtrl.text.trim().isEmpty) {
        _emailCtrl.text = email;
      }
      final beallitottEmail = await Navigator.of(context).push<String>(
        MaterialPageRoute(
          builder: (_) => ResetPasswordScreen(email: email),
        ),
      );
      if (!mounted) return;
      if (beallitottEmail != null && beallitottEmail.isNotEmpty) {
        _emailCtrl.text = beallitottEmail;
        _passCtrl.clear();
        setState(() {});
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      _hibaUzenet(e.errorMessage ?? 'Nem sikerült elküldeni az e-mailt.');
    } catch (_) {
      if (!mounted) return;
      _hibaUzenet('A szerver nem elérhető. Próbáld újra később.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
                          _buildMezo(
                            ctrl: _emailCtrl,
                            label: 'E-mail vagy felhasználónév',
                            hint: 'pelda@gmail.com',
                            isOk: _emailOk,
                            keyboardType: TextInputType.emailAddress,
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 4),
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
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _loading ? null : _jelszoEmlekezteto,
                              child: const Text(
                                'Elfelejtett jelszó?',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _kBlue,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: ElevatedButton(
                              onPressed: (_mindenOk && !_loading)
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
                              child: _loading
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
