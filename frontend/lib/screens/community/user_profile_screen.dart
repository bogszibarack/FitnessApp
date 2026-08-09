import 'package:flutter/material.dart';

import '../../config/api_config.dart';
import '../../models/community_models.dart';
import '../../models/workout_models.dart';
import '../../services/community_service.dart';
import '../../theme/app_theme.dart';
import 'community_widgets.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key, required this.userName});
  final String userName;

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen>
    with SingleTickerProviderStateMixin {
  final _service = CommunityService.instance;
  final _sajtNev = ApiConfig.defaultUserName;

  CommunityProfileModel? _profil;
  bool _betolt = true;
  bool _akcio = false;
  final Set<String> _mentettPosztIds = {};
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _betoltes();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _betoltes() async {
    setState(() => _betolt = true);
    try {
      final profil = await _service.profile(widget.userName);
      if (!mounted) return;
      setState(() {
        _profil = profil;
        _betolt = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _betolt = false);
    }
  }

  Future<void> _baratAkcio() async {
    final p = _profil;
    if (p == null || _akcio) return;
    setState(() => _akcio = true);
    try {
      switch (p.friendStatus) {
        case 'none':
          await _service.requestFriend(p.userName);
          break;
        case 'friends':
          await _service.unfriend(p.userName);
          break;
        case 'incoming':
          final id = p.incomingRequestId;
          if (id != null) await _service.acceptFriend(id);
          break;
        default:
          break;
      }
      await _betoltes();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _akcio = false);
    }
  }

  Future<void> _elutasitas() async {
    final id = _profil?.incomingRequestId;
    if (id == null) return;
    setState(() => _akcio = true);
    try {
      await _service.rejectFriend(id);
      await _betoltes();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _akcio = false);
    }
  }

  Future<void> _toggleLike(CommunityPostModel poszt) async {
    final likeolt = poszt.likeolt(_sajtNev);
    final posts = _profil?.posts;
    if (posts == null) return;
    setState(() {
      final idx = posts.indexWhere((p) => p.id == poszt.id);
      if (idx == -1) return;
      final ujLikedBy = List<String>.from(poszt.likedBy);
      if (likeolt) {
        ujLikedBy.removeWhere((u) => u.toLowerCase() == _sajtNev.toLowerCase());
      } else {
        ujLikedBy.add(_sajtNev);
      }
      posts[idx] =
          poszt.copyWith(likeCount: ujLikedBy.length, likedBy: ujLikedBy);
    });
    try {
      final friss = likeolt
          ? await _service.unlike(poszt.id)
          : await _service.like(poszt.id);
      if (!mounted || _profil == null) return;
      setState(() {
        final idx = _profil!.posts.indexWhere((p) => p.id == poszt.id);
        if (idx != -1) _profil!.posts[idx] = friss;
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final sajatProfil =
        widget.userName.toLowerCase() == _sajtNev.toLowerCase();
    final p = _profil;

    return Scaffold(
      backgroundColor: AppColors.hatter,
      appBar: AppBar(
        backgroundColor: AppColors.felulet,
        title: Text(widget.userName),
      ),
      body: _betolt
          ? const Center(child: CircularProgressIndicator())
          : p == null
              ? const Center(child: Text('Profil nem elérhető'))
              : Column(
                  children: [
                    _buildProfilFejlec(sajatProfil, p),
                    TabBar(
                      controller: _tabCtrl,
                      labelColor: const Color(0xFF1E88E5),
                      unselectedLabelColor: Colors.grey.shade600,
                      indicatorColor: const Color(0xFF1E88E5),
                      tabs: [
                        Tab(text: 'Edzések (${p.workoutHistory.length})'),
                        Tab(text: 'Megosztások (${p.posts.length})'),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        controller: _tabCtrl,
                        children: [
                          _buildHistory(p.workoutHistory),
                          _buildPosts(p.posts),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildProfilFejlec(bool sajatProfil, CommunityProfileModel p) {
    final nev = p.displayName.isNotEmpty ? p.displayName : p.userName;
    final status = p.friendStatus;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Column(
        children: [
          Row(
            children: [
              AvatarKor(nev: nev, meret: 72, kepUrl: p.profileImageUrl),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nev,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w900),
                    ),
                    if (p.userName != nev)
                      Text('@${p.userName}',
                          style: TextStyle(
                              fontSize: 13, color: Colors.grey.shade600)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _ProfilStat(
                            szam: p.workoutHistory.length, cimke: 'edzés'),
                        const SizedBox(width: 16),
                        _ProfilStat(szam: p.postCount, cimke: 'megosztás'),
                        const SizedBox(width: 16),
                        _ProfilStat(szam: p.friendsCount, cimke: 'barát'),
                      ],
                    ),
                    if (p.county.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.location_on,
                              size: 14, color: Colors.grey.shade500),
                          const SizedBox(width: 2),
                          Text(p.county,
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey.shade600)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (p.bio.isNotEmpty) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(p.bio, style: const TextStyle(fontSize: 13)),
            ),
          ],
          if (!sajatProfil) ...[
            const SizedBox(height: 12),
            if (status == 'incoming')
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: _akcio ? null : _baratAkcio,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF1E88E5),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      child: const Text('Elfogadás',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _akcio ? null : _elutasitas,
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      child: const Text('Elutasítás',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              )
            else
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed:
                      (status == 'outgoing' || _akcio) ? null : _baratAkcio,
                  style: FilledButton.styleFrom(
                    backgroundColor: status == 'friends'
                        ? Colors.grey.shade200
                        : const Color(0xFF1E88E5),
                    foregroundColor:
                        status == 'friends' ? Colors.black87 : Colors.white,
                    disabledBackgroundColor: Colors.grey.shade200,
                    disabledForegroundColor: Colors.black54,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  child: Text(
                    switch (status) {
                      'friends' => 'Barátok · törlés',
                      'outgoing' => 'Kérés elküldve',
                      _ => 'Jelölés barátnak',
                    },
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildHistory(List<WorkoutSessionModel> history) {
    if (history.isEmpty) {
      return Center(
        child: Text('Még nincs edzéselőzmény',
            style: TextStyle(color: Colors.grey.shade600)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
      itemCount: history.length,
      itemBuilder: (_, i) {
        final w = history[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(w.title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 15)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  StatBadge(ikon: Icons.timer_outlined, ertek: w.idoSzoveg),
                  StatBadge(
                      ikon: Icons.fitness_center,
                      ertek: '${w.osszSorozatSzam} sor'),
                  StatBadge(
                      ikon: Icons.monitor_weight_outlined,
                      ertek: '${w.osszTomegKg.toStringAsFixed(0)} kg'),
                  StatBadge(
                      ikon: Icons.list_alt,
                      ertek: '${w.exercises.length} gy.'),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPosts(List<CommunityPostModel> posts) {
    if (posts.isEmpty) {
      return Center(
        child: Text('Még nincs megosztott edzés',
            style: TextStyle(color: Colors.grey.shade600)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
      itemCount: posts.length,
      itemBuilder: (ctx, i) {
        final poszt = posts[i];
        return _ProfilPosztKartya(
          poszt: poszt,
          sajtNev: _sajtNev,
          onLike: () => _toggleLike(poszt),
          onMentes: () => _mentesRutinkent(poszt.id),
          mentett: _mentettPosztIds.contains(poszt.id),
        );
      },
    );
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
}

class _ProfilStat extends StatelessWidget {
  const _ProfilStat({required this.szam, required this.cimke});
  final int szam;
  final String cimke;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('$szam',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        Text(cimke,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
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
    this.mentett = false,
  });

  final CommunityPostModel poszt;
  final String sajtNev;
  final VoidCallback onLike;
  final VoidCallback onMentes;
  final bool mentett;

  @override
  Widget build(BuildContext context) {
    final likeolt = poszt.likeolt(sajtNev);
    final selfie = poszt.selfieUrl.isNotEmpty
        ? ApiConfig.mediaUrl(poszt.selfieUrl)
        : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (selfie.isNotEmpty)
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(18)),
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: Image.network(
                  selfie,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        poszt.workout.title,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                    ),
                    Text(
                      poszt.idoSzoveg,
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade400),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: [
                    StatBadge(
                        ikon: Icons.timer_outlined,
                        ertek: poszt.workout.idoSzoveg),
                    StatBadge(
                        ikon: Icons.fitness_center,
                        ertek: '${poszt.workout.osszSorozatSzam} sor'),
                    StatBadge(
                        ikon: Icons.monitor_weight_outlined,
                        ertek:
                            '${poszt.workout.osszTomegKg.toStringAsFixed(0)} kg'),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    AkcioGomb(
                      ikon: likeolt ? Icons.favorite : Icons.favorite_border,
                      cimke: '${poszt.likeCount}',
                      szin: likeolt ? Colors.red : Colors.grey.shade600,
                      onTap: onLike,
                    ),
                    AkcioGomb(
                      ikon: mentett ? Icons.bookmark : Icons.bookmark_border,
                      cimke: mentett ? 'Mentve' : 'Mentés',
                      szin: mentett
                          ? Colors.amber.shade700
                          : Colors.grey.shade600,
                      onTap: onMentes,
                    ),
                    const Spacer(),
                    if (poszt.county.isNotEmpty)
                      Row(
                        children: [
                          Icon(Icons.location_on,
                              size: 13, color: Colors.grey.shade400),
                          Text(poszt.county,
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey.shade400)),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
