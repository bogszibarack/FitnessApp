import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/auth_service.dart';

const _kBlue = Color(0xFF2979FF);
const _kTextLight = Color(0xFF888888);

/// After forgot-password email: enter temp password + choose a new one.
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key, required this.email});

  final String email;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _tempCtrl = TextEditingController();
  final _ujCtrl = TextEditingController();
  final _uj2Ctrl = TextEditingController();
  bool _tempVisible = false;
  bool _ujVisible = false;
  bool _loading = false;

  @override
  void dispose() {
    _tempCtrl.dispose();
    _ujCtrl.dispose();
    _uj2Ctrl.dispose();
    super.dispose();
  }

  bool get _tempOk => _tempCtrl.text.trim().length >= 6;
  bool get _ujOk => _ujCtrl.text.length >= 6;
  bool get _egyezik => _ujCtrl.text == _uj2Ctrl.text && _ujOk;
  bool get _mindenOk => _tempOk && _egyezik;

  Future<void> _mentes() async {
    if (!_mindenOk || _loading) return;
    setState(() => _loading = true);
    try {
      final msg = await AuthService.instance.confirmForgotPassword(
        email: widget.email,
        temporaryPassword: _tempCtrl.text.trim(),
        newPassword: _ujCtrl.text,
        confirmPassword: _uj2Ctrl.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: const Color(0xFF2E7D32),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      Navigator.of(context).pop(widget.email);
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.errorMessage ?? 'Nem sikerült beállítani a jelszót.'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('A szerver nem elérhető. Próbáld újra később.'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
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
                        'Új jelszó beállítása',
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
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      const Text(
                        'Másold be az e-mailben kapott ideiglenes jelszót, majd add meg az új jelszavadat kétszer.',
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.4,
                          color: Color(0xFF444444),
                        ),
                      ),
                      const SizedBox(height: 20),
                      _label('E-mail'),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F0F0),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          widget.email,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF333333),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _mezo(
                        ctrl: _tempCtrl,
                        label: 'Ideiglenes jelszó (e-mailből)',
                        hint: 'Fx-........',
                        isOk: _tempOk,
                        obscure: !_tempVisible,
                        suffix: IconButton(
                          onPressed: () =>
                              setState(() => _tempVisible = !_tempVisible),
                          icon: Icon(
                            _tempVisible
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: _kTextLight,
                            size: 20,
                          ),
                        ),
                      ),
                      _mezo(
                        ctrl: _ujCtrl,
                        label: 'Új jelszó',
                        hint: 'minimum 6 karakter',
                        isOk: _ujOk,
                        obscure: !_ujVisible,
                        suffix: IconButton(
                          onPressed: () =>
                              setState(() => _ujVisible = !_ujVisible),
                          icon: Icon(
                            _ujVisible
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: _kTextLight,
                            size: 20,
                          ),
                        ),
                      ),
                      _mezo(
                        ctrl: _uj2Ctrl,
                        label: 'Új jelszó megerősítése',
                        hint: 'írd be újra',
                        isOk: _egyezik,
                        obscure: !_ujVisible,
                      ),
                      if (_uj2Ctrl.text.isNotEmpty && !_egyezik)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            'A két új jelszó nem egyezik.',
                            style: TextStyle(
                              color: Color(0xFFD32F2F),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      const SizedBox(height: 28),
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed:
                              (_mindenOk && !_loading) ? _mentes : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _kBlue,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: const Color(0xFFE0E0E0),
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
                                  'Új jelszó mentése',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 32),
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

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, top: 12),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Color(0xFF333333),
        ),
      ),
    );
  }

  Widget _mezo({
    required TextEditingController ctrl,
    required String label,
    required String hint,
    required bool isOk,
    bool obscure = false,
    Widget? suffix,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label),
        TextFormField(
          controller: ctrl,
          obscureText: obscure,
          onChanged: (_) => setState(() {}),
          style: const TextStyle(fontSize: 15, color: Color(0xFF111111)),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: _kTextLight, fontSize: 14),
            filled: true,
            fillColor: const Color(0xFFF7F7F7),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
            suffixIcon: suffix,
            suffixIconConstraints:
                const BoxConstraints(minWidth: 44, minHeight: 44),
          ),
        ),
      ],
    );
  }
}
