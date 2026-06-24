import 'package:flutter/material.dart';

// Közös widgetek a community képernyőkhöz

class AvatarKor extends StatelessWidget {
  const AvatarKor({super.key, required this.nev, required this.meret});
  final String nev;
  final double meret;

  static const _szinek = [
    Color(0xFF1E88E5), Color(0xFF43A047), Color(0xFFE53935),
    Color(0xFF8E24AA), Color(0xFFFF7043), Color(0xFF00ACC1),
  ];

  Color get _szin {
    final hash = nev.codeUnits.fold(0, (a, b) => a + b);
    return _szinek[hash % _szinek.length];
  }

  String get _betuk {
    final reszek = nev.split(RegExp(r'[_.\-]'));
    if (reszek.length >= 2) {
      return '${reszek[0][0]}${reszek[1][0]}'.toUpperCase();
    }
    return nev.substring(0, nev.length.clamp(1, 2)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: meret / 2,
      backgroundColor: _szin,
      child: Text(
        _betuk,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: meret * 0.35,
        ),
      ),
    );
  }
}

class StatBadge extends StatelessWidget {
  const StatBadge({super.key, required this.ikon, required this.ertek});
  final IconData ikon;
  final String ertek;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4FF),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ikon, size: 13, color: const Color(0xFF1E88E5)),
          const SizedBox(width: 4),
          Text(ertek,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E88E5))),
        ],
      ),
    );
  }
}

class AkcioGomb extends StatelessWidget {
  const AkcioGomb(
      {super.key, required this.ikon, required this.cimke, required this.szin, required this.onTap});
  final IconData ikon;
  final String cimke;
  final Color szin;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(ikon, size: 20, color: szin),
      label: Text(cimke,
          style: TextStyle(fontSize: 13, color: szin, fontWeight: FontWeight.w600)),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}
