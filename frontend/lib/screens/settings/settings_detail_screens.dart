import 'package:flutter/material.dart';

import '../../models/beallitas_models.dart';
import '../../services/beallitasok_service.dart';

// --- Alap detail scaffold ---

class _DetailScaffold extends StatelessWidget {
  const _DetailScaffold({
    required this.cim,
    required this.child,
    this.mentes,
    this.mentesBetolt = false,
  });

  final String cim;
  final Widget child;
  final VoidCallback? mentes;
  final bool mentesBetolt;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
        title: Text(cim, style: const TextStyle(fontWeight: FontWeight.w600)),
        actions: [
          if (mentes != null)
            TextButton(
              onPressed: mentesBetolt ? null : mentes,
              child: mentesBetolt
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Ment'),
            ),
        ],
      ),
      body: child,
    );
  }
}

// --- Profil ---

class ProfilScreen extends StatefulWidget {
  const ProfilScreen({super.key, required this.service});
  final BeallitasokService service;

  @override
  State<ProfilScreen> createState() => _ProfilScreenState();
}

class _ProfilScreenState extends State<ProfilScreen> {
  final _nev = TextEditingController();
  final _bio = TextEditingController();
  final _social = TextEditingController();
  bool _betolt = true;
  bool _ment = false;

  @override
  void initState() {
    super.initState();
    _betoltes();
  }

  Future<void> _betoltes() async {
    final data = await widget.service.getSzekcio('/api/beallitasok/${widget.service.userName}/profil');
    _nev.text = data['nev'] as String? ?? '';
    _bio.text = data['bio'] as String? ?? '';
    _social.text = data['socialLink'] as String? ?? '';
    setState(() => _betolt = false);
  }

  Future<void> _mentes() async {
    setState(() => _ment = true);
    try {
      await widget.service.putSzekcio(
        '/api/beallitasok/${widget.service.userName}/profil',
        {'nev': _nev.text, 'bio': _bio.text, 'socialLink': _social.text},
      );
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profil mentve!')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _ment = false);
    }
  }

  @override
  void dispose() {
    _nev.dispose();
    _bio.dispose();
    _social.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _DetailScaffold(
      cim: 'Profil',
      mentes: _mentes,
      mentesBetolt: _ment,
      child: _betolt
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _Mezo('Nev', _nev),
                _Mezo('Bio', _bio, maxLines: 3),
                _Mezo('Social link', _social),
              ],
            ),
    );
  }
}

// --- Fiok ---

class FiokScreen extends StatefulWidget {
  const FiokScreen({super.key, required this.service});
  final BeallitasokService service;

  @override
  State<FiokScreen> createState() => _FiokScreenState();
}

class _FiokScreenState extends State<FiokScreen> {
  Map<String, dynamic>? _fiok;
  bool _betolt = true;

