import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../models/beallitas_models.dart';
import '../../services/apple_health_service.dart';
import '../../services/beallitasok_service.dart';
import '../../widgets/settings_widgets.dart';

// ─── Alap detail scaffold ───────────────────────────────────────────────────

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
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        surfaceTintColor: Colors.white,
        title: Text(cim, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
        actions: [
          if (mentes != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton(
                onPressed: mentesBetolt ? null : mentes,
                child: mentesBetolt
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Kész', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Color(0xFF1E88E5))),
              ),
            ),
        ],
      ),
      body: child,
    );
  }
}

// ─── Profil ────────────────────────────────────────────────────────────────

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
  String _nem = 'Férfi';
  DateTime? _szuletesiDatum;
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profil elmentve!')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _ment = false);
    }
  }

  @override
  void dispose() {
    _nev.dispose(); _bio.dispose(); _social.dispose();
    super.dispose();
  }

  String _datumSzoveg() {
    if (_szuletesiDatum == null) return 'Nincs megadva';
    final h = ['jan.', 'febr.', 'márc.', 'ápr.', 'máj.', 'jún.', 'júl.', 'aug.', 'szept.', 'okt.', 'nov.', 'dec.'];
    return '${_szuletesiDatum!.year}. ${h[_szuletesiDatum!.month - 1]} ${_szuletesiDatum!.day}.';
  }

  @override
  Widget build(BuildContext context) {
    final initials = _nev.text.isNotEmpty ? _nev.text[0].toUpperCase() : widget.service.userName[0].toUpperCase();

    return _DetailScaffold(
      cim: 'Profil szerkesztése',
      mentes: _mentes,
      mentesBetolt: _ment,
      child: _betolt
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                const SizedBox(height: 24),
                // Avatar
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 48,
                        backgroundColor: const Color(0xFF1E88E5),
                        child: Text(initials, style: const TextStyle(color: Colors.white, fontSize: 38, fontWeight: FontWeight.w700)),
                      ),
                      Positioned(
                        bottom: 4,
                        right: 4,
                        child: GestureDetector(
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E88E5),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2.5),
                            ),
                            child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    onPressed: () {},
                    child: const Text('Kép módosítása', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF1E88E5))),
                  ),
                ),
                const SizedBox(height: 8),

                // Nyilvános adatok
                SettingsSectionHeader(title: 'Nyilvános adatok'),
                BeallitasSzekcio(
                  children: [
                    _ModernMezo(label: 'Teljes név', controller: _nev, hint: 'Add meg a neved'),
                    _ModernMezo(label: 'Bio', controller: _bio, hint: 'Rövid leírás magadról', maxLines: 3),
                    _ModernMezo(label: 'Weboldal / link', controller: _social, hint: 'https://'),
                  ],
                ),

                // Személyes adatok
                SettingsSectionHeader(title: 'Személyes adatok'),
                BeallitasSzekcio(
                  children: [
                    _AdatTile(
                      cimke: 'Nem',
                      ertek: _nem,
                      szin: const Color(0xFF1E88E5),
                      onTap: () async {
                        final val = await showCupertinoModalPopup<String>(
                          context: context,
                          builder: (_) => CupertinoActionSheet(
                            title: const Text('Nem'),
                            actions: ['Férfi', 'Nő', 'Egyéb'].map((n) => CupertinoActionSheetAction(
                              onPressed: () => Navigator.pop(context, n),
                              child: Text(n),
                            )).toList(),
                            cancelButton: CupertinoActionSheetAction(
                              isDestructiveAction: true,
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Mégse'),
                            ),
                          ),
                        );
                        if (val != null) setState(() => _nem = val);
                      },
                    ),
                    _AdatTile(
                      cimke: 'Születési dátum',
                      ertek: _datumSzoveg(),
                      szin: const Color(0xFF8E24AA),
                      onTap: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: _szuletesiDatum ?? DateTime(1995),
                          firstDate: DateTime(1940),
                          lastDate: DateTime.now().subtract(const Duration(days: 365 * 13)),
                          helpText: 'Születési dátum',
                          confirmText: 'Kész',
                          cancelText: 'Mégse',
                        );
                        if (d != null) setState(() => _szuletesiDatum = d);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 32),
              ],
            ),
    );
  }
}

