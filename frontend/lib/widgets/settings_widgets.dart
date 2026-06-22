import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

// ─── Ikon segéd ────────────────────────────────────────────────────────────

IconData settingsIkon(String ikon) {
  switch (ikon) {
    case 'user':      return Icons.person_rounded;
    case 'lock':      return Icons.lock_rounded;
    case 'pro':       return Icons.workspace_premium_rounded;
    case 'bell':      return Icons.notifications_rounded;
    case 'dumbbell':  return Icons.fitness_center_rounded;
    case 'shield':    return Icons.shield_rounded;
    case 'ruler':     return Icons.straighten_rounded;
    case 'flag':      return Icons.flag_rounded;
    case 'heart':     return Icons.favorite_rounded;
    case 'watch':     return Icons.watch_rounded;
    case 'link':      return Icons.link_rounded;
    case 'moon':      return Icons.dark_mode_rounded;
    case 'export':    return Icons.upload_rounded;
    case 'info':      return Icons.info_rounded;
    case 'clipboard': return Icons.content_paste_rounded;
    case 'help':      return Icons.help_rounded;
    case 'mail':      return Icons.mail_rounded;
    case 'logo':      return Icons.apps_rounded;
    default:          return Icons.settings_rounded;
  }
}

Color settingsIkonSzin(String ikon) {
  switch (ikon) {
    case 'user':      return const Color(0xFF1E88E5);
    case 'lock':      return const Color(0xFF8E24AA);
    case 'pro':       return const Color(0xFFFFB300);
    case 'bell':      return const Color(0xFFE53935);
    case 'dumbbell':  return const Color(0xFF00ACC1);
    case 'shield':    return const Color(0xFF43A047);
    case 'ruler':     return const Color(0xFF6D4C41);
    case 'flag':      return const Color(0xFFFF7043);
    case 'heart':     return const Color(0xFFE91E63);
    case 'watch':     return const Color(0xFF1E88E5);
    case 'link':      return const Color(0xFF039BE5);
    case 'moon':      return const Color(0xFF5C6BC0);
    case 'export':    return const Color(0xFF00897B);
    case 'info':      return const Color(0xFF1E88E5);
    case 'clipboard': return const Color(0xFF6D4C41);
    case 'help':      return const Color(0xFF7CB342);
    case 'mail':      return const Color(0xFFE53935);
    case 'logo':      return const Color(0xFF1E88E5);
    default:          return const Color(0xFF9E9E9E);
  }
}

// ─── Szekció fejléc ────────────────────────────────────────────────────────

class SettingsSectionHeader extends StatelessWidget {
  const SettingsSectionHeader({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 16, 6),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
          color: Colors.grey.shade500,
        ),
      ),
    );
  }
}

// ─── Settings List Tile (színes ikon, modern) ──────────────────────────────

class SettingsListTile extends StatelessWidget {
  const SettingsListTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.proBadge = false,
    this.ikonSzin,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool proBadge;
  final Color? ikonSzin;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final szin = ikonSzin ?? const Color(0xFF9E9E9E);
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: szin.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, color: szin, size: 19),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.black87),
                          ),
                        ),
                        if (proBadge)
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [Color(0xFFFFB300), Color(0xFFFF8F00)]),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'PRO',
                              style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
                            ),
                          ),
                      ],
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Kapcsoló tile (CupertinoSwitch) ──────────────────────────────────────

class KapcsoloTile extends StatelessWidget {
  const KapcsoloTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.ertek,
    required this.onChange,
    this.ikonSzin,
    this.letiltva = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool ertek;
  final ValueChanged<bool>? onChange;
  final Color? ikonSzin;
  final bool letiltva;

  @override
  Widget build(BuildContext context) {
    final szin = ikonSzin ?? const Color(0xFF1E88E5);
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: szin.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: letiltva ? Colors.grey : szin, size: 19),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: letiltva ? Colors.grey : Colors.black87,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                ],
              ],
            ),
          ),
          CupertinoSwitch(
            value: ertek,
            onChanged: letiltva ? null : onChange,
            activeTrackColor: szin,
          ),
        ],
      ),
    );
  }
}

// ─── Szekció kártya wrapper ────────────────────────────────────────────────

class BeallitasSzekcio extends StatelessWidget {
  const BeallitasSzekcio({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              children[i],
              if (i < children.length - 1)
                Divider(height: 1, indent: 64, color: Colors.grey.shade100),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Pro banner ────────────────────────────────────────────────────────────

class ProBanner extends StatelessWidget {
  const ProBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1565C0), Color(0xFF1E88E5), Color(0xFF42A5F5)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E88E5).withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Fitness Pro', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                SizedBox(height: 2),
                Text('Korlátlan receptek, fejlett statisztikák', style: TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
          TextButton(
            onPressed: () {},
            style: TextButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF1565C0),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            child: const Text('Feloldás', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