  @override
  void initState() {
    super.initState();
    widget.service.getSzekcio('/api/beallitasok/${widget.service.userName}/fiok').then((d) {
      setState(() {
        _fiok = d;
        _betolt = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return _DetailScaffold(
      cim: 'Fiok',
      child: _betolt
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                ListTile(title: const Text('Felhasznalonev'), subtitle: Text(_fiok?['userName'] ?? '')),
                ListTile(title: const Text('Email'), subtitle: Text(_fiok?['email']?.toString().isEmpty == true ? 'Nincs megadva' : (_fiok?['email'] ?? ''))),
                ListTile(
                  title: const Text('Regisztralt'),
                  subtitle: Text((_fiok?['regisztralt'] == true) ? 'Igen' : 'Nem (demo mod)'),
                ),
              ],
            ),
    );
  }
}

// --- Tagsag ---

class TagsagScreen extends StatefulWidget {
  const TagsagScreen({super.key, required this.service});
  final BeallitasokService service;

  @override
  State<TagsagScreen> createState() => _TagsagScreenState();
}

class _TagsagScreenState extends State<TagsagScreen> {
  bool _pro = false;
  bool _betolt = true;

  @override
  void initState() {
    super.initState();
    widget.service.getSzekcio('/api/beallitasok/${widget.service.userName}/tagsag').then((d) {
      setState(() {
        _pro = d['proAktiv'] as bool? ?? false;
        _betolt = false;
      });
    });
  }

  Future<void> _mentes() async {
    await widget.service.putSzekcio(
      '/api/beallitasok/${widget.service.userName}/tagsag',
      {'proAktiv': _pro, 'csomag': _pro ? 'pro' : 'ingyenes'},
    );
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tagsag mentve!')));
  }

  @override
  Widget build(BuildContext context) {
    return _DetailScaffold(
      cim: 'Tagsag',
      mentes: _mentes,
      child: _betolt
          ? const Center(child: CircularProgressIndicator())
          : SwitchListTile(
              title: const Text('PRO aktiv'),
              subtitle: const Text('Demo: kapcsold be a Pro funkciokat'),
              value: _pro,
              onChanged: (v) => setState(() => _pro = v),
            ),
    );
  }
}

// --- Ertesitesek ---

class ErtesitesekScreen extends StatefulWidget {
  const ErtesitesekScreen({super.key, required this.service});
  final BeallitasokService service;

  @override
  State<ErtesitesekScreen> createState() => _ErtesitesekScreenState();
}

class _ErtesitesekScreenState extends State<ErtesitesekScreen> {
  Map<String, bool> _kapcsolok = {};
  bool _betolt = true;

  static const _mezoLista = {
    'pushEngedelyezve': 'Push ertesitesek',
    'emailEngedelyezve': 'Email ertesitesek',
    'pihenoIdozito': 'Piheno idozito',
    'kovetesErtesites': 'Kovetes',
    'likeValasz': 'Like es valasz',
    'ujEdzesKozosseg': 'Uj edzes a kozossegiben',
    'sajatEdzesLike': 'Like a sajat edzesemen',
    'sajatEdzesKomment': 'Komment a sajat edzesemen',
  };

  @override
  void initState() {
    super.initState();
    widget.service.getSzekcio('/api/beallitasok/${widget.service.userName}/ertesitesek').then((d) {
      setState(() {
        for (final key in _mezoLista.keys) {
          _kapcsolok[key] = d[key] as bool? ?? true;
        }
        _betolt = false;
      });
    });
  }

  Future<void> _mentes() async {
    await widget.service.putSzekcio(
      '/api/beallitasok/${widget.service.userName}/ertesitesek',
      _kapcsolok,
    );
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ertesitesek mentve!')));
  }

  @override
  Widget build(BuildContext context) {
    return _DetailScaffold(
      cim: 'Ertesitesek',
      mentes: _mentes,
      child: _betolt
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: _mezoLista.entries
                  .map((e) => SwitchListTile(
                        title: Text(e.value),
                        value: _kapcsolok[e.key] ?? true,
                        onChanged: (v) => setState(() => _kapcsolok[e.key] = v),
                      ))
                  .toList(),
            ),
    );
  }
}

// --- Edzes beallitasok ---

class EdzesBeallitasokScreen extends StatefulWidget {
  const EdzesBeallitasokScreen({super.key, required this.service});
  final BeallitasokService service;

  @override
  State<EdzesBeallitasokScreen> createState() => _EdzesBeallitasokScreenState();
}

class _EdzesBeallitasokScreenState extends State<EdzesBeallitasokScreen> {
  bool _hangok = true;
  bool _prHang = true;
  bool _autoKitoltes = true;
  bool _kijelzo = true;
  bool _rpe = true;
  bool _superset = true;
  int _piheno = 90;
  String _hetNap = 'hetfo';
  List<ValasztasiOpcio> _hetOpcio = [];
  bool _betolt = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final data = await widget.service.getSzekcio('/api/beallitasok/${widget.service.userName}/edzes');
    final napok = await widget.service.hetNapjai();
    setState(() {
      _hangok = data['hangok'] as bool? ?? true;
      _prHang = data['prHang'] as bool? ?? true;
      _autoKitoltes = data['automatikusKitoltes'] as bool? ?? true;
      _kijelzo = data['kijelzoEbredve'] as bool? ?? true;
      _rpe = data['rpeKovetes'] as bool? ?? true;
      _superset = data['okosSuperset'] as bool? ?? true;
      _piheno = data['pihenoIdozitoMasodperc'] as int? ?? 90;
      _hetNap = data['hetElsoNapja'] as String? ?? 'hetfo';
      _hetOpcio = napok;
      _betolt = false;
    });
  }

