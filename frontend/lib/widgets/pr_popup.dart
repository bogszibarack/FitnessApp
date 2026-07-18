import 'dart:async';

import 'package:flutter/material.dart';

/// Új rekord pop-up — a képernyő közepén jelenik meg, majd magától eltűnik.
class PrPopup {
  static OverlayEntry? _aktiv;

  static void mutat(BuildContext context, {required double suly}) {
    _aktiv?.remove();
    _aktiv = null;

    final overlay = Overlay.of(context, rootOverlay: true);
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _PrPopupTartalom(
        suly: suly,
        onKesz: () {
          entry.remove();
          if (_aktiv == entry) _aktiv = null;
        },
      ),
    );
    _aktiv = entry;
    overlay.insert(entry);
  }
}

class _PrPopupTartalom extends StatefulWidget {
  const _PrPopupTartalom({required this.suly, required this.onKesz});

  final double suly;
  final VoidCallback onKesz;

  @override
  State<_PrPopupTartalom> createState() => _PrPopupTartalomState();
}

class _PrPopupTartalomState extends State<_PrPopupTartalom>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  late final Animation<double> _skala;
  late final Animation<double> _atlatszosag;
  Timer? _zaras;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _skala = CurvedAnimation(parent: _anim, curve: Curves.easeOutBack);
    _atlatszosag = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    _anim.forward();

    _zaras = Timer(const Duration(milliseconds: 1900), _eltuntetes);
  }

  Future<void> _eltuntetes() async {
    if (!mounted) return;
    await _anim.reverse();
    widget.onKesz();
  }

  @override
  void dispose() {
    _zaras?.cancel();
    _anim.dispose();
    super.dispose();
  }

  String get _sulySzoveg {
    final s = widget.suly;
    return s % 1 == 0 ? s.toInt().toString() : s.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Center(
          child: FadeTransition(
            opacity: _atlatszosag,
            child: ScaleTransition(
              scale: _skala,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 48),
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFB300), Color(0xFFFF8F00)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF8F00).withValues(alpha: 0.45),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🏆', style: TextStyle(fontSize: 44)),
                    const SizedBox(height: 8),
                    const Text(
                      'ÚJ REKORD!',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$_sulySzoveg kg',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