// ─── Fiók ──────────────────────────────────────────────────────────────────

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
      setState(() { _fiok = d; _betolt = false; });
    });
  }

  @override
  Widget build(BuildContext context) {
    return _DetailScaffold(
      cim: 'Fiók',
      child: _betolt
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                SettingsSectionHeader(title: 'Fiók adatok'),
                BeallitasSzekcio(
                  children: [
                    _InfoTile(cimke: 'Felhasználónév', ertek: _fiok?['userName'] ?? '-'),
                    _InfoTile(
                      cimke: 'Email',
                      ertek: (_fiok?['email']?.toString().isEmpty == true) ? 'Nincs megadva' : (_fiok?['email'] ?? '-'),
                    ),
                    _InfoTile(
                      cimke: 'Regisztrált',
                      ertek: (_fiok?['regisztralt'] == true) ? 'Igen' : 'Demo mód',
                    ),
                  ],
                ),
                const SizedBox(height: 32),
              ],
            ),
    );
  }
}

// ─── Tagság ────────────────────────────────────────────────────────────────

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
      setState(() { _pro = d['proAktiv'] as bool? ?? false; _betolt = false; });
    });
  }

  Future<void> _mentes() async {
    await widget.service.putSzekcio(
      '/api/beallitasok/${widget.service.userName}/tagsag',
      {'proAktiv': _pro, 'csomag': _pro ? 'pro' : 'ingyenes'},
    );
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tagság elmentve!')));
  }

  @override
  Widget build(BuildContext context) {
    return _DetailScaffold(
      cim: 'Tagság',
      mentes: _mentes,
      child: _betolt
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                SettingsSectionHeader(title: 'Pro csomag'),
                BeallitasSzekcio(
                  children: [
                    KapcsoloTile(
                      icon: Icons.workspace_premium_rounded,
                      ikonSzin: const Color(0xFFFFB300),
                      title: 'PRO aktív',
                      subtitle: 'Demo: kapcsold be a Pro funkciókat',
                      ertek: _pro,
                      onChange: (v) => setState(() => _pro = v),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
              ],
            ),
    );
  }
}

// ─── Értesítések ───────────────────────────────────────────────────────────

class ErtesitesekScreen extends StatefulWidget {
  const ErtesitesekScreen({super.key, required this.service});
  final BeallitasokService service;

  @override
  State<ErtesitesekScreen> createState() => _ErtesitesekScreenState();
}

class _ErtesitesekScreenState extends State<ErtesitesekScreen> {
  final Map<String, bool> _k = {};
  bool _betolt = true;

  @override
  void initState() {
    super.initState();
    widget.service.getSzekcio('/api/beallitasok/${widget.service.userName}/ertesitesek').then((d) {
      setState(() {
        for (final key in _mezoLista.keys) { _k[key] = d[key] as bool? ?? true; }
        _betolt = false;
      });
    });
  }

  static const _mezoLista = {
    'pushEngedelyezve': 'Push értesítések',
    'emailEngedelyezve': 'E-mail értesítések',
    'pihenoIdozito': 'Pihenő időzítő',
    'kovetesErtesites': 'Követési értesítés',
    'likeValasz': 'Kedvelés és válasz',
    'ujEdzesKozosseg': 'Új edzés a közösségedben',
    'sajatEdzesLike': 'Kedvelés az edzéseden',
    'sajatEdzesKomment': 'Hozzászólás az edzéseden',
  };

  static final _mezoIkon = <String, (IconData, Color)>{
    'pushEngedelyezve':  (Icons.notifications_rounded,       Color(0xFFE53935)),
    'emailEngedelyezve': (Icons.mail_rounded,                Color(0xFF1E88E5)),
    'pihenoIdozito':     (Icons.timer_rounded,               Color(0xFF00ACC1)),
    'kovetesErtesites':  (Icons.person_add_rounded,          Color(0xFF43A047)),
    'likeValasz':        (Icons.favorite_rounded,            Color(0xFFE91E63)),
    'ujEdzesKozosseg':   (Icons.fitness_center_rounded,      Color(0xFF8E24AA)),
    'sajatEdzesLike':    (Icons.thumb_up_rounded,            Color(0xFFFF7043)),
    'sajatEdzesKomment': (Icons.chat_bubble_rounded,         Color(0xFF039BE5)),
  };

  Future<void> _mentes() async {
    await widget.service.putSzekcio('/api/beallitasok/${widget.service.userName}/ertesitesek', _k);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Értesítések elmentve!')));
  }

