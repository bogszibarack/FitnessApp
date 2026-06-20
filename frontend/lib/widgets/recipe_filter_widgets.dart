import 'package:flutter/material.dart';

import '../models/nutrition_models.dart';

/// Színes kategória kártya — Yazio „Népszerű kategóriák” stílus.
class ReceptKategoriaKartya extends StatelessWidget {
  const ReceptKategoriaKartya({
    super.key,
    required this.kategoria,
    required this.aktiv,
    required this.onTap,
  });

  final ReceptKategoriaModel kategoria;
  final bool aktiv;
  final VoidCallback onTap;

  static const _stilusok = <String, _KategoriaStilus>{
    'reggeli': _KategoriaStilus(Color(0xFFFF9F43), Color(0xFFFFD59A), Icons.free_breakfast),
    'ebed': _KategoriaStilus(Color(0xFF4A90D9), Color(0xFFA8D4FF), Icons.lunch_dining),
    'vacsora': _KategoriaStilus(Color(0xFF34C759), Color(0xFFA8E6B8), Icons.dinner_dining),
    'magas_feherje': _KategoriaStilus(Color(0xFFE85D75), Color(0xFFFFB3C1), Icons.egg_alt),
    'vega': _KategoriaStilus(Color(0xFF7ED957), Color(0xFFC8F5A8), Icons.spa),
    'vegan': _KategoriaStilus(Color(0xFF2D6A4F), Color(0xFF95D5B2), Icons.eco),
    'keves_szenhidrat': _KategoriaStilus(Color(0xFF9B59B6), Color(0xFFD7BDE2), Icons.grain),
    'alacsony_zsir': _KategoriaStilus(Color(0xFF00B4D8), Color(0xFF90E0EF), Icons.water_drop),
    'cukormentes': _KategoriaStilus(Color(0xFFF4D03F), Color(0xFFFFF3A3), Icons.cake_outlined),
    'egeszseges': _KategoriaStilus(Color(0xFF1ABC9C), Color(0xFFA3E4D7), Icons.favorite),
    'gyors_elkeszites': _KategoriaStilus(Color(0xFFFF6B6B), Color(0xFFFFB8B8), Icons.timer_outlined),
  };

  @override
  Widget build(BuildContext context) {
    final stilus = _stilusok[kategoria.id] ??
        _KategoriaStilus(const Color(0xFF6C63FF), const Color(0xFFB8B5FF), Icons.restaurant);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 88,
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [stilus.fo, stilus.vilagos],
          ),
          border: aktiv ? Border.all(color: Colors.white, width: 2.5) : null,
          boxShadow: [
            BoxShadow(
              color: stilus.fo.withValues(alpha: aktiv ? 0.45 : 0.25),
              blurRadius: aktiv ? 10 : 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -6,
              bottom: -6,
              child: Icon(stilus.ikon, size: 44, color: Colors.white.withValues(alpha: 0.25)),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(stilus.ikon, color: Colors.white, size: 22),
                  const Spacer(),
                  Text(
                    kategoria.nev,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      height: 1.15,
                    ),
                  ),
                ],
              ),
            ),
            if (aktiv)
              const Positioned(
                top: 6,
                right: 6,
                child: Icon(Icons.check_circle, color: Colors.white, size: 16),
              ),
          ],
        ),
      ),
    );
  }
}

/// Kalória tartomány kártya — 2×3 rács, Yazio stílus.
class KaloriaTartomanyKartya extends StatelessWidget {
  const KaloriaTartomanyKartya({
    super.key,
    required this.tartomany,
    required this.aktiv,
    required this.onTap,
    required this.index,
  });

  final KaloriaTartomanyModel tartomany;
  final bool aktiv;
  final VoidCallback onTap;
  final int index;

  static const _paletta = [
    (Color(0xFF74C69D), Color(0xFFD8F3DC), '🍉'),
    (Color(0xFFFFB347), Color(0xFFFFE5B4), '🥪'),
    (Color(0xFF90BE6D), Color(0xFFE9F5DB), '🥯'),
    (Color(0xFFF8961E), Color(0xFFFFE0B2), '🥞'),
    (Color(0xFF577590), Color(0xFFB8D0E8), '🍛'),
    (Color(0xFF43AA8B), Color(0xFFB7E4C7), '🍱'),
  ];

  @override
  Widget build(BuildContext context) {
    final (fo, vilagos, emoji) = _paletta[index % _paletta.length];

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [vilagos, fo.withValues(alpha: 0.35)],
          ),
          border: aktiv ? Border.all(color: fo, width: 2.5) : Border.all(color: Colors.white, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: fo.withValues(alpha: aktiv ? 0.35 : 0.15),
              blurRadius: aktiv ? 12 : 6,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: 8,
              bottom: 4,
              child: Text(emoji, style: const TextStyle(fontSize: 36)),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tartomany.nev,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: fo.withValues(alpha: 0.95),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'kalória',
                    style: TextStyle(fontSize: 11, color: fo.withValues(alpha: 0.7)),
                  ),
                  if (aktiv) ...[
                    const Spacer(),
                    Row(
                      children: [
                        Icon(Icons.check_circle, size: 14, color: fo),
                        const SizedBox(width: 4),
                        Text('Aktív', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: fo)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ReceptSzekcioCim extends StatelessWidget {
  const ReceptSzekcioCim({super.key, required this.cim, this.ujraGomb});

  final String cim;
  final VoidCallback? ujraGomb;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Text(cim, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF1A1A2E))),
          const Spacer(),
          if (ujraGomb != null)
            TextButton.icon(
              onPressed: ujraGomb,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Összes', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(foregroundColor: const Color(0xFF34C759)),
            ),
        ],
      ),
    );
  }
}

class _KategoriaStilus {
  const _KategoriaStilus(this.fo, this.vilagos, this.ikon);
  final Color fo;
  final Color vilagos;
  final IconData ikon;
}