  Future<void> _mentes() async {
    await widget.service.putSzekcio(
      '/api/beallitasok/${widget.service.userName}/edzes',
      {
        'hangok': _hangok,
        'prHang': _prHang,
        'automatikusKitoltes': _autoKitoltes,
        'kijelzoEbredve': _kijelzo,
        'rpeKovetes': _rpe,
        'okosSuperset': _superset,
        'pihenoIdozitoMasodperc': _piheno,
        'hetElsoNapja': _hetNap,
      },
    );
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Edzes beallitasok mentve!')));
  }

  @override
  Widget build(BuildContext context) {
    return _DetailScaffold(
      cim: 'Edzesek',
      mentes: _mentes,
      child: _betolt
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                SwitchListTile(title: const Text('Hangok'), value: _hangok, onChanged: (v) => setState(() => _hangok = v)),
                SwitchListTile(title: const Text('PR hang (bang)'), value: _prHang, onChanged: (v) => setState(() => _prHang = v)),
                SwitchListTile(title: const Text('Automatikus kitoltes'), value: _autoKitoltes, onChanged: (v) => setState(() => _autoKitoltes = v)),
                SwitchListTile(title: const Text('Kijelzo ebredve'), value: _kijelzo, onChanged: (v) => setState(() => _kijelzo = v)),
                SwitchListTile(title: const Text('RPE kovetes'), value: _rpe, onChanged: (v) => setState(() => _rpe = v)),
                SwitchListTile(title: const Text('Okos superset'), value: _superset, onChanged: (v) => setState(() => _superset = v)),
                ListTile(
                  title: Text('Piheno idozito: $_piheno mp'),
                  subtitle: Slider(
                    min: 30,
                    max: 300,
                    divisions: 27,
                    value: _piheno.toDouble(),
                    label: '$_piheno',
                    onChanged: (v) => setState(() => _piheno = v.round()),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: DropdownButtonFormField<String>(
                    value: _hetNap,
                    decoration: const InputDecoration(labelText: 'Het elso napja'),
                    items: _hetOpcio
                        .map((o) => DropdownMenuItem(value: o.id, child: Text(o.cimke)))
                        .toList(),
                    onChanged: (v) => setState(() => _hetNap = v ?? 'hetfo'),
                  ),
                ),
              ],
            ),
    );
  }
}

// --- Privat & szocial ---

class PrivatSzocialScreen extends StatefulWidget {
  const PrivatSzocialScreen({super.key, required this.service});
  final BeallitasokService service;

  @override
  State<PrivatSzocialScreen> createState() => _PrivatSzocialScreenState();
}

class _PrivatSzocialScreenState extends State<PrivatSzocialScreen> {
  String _lathatosag = 'kozosseg';
  bool _megosztas = true;
  bool _megye = true;
  bool _szelfi = false;
  bool _rutin = true;
  List<ValasztasiOpcio> _opcio = [];
  bool _betolt = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final data = await widget.service.getSzekcio('/api/beallitasok/${widget.service.userName}/privat-szocial');
    final opcio = await widget.service.lathatosag();
    setState(() {
      _lathatosag = data['profilLathatosag'] as String? ?? 'kozosseg';
      _megosztas = data['edzesMegosztasAlapertelmezett'] as bool? ?? true;
      _megye = data['megyeMutatasa'] as bool? ?? true;
      _szelfi = data['szelfiKizarolagKovetoknek'] as bool? ?? false;
      _rutin = data['rutinMasolhato'] as bool? ?? true;
      _opcio = opcio;
      _betolt = false;
    });
  }

  Future<void> _mentes() async {
    await widget.service.putSzekcio(
      '/api/beallitasok/${widget.service.userName}/privat-szocial',
      {
        'profilLathatosag': _lathatosag,
        'edzesMegosztasAlapertelmezett': _megosztas,
        'megyeMutatasa': _megye,
        'szelfiKizarolagKovetoknek': _szelfi,
        'rutinMasolhato': _rutin,
      },
    );
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Privat beallitasok mentve!')));
  }

  @override
  Widget build(BuildContext context) {
    return _DetailScaffold(
      cim: 'Privat es kozosseg',
      mentes: _mentes,
      child: _betolt
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                DropdownButtonFormField<String>(
                  value: _lathatosag,
                  decoration: const InputDecoration(labelText: 'Profil lathatosag'),
                  items: _opcio.map((o) => DropdownMenuItem(value: o.id, child: Text(o.cimke))).toList(),
                  onChanged: (v) => setState(() => _lathatosag = v ?? 'kozosseg'),
                ),
                SwitchListTile(title: const Text('Edzes megosztas alapertelmezetten'), value: _megosztas, onChanged: (v) => setState(() => _megosztas = v)),
                SwitchListTile(title: const Text('Megye mutatasa'), value: _megye, onChanged: (v) => setState(() => _megye = v)),
                SwitchListTile(title: const Text('Szelfi csak kovetoknek'), value: _szelfi, onChanged: (v) => setState(() => _szelfi = v)),
                SwitchListTile(title: const Text('Rutin masolhato'), value: _rutin, onChanged: (v) => setState(() => _rutin = v)),
              ],
            ),
    );
  }
}