  @override
  Widget build(BuildContext context) {
    final push = _k['pushEngedelyezve'] ?? true;

    return _DetailScaffold(
      cim: 'Értesítések',
      mentes: _mentes,
      child: _betolt
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                // Értesítési figyelmeztetés ha ki van kapcsolva
                if (!push)
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8E1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFFE082)),
                    ),
                    child: const Row(
                      children: [
                        Text('⚠️', style: TextStyle(fontSize: 18)),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'A telefon értesítések ki vannak kapcsolva. Engedélyezd a telefon beállításaiban.',
                            style: TextStyle(fontSize: 13, color: Color(0xFF795548)),
                          ),
                        ),
                      ],
                    ),
                  ),

                SettingsSectionHeader(title: 'Általános'),
                BeallitasSzekcio(
                  children: [
                    _kapcsoloTileEpito('pushEngedelyezve', push),
                    _kapcsoloTileEpito('emailEngedelyezve', push),
                    _kapcsoloTileEpito('pihenoIdozito', push),
                    _kapcsoloTileEpito('kovetesErtesites', push),
                  ],
                ),

                SettingsSectionHeader(title: 'Közösségi aktivitás'),
                BeallitasSzekcio(
                  children: [
                    _kapcsoloTileEpito('likeValasz', push),
                    _kapcsoloTileEpito('ujEdzesKozosseg', push),
                    _kapcsoloTileEpito('sajatEdzesLike', push),
                    _kapcsoloTileEpito('sajatEdzesKomment', push),
                  ],
                ),
                const SizedBox(height: 32),
              ],
            ),
    );
  }

  Widget _kapcsoloTileEpito(String key, bool pushAktiv) {
    final (ikon, szin) = _mezoIkon[key] ?? (Icons.settings_rounded, const Color(0xFF9E9E9E));
    final letiltva = key != 'pushEngedelyezve' && !pushAktiv;
    return KapcsoloTile(
      icon: ikon,
      ikonSzin: szin,
      title: _mezoLista[key] ?? key,
      ertek: _k[key] ?? true,
      letiltva: letiltva,
      onChange: letiltva ? null : (v) => setState(() => _k[key] = v),
    );
  }
}

// ─── Edzés beállítások ──────────────────────────────────────────────────────

class EdzesBeallitasokScreen extends StatefulWidget {
  const EdzesBeallitasokScreen({super.key, required this.service});
  final BeallitasokService service;

  @override
  State<EdzesBeallitasokScreen> createState() => _EdzesBeallitasokScreenState();
}

