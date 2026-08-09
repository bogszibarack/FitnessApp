import 'dart:async';

import 'package:flutter/material.dart';

import '../../config/api_config.dart';
import '../../models/community_models.dart';
import '../../services/community_service.dart';
import '../../theme/app_theme.dart';
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
  List<CommunityPostModel> _feed = [];
  List<PeopleListItemModel> _emberek = [];
  List<PeopleListItemModel> _pending = [];
  bool _betolt = true;
  bool _emberekBetolt = false;
  String? _hiba;
  final Set<String> _mentettPosztIds = {};

  final _keresCtrl = TextEditingController();
  Timer? _keresDebounce;
  String _keresKifejezes = '';

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _tabCtrl.addListener(_tabValtozas);
    _betoltes();
    _felhasznalokBetoltes();
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
    if (_tabCtrl.index == 1 && !_emberekBetolt) {
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
      final results = await Future.wait([
        _service.people(kereses),
        _service.pendingFriends(),
      ]);
      if (!mounted) return;
      setState(() {
        _emberek = results[0];
        _pending = results[1];
        _emberekBetolt = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _emberekBetolt = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Felhasználók: $e')),
      );
    }
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

  Future<void> _toggleLike(CommunityPostModel poszt) async {
    final likeolt = poszt.likeolt(_sajtNev);
    setState(() {
      final idx = _feed.indexWhere((p) => p.id == poszt.id);
      if (idx == -1) return;
      final ujLikedBy = List<String>.from(poszt.likedBy);
      if (likeolt) {
        ujLikedBy.removeWhere((u) => u.toLowerCase() == _sajtNev.toLowerCase());
      } else {
        ujLikedBy.add(_sajtNev);
      }
      _feed[idx] = poszt.copyWith(
        likeCount: ujLikedBy.length,
        likedBy: ujLikedBy,
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
      backgroundColor: AppColors.hatter,
      body: NestedScrollView(
        headerSliverBuilder: (ctx, inner) => [
          SliverAppBar(
            backgroundColor: AppColors.felulet,
            pinned: true,
            title: Text(
              'Közösség',
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                  color: AppColors.szoveg),
            ),
            actions: [
              if (_pending.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Center(
                    child: Badge(
                      label: Text('${_pending.length}'),
                      child: IconButton(
                        tooltip: 'Barátkérelmek',
                        onPressed: () {
                          _tabCtrl.animateTo(1);
                          _felhasznalokBetoltes(_keresCtrl.text);
                        },
                        icon: const Icon(Icons.person_add_alt_1_outlined),
                      ),
                    ),
                  ),
                ),
            ],
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
                        fillColor: AppColors.halvanyKitoltes,
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
                    labelStyle: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14),
                    unselectedLabelStyle: const TextStyle(
                        fontWeight: FontWeight.w500, fontSize: 14),
                    labelColor: const Color(0xFF1E88E5),
                    unselectedLabelColor: Colors.grey.shade600,
                    indicatorColor: const Color(0xFF1E88E5),
                    indicatorWeight: 3,
                    tabs: [
                      const Tab(text: 'Feed'),
                      Tab(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Felhasználók'),
                            if (_pending.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E88E5),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${_pending.length}',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
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
            const Text('Nem sikerült betölteni',
                style: TextStyle(fontWeight: FontWeight.w600)),
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
                p.userName
                    .toLowerCase()
                    .contains(_keresKifejezes.toLowerCase()) ||
                p.workout.title
                    .toLowerCase()
                    .contains(_keresKifejezes.toLowerCase()) ||
                p.county.toLowerCase().contains(_keresKifejezes.toLowerCase()))
            .toList();

    if (szurt.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.fitness_center, size: 48, color: Colors.grey.shade400),
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
          onFelhasznaloTap: _profilMegnyitas,
          onMentesRutinkent: _mentesRutinkent,
          onKomment: _kommentSheet,
          mentett: _mentettPosztIds.contains(szurt[i].id),
        ),
      ),
    );
  }

  Widget _buildFelhasznalok() {
    if (!_emberekBetolt && _emberek.isEmpty) {
      return Center(
        child: ElevatedButton(
          onPressed: () => _felhasznalokBetoltes(),
          child: const Text('Felhasználók betöltése'),
        ),
      );
    }

    final ismerhetek = _emberek
        .where((e) => e.friendStatus == 'none' || e.friendStatus == 'outgoing')
        .toList();
    final baratok =
        _emberek.where((e) => e.friendStatus == 'friends').toList();

    return RefreshIndicator(
      onRefresh: () => _felhasznalokBetoltes(_keresCtrl.text),
      child: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 32),
        children: [
          if (_pending.isNotEmpty) ...[
            _szekcioCim('Barátkérelmek', _pending.length),
            ..._pending.map(_pendingTile),
            const SizedBox(height: 8),
          ],
          _szekcioCim('Kit ismerhetek', ismerhetek.length),
          if (ismerhetek.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Text(
                'Nincs megjeleníthető felhasználó.',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            )
          else
            ...ismerhetek.map(_emberTile),
          if (baratok.isNotEmpty) ...[
            const SizedBox(height: 8),
            _szekcioCim('Barátok', baratok.length),
            ...baratok.map(_emberTile),
          ],
        ],
      ),
    );
  }

  Widget _szekcioCim(String cim, int darab) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Row(
        children: [
          Text(cim,
              style:
                  const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(width: 8),
          Text('$darab',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _pendingTile(PeopleListItemModel f) {
    final requestId = f.requestId;
    return ListTile(
      onTap: () => _profilMegnyitas(f.userName),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: AvatarKor(
          nev: f.displayName.isNotEmpty ? f.displayName : f.userName,
          meret: 44,
          kepUrl: f.profileImageUrl),
      title: Text(f.displayName.isNotEmpty ? f.displayName : f.userName,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
      subtitle: Text(
        f.county.isEmpty ? f.userName : '${f.userName} · ${f.county}',
        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Elfogadás',
            onPressed: requestId == null
                ? null
                : () async {
                    try {
                      await _service.acceptFriend(requestId);
                      await _felhasznalokBetoltes(_keresCtrl.text);
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text('$e')));
                    }
                  },
            icon: const Icon(Icons.check_circle, color: Color(0xFF43A047)),
          ),
          IconButton(
            tooltip: 'Elutasítás',
            onPressed: requestId == null
                ? null
                : () async {
                    try {
                      await _service.rejectFriend(requestId);
                      await _felhasznalokBetoltes(_keresCtrl.text);
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text('$e')));
                    }
                  },
            icon: Icon(Icons.cancel, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _emberTile(PeopleListItemModel f) {
    return ListTile(
      onTap: () => _profilMegnyitas(f.userName),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: AvatarKor(
          nev: f.displayName.isNotEmpty ? f.displayName : f.userName,
          meret: 44,
          kepUrl: f.profileImageUrl),
      title: Text(
        f.displayName.isNotEmpty ? f.displayName : f.userName,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
      subtitle: Text(
        [
          if (f.county.isNotEmpty) f.county,
          if (f.sameCounty) 'ugyanaz a megye',
          '${f.postCount} megosztás',
        ].join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
      ),
      trailing: _friendAction(f),
    );
  }

  Widget _friendAction(PeopleListItemModel f) {
    switch (f.friendStatus) {
      case 'friends':
        return TextButton(
          onPressed: () async {
            try {
              await _service.unfriend(f.userName);
              await _felhasznalokBetoltes(_keresCtrl.text);
            } catch (e) {
              if (!mounted) return;
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text('$e')));
            }
          },
          child: const Text('Barátok'),
        );
      case 'outgoing':
        return Text('Várakozik',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600));
      case 'incoming':
        return const Icon(Icons.mark_email_unread_outlined,
            color: Color(0xFF1E88E5));
      default:
        return FilledButton(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            minimumSize: const Size(0, 34),
          ),
          onPressed: () async {
            try {
              await _service.requestFriend(f.userName);
              await _felhasznalokBetoltes(_keresCtrl.text);
            } catch (e) {
              if (!mounted) return;
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text('$e')));
            }
          },
          child: const Text('Jelölés'),
        );
    }
  }

  Future<void> _profilMegnyitas(String nev) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => UserProfileScreen(userName: nev)),
    );
    if (_tabCtrl.index == 1) {
      await _felhasznalokBetoltes(_keresCtrl.text);
    }
  }

  Future<void> _mentesRutinkent(String posztId) async {
    try {
      await _service.saveAsPlan(posztId);
      if (!mounted) return;
      setState(() => _mentettPosztIds.add(posztId));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Rutin elmentve a saját rutinjaid közé!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Hiba: $e'), backgroundColor: Colors.red.shade700),
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
    this.mentett = false,
  });

  final CommunityPostModel poszt;
  final String sajtNev;
  final VoidCallback onLike;
  final ValueChanged<String> onFelhasznaloTap;
  final ValueChanged<String> onMentesRutinkent;
  final ValueChanged<String> onKomment;
  final bool mentett;

  @override
  Widget build(BuildContext context) {
    final likeolt = poszt.likeolt(sajtNev);
    final selfie = poszt.selfieUrl.isNotEmpty
        ? ApiConfig.mediaUrl(poszt.selfieUrl)
        : '';

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 14),
      decoration: BoxDecoration(
        color: AppColors.kartya,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.arnyek,
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
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                        Row(
                          children: [
                            Icon(Icons.location_on,
                                size: 12, color: Colors.grey.shade500),
                            const SizedBox(width: 2),
                            Text(poszt.county,
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey.shade500)),
                            const SizedBox(width: 8),
                            Text(poszt.idoSzoveg,
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey.shade400)),
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
          if (selfie.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 12, 0, 0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(0),
                child: AspectRatio(
                  aspectRatio: 4 / 3,
                  child: Image.network(
                    selfie,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(poszt.workout.title,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    StatBadge(
                        ikon: Icons.timer_outlined,
                        ertek: poszt.workout.idoSzoveg),
                    const SizedBox(width: 8),
                    StatBadge(
                        ikon: Icons.fitness_center,
                        ertek: '${poszt.workout.osszSorozatSzam} sor'),
                    const SizedBox(width: 8),
                    StatBadge(
                        ikon: Icons.monitor_weight_outlined,
                        ertek:
                            '${poszt.workout.osszTomegKg.toStringAsFixed(0)} kg'),
                  ],
                ),
              ],
            ),
          ),
          if (poszt.workout.exercises.isNotEmpty) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
              child: Column(
                children: poszt.workout.exercises.take(3).map((gy) {
                  final elvegzett = gy.sets.where((s) => s.isDone).toList();
                  final maxSuly = elvegzett.isEmpty
                      ? 0.0
                      : elvegzett
                          .map((s) => s.weight)
                          .reduce((a, b) => a > b ? a : b);
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Container(
                          width: 4,
                          height: 4,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                              color: Colors.blue.shade400,
                              shape: BoxShape.circle),
                        ),
                        Expanded(
                          child: Text(gy.exerciseName,
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w500)),
                        ),
                        Text(
                          '${elvegzett.length} × ${maxSuly > 0 ? "${maxSuly.toStringAsFixed(maxSuly == maxSuly.roundToDouble() ? 0 : 1)} kg" : "–"}',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            if (poszt.workout.exercises.length > 3)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                child: Text(
                  '+ ${poszt.workout.exercises.length - 3} további gyakorlat',
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
                  cimke: '${poszt.likeCount}',
                  szin: likeolt ? Colors.red : Colors.grey.shade600,
                  onTap: onLike,
                ),
                AkcioGomb(
                  ikon: Icons.chat_bubble_outline,
                  cimke: '${poszt.comments.length}',
                  szin: Colors.grey.shade600,
                  onTap: () => onKomment(poszt.id),
                ),
                const Spacer(),
                AkcioGomb(
                  ikon: mentett ? Icons.bookmark : Icons.bookmark_border,
                  cimke: mentett ? 'Mentve' : 'Mentés',
                  szin: mentett
                      ? Colors.amber.shade700
                      : Colors.grey.shade600,
                  onTap: () => onMentesRutinkent(poszt.id),
                ),
              ],
            ),
          ),
          if (poszt.comments.isNotEmpty) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: poszt.comments.take(2).map((k) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: RichText(
                      text: TextSpan(
                        style:
                            TextStyle(color: AppColors.szoveg, fontSize: 13),
                        children: [
                          TextSpan(
                            text: '${k.userName}  ',
                            style:
                                const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          TextSpan(text: k.text),
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
      {super.key,
      required this.posztId,
      required this.sajtNev,
      required this.service});
  final String posztId;
  final String sajtNev;
  final CommunityService service;

  @override
  State<KommentSheet> createState() => _KommentSheetState();
}

class _KommentSheetState extends State<KommentSheet> {
  List<CommunityCommentModel> _kommentek = [];
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
    final lista = await widget.service.comments(widget.posztId);
    if (!mounted) return;
    setState(() => _kommentek = lista);
  }

  Future<void> _kuldes_() async {
    final szoveg = _ctrl.text.trim();
    if (szoveg.isEmpty || _kuldes) return;
    setState(() => _kuldes = true);
    try {
      await widget.service.addComment(widget.posztId, szoveg);
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
        decoration: BoxDecoration(
          color: AppColors.kartya,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13)),
                                  const SizedBox(width: 6),
                                  Text(k.idoSzoveg,
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey.shade400)),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(k.text, style: const TextStyle(fontSize: 13)),
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
                        fillColor: AppColors.halvanyKitoltes,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
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
                        : const Icon(Icons.send_rounded,
                            color: Color(0xFF1E88E5)),
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