// --- Egyseg ---

class EgysegScreen extends StatefulWidget {
  const EgysegScreen({super.key, required this.service});
  final BeallitasokService service;

  @override
  State<EgysegScreen> createState() => _EgysegScreenState();
}

class _EgysegScreenState extends State<EgysegScreen> {
  String _suly = 'kg';
  String _tav = 'km';
  String _hossz = 'cm';
  Map<String, List<ValasztasiOpcio>> _opcio = {};
  bool _betolt = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final data = await widget.service.getSzekcio('/api/beallitasok/${widget.service.userName}/egyseg');
    final opcioRaw = await widget.service.egysegOpcio();
    setState(() {
      _suly = data['suly'] as String? ?? 'kg';
      _tav = data['tavolsag'] as String? ?? 'km';
      _hossz = data['hossz'] as String? ?? 'cm';
      _opcio = {
        'suly': (opcioRaw['suly'] as List).map((e) => ValasztasiOpcio.fromJson(e)).toList(),
        'tavolsag': (opcioRaw['tavolsag'] as List).map((e) => ValasztasiOpcio.fromJson(e)).toList(),
        'hossz': (opcioRaw['hossz'] as List).map((e) => ValasztasiOpcio.fromJson(e)).toList(),
      };
      _betolt = false;
    });
  }

  Future<void> _mentes() async {
    await widget.service.putSzekcio(
      '/api/beallitasok/${widget.service.userName}/egyseg',
      {'suly': _suly, 'tavolsag': _tav, 'hossz': _hossz},
    );
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mertekegysegek mentve!')));
  }

  @override
  Widget build(BuildContext context) {
    return _DetailScaffold(
      cim: 'Mertekegysegek',
      mentes: _mentes,
      child: _betolt
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: DropdownButtonFormField<String>(
                    value: _suly,
                    decoration: const InputDecoration(labelText: 'Suly'),
                    items: (_opcio['suly'] ?? []).map((o) => DropdownMenuItem(value: o.id, child: Text(o.cimke))).toList(),
                    onChanged: (v) => setState(() => _suly = v ?? 'kg'),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: DropdownButtonFormField<String>(
                    value: _tav,
                    decoration: const InputDecoration(labelText: 'Tavolsag'),
                    items: (_opcio['tavolsag'] ?? []).map((o) => DropdownMenuItem(value: o.id, child: Text(o.cimke))).toList(),
                    onChanged: (v) => setState(() => _tav = v ?? 'km'),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: DropdownButtonFormField<String>(
                    value: _hossz,
                    decoration: const InputDecoration(labelText: 'Hossz'),
                    items: (_opcio['hossz'] ?? []).map((o) => DropdownMenuItem(value: o.id, child: Text(o.cimke))).toList(),
                    onChanged: (v) => setState(() => _hossz = v ?? 'cm'),
                  ),
                ),
              ],
            ),
    );
  }
}

// --- Nyelv ---

class NyelvScreen extends StatefulWidget {
  const NyelvScreen({super.key, required this.service});
  final BeallitasokService service;

  @override
  State<NyelvScreen> createState() => _NyelvScreenState();
}

class _NyelvScreenState extends State<NyelvScreen> {
  String _nyelv = 'hu';
  List<ValasztasiOpcio> _opcio = [];
  bool _betolt = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final data = await widget.service.getSzekcio('/api/beallitasok/${widget.service.userName}/nyelv');
    final opcio = await widget.service.nyelvek();
    setState(() {
      _nyelv = data['nyelv'] as String? ?? 'hu';
      _opcio = opcio;
      _betolt = false;
    });
  }

  Future<void> _mentes() async {
    await widget.service.putSzekcio('/api/beallitasok/${widget.service.userName}/nyelv', {'nyelv': _nyelv});
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nyelv mentve!')));
  }

  @override
  Widget build(BuildContext context) {
    return _DetailScaffold(
      cim: 'Nyelv',
      mentes: _mentes,
      child: _betolt
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: _opcio
                  .map((o) => RadioListTile<String>(
                        title: Text(o.cimke),
                        value: o.id,
                        groupValue: _nyelv,
                        onChanged: (v) => setState(() => _nyelv = v ?? 'hu'),
                      ))
                  .toList(),
            ),
    );
  }
}

