import 'dart:async';

import 'package:flutter/material.dart';

import '../../config/api_config.dart';
import '../../models/community_models.dart';
import '../../services/community_service.dart';
import 'community_widgets.dart';
import 'user_profile_screen.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen>
    with SingleTickerProviderStateMixin {
  final _service = CommunityService.instance;
  final _sajtNev = ApiConfig.defaultUserName;

  late TabController _tabCtrl;
  List<CommunityPosztModel> _feed = [];
  List<CommunityFelhasznaloModel> _felhasznalok = [];
  bool _betolt = true;
  String? _hiba;

  final _keresCtrl = TextEditingController();
  Timer? _keresDebounce;
  String _keresKifejezes = '';

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _tabCtrl.addListener(_tabValtozas);
    _betoltes();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _keresCtrl.dispose();
    _keresDebounce?.cancel();
    super.dispose();
  }

  void _tabValtozas() {
    if (!_tabCtrl.indexIsChanging) return;
    if (_tabCtrl.index == 1 && _felhasznalok.isEmpty) {
      _felhasznalokBetoltes();
    }
  }

  Future<void> _betoltes() async {
    setState(() {
      _betolt = true;
      _hiba = null;
    });
    try {
      final lista = await _service.feed();
      if (!mounted) return;
      setState(() {
        _feed = lista;
        _betolt = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hiba = '$e';
        _betolt = false;
      });
    }
  }

  Future<void> _felhasznalokBetoltes([String? kereses]) async {
    try {
      final lista = await _service.felhasznalokKeresese(kereses);
      if (!mounted) return;
      setState(() => _felhasznalok = lista);
    } catch (_) {}
  }

  void _keresValtozas(String ertek) {
    _keresDebounce?.cancel();
    _keresDebounce = Timer(const Duration(milliseconds: 400), () {
      setState(() => _keresKifejezes = ertek);
      if (_tabCtrl.index == 1) {
        _felhasznalokBetoltes(ertek);
      }
    });
  }

  Future<void> _toggleLike(CommunityPosztModel poszt) async {
    final likeolt = poszt.likeolt(_sajtNev);
    setState(() {
      final idx = _feed.indexWhere((p) => p.id == poszt.id);
      if (idx == -1) return;
      final ujLikeolok = List<String>.from(poszt.likeolok);
      if (likeolt) {
        ujLikeolok.remove(_sajtNev);
      } else {
        ujLikeolok.add(_sajtNev);
      }
      _feed[idx] = poszt.copyWith(
        likeSzam: ujLikeolok.length,
        likeolok: ujLikeolok,
      );
    });
    try {
      final friss = likeolt
          ? await _service.unlike(poszt.id)
          : await _service.like(poszt.id);
      if (!mounted) return;
      setState(() {
        final idx = _feed.indexWhere((p) => p.id == poszt.id);
        if (idx != -1) _feed[idx] = friss;
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: NestedScrollView(
        headerSliverBuilder: (ctx, inner) => [
          SliverAppBar(
            backgroundColor: Colors.white,
            pinned: true,
            title: const Text(
              'Közösség',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22, color: Colors.black87),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(96),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: TextField(
                      controller: _keresCtrl,
                      onChanged: _keresValtozas,
                      decoration: InputDecoration(
                        hintText: _tabCtrl.index == 1
                            ? 'Felhasználó keresése…'
                            : 'Keresés a feedben…',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        filled: true,
                        fillColor: const Color(0xFFF0F0F5),
                        contentPadding: EdgeInsets.zero,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        isDense: true,
                      ),
                    ),
                  ),
                  TabBar(
                    controller: _tabCtrl,
                    labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    unselectedLabelStyle:
                        const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                    labelColor: const Color(0xFF1E88E5),
                    unselectedLabelColor: Colors.grey.shade600,
                    indicatorColor: const Color(0xFF1E88E5),
                    indicatorWeight: 3,
                    tabs: const [
                      Tab(text: 'Feed'),
                      Tab(text: 'Felhasználók'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabCtrl,
          children: [
            _buildFeed(),
            _buildFelhasznalok(),
          ],
        ),
      ),
    );
  }

  Widget _buildFeed() {
    if (_betolt) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_hiba != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text('Nem sikerült betölteni', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            FilledButton(onPressed: _betoltes, child: const Text('Újra')),
          ],
        ),
      );
    }

    final szurt = _keresKifejezes.isEmpty
        ? _feed
        : _feed
            .where((p) =>
                p.userName.contains(_keresKifejezes.toLowerCase()) ||
                p.edzes.title.toLowerCase().contains(_keresKifejezes.toLowerCase()) ||
                p.megye.toLowerCase().contains(_keresKifejezes.toLowerCase()))
            .toList();

    if (szurt.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🏋️', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            const Text('Még nincs megosztott edzés',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(
              'Fejezz be egy edzést és oszd meg!',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _betoltes,
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 12, bottom: 32),
        itemCount: szurt.length,
        itemBuilder: (ctx, i) => PosztKartya(
          poszt: szurt[i],
          sajtNev: _sajtNev,
          onLike: () => _toggleLike(szurt[i]),
          onFelhasznaloTap: (nev) => _profilMegnyitas(nev),
          onMentesRutinkent: (id) => _mentesRutinkent(id),
          onKomment: (id) => _kommentSheet(id),
        ),
      ),
    );
  }

  Widget _buildFelhasznalok() {
    if (_felhasznalok.isEmpty) {
      return Center(
        child: ElevatedButton(
          onPressed: () => _felhasznalokBetoltes(),
          child: const Text('Felhasználók betöltése'),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 12, bottom: 32),
      itemCount: _felhasznalok.length,
      itemBuilder: (ctx, i) {
        final f = _felhasznalok[i];
        return ListTile(
          onTap: () => _profilMegnyitas(f.userName),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          leading: AvatarKor(nev: f.userName, meret: 44),
          title: Text(
            f.userName,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          subtitle: Text(
            '${f.posztSzam} edzés · ${f.osszLike} like · ${f.legutobbiEdzesCim}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          trailing: const Icon(Icons.chevron_right),
        );
      },
    );
  }

  void _profilMegnyitas(String nev) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => UserProfileScreen(userName: nev)),
    );
  }

  Future<void> _mentesRutinkent(String posztId) async {
    try {
      await _service.mentesRutinkent(posztId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rutin elmentve a saját rutinjaid közé!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hiba: $e'), backgroundColor: Colors.red.shade700),
      );
    }
  }

  Future<void> _kommentSheet(String posztId) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          KommentSheet(posztId: posztId, sajtNev: _sajtNev, service: _service),
    );
    await _betoltes();
  }
}

