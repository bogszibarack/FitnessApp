import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Egységes haptic feedback segéd — minden gombnyomásnál használjuk.
class Haptika {
  static void konnyu() => HapticFeedback.lightImpact();
  static void kozepes() => HapticFeedback.mediumImpact();
  static void eros() => HapticFeedback.heavyImpact();
  static void valasztas() => HapticFeedback.selectionClick();
}

/// Modern, gradientes gomb beépített haptic feedbackkel és nyomás animációval.
class ModernGomb extends StatefulWidget {
  const ModernGomb({
    super.key,
    required this.cimke,
    required this.onTap,
    this.ikon,
    this.szin = const Color(0xFF1E88E5),
    this.kitoltott = true,
    this.kicsi = false,
    this.teljesSzelesseg = false,
  });

  final String cimke;
  final VoidCallback onTap;
  final IconData? ikon;
  final Color szin;

  /// true: gradient kitöltés, false: halvány tonal háttér.
  final bool kitoltott;

  /// Kompakt méret (pl. AppBar-ba).
  final bool kicsi;
  final bool teljesSzelesseg;

  @override
  State<ModernGomb> createState() => _ModernGombState();
}

class _ModernGombState extends State<ModernGomb> {
  bool _lenyomva = false;

  Color get _sotetebb {
    final hsl = HSLColor.fromColor(widget.szin);
    return hsl.withLightness((hsl.lightness - 0.12).clamp(0.0, 1.0)).toColor();
  }

  @override
  Widget build(BuildContext context) {
    final szoveg = TextStyle(
      fontSize: widget.kicsi ? 14 : 16,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.2,
      color: widget.kitoltott ? Colors.white : widget.szin,
    );

    final tartalom = Row(
      mainAxisSize: widget.teljesSzelesseg ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.ikon != null) ...[
          Icon(widget.ikon, size: widget.kicsi ? 17 : 20,
              color: widget.kitoltott ? Colors.white : widget.szin),
          const SizedBox(width: 6),
        ],
        Text(widget.cimke, style: szoveg),
      ],
    );

    return GestureDetector(
      onTapDown: (_) => setState(() => _lenyomva = true),
      onTapUp: (_) => setState(() => _lenyomva = false),
      onTapCancel: () => setState(() => _lenyomva = false),
      onTap: () {
        Haptika.kozepes();
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _lenyomva ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 90),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: EdgeInsets.symmetric(
            horizontal: widget.kicsi ? 14 : 20,
            vertical: widget.kicsi ? 8 : 14,
          ),
          decoration: BoxDecoration(
            gradient: widget.kitoltott
                ? LinearGradient(
                    colors: [widget.szin, _sotetebb],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: widget.kitoltott ? null : widget.szin.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(widget.kicsi ? 20 : 14),
            border: widget.kitoltott
                ? null
                : Border.all(color: widget.szin.withValues(alpha: 0.35), width: 1.2),
            boxShadow: widget.kitoltott && !_lenyomva
                ? [
                    BoxShadow(
                      color: widget.szin.withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: tartalom,
        ),
      ),
    );
  }
}
