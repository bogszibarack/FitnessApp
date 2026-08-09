import 'package:flutter/material.dart';

import '../../config/api_config.dart';
import '../../models/beallitas_models.dart';
import '../../services/apple_health_service.dart';
import '../../services/auth_service.dart';
import '../../services/local_store.dart';
import '../../services/settings_service.dart';
import '../../services/streak_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/platform_utils.dart';
import '../../widgets/settings_widgets.dart';
import '../onboarding/onboarding_screen.dart';
import 'settings_detail_screens.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final SettingsService _service;
  List<BeallitasMenuSzekcio> _szekciok = [];
  bool _betolt = true;
  String? _hiba;
  int _streak = 0;
  String _nev = '';
  String _kepUrl = '';
  bool _healthEnabled = false;
  bool _healthBetolt = false;

  @override
  void initState() {
    super.initState();
    _service = SettingsService();
    _init();
  }

  Future<void> _init() async {
    setState(() { _betolt = true; _hiba = null; });
    try {
      final szekciok = await _service.menuLekerdezes();
      final streak = await StreakService.fetch();
      String nev = '';
      String kepUrl = '';
      try {
        final profil = await _service.getSzekcio('/api/settings/${_service.userName}/profile');
        nev = profil['name'] as String? ?? profil['nev'] as String? ?? '';
        kepUrl = profil['imageUrl'] as String? ?? profil['kepUrl'] as String? ?? '';
      } catch (_) {}
      final healthEnabled = await LocalStore.instance.getHealthEnabled();
      if (!mounted) return;
      setState(() {
        _szekciok = szekciok;
        _streak = streak;
        _nev = nev.isNotEmpty ? nev : _service.userName;
        _kepUrl = kepUrl;
        _betolt = false;
        _healthEnabled = healthEnabled;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _hiba = e.toString(); _betolt = false; });
    }
  }

  void _elemMegnyitasa(BeallitasMenuElem elem) {
    Widget? kepernyo;
    switch (elem.id) {
      case 'profil':       kepernyo = ProfilScreen(service: _service); break;
      case 'fiok':         kepernyo = FiokScreen(service: _service); break;
      case 'tagsag':       kepernyo = TagsagScreen(service: _service); break;
      case 'ertesitesek':  kepernyo = ErtesitesekScreen(service: _service); break;
      case 'edzes':        kepernyo = EdzesBeallitasokScreen(service: _service); break;
      case 'privat-szocial': kepernyo = PrivatSzocialScreen(service: _service); break;
      case 'egyseg':       kepernyo = EgysegScreen(service: _service); break;
      case 'nyelv':        kepernyo = NyelvScreen(service: _service); break;
      case 'tema':         kepernyo = TemaScreen(service: _service); break;
      case 'integraciok':
      case 'integraciok-watch':
      case 'integraciok-all': kepernyo = IntegraciokScreen(service: _service); break;
      case 'export-import': kepernyo = ExportScreen(service: _service); break;
      case 'utmutato-kezdes':
        kepernyo = StatikusTartalomScreen(cim: 'Kezdő útmutató', apiUt: '/api/settings/guides/getting-started', service: _service);
        break;
      case 'utmutato-rutin':
        kepernyo = StatikusTartalomScreen(cim: 'Rutin segítség', apiUt: '/api/settings/guides/routine', service: _service);
        break;
      case 'gyik':         kepernyo = GyikScreen(service: _service); break;
      case 'kapcsolat':    kepernyo = KapcsolatScreen(service: _service); break;
      case 'rolunk':       kepernyo = RolunkScreen(service: _service); break;
    }
    if (kepernyo != null) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => kepernyo!));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.hatter,
      body: SafeArea(
        child: _betolt
            ? const Center(child: CircularProgressIndicator())
            : _hiba != null
                ? _HibaNezet(hiba: _hiba!, ujra: _init)
                : RefreshIndicator(
                    onRefresh: _init,
                    child: CustomScrollView(
                      slivers: [
                        SliverToBoxAdapter(child: _buildBrandHeader()),
                        SliverToBoxAdapter(child: _buildProfilFejlec()),
                        SliverToBoxAdapter(child: _buildSzekciok()),
                        if (isAppleHealthPlatform)
                          SliverToBoxAdapter(child: _buildAppleHealthKartya()),
                        SliverToBoxAdapter(child: _buildKijelentkezesGomb()),
                        const SliverToBoxAdapter(child: SizedBox(height: 40)),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildBrandHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          Image.asset('assets/logo.png', height: 26),
          const SizedBox(width: 10),
          Text(
            'Flexio',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: AppColors.szoveg,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfilFejlec() {
    final initials = _nev.isNotEmpty ? _nev[0].toUpperCase() : 'F';
    final kep = _kepUrl.isNotEmpty ? ApiConfig.mediaUrl(_kepUrl) : '';
    return GestureDetector(
      onTap: () async {
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ProfilScreen(service: _service)),
        );
        if (mounted) await _init();
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.kartya,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: AppColors.arnyek, blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: const Color(0xFF1E88E5),
                  backgroundImage: kep.isNotEmpty ? NetworkImage(kep) : null,
                  onBackgroundImageError: kep.isNotEmpty ? (_, __) {} : null,
                  child: kep.isEmpty
                      ? Text(initials,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w700))
                      : null,
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: const Color(0xFF34C759),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(Icons.edit, size: 10, color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_nev, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.szoveg)),
                  const SizedBox(height: 4),
                  Text('Profil szerkesztése', style: TextStyle(fontSize: 13, color: AppColors.halvanySzoveg)),
                ],
              ),
            ),
            if (_streak > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFFF6D00), Color(0xFFFFB300)]),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🔥', style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 4),
                    Text('$_streak', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppleHealthKartya() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.kartya,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: AppColors.arnyek,
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF0F0),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.favorite_rounded,
                      color: Color(0xFFFF3B30),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Apple Health',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.szoveg,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _healthEnabled
                              ? 'Csatlakoztatva – adatok szinkronizálva'
                              : 'Nincs csatlakoztatva',
                          style: TextStyle(
                            fontSize: 12,
                            color: _healthEnabled
                                ? const Color(0xFF34C759)
                                : Colors.grey.shade500,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _healthEnabled
                          ? const Color(0xFFE8F5E9)
                          : const Color(0xFFF2F2F7),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _healthEnabled
                              ? Icons.check_circle_rounded
                              : Icons.radio_button_unchecked,
                          size: 14,
                          color: _healthEnabled
                              ? const Color(0xFF34C759)
                              : Colors.grey.shade400,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _healthEnabled ? 'Aktív' : 'Inaktív',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _healthEnabled
                                ? const Color(0xFF2E7D32)
                                : Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Lépésszám, kalória, edzés és egyéb mozgásadatok szinkronizálása a Home képernyőre.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.mellekSzoveg,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton.icon(
                  onPressed: _healthBetolt ? null : _csatlakozAppleHealth,
                  icon: _healthBetolt
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Icon(
                          _healthEnabled
                              ? Icons.refresh_rounded
                              : Icons.link_rounded,
                          size: 18,
                        ),
                  label: Text(
                    _healthEnabled
                        ? 'Újracsatlakoztatás'
                        : 'Apple Health csatlakoztatása',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF3B30),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
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

  Future<void> _csatlakozAppleHealth() async {
    setState(() => _healthBetolt = true);
    try {
      await AppleHealthService.instance.requestPermissions();
      await LocalStore.instance.setHealthEnabled(true);
      if (!mounted) return;
      setState(() {
        _healthEnabled = true;
        _healthBetolt = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Apple Health csatlakoztatva! Adatok a Home képernyőn jelennek meg.'),
          backgroundColor: Color(0xFF34C759),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _healthBetolt = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hiba: $e'),
          backgroundColor: Colors.red.shade600,
        ),
      );
    }
  }

  Widget _buildKijelentkezesGomb() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppColors.kartya,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: AppColors.arnyek,
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                )
              ],
            ),
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 2),
              leading: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.logout_rounded,
                    color: Colors.red.shade600, size: 18),
              ),
              title: Text(
                'Kijelentkezés',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.red.shade600,
                ),
              ),
              subtitle: Text(
                'Visszatérés a bejelentkezési képernyőre',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
              trailing:
                  Icon(Icons.chevron_right, color: Colors.red.shade300, size: 20),
              onTap: _kijelentkezes,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _kijelentkezes() async {
    final megerosit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Kijelentkezés',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'Biztosan ki szeretnél jelentkezni? A beállításaid és edzéseid megmaradnak.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Mégse'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Kijelentkezés'),
          ),
        ],
      ),
    );

    if (megerosit != true || !mounted) return;

    await AuthService.instance.logout();

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      (_) => false,
    );
  }

  Widget _buildSzekciok() {
    if (_szekciok.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final szekcio in _szekciok) ...[
          SettingsSectionHeader(title: szekcio.cim),
          BeallitasSzekcio(
            children: [
              for (final elem in szekcio.elemek)
                SettingsListTile(
                  icon: settingsIkon(elem.ikon),
                  ikonSzin: settingsIkonSzin(elem.ikon),
                  title: elem.cimke,
                  proBadge: elem.proFunkcio,
                  onTap: () => _elemMegnyitasa(elem),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _HibaNezet extends StatelessWidget {
  const _HibaNezet({required this.hiba, required this.ujra});

  final String hiba;
  final VoidCallback ujra;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 52, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('Nem sikerült csatlakozni', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(hiba, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            const SizedBox(height: 6),
            const Text('Indítsd el: dotnet run', style: TextStyle(fontSize: 12)),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: ujra,
              icon: const Icon(Icons.refresh),
              label: const Text('Újra'),
            ),
          ],
        ),
      ),
    );
  }
}