// ─── Poszt kártya ─────────────────────────────────────────────────────────────

class PosztKartya extends StatelessWidget {
  const PosztKartya({
    super.key,
    required this.poszt,
    required this.sajtNev,
    required this.onLike,
    required this.onFelhasznaloTap,
    required this.onMentesRutinkent,
    required this.onKomment,
  });

  final CommunityPosztModel poszt;
  final String sajtNev;
  final VoidCallback onLike;
  final ValueChanged<String> onFelhasznaloTap;
  final ValueChanged<String> onMentesRutinkent;
  final ValueChanged<String> onKomment;

  @override
  Widget build(BuildContext context) {
    final likeolt = poszt.likeolt(sajtNev);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => onFelhasznaloTap(poszt.userName),
                  child: AvatarKor(nev: poszt.userName, meret: 40),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () => onFelhasznaloTap(poszt.userName),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          poszt.userName,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                        Row(
                          children: [
                            Icon(Icons.location_on, size: 12, color: Colors.grey.shade500),
                            const SizedBox(width: 2),
                            Text(poszt.megye,
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                            const SizedBox(width: 8),
                            Text(poszt.idoSzoveg,
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'mentes') onMentesRutinkent(poszt.id);
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'mentes',
                      child: Row(
                        children: [
                          Icon(Icons.bookmark_add_outlined, size: 18),
                          SizedBox(width: 8),
                          Text('Mentés rutinként'),
                        ],
                      ),
                    ),
                  ],
                  icon: Icon(Icons.more_horiz, color: Colors.grey.shade400),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(poszt.edzes.title,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    StatBadge(ikon: Icons.timer_outlined, ertek: poszt.edzes.idoSzoveg),
                    const SizedBox(width: 8),
                    StatBadge(
                        ikon: Icons.fitness_center,
                        ertek: '${poszt.edzes.osszSorozatSzam} sor'),
                    const SizedBox(width: 8),
                    StatBadge(
                        ikon: Icons.monitor_weight_outlined,
                        ertek: '${poszt.edzes.osszTomegKg.toStringAsFixed(0)} kg'),
                  ],
                ),
              ],
            ),
          ),

          if (poszt.edzes.exercises.isNotEmpty) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
              child: Column(
                children: poszt.edzes.exercises.take(3).map((gy) {
                  final elvegzett = gy.sets.where((s) => s.elvegezve).toList();
                  final maxSuly = elvegzett.isEmpty
                      ? 0.0
                      : elvegzett.map((s) => s.weight).reduce((a, b) => a > b ? a : b);
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Container(
                          width: 4,
                          height: 4,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                              color: Colors.blue.shade400, shape: BoxShape.circle),
                        ),
                        Expanded(
                          child: Text(gy.exerciseName,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                        ),
                        Text(
                          '${elvegzett.length} × ${maxSuly > 0 ? "${maxSuly.toStringAsFixed(maxSuly == maxSuly.roundToDouble() ? 0 : 1)} kg" : "–"}',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            if (poszt.edzes.exercises.length > 3)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                child: Text(
                  '+ ${poszt.edzes.exercises.length - 3} további gyakorlat',
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade400,
                      fontStyle: FontStyle.italic),
                ),
              ),
          ],

          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              children: [
                AkcioGomb(
                  ikon: likeolt ? Icons.favorite : Icons.favorite_border,
                  cimke: '${poszt.likeSzam}',
                  szin: likeolt ? Colors.red : Colors.grey.shade600,
                  onTap: onLike,
                ),
                AkcioGomb(
                  ikon: Icons.chat_bubble_outline,
                  cimke: '${poszt.kommentek.length}',
                  szin: Colors.grey.shade600,
                  onTap: () => onKomment(poszt.id),
                ),
                const Spacer(),
                AkcioGomb(
                  ikon: Icons.bookmark_border,
                  cimke: 'Mentés',
                  szin: Colors.grey.shade600,
                  onTap: () => onMentesRutinkent(poszt.id),
                ),
              ],
            ),
          ),

          if (poszt.kommentek.isNotEmpty) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: poszt.kommentek.take(2).map((k) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(color: Colors.black87, fontSize: 13),
                        children: [
                          TextSpan(
                            text: '${k.userName}  ',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          TextSpan(text: k.szoveg),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Komment bottom sheet ─────────────────────────────────────────────────────

class KommentSheet extends StatefulWidget {
  const KommentSheet(
      {super.key, required this.posztId, required this.sajtNev, required this.service});
  final String posztId;
  final String sajtNev;
  final CommunityService service;

  @override
  State<KommentSheet> createState() => _KommentSheetState();
}

class _KommentSheetState extends State<KommentSheet> {
  List<CommunityKommentModel> _kommentek = [];
  final _ctrl = TextEditingController();
  bool _kuldes = false;

  @override
  void initState() {
    super.initState();
    _betoltes();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _betoltes() async {
    final lista = await widget.service.kommentek(widget.posztId);
    if (!mounted) return;
    setState(() => _kommentek = lista);
  }

  Future<void> _kuldes_() async {
    final szoveg = _ctrl.text.trim();
    if (szoveg.isEmpty || _kuldes) return;
    setState(() => _kuldes = true);
    try {
      await widget.service.kommentIrasa(widget.posztId, szoveg);
      _ctrl.clear();
      await _betoltes();
    } finally {
      if (mounted) setState(() => _kuldes = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      maxChildSize: 0.92,
      minChildSize: 0.3,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text('Hozzászólások',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                controller: ctrl,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: _kommentek.length,
                itemBuilder: (_, i) {
                  final k = _kommentek[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AvatarKor(nev: k.userName, meret: 32),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(k.userName,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700, fontSize: 13)),
                                  const SizedBox(width: 6),
                                  Text(k.idoSzoveg,
                                      style: TextStyle(
                                          fontSize: 11, color: Colors.grey.shade400)),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(k.szoveg, style: const TextStyle(fontSize: 13)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: EdgeInsets.fromLTRB(
                  12, 8, 12, MediaQuery.of(context).viewInsets.bottom + 12),
              child: Row(
                children: [
                  AvatarKor(nev: widget.sajtNev, meret: 32),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      decoration: InputDecoration(
                        hintText: 'Írj hozzászólást…',
                        filled: true,
                        fillColor: const Color(0xFFF0F0F5),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                        isDense: true,
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _kuldes_(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _kuldes_,
                    icon: _kuldes
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.send_rounded, color: Color(0xFF1E88E5)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