class _EdzesBeallitasokScreenState extends State<EdzesBeallitasokScreen> {
  bool _hangok = true, _prHang = true, _autoKitoltes = true, _kijelzo = true, _rpe = true, _superset = true;
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
    await widget.service.putSzekcio('/api/beallitasok/${widget.service.userName}/edzes', {
      'hangok': _hangok, 'prHang': _prHang, 'automatikusKitoltes': _autoKitoltes,
      'kijelzoEbredve': _kijelzo, 'rpeKovetes': _rpe, 'okosSuperset': _superset,
      'pihenoIdozitoMasodperc': _piheno, 'hetElsoNapja': _hetNap,
    });
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Edzés beállítások elmentve!')));
  }

  @override
  Widget build(BuildContext context) {
    return _DetailScaffold(
      cim: 'Edzés',
      mentes: _mentes,
      child: _betolt
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                SettingsSectionHeader(title: 'Hangok és visszajelzés'),
                BeallitasSzekcio(children: [
                  KapcsoloTile(icon: Icons.volume_up_rounded, ikonSzin: const Color(0xFF00ACC1), title: 'Hangok', ertek: _hangok, onChange: (v) => setState(() => _hangok = v)),
                  KapcsoloTile(icon: Icons.emoji_events_rounded, ikonSzin: const Color(0xFFFFB300), title: 'PR hang (bang!)', ertek: _prHang, onChange: (v) => setState(() => _prHang = v)),
                ]),
                SettingsSectionHeader(title: 'Funkciók'),
                BeallitasSzekcio(children: [
                  KapcsoloTile(icon: Icons.auto_fix_high_rounded, ikonSzin: const Color(0xFF1E88E5), title: 'Automatikus kitöltés', ertek: _autoKitoltes, onChange: (v) => setState(() => _autoKitoltes = v)),
                  KapcsoloTile(icon: Icons.phone_android_rounded, ikonSzin: const Color(0xFF43A047), title: 'Kijelző ébren tartása', ertek: _kijelzo, onChange: (v) => setState(() => _kijelzo = v)),
                  KapcsoloTile(icon: Icons.show_chart_rounded, ikonSzin: const Color(0xFF8E24AA), title: 'RPE követés', subtitle: 'Erőfeszítés osztályozása', ertek: _rpe, onChange: (v) => setState(() => _rpe = v)),
                  KapcsoloTile(icon: Icons.merge_rounded, ikonSzin: const Color(0xFFFF7043), title: 'Okos szuperset', ertek: _superset, onChange: (v) => setState(() => _superset = v)),
                ]),
                SettingsSectionHeader(title: 'Pihenő időzítő'),
                BeallitasSzekcio(children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Row(
                      children: [
                        Container(
                          width: 34, height: 34,
                          decoration: BoxDecoration(color: const Color(0xFF00897B).withValues(alpha: 0.13), borderRadius: BorderRadius.circular(9)),
                          child: const Icon(Icons.timer_rounded, color: Color(0xFF00897B), size: 19),
                        ),
                        const SizedBox(width: 14),
                        Text('$_piheno másodperc', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                        const Spacer(),
                        Text('${(_piheno / 60).floor()}:${(_piheno % 60).toString().padLeft(2, '0')} perc',
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: const Color(0xFF00897B),
                        thumbColor: const Color(0xFF00897B),
                        inactiveTrackColor: const Color(0xFF00897B).withValues(alpha: 0.2),
                      ),
                      child: Slider(
                        min: 30, max: 300, divisions: 27,
                        value: _piheno.toDouble(),
                        onChanged: (v) => setState(() => _piheno = v.round()),
                      ),
                    ),
                  ),
                ]),
                SettingsSectionHeader(title: 'Naptár'),
                BeallitasSzekcio(children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    child: DropdownButtonFormField<String>(
                      initialValue: _hetNap,
                      decoration: InputDecoration(
                        labelText: 'Hét első napja',
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      ),
                      items: _hetOpcio.map((o) => DropdownMenuItem(value: o.id, child: Text(o.cimke))).toList(),
                      onChanged: (v) => setState(() => _hetNap = v ?? 'hetfo'),
                    ),
                  ),
                ]),
                const SizedBox(height: 32),
              ],
            ),
    );
  }
}

// ─── Privát és közösségi ────────────────────────────────────────────────────

class PrivatSzocialScreen extends StatefulWidget {
  const PrivatSzocialScreen({super.key, required this.service});
  final BeallitasokService service;

  @override
  State<PrivatSzocialScreen> createState() => _PrivatSzocialScreenState();
}

class _PrivatSzocialScreenState extends State<PrivatSzocialScreen> {
  String _lathatosag = 'kozosseg';
  bool _megosztas = true, _megye = true, _szelfi = false, _rutin = true;
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
      {'profilLathatosag': _lathatosag, 'edzesMegosztasAlapertelmezett': _megosztas,
       'megyeMutatasa': _megye, 'szelfiKizarolagKovetoknek': _szelfi, 'rutinMasolhato': _rutin},
    );
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Adatvédelmi beállítások elmentve!')));
  }

  @override
  Widget build(BuildContext context) {
    return _DetailScaffold(
      cim: 'Adatvédelem & közösség',
      mentes: _mentes,
      child: _betolt
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                SettingsSectionHeader(title: 'Profil láthatósága'),
                BeallitasSzekcio(children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    child: DropdownButtonFormField<String>(
                      initialValue: _lathatosag,
                      decoration: InputDecoration(
                        labelText: 'Ki láthatja a profilodat',
                        filled: true, fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      ),
                      items: _opcio.map((o) => DropdownMenuItem(value: o.id, child: Text(o.cimke))).toList(),
                      onChanged: (v) => setState(() => _lathatosag = v ?? 'kozosseg'),
                    ),
                  ),
                ]),
                SettingsSectionHeader(title: 'Megosztás'),
                BeallitasSzekcio(children: [
                  KapcsoloTile(icon: Icons.share_rounded, ikonSzin: const Color(0xFF1E88E5), title: 'Edzés megosztás alapértelmezett', ertek: _megosztas, onChange: (v) => setState(() => _megosztas = v)),
                  KapcsoloTile(icon: Icons.location_on_rounded, ikonSzin: const Color(0xFFE53935), title: 'Megye megjelenítése', ertek: _megye, onChange: (v) => setState(() => _megye = v)),
                  KapcsoloTile(icon: Icons.camera_front_rounded, ikonSzin: const Color(0xFF8E24AA), title: 'Szelfik csak követőknek', ertek: _szelfi, onChange: (v) => setState(() => _szelfi = v)),
                  KapcsoloTile(icon: Icons.content_copy_rounded, ikonSzin: const Color(0xFF00897B), title: 'Rutin másolható mások által', ertek: _rutin, onChange: (v) => setState(() => _rutin = v)),
                ]),
                const SizedBox(height: 32),
              ],
            ),
    );
  }
}