// --- Tema ---

class TemaScreen extends StatefulWidget {
  const TemaScreen({super.key, required this.service});
  final BeallitasokService service;

  @override
  State<TemaScreen> createState() => _TemaScreenState();
}

class _TemaScreenState extends State<TemaScreen> {
  String _mod = 'rendszer';
  List<ValasztasiOpcio> _opcio = [];
  bool _betolt = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final data = await widget.service.getSzekcio('/api/beallitasok/${widget.service.userName}/tema');
    final opcio = await widget.service.temak();
    setState(() {
      _mod = data['mod'] as String? ?? 'rendszer';
      _opcio = opcio;
      _betolt = false;
    });
  }

  Future<void> _mentes() async {
    await widget.service.putSzekcio('/api/beallitasok/${widget.service.userName}/tema', {'mod': _mod});
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tema mentve!')));
  }

  @override
  Widget build(BuildContext context) {
    return _DetailScaffold(
      cim: 'Tema',
      mentes: _mentes,
      child: _betolt
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: _opcio
                  .map((o) => RadioListTile<String>(
                        title: Text(o.cimke),
                        value: o.id,
                        groupValue: _mod,
                        onChanged: (v) => setState(() => _mod = v ?? 'rendszer'),
                      ))
                  .toList(),
            ),
    );
  }
}

// --- Integraciok ---

class IntegraciokScreen extends StatefulWidget {
  const IntegraciokScreen({super.key, required this.service});
  final BeallitasokService service;

  @override
  State<IntegraciokScreen> createState() => _IntegraciokScreenState();
}

class _IntegraciokScreenState extends State<IntegraciokScreen> {
  bool _appleHealth = false;
  bool _appleWatch = false;
  bool _googleFit = false;
  bool _strava = false;
  bool _betolt = true;

  @override
  void initState() {
    super.initState();
    widget.service.getSzekcio('/api/beallitasok/${widget.service.userName}/integraciok').then((d) {
      setState(() {
        _appleHealth = d['appleHealth'] as bool? ?? false;
        _appleWatch = d['appleWatch'] as bool? ?? false;
        _googleFit = d['googleFit'] as bool? ?? false;
        _strava = d['strava'] as bool? ?? false;
        _betolt = false;
      });
    });
  }

  Future<void> _mentes() async {
    await widget.service.putSzekcio(
      '/api/beallitasok/${widget.service.userName}/integraciok',
      {
        'appleHealth': _appleHealth,
        'appleWatch': _appleWatch,
        'googleFit': _googleFit,
        'strava': _strava,
      },
    );
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Integraciok mentve!')));
  }

  @override
  Widget build(BuildContext context) {
    return _DetailScaffold(
      cim: 'Integraciok',
      mentes: _mentes,
      child: _betolt
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                SwitchListTile(title: const Text('Apple Health'), value: _appleHealth, onChanged: (v) => setState(() => _appleHealth = v)),
                SwitchListTile(title: const Text('Apple Watch'), value: _appleWatch, onChanged: (v) => setState(() => _appleWatch = v)),
                SwitchListTile(title: const Text('Google Fit'), value: _googleFit, onChanged: (v) => setState(() => _googleFit = v)),
                SwitchListTile(title: const Text('Strava'), value: _strava, onChanged: (v) => setState(() => _strava = v)),
              ],
            ),
    );
  }
}

// --- Export ---

class ExportScreen extends StatefulWidget {
  const ExportScreen({super.key, required this.service});
  final BeallitasokService service;

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  bool _exportal = false;
  String? _eredmeny;

