import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/api_config.dart';
import '../../models/routine_model.dart';
import '../../models/workout_models.dart';
import '../../services/workout_service.dart';
import 'ai_explore_screen.dart';
import 'active_workout_screen.dart';
import 'routine_edit_screen.dart';
import 'routine_preview_screen.dart';
import 'workout_history_detail_screen.dart';

class WorkoutScreen extends StatefulWidget {
  const WorkoutScreen({super.key});

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  static const _proYellow = Color(0xFFFFD60A);

  static const _progresszioPrefKey = 'utolso_progresszio';

  final _service = WorkoutService.instance;
  List<RoutineModel> _aiRutinok = [];
  List<RoutineModel> _sajatRutinok = [];
  List<WorkoutSessionModel> _befejezettEdzesek = [];
  double _progresszio = 5.0;
  bool _betolt = true;
  bool _hiba = false;
  bool _aiNyitva = true;
  bool _sajatNyitva = true;
  bool _tortenetNyitva = true;

  @override
  void initState() {
    super.initState();
    _betoltes();
  }

  Future<void> _betoltes() async {
    setState(() {
      _betolt = true;
      _hiba = false;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final eredmenyek = await Future.wait([
        _service.aiAjanlatok(targetMuscle: 'Chest'),
        _service.sajatRutinok(),
        _service.edzesTortenet(),
      ]);
      if (!mounted) return;
      setState(() {
        _progresszio = (prefs.getDouble(_progresszioPrefKey) ?? 5.0).clamp(0.0, 20.0);
        _aiRutinok = eredmenyek[0] as List<RoutineModel>;
        _sajatRutinok = eredmenyek[1] as List<RoutineModel>;
        _befejezettEdzesek = eredmenyek[2] as List<WorkoutSessionModel>;
        _betolt = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _hiba = true;
        _betolt = false;
      });
    }
  }

  Future<void> _uresEdzesInditasa() async {
    if (!await _kezelFutoEdzest()) return;
    try {
      await _service.uresEdzesInditasa();
      if (!mounted) return;
      _nyissonAktivEdzest('Üres edzés');
    } catch (e) {
      _uzenet('$e', hiba: true);
    }
  }

  Future<void> _rutinInditasa(RoutineModel rutin, {bool mentett = false}) async {
    if (!await _kezelFutoEdzest()) return;
    try {
      await _service.rutinInditasa(rutin, mentett: mentett);
      if (!mounted) return;
      _nyissonAktivEdzest(rutin.title);
    } catch (e) {
      _uzenet('$e', hiba: true);
    }
  }

  Future<void> _aiRutinMegnyitasa(RoutineModel rutin) async {
    final eredmeny = await Navigator.of(context).push<RoutineModel>(
      MaterialPageRoute(
        builder: (_) => RoutinePreviewScreen(rutin: rutin, ai: true),
      ),
    );
    if (eredmeny != null) {
      await _rutinInditasa(eredmeny);
    } else {
      await _betoltes();
    }
  }

  Future<void> _ujRutin() async {
    final friss = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => RoutineEditScreen(
          ujRutin: true,
          rutin: RoutineModel(
            id: '',
            title: '',
            difficulty: 'beginner',
            targetMuscle: 'Full Body',
            sportCategory: 'gym',
            exerciseIds: const [],
            exerciseNames: const [],
            creatorName: ApiConfig.defaultUserName,
          ),
        ),
      ),
    );
    if (friss == true) await _betoltes();
  }

  Future<void> _felfedezes() async {
    final rutin = await Navigator.of(context).push<RoutineModel>(
      MaterialPageRoute(builder: (_) => const AiExploreScreen()),
    );
    if (rutin != null) {
      await _rutinInditasa(rutin);
    } else {
      await _betoltes();
    }
  }

  /// Ha mar fut edzes: Folytatas / Elvetés / Megse
  Future<bool> _kezelFutoEdzest() async {
    final aktiv = await _service.aktivEdzesVagyNull();
    if (aktiv == null) return true;

    if (!mounted) return false;
    final valasztas = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mar fut egy edzes'),
        content: const Text('Eloszor fejezd be vagy dobd el a futo edzest, vagy folytasd.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, 'megse'), child: const Text('Megse')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'elvet'),
            child: const Text('Elvetés', style: TextStyle(color: Colors.red)),
          ),
          FilledButton(onPressed: () => Navigator.pop(ctx, 'folytat'), child: const Text('Folytatas')),
        ],
      ),
    );

    if (valasztas == 'folytat') {
      _nyissonAktivEdzest(aktiv.title);
      return false;
    }
    if (valasztas == 'elvet') {
      await _service.edzesElvetese();
      return true;
    }
    return false;
  }

  void _nyissonAktivEdzest(String cim) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ActiveWorkoutScreen(edzesCim: cim)),
    ).then((_) => _betoltes());
  }

  Future<void> _kovetkezoEdzesInditasa(WorkoutSessionModel forras) async {
    if (!await _kezelFutoEdzest()) return;
    try {
      final szorzo = 1 + _progresszio / 100;

      // Az elvégzett sorozatok progressziós változata
      final modositottGyakorlatok = forras.exercises.map((gy) {
        final modositottSorozatok = gy.sets
            .where((s) => s.elvegezve)
            .toList()
            .asMap()
            .entries
            .map((e) => e.value.copyWith(
                  setNumber: e.key + 1,
                  weight: double.parse(
                      (e.value.weight * szorzo).toStringAsFixed(1)),
                  reps: e.value.reps,
                  elvegezve: false,
                  celIsmetles: '${e.value.reps}',
                  elozoSulyKg: e.value.weight,
                  elozoIsmetles: e.value.reps,
                ))
            .toList();
        if (modositottSorozatok.isEmpty) return null;
        return LoggedExerciseModel(
          exerciseId: gy.exerciseId,
          exerciseName: gy.exerciseName,
          sets: modositottSorozatok,
        );
      }).whereType<LoggedExerciseModel>().toList();

      if (modositottGyakorlatok.isEmpty) {
        _uzenet('Nincs elvégzett sorozat ebben az edzésben.', hiba: true);
        return;
      }

      // A cím NEM tartalmazza a % jelzést (a forrásnév alapján)
      final alapNev = forras.megjelenitettCim
          .replaceAll(RegExp(r'\s*\+[\d.]+%'), '');
      final progresszioCimke = _progresszio == 0
          ? alapNev
          : '$alapNev +${_progresszio.toStringAsFixed(1)}%';

      // 1. Indítjuk az edzést a gyakorlatlistával
      final rutin = RoutineModel(
        id: '',
        title: progresszioCimke,
        difficulty: 'intermediate',
        targetMuscle: 'Full Body',
        sportCategory: 'gym',
        exerciseIds: modositottGyakorlatok.map((e) => e.exerciseId).toList(),
        exerciseNames: modositottGyakorlatok.map((e) => e.exerciseName).toList(),
        gyakorlatSablonok: modositottGyakorlatok,
      );
      await _service.rutinInditasa(rutin, mentett: false);

      // 2. Azonnali sorozat-frissítés: a backend esetleg 0-ra reset-eli a súlyt,
      //    ezért explicit elküldjük a helyes értékeket minden gyakorlathoz
      for (final gy in modositottGyakorlatok) {
        await _service.sorozatokFrissitese(gy.exerciseId, gy.sets);
      }

      if (!mounted) return;
      _nyissonAktivEdzest(progresszioCimke);
    } catch (e) {
      _uzenet('$e', hiba: true);
    }
  }

  void _uzenet(String szoveg, {bool hiba = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(szoveg),
        backgroundColor: hiba ? Colors.red.shade700 : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _betoltes,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildFejlec()),
              SliverToBoxAdapter(child: _buildUresEdzesGomb()),
              SliverToBoxAdapter(child: _buildRutinFejlec()),
              SliverToBoxAdapter(child: _buildRutinAkcioGombok()),
              if (_betolt)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_hiba)
                SliverFillRemaining(hasScrollBody: false, child: _buildHiba())
              else ...[
                if (_befejezettEdzesek.isNotEmpty)
                  _buildKovetkezoEdzesSliver(),
                _buildAiSliver(),
                SliverToBoxAdapter(child: _buildMenteseimFejlec()),
                _buildSajatRutinokSliver(),
                _buildBefejezettEdzesekSliver(),
              ],
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFejlec() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(
        children: [
          const Text(
            'Edzés',
            style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: Colors.black87),
          ),
          const Icon(Icons.keyboard_arrow_down, size: 28, color: Colors.black87),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _proYellow,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'PRO',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUresEdzesGomb() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      child: Material(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: _uresEdzesInditasa,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add, size: 22, color: Colors.black87),
                SizedBox(width: 8),
                Text(
                  'Üres edzés indítása',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.black87),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRutinFejlec() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Text(
            'Rutinok',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.black87),
          ),
        ],
      ),
    );
  }

  Widget _buildRutinAkcioGombok() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Row(
        children: [
          Expanded(child: _szurkGomb(Icons.assignment_outlined, 'Új rutin', _ujRutin)),
          const SizedBox(width: 12),
          Expanded(child: _szurkGomb(Icons.auto_awesome, 'AI felfedezés', _felfedezes)),
        ],
      ),
    );
  }

  Widget _szurkGomb(IconData ikon, String cimke, VoidCallback onTap) {
    return Material(
      color: Colors.grey.shade100,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(ikon, size: 20, color: Colors.black87),
              const SizedBox(width: 8),
              Text(cimke, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHiba() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text('Nem sikerült betölteni a rutinokat', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            const Text('Indítsd el: dotnet run', style: TextStyle(fontSize: 13)),
            const SizedBox(height: 16),
            FilledButton(onPressed: _betoltes, child: const Text('Újra')),
          ],
        ),
      ),
    );
  }

  Widget _buildKovetkezoEdzesSliver() {
    final legutobbiEdzesek = _befejezettEdzesek.take(3).toList();
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
            child: Row(
              children: [
                const Text('🚀', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                const Text(
                  'Következő edzés',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.black87),
                ),
                const SizedBox(width: 10),
                if (_progresszio > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00BFA5).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '+${_progresszio.toStringAsFixed(1)}%',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF00897B),
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Pihenő',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.blue),
                    ),
                  ),
              ],
            ),
          ),
          ...legutobbiEdzesek.map((edzes) => _KovetkezoEdzesKartya(
                edzes: edzes,
                progresszio: _progresszio,
                onInditas: () => _kovetkezoEdzesInditasa(edzes),
              )),
        ],
      ),
    );
  }

  Widget _buildMenteseimFejlec() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Row(
        children: [
          const Icon(Icons.bookmark_outline, size: 22),
          const SizedBox(width: 8),
          const Text(
            'Mentéseim',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.black87),
          ),
        ],
      ),
    );
  }

  Widget _buildSajatRutinokSliver() {
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _sajatNyitva = !_sajatNyitva),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
              child: Row(
                children: [
                  Icon(_sajatNyitva ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right, size: 22),
                  Expanded(
                    child: Text(
                      'Saját rutinok (${_sajatRutinok.length})',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_sajatNyitva)
            if (_sajatRutinok.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Text(
                  'Még nincs mentett rutin. Befejezésnél pipáld be: „Mentés saját rutinként”.',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.4),
                ),
              )
            else
              ..._sajatRutinok.asMap().entries.map((e) => _RutinKartya(
                    key: ValueKey('sajat_${e.value.id}'),
                    rutin: e.value,
                    index: e.key,
                    onInditas: () => _rutinInditasa(e.value, mentett: true),
                    mentett: true,
                    onSzerkesztes: () async {
                      final friss = await Navigator.of(context).push<bool>(
                        MaterialPageRoute(builder: (_) => RoutineEditScreen(rutin: e.value)),
                      );
                      if (friss == true) await _betoltes();
                    },
                  )),
        ],
      ),
    );
  }

  Widget _buildBefejezettEdzesekSliver() {
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _tortenetNyitva = !_tortenetNyitva),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
              child: Row(
                children: [
                  Icon(_tortenetNyitva ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right, size: 22),
                  Expanded(
                    child: Text(
                      'Befejezett edzések (${_befejezettEdzesek.length})',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_tortenetNyitva)
            if (_befejezettEdzesek.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Text(
                  'Még nincs befejezett edzés. Fejezz be egy edzést a „Befejezés” gombbal.',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.4),
                ),
              )
            else
              ..._befejezettEdzesek.map((edzes) => _BefejezettEdzesKartya(
                    edzes: edzes,
                    onTap: () async {
                      final friss = await Navigator.of(context).push<bool>(
                        MaterialPageRoute(
                          builder: (_) => WorkoutHistoryDetailScreen(edzes: edzes),
                        ),
                      );
                      if (friss == true) await _betoltes();
                    },
                  )),
        ],
      ),
    );
  }

  Widget _buildAiSliver() {
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _aiNyitva = !_aiNyitva),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
              child: Row(
                children: [
                  Icon(_aiNyitva ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right, size: 22),
                  const Icon(Icons.auto_awesome, size: 18, color: Color(0xFF1E88E5)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'AI ajánlott edzések (${_aiRutinok.length})',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                    ),
                  ),
                  TextButton(onPressed: _felfedezes, child: const Text('Új variációk')),
                ],
              ),
            ),
          ),
          if (_aiNyitva)
            if (_aiRutinok.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Text(
                  'Nincs AI ajánlat. Nyomd meg az „AI felfedezés” gombot.',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
              )
            else
              ..._aiRutinok.asMap().entries.map((e) => _RutinKartya(
                    key: ValueKey('ai_${e.value.id}'),
                    rutin: e.value,
                    index: e.key,
                    ai: true,
                    onTap: () => _aiRutinMegnyitasa(e.value),
                  )),
        ],
      ),
    );
  }
}

