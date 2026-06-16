import 'package:flutter/material.dart';

import '../../config/api_config.dart';
import '../../models/beallitas_models.dart';
import '../../services/beallitasok_service.dart';
import '../../widgets/settings_widgets.dart';
import 'settings_detail_screens.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final BeallitasokService _service;
  List<BeallitasMenuSzekcio> _szekciok = [];
  bool _betolt = true;
  String? _hiba;

  @override
  void initState() {
    super.initState();
    _service = BeallitasokService();
    _menuBetoltese();
  }

  Future<void> _menuBetoltese() async {
    setState(() {
      _betolt = true;
      _hiba = null;
    });
    try {
      final szekciok = await _service.menuLekerdezes();
      if (!mounted) return;
      setState(() {
        _szekciok = szekciok;
        _betolt = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hiba = e.toString();
        _betolt = false;
      });
    }
  }

  void _elemMegnyitasa(BeallitasMenuElem elem) {
    Widget? kepernyo;

    switch (elem.id) {
      case 'profil':
        kepernyo = ProfilScreen(service: _service);
        break;
      case 'fiok':
        kepernyo = FiokScreen(service: _service);
        break;
      case 'tagsag':
        kepernyo = TagsagScreen(service: _service);
        break;
      case 'ertesitesek':
        kepernyo = ErtesitesekScreen(service: _service);
        break;
      case 'edzes':
        kepernyo = EdzesBeallitasokScreen(service: _service);
        break;
      case 'privat-szocial':
        kepernyo = PrivatSzocialScreen(service: _service);
        break;
      case 'egyseg':
        kepernyo = EgysegScreen(service: _service);
        break;
      case 'nyelv':
        kepernyo = NyelvScreen(service: _service);
        break;
      case 'tema':
        kepernyo = TemaScreen(service: _service);
        break;
      case 'integraciok':
      case 'integraciok-watch':
      case 'integraciok-all':
        kepernyo = IntegraciokScreen(service: _service);
        break;
      case 'export-import':
        kepernyo = ExportScreen(service: _service);
        break;
      case 'utmutato-kezdes':
        kepernyo = StatikusTartalomScreen(
          cim: 'Kezdo utmutato',
          apiUt: '/api/beallitasok/utmutatok/kezdes',
          service: _service,
        );
        break;
      case 'utmutato-rutin':
        kepernyo = StatikusTartalomScreen(
          cim: 'Rutin segitseg',
          apiUt: '/api/beallitasok/utmutatok/rutin',
          service: _service,
        );
        break;
      case 'gyik':
        kepernyo = GyikScreen(service: _service);
        break;
      case 'kapcsolat':
        kepernyo = KapcsolatScreen(service: _service);
        break;
      case 'rolunk':
        kepernyo = RolunkScreen(service: _service);
        break;
    }

    if (kepernyo != null) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => kepernyo!));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
        title: const Text('Beallitasok', style: TextStyle(fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _menuBetoltese,
          ),
        ],
      ),
      body: _betolt
          ? const Center(child: CircularProgressIndicator())
          : _hiba != null
              ? _HibaNezet(hiba: _hiba!, ujra: _menuBetoltese)
              : RefreshIndicator(
                  onRefresh: _menuBetoltese,
                  child: ListView(
                    children: [
                      const ProBanner(),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'Felhasznalo: ${ApiConfig.defaultUserName} · API: ${ApiConfig.baseUrl}',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ),
                      const SizedBox(height: 8),
                      for (final szekcio in _szekciok) ...[
                        SettingsSectionHeader(title: szekcio.cim),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border(
                              top: BorderSide(color: Colors.grey.shade200),
                              bottom: BorderSide(color: Colors.grey.shade200),
                            ),
                          ),
                          child: Column(
                            children: [
                              for (var i = 0; i < szekcio.elemek.length; i++) ...[
                                SettingsListTile(
                                  icon: settingsIkon(szekcio.elemek[i].ikon),
                                  title: szekcio.elemek[i].cimke,
                                  proBadge: szekcio.elemek[i].proFunkcio,
                                  onTap: () => _elemMegnyitasa(szekcio.elemek[i]),
                                ),
                                if (i < szekcio.elemek.length - 1)
                                  Divider(height: 1, indent: 56, color: Colors.grey.shade200),
                              ],
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 2,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.fitness_center), label: 'Workout'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'Profil'),
        ],
      ),
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
            const Icon(Icons.cloud_off, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('Nem sikerult csatlakozni az API-hoz', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(hiba, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
            const SizedBox(height: 16),
            const Text('Inditsd el: dotnet run', style: TextStyle(fontSize: 12)),
            const SizedBox(height: 16),
            FilledButton(onPressed: ujra, child: const Text('Ujra')),
          ],
        ),
      ),
    );
  }
}