  Future<void> _export() async {
    setState(() {
      _exportal = true;
      _eredmeny = null;
    });
    try {
      final data = await widget.service.exportAdatok();
      setState(() => _eredmeny = 'Export kesz: ${data['rutinok']?.length ?? 0} rutin, ${data['kozossegPosztok']?.length ?? 0} poszt');
    } catch (e) {
      setState(() => _eredmeny = 'Hiba: $e');
    } finally {
      setState(() => _exportal = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _DetailScaffold(
      cim: 'Export es import',
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Az adataid exportalasa JSON formatumban a backendrol.'),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _exportal ? null : _export,
              child: _exportal ? const CircularProgressIndicator() : const Text('Export inditasa'),
            ),
            if (_eredmeny != null) ...[
              const SizedBox(height: 16),
              Text(_eredmeny!, style: TextStyle(color: Colors.grey.shade700)),
            ],
          ],
        ),
      ),
    );
  }
}

// --- Statikus tartalom ---

class StatikusTartalomScreen extends StatefulWidget {
  const StatikusTartalomScreen({super.key, required this.cim, required this.apiUt, required this.service});
  final String cim;
  final String apiUt;
  final BeallitasokService service;

  @override
  State<StatikusTartalomScreen> createState() => _StatikusTartalomScreenState();
}

class _StatikusTartalomScreenState extends State<StatikusTartalomScreen> {
  dynamic _data;
  bool _betolt = true;

  @override
  void initState() {
    super.initState();
    widget.service.statikusTartalom(widget.apiUt).then((d) {
      setState(() {
        _data = d;
        _betolt = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return _DetailScaffold(
      cim: widget.cim,
      child: _betolt
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_data is Map && (_data as Map)['lepesek'] != null)
                  ...((_data as Map)['lepesek'] as List).map((s) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(s.toString(), style: const TextStyle(fontSize: 15, height: 1.4)),
                      )),
              ],
            ),
    );
  }
}

class GyikScreen extends StatefulWidget {
  const GyikScreen({super.key, required this.service});
  final BeallitasokService service;

  @override
  State<GyikScreen> createState() => _GyikScreenState();
}

class _GyikScreenState extends State<GyikScreen> {
  List<dynamic> _kerdesek = [];
  bool _betolt = true;

  @override
  void initState() {
    super.initState();
    widget.service.statikusTartalom('/api/beallitasok/gyik').then((d) {
      setState(() {
        _kerdesek = (d as Map)['kerdesek'] as List? ?? [];
        _betolt = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return _DetailScaffold(
      cim: 'GYIK',
      child: _betolt
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _kerdesek.length,
              itemBuilder: (_, i) {
                final k = _kerdesek[i] as Map;
                return ExpansionTile(
                  title: Text(k['kerdes']?.toString() ?? ''),
                  children: [Padding(padding: const EdgeInsets.all(16), child: Text(k['valasz']?.toString() ?? ''))],
                );
              },
            ),
    );
  }
}

class KapcsolatScreen extends StatefulWidget {
  const KapcsolatScreen({super.key, required this.service});
  final BeallitasokService service;

  @override
  State<KapcsolatScreen> createState() => _KapcsolatScreenState();
}

class _KapcsolatScreenState extends State<KapcsolatScreen> {
  final _email = TextEditingController();
  final _uzenet = TextEditingController();

  Future<void> _kuldes() async {
    try {
      await widget.service.kapcsolatUzenet(email: _email.text, uzenet: _uzenet.text);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Uzenet elkuldve!')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _uzenet.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _DetailScaffold(
      cim: 'Kapcsolat',
      mentes: _kuldes,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Mezo('Email', _email),
          _Mezo('Uzenet', _uzenet, maxLines: 5),
        ],
      ),
    );
  }
}

class RolunkScreen extends StatefulWidget {
  const RolunkScreen({super.key, required this.service});
  final BeallitasokService service;

  @override
  State<RolunkScreen> createState() => _RolunkScreenState();
}

class _RolunkScreenState extends State<RolunkScreen> {
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    widget.service.statikusTartalom('/api/beallitasok/rolunk').then((d) {
      setState(() => _data = d as Map<String, dynamic>);
    });
  }

  @override
  Widget build(BuildContext context) {
    return _DetailScaffold(
      cim: 'Rolunk',
      child: _data == null
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_data!['appNev']?.toString() ?? '', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  Text('Verzio: ${_data!['verzio']}'),
                  const SizedBox(height: 12),
                  Text(_data!['leiras']?.toString() ?? ''),
                ],
              ),
            ),
    );
  }
}

class _Mezo extends StatelessWidget {
  const _Mezo(this.label, this.controller, {this.maxLines = 1});
  final String label;
  final TextEditingController controller;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }
}