// ─── Mértékegységek ─────────────────────────────────────────────────────────

class EgysegScreen extends StatefulWidget {
  const EgysegScreen({super.key, required this.service});
  final BeallitasokService service;

  @override
  State<EgysegScreen> createState() => _EgysegScreenState();
}

class _EgysegScreenState extends State<EgysegScreen> {
  String _suly = 'kg', _tav = 'km', _hossz = 'cm';
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
    await widget.service.putSzekcio('/api/beallitasok/${widget.service.userName}/egyseg', {'suly': _suly, 'tavolsag': _tav, 'hossz': _hossz});
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mértékegységek elmentve!')));
  }

  @override
  Widget build(BuildContext context) {
    return _DetailScaffold(
      cim: 'Mértékegységek',
      mentes: _mentes,
      child: _betolt
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                SettingsSectionHeader(title: 'Egységek'),
                BeallitasSzekcio(children: [
                  _DropdownTile(cimke: 'Súly', ertek: _suly, opcio: _opcio['suly'] ?? [], onChange: (v) => setState(() => _suly = v ?? 'kg')),
                  _DropdownTile(cimke: 'Távolság', ertek: _tav, opcio: _opcio['tavolsag'] ?? [], onChange: (v) => setState(() => _tav = v ?? 'km')),
                  _DropdownTile(cimke: 'Magasság', ertek: _hossz, opcio: _opcio['hossz'] ?? [], onChange: (v) => setState(() => _hossz = v ?? 'cm')),
                ]),
                const SizedBox(height: 32),
              ],
            ),
    );
  }
}

// ─── Nyelv ─────────────────────────────────────────────────────────────────

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
    setState(() { _nyelv = data['nyelv'] as String? ?? 'hu'; _opcio = opcio; _betolt = false; });
  }

  Future<void> _mentes() async {
    await widget.service.putSzekcio('/api/beallitasok/${widget.service.userName}/nyelv', {'nyelv': _nyelv});
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nyelv elmentve!')));
  }

  @override
  Widget build(BuildContext context) {
    return _DetailScaffold(
      cim: 'Nyelv',
      mentes: _mentes,
      child: _betolt
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                SettingsSectionHeader(title: 'Felület nyelve'),
                BeallitasSzekcio(
                  children: _opcio.map((o) => Material(
                    color: Colors.white,
                    child: RadioListTile<String>(
                      title: Text(o.cimke, style: const TextStyle(fontSize: 15)),
                      value: o.id,
                      groupValue: _nyelv,
                      activeColor: const Color(0xFF1E88E5),
                      onChanged: (v) => setState(() => _nyelv = v ?? 'hu'),
                    ),
                  )).toList(),
                ),
                const SizedBox(height: 32),
              ],
            ),
    );
  }
}

