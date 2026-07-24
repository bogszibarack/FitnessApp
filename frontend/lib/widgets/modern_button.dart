import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Unified haptic feedback helper for button presses.
class Haptics {
  static void light() => HapticFeedback.lightImpact();
  static void medium() => HapticFeedback.mediumImpact();
  static void heavy() => HapticFeedback.heavyImpact();
  static void selection() => HapticFeedback.selectionClick();
}

/// Modern gradient button with haptic feedback and press animation.
class ModernButton extends StatefulWidget {
  const ModernButton({
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
  final bool kitoltott;
  final bool kicsi;
  final bool teljesSzelesseg;

  @override
  State<ModernButton> createState() => _ModernButtonState();
}

class _ModernButtonState extends State<ModernButton> {
  bool _pressed = false;

  Color get _darker {
    final hsl = HSLColor.fromColor(widget.szin);
    return hsl.withLightness((hsl.lightness - 0.12).clamp(0.0, 1.0)).toColor();
  }

  @override
  Widget build(BuildContext context) {
    final labelStyle = TextStyle(
      fontSize: widget.kicsi ? 14 : 16,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.2,
      color: widget.kitoltott ? Colors.white : widget.szin,
    );

    final content = Row(
      mainAxisSize: widget.teljesSzelesseg ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.ikon != null) ...[
          Icon(
            widget.ikon,
            size: widget.kicsi ? 17 : 20,
            color: widget.kitoltott ? Colors.white : widget.szin,
          ),
          const SizedBox(width: 6),
        ],
        Text(widget.cimke, style: labelStyle),
      ],
    );

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: () {
        Haptics.medium();
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1.0,
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
                    colors: [widget.szin, _darker],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: widget.kitoltott ? null : widget.szin.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(widget.kicsi ? 20 : 14),
            border: widget.kitoltott
                ? null
                : Border.all(color: widget.szin.withValues(alpha: 0.35), width: 1.2),
            boxShadow: widget.kitoltott && !_pressed
                ? [
                    BoxShadow(
                      color: widget.szin.withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: content,
        ),
      ),
    );
  }
}