class _RutinKartya extends StatelessWidget {
  const _RutinKartya({
    required super.key,
    required this.rutin,
    required this.index,
    this.onInditas,
    this.onTap,
    this.mentett = false,
    this.ai = false,
    this.onSzerkesztes,
  });

  final RoutineModel rutin;
  final int index;
  final VoidCallback? onInditas;
  final VoidCallback? onTap;
  final bool mentett;
  final bool ai;
  final VoidCallback? onSzerkesztes;

  static const _primaryBlue = Color(0xFF1E88E5);

  @override
  Widget build(BuildContext context) {
    final kattinthato = onTap != null;

    return Container(
      key: key,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: kattinthato
          ? InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(16),
              child: _kartyaTartalom(kattinthato: true),
            )
          : _kartyaTartalom(kattinthato: false),
    );
  }

  Widget _kartyaTartalom({required bool kattinthato}) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (ai)
                const Icon(Icons.auto_awesome, color: Color(0xFF1E88E5), size: 20)
              else if (mentett)
                Icon(Icons.bookmark, color: Colors.amber.shade700, size: 20)
              else
                ReorderableDragStartListener(
                  index: index,
                  child: Icon(Icons.drag_handle, color: Colors.grey.shade400, size: 20),
                ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  rutin.title,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
              ),
              if (kattinthato)
                Icon(Icons.chevron_right, color: Colors.grey.shade400)
              else if (onSzerkesztes != null)
                IconButton(
                  onPressed: onSzerkesztes,
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            kattinthato
                ? '${rutin.exerciseNames.length} gyakorlat · ${rutin.previewText}'
                : rutin.previewText,
            maxLines: kattinthato ? 2 : null,
            overflow: kattinthato ? TextOverflow.ellipsis : null,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600, height: 1.35),
          ),
          if (kattinthato) ...[
            const SizedBox(height: 8),
            Text(
              'Koppints a részletekért',
              style: TextStyle(fontSize: 12, color: _primaryBlue, fontWeight: FontWeight.w600),
            ),
          ],
          if (onInditas != null) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onInditas,
                style: FilledButton.styleFrom(
                  backgroundColor: _primaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text(
                  'Rutin indítása',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _KovetkezoEdzesKartya extends StatelessWidget {
  const _KovetkezoEdzesKartya({
    required this.edzes,
    required this.progresszio,
    required this.onInditas,
  });

  final WorkoutSessionModel edzes;
  final double progresszio;
  final VoidCallback onInditas;

  static const _teal = Color(0xFF00897B);
  static const _tealLight = Color(0xFF00BFA5);

  @override
  Widget build(BuildContext context) {
    final szorzo = 1 + progresszio / 100;
    final elvegzettGyakorlatok = edzes.exercises
        .where((gy) => gy.sets.any((s) => s.elvegezve))
        .toList();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F2027), Color(0xFF1A3A35)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _teal.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: _teal.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Fejléc
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        edzes.megjelenitettCim,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        edzes.datumSzoveg,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.45),
                        ),
                      ),
                    ],
                  ),
                ),
                // Progresszió badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: progresszio > 0
                        ? _tealLight.withValues(alpha: 0.2)
                        : Colors.blue.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: progresszio > 0
                          ? _tealLight.withValues(alpha: 0.5)
                          : Colors.blue.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    progresszio > 0
                        ? '+${progresszio.toStringAsFixed(1)}%'
                        : 'Pihenő',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: progresszio > 0 ? _tealLight : Colors.lightBlueAccent,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Gyakorlatok listája módosított súlyokkal
            if (elvegzettGyakorlatok.isNotEmpty) ...[
              ...elvegzettGyakorlatok.take(4).map((gy) {
                final elvegzettSorozatok = gy.sets.where((s) => s.elvegezve).toList();
                final maxSulyRegi = elvegzettSorozatok
                    .map((s) => s.weight)
                    .fold(0.0, (a, b) => a > b ? a : b);
                final maxSulyUj = maxSulyRegi * szorzo;
                final sorozatSzam = elvegzettSorozatok.length;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 4,
                        margin: const EdgeInsets.only(right: 8, top: 1),
                        decoration: BoxDecoration(
                          color: _tealLight.withValues(alpha: 0.7),
                          shape: BoxShape.circle,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          gy.exerciseName,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.8),
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (maxSulyRegi > 0)
                        Row(
                          children: [
                            Text(
                              '${maxSulyRegi.toStringAsFixed(maxSulyRegi == maxSulyRegi.roundToDouble() ? 0 : 1)} kg',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.35),
                                decoration: progresszio > 0 ? TextDecoration.lineThrough : null,
                              ),
                            ),
                            if (progresszio > 0) ...[
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 4),
                                child: Icon(Icons.arrow_forward_rounded, size: 12, color: Color(0xFF00BFA5)),
                              ),
                              Text(
                                '${maxSulyUj.toStringAsFixed(maxSulyUj == maxSulyUj.roundToDouble() ? 0 : 1)} kg',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: _tealLight,
                                ),
                              ),
                            ],
                            const SizedBox(width: 6),
                            Text(
                              '× $sorozatSzam',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white.withValues(alpha: 0.3),
                              ),
                            ),
                          ],
                        )
                      else
                        Text(
                          '$sorozatSzam sorozat',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.4),
                          ),
                        ),
                    ],
                  ),
                );
              }),
              if (elvegzettGyakorlatok.length > 4)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8, left: 12),
                  child: Text(
                    '+ ${elvegzettGyakorlatok.length - 4} további gyakorlat',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.35),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              const SizedBox(height: 10),
            ],

            // Indítás gomb
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onInditas,
                style: FilledButton.styleFrom(
                  backgroundColor: _teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.play_arrow_rounded, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      progresszio > 0
                          ? 'Indítás +${progresszio.toStringAsFixed(1)}% súllyal'
                          : 'Indítás (változatlan súlyok)',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BefejezettEdzesKartya extends StatelessWidget {
  const _BefejezettEdzesKartya({required this.edzes, required this.onTap});

  final WorkoutSessionModel edzes;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.check_circle, color: Colors.green.shade600),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      edzes.megjelenitettCim,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      edzes.datumSzoveg,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      edzes.gyakorlatOsszefoglalo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(edzes.idoSzoveg, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(
                    '${edzes.osszSorozatSzam} sor · ${edzes.osszTomegKg.toStringAsFixed(0)} kg',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}