// ─── Téma ──────────────────────────────────────────────────────────────────

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
    setState(() { _mod = data['mod'] as String? ?? 'rendszer'; _opcio = opcio; _betolt = false; });
  }

  Future<void> _mentes() async {
    await widget.service.putSzekcio('/api/beallitasok/${widget.service.userName}/tema', {'mod': _mod});
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Téma elmentve!')));
  }

  static const _temaIkon = {
    'rendszer': Icons.phone_android_rounded,
    'vilagos': Icons.light_mode_rounded,
    'sotet': Icons.dark_mode_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return _DetailScaffold(
      cim: 'Megjelenés',
      mentes: _mentes,
      child: _betolt
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                SettingsSectionHeader(title: 'Témamód'),
                BeallitasSzekcio(
                  children: _opcio.map((o) {
                    final ikon = _temaIkon[o.id] ?? Icons.settings_rounded;
                    return Material(
                      color: Colors.white,
                      child: ListTile(
                        leading: Container(
                          width: 34, height: 34,
                          decoration: BoxDecoration(color: const Color(0xFF5C6BC0).withValues(alpha: 0.13), borderRadius: BorderRadius.circular(9)),
                          child: Icon(ikon, color: const Color(0xFF5C6BC0), size: 19),
                        ),
                        title: Text(o.cimke, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                        trailing: _mod == o.id
                            ? const Icon(Icons.check_circle_rounded, color: Color(0xFF1E88E5))
                            : null,
                        onTap: () => setState(() => _mod = o.id),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 32),
              ],
            ),
    );
  }
}

// ─── Integrációk ────────────────────────────────────────────────────────────

class IntegraciokScreen extends StatefulWidget {
  const IntegraciokScreen({super.key, required this.service});
  final BeallitasokService service;

  @override
  State<IntegraciokScreen> createState() => _IntegraciokScreenState();
}

class _IntegraciokScreenState extends State<IntegraciokScreen> {
  bool _appleHealth = false, _appleWatch = false, _googleFit = false, _strava = false;
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
      {'appleHealth': _appleHealth, 'appleWatch': _appleWatch, 'googleFit': _googleFit, 'strava': _strava},
    );
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Integrációk elmentve!')));
  }

  Future<void> _appleHealthValtas(bool v) async {
    setState(() => _appleHealth = v);
    if (v && AppleHealthService.instance.isSupported) {
      final granted = await AppleHealthService.instance.requestPermissions();
      if (!mounted) return;
      if (!granted) {
        setState(() => _appleHealth = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Apple Health hozzáférés szükséges.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _DetailScaffold(
      cim: 'Integrációk',
      mentes: _mentes,
      child: _betolt
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                SettingsSectionHeader(title: 'Egészség & aktivitás'),
                BeallitasSzekcio(children: [
                  KapcsoloTile(
                    icon: Icons.favorite_rounded,
                    ikonSzin: const Color(0xFFE91E63),
                    title: 'Apple Health',
                    subtitle: AppleHealthService.instance.isSupported ? 'Aktivitás és kalória adatok' : 'Csak iOS eszközön elérhető',
                    ertek: _appleHealth,
                    letiltva: !AppleHealthService.instance.isSupported,
                    onChange: AppleHealthService.instance.isSupported ? _appleHealthValtas : null,
                  ),
                  KapcsoloTile(icon: Icons.watch_rounded, ikonSzin: const Color(0xFF1E88E5), title: 'Apple Watch', ertek: _appleWatch, onChange: (v) => setState(() => _appleWatch = v)),
                  KapcsoloTile(icon: Icons.directions_run_rounded, ikonSzin: const Color(0xFF43A047), title: 'Google Fit', ertek: _googleFit, onChange: (v) => setState(() => _googleFit = v)),
                  KapcsoloTile(icon: Icons.route_rounded, ikonSzin: const Color(0xFFFF7043), title: 'Strava', ertek: _strava, onChange: (v) => setState(() => _strava = v)),
                ]),
                const SizedBox(height: 32),
              ],
            ),
    );
  }
}

// ─── Export ────────────────────────────────────────────────────────────────

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
    setState(() { _exportal = true; _eredmeny = null; });
    try {
      final data = await widget.service.exportAdatok();
      setState(() => _eredmeny = 'Export kész: ${data['rutinok']?.length ?? 0} rutin, ${data['kozossegPosztok']?.length ?? 0} poszt');
    } catch (e) {
      setState(() => _eredmeny = 'Hiba: $e');
    } finally {
      setState(() => _exportal = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _DetailScaffold(
      cim: 'Export és import',
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Adatok exportálása', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text('Az adataid JSON formátumban tölthetőek le a szerverről.', style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _exportal ? null : _export,
                    icon: _exportal ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.download_rounded),
                    label: Text(_exportal ? 'Exportálás...' : 'Export indítása'),
                  ),
                ),
                if (_eredmeny != null) ...[
                  const SizedBox(height: 12),
                  Text(_eredmeny!, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Statikus tartalom ─────────────────────────────────────────────────────

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
      setState(() { _data = d; _betolt = false; });
    });
  }

  @override
  Widget build(BuildContext context) {
    return _DetailScaffold(
      cim: widget.cim,
      child: _betolt
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (_data is Map && (_data as Map)['lepesek'] != null)
                  ...((_data as Map)['lepesek'] as List).asMap().entries.map((e) => Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 26, height: 26,
                          decoration: const BoxDecoration(color: Color(0xFF1E88E5), shape: BoxShape.circle),
                          child: Center(child: Text('${e.key + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12))),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Text(e.value.toString(), style: const TextStyle(fontSize: 15, height: 1.4))),
                      ],
                    ),
                  )),
              ],
            ),
    );
  }
}

