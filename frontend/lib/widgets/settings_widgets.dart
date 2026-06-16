import 'package:flutter/material.dart';

IconData settingsIkon(String ikon) {
  switch (ikon) {
    case 'user':
      return Icons.person_outline;
    case 'lock':
      return Icons.lock_outline;
    case 'pro':
      return Icons.workspace_premium_outlined;
    case 'bell':
      return Icons.notifications_outlined;
    case 'dumbbell':
      return Icons.fitness_center;
    case 'shield':
      return Icons.shield_outlined;
    case 'ruler':
      return Icons.straighten;
    case 'flag':
      return Icons.flag_outlined;
    case 'heart':
      return Icons.favorite_border;
    case 'watch':
      return Icons.watch_outlined;
    case 'link':
      return Icons.link;
    case 'moon':
      return Icons.dark_mode_outlined;
    case 'export':
      return Icons.upload_outlined;
    case 'info':
      return Icons.info_outline;
    case 'clipboard':
      return Icons.content_paste_outlined;
    case 'help':
      return Icons.help_outline;
    case 'mail':
      return Icons.mail_outline;
    case 'logo':
      return Icons.apps;
    default:
      return Icons.settings_outlined;
  }
}

class SettingsSectionHeader extends StatelessWidget {
  const SettingsSectionHeader({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
          color: Colors.grey.shade600,
        ),
      ),
    );
  }
}

class SettingsListTile extends StatelessWidget {
  const SettingsListTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.proBadge = false,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool proBadge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: ListTile(
        leading: Icon(icon, color: Colors.black87),
        title: Row(
          children: [
            Expanded(child: Text(title, style: const TextStyle(fontSize: 16))),
            if (proBadge)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E88E5),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'PRO',
                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
        subtitle: subtitle != null ? Text(subtitle!) : null,
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }
}

class ProBanner extends StatelessWidget {
  const ProBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Text(
            'FITNESS PRO',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const Spacer(),
          TextButton(
            onPressed: () {},
            style: TextButton.styleFrom(
              backgroundColor: const Color(0xFF1E88E5),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            child: const Text('Feloldas'),
          ),
        ],
      ),
    );
  }
}
