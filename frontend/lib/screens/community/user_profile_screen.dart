import 'package:flutter/material.dart';

import '../../config/api_config.dart';
import '../../models/community_models.dart';
import '../../services/community_service.dart';
import 'community_widgets.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key, required this.userName});
  final String userName;

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final _service = CommunityService.instance;
  final _sajtNev = ApiConfig.defaultUserName;

  List<CommunityPosztModel> _posztok = [];
  bool _betolt = true;
  bool _kovet = false;
  int _kovetoSzam = 0;

  @override
  void initState() {
    super.initState();
    _betoltes();
  }

  Future<void> _betoltes() async {
    setState(() => _betolt = true);
    try {
      final eredmenyek = await Future.wait([
        _service.felhasznaloPosztjai(widget.userName),
        _service.kovetesek(),
      ]);
      final posztok = eredmenyek[0] as List<CommunityPosztModel>;
      final kovetesData = eredmenyek[1] as Map<String, dynamic>;
      final kovetett = (kovetesData['kovetett'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
      if (!mounted) return;
      setState(() {
        _posztok = posztok;
        _kovet = kovetett.contains(widget.userName);
        _kovetoSzam = (kovetesData['kovetoSzam'] as int?) ?? 0;
        _betolt = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _betolt = false);
    }
  }

  Future<void> _toggleKovetes() async {
    final volt = _kovet;
    setState(() => _kovet = !volt);
    try {
      if (volt) {
        await _service.kovetesVisszavon(widget.userName);
      } else {
        await _service.kovet(widget.userName);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _kovet = volt);
    }
  }

  Future<void> _toggleLike(CommunityPosztModel poszt) async {
    final likeolt = poszt.likeolt(_sajtNev);
    setState(() {
      final idx = _posztok.indexWhere((p) => p.id == poszt.id);
      if (idx == -1) return;
      final ujLikeolok = List<String>.from(poszt.likeolok);
      if (likeolt) {
        ujLikeolok.remove(_sajtNev);
      } else {
        ujLikeolok.add(_sajtNev);
      }
      _posztok[idx] = poszt.copyWith(likeSzam: ujLikeolok.length, likeolok: ujLikeolok);
    });
    try {
      final friss = likeolt
          ? await _service.unlike(poszt.id)
          : await _service.like(poszt.id);
      if (!mounted) return;
      setState(() {
        final idx = _posztok.indexWhere((p) => p.id == poszt.id);
        if (idx != -1) _posztok[idx] = friss;
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final sajatProfil = widget.userName == _sajtNev;
    final osszLike = _posztok.fold(0, (sum, p) => sum + p.likeSzam);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: CustomScrollView(
        slivers: [
          // App bar
          SliverAppBar(
            backgroundColor: Colors.white,
            expandedHeight: 220,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: _buildProfilFejlec(sajatProfil, osszLike),
            ),
          ),

          if (_betolt)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_posztok.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('🏋️', style: const TextStyle(fontSize: 48)),
                    const SizedBox(height: 12),
                    Text(
                      'Még nincs megosztott edzés',
                      style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) {
                    final poszt = _posztok[i];
                    return _ProfilPosztKartya(
                      poszt: poszt,
                      sajtNev: _sajtNev,
                      onLike: () => _toggleLike(poszt),
                      onMentes: () => _mentesRutinkent(poszt.id),
                    );
                  },
                  childCount: _posztok.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProfilFejlec(bool sajatProfil, int osszLike) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 80, 20, 20),
      child: Column(
        children: [
          Row(
            children: [
              AvatarKor(nev: widget.userName, meret: 72),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.userName,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _ProfilStat(szam: _posztok.length, cimke: 'edzés'),
                        const SizedBox(width: 20),
                        _ProfilStat(szam: osszLike, cimke: 'like'),
                        const SizedBox(width: 20),
                        _ProfilStat(szam: _kovetoSzam, cimke: 'követő'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (!sajatProfil)
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _toggleKovetes,
                style: FilledButton.styleFrom(
                  backgroundColor: _kovet ? Colors.grey.shade200 : const Color(0xFF1E88E5),
                  foregroundColor: _kovet ? Colors.black87 : Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                child: Text(
                  _kovet ? '✓ Követve' : '+ Követés',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _mentesRutinkent(String posztId) async {
    try {
      await _service.mentesRutinkent(posztId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rutin elmentve!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hiba: $e'), backgroundColor: Colors.red.shade700),
      );
    }
  }
}

class _ProfilStat extends StatelessWidget {
  const _ProfilStat({required this.szam, required this.cimke});
  final int szam;
  final String cimke;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('$szam', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        Text(cimke, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
      ],
    );
  }
}

class _ProfilPosztKartya extends StatelessWidget {
  const _ProfilPosztKartya({
    required this.poszt,
    required this.sajtNev,
    required this.onLike,
    required this.onMentes,
  });

  final CommunityPosztModel poszt;
  final String sajtNev;
  final VoidCallback onLike;
  final VoidCallback onMentes;

  @override
  Widget build(BuildContext context) {
    final likeolt = poszt.likeolt(sajtNev);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    poszt.edzes.title,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
                Text(
                  poszt.idoSzoveg,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: [
                StatBadge(ikon: Icons.timer_outlined, ertek: poszt.edzes.idoSzoveg),
                StatBadge(ikon: Icons.fitness_center, ertek: '${poszt.edzes.osszSorozatSzam} sor'),
                StatBadge(
                    ikon: Icons.monitor_weight_outlined,
                    ertek: '${poszt.edzes.osszTomegKg.toStringAsFixed(0)} kg'),
              ],
            ),
            if (poszt.edzes.exercises.isNotEmpty) ...[
              const SizedBox(height: 10),
              ...poszt.edzes.exercises.take(3).map((gy) {
                final elvegzett = gy.sets.where((s) => s.elvegezve).toList();
                final maxSuly = elvegzett.isEmpty
                    ? 0.0
                    : elvegzett.map((s) => s.weight).reduce((a, b) => a > b ? a : b);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Row(
                    children: [
                      Container(
                          width: 4, height: 4,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(color: Colors.blue.shade400, shape: BoxShape.circle)),
                      Expanded(child: Text(gy.exerciseName, style: const TextStyle(fontSize: 13))),
                      Text(
                        '${elvegzett.length} × ${maxSuly > 0 ? "${maxSuly.toStringAsFixed(0)} kg" : "–"}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                );
              }),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                AkcioGomb(
                  ikon: likeolt ? Icons.favorite : Icons.favorite_border,
                  cimke: '${poszt.likeSzam}',
                  szin: likeolt ? Colors.red : Colors.grey.shade600,
                  onTap: onLike,
                ),
                AkcioGomb(
                  ikon: Icons.bookmark_border,
                  cimke: 'Mentés',
                  szin: Colors.grey.shade600,
                  onTap: onMentes,
                ),
                const Spacer(),
                if (poszt.megye.isNotEmpty)
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 13, color: Colors.grey.shade400),
                      Text(poszt.megye,
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