// ─── GYIK ──────────────────────────────────────────────────────────────────

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
      setState(() { _kerdesek = (d as Map)['kerdesek'] as List? ?? []; _betolt = false; });
    });
  }

  @override
  Widget build(BuildContext context) {
    return _DetailScaffold(
      cim: 'GYIK',
      child: _betolt
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                BeallitasSzekcio(
                  children: List.generate(_kerdesek.length, (i) {
                    final k = _kerdesek[i] as Map;
                    return Theme(
                      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        title: Text(k['kerdes']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                            child: Text(k['valasz']?.toString() ?? '', style: TextStyle(fontSize: 14, color: Colors.grey.shade700, height: 1.5)),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 32),
              ],
            ),
    );
  }
}

// ─── Kapcsolat ─────────────────────────────────────────────────────────────

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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Üzenet elküldve!')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  void dispose() {
    _email.dispose(); _uzenet.dispose();
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
          BeallitasSzekcio(children: [
            _ModernMezo(label: 'E-mail cím', controller: _email, hint: 'email@pelda.hu'),
            _ModernMezo(label: 'Üzenet', controller: _uzenet, hint: 'Írd le kérdésedet...', maxLines: 5),
          ]),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ─── Rólunk ────────────────────────────────────────────────────────────────

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
      cim: 'Névjegy',
      child: _data == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.fitness_center_rounded, color: Colors.white, size: 48),
                      const SizedBox(height: 12),
                      Text(_data!['appNev']?.toString() ?? 'Fitness App',
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
                      const SizedBox(height: 4),
                      Text('Verzió: ${_data!['verzio'] ?? '1.0.0'}',
                          style: const TextStyle(fontSize: 14, color: Colors.white70)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                  child: Text(_data!['leiras']?.toString() ?? '', style: const TextStyle(fontSize: 15, height: 1.6)),
                ),
                const SizedBox(height: 32),
              ],
            ),
    );
  }
}

// ─── Segéd widgetek ────────────────────────────────────────────────────────

class _ModernMezo extends StatelessWidget {
  const _ModernMezo({required this.label, required this.controller, this.hint = '', this.maxLines = 1});
  final String label;
  final TextEditingController controller;
  final String hint;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF6B6B6B))),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            maxLines: maxLines,
            style: const TextStyle(fontSize: 15),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.grey.shade400),
              filled: true,
              fillColor: Colors.grey.shade50,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF1E88E5), width: 1.5)),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.cimke, required this.ertek});
  final String cimke;
  final String ertek;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Text(cimke, style: const TextStyle(fontSize: 15, color: Colors.black87)),
          const Spacer(),
          Text(ertek, style: TextStyle(fontSize: 15, color: Colors.grey.shade500)),
        ],
      ),
    );
  }
}

class _AdatTile extends StatelessWidget {
  const _AdatTile({required this.cimke, required this.ertek, required this.onTap, required this.szin});
  final String cimke;
  final String ertek;
  final VoidCallback onTap;
  final Color szin;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              Text(cimke, style: const TextStyle(fontSize: 15, color: Colors.black87)),
              const Spacer(),
              Text(ertek, style: TextStyle(fontSize: 15, color: szin, fontWeight: FontWeight.w600)),
              const SizedBox(width: 6),
              Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _DropdownTile extends StatelessWidget {
  const _DropdownTile({required this.cimke, required this.ertek, required this.opcio, required this.onChange});
  final String cimke;
  final String ertek;
  final List<ValasztasiOpcio> opcio;
  final ValueChanged<String?> onChange;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          Text(cimke, style: const TextStyle(fontSize: 15)),
          const Spacer(),
          DropdownButton<String>(
            value: ertek,
            underline: const SizedBox.shrink(),
            style: const TextStyle(fontSize: 15, color: Color(0xFF1E88E5), fontWeight: FontWeight.w600),
            items: opcio.map((o) => DropdownMenuItem(value: o.id, child: Text(o.cimke))).toList(),
            onChanged: onChange,
          ),
        ],
      ),
    );
  }
}
