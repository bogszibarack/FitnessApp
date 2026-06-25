import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/workout_models.dart';
import '../../services/sound_service.dart';

/// Edzés befejezése után megjelenő összefoglaló + progresszió-tervező.
class WorkoutSummaryScreen extends StatefulWidget {
  const WorkoutSummaryScreen({
    super.key,
    required this.edzes,
    required this.onMentes,
  });

  /// A befejezett edzés adatai.
  final WorkoutSessionModel edzes;

  /// Callback: visszaadja az edzés nevét és a progresszió %-ot, majd bezárja a screent.
  final Future<void> Function(String cim, bool mentRutin, double progresszioSzazalek) onMentes;

  @override
  State<WorkoutSummaryScreen> createState() => _WorkoutSummaryScreenState();
}

class _WorkoutSummaryScreenState extends State<WorkoutSummaryScreen> with SingleTickerProviderStateMixin {
  late final TextEditingController _cimCtrl;
  bool _mentRutin = false;
  double _progresszio = 5.0;
  bool _mentes = false;
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  static const _prefKey = 'utolso_progresszio';

  @override
  void initState() {
    super.initState();
    _cimCtrl = TextEditingController(text: widget.edzes.title);
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    // Edzés befejezés hang
    SoundService.instance.edzesBefejezesHang();
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final mentett = prefs.getDouble(_prefKey);
    if (mentett != null && mounted) {
      setState(() => _progresszio = mentett.clamp(0.0, 20.0));
    }
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_prefKey, _progresszio);
  }

  @override
  void dispose() {
    _cimCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  // ─── Progresszió értékelő logika ──────────────────────────────────────────

  _ProgresszioSzint get _szint {
    if (_progresszio == 0) return _ProgresszioSzint.deload;
    if (_progresszio <= 2.5) return _ProgresszioSzint.mikro;
    if (_progresszio <= 5.0) return _ProgresszioSzint.ajanlott;
    if (_progresszio <= 10.0) return _ProgresszioSzint.aggressziv;
    return _ProgresszioSzint.tulterheles;
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final szint = _szint;
    return Scaffold(
      backgroundColor: const Color(0xFF0F1923),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _buildHeader()),
              SliverToBoxAdapter(child: _buildStatCards()),
              SliverToBoxAdapter(child: _buildEdzesNev()),
              SliverToBoxAdapter(child: _buildProgresszioSzekcio(szint)),
              SliverToBoxAdapter(child: _buildProKon(szint)),
              SliverToBoxAdapter(child: _buildGiakorlatok()),
              SliverToBoxAdapter(child: _buildMentesGomb()),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Fejléc ───────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Column(
        children: [
          const Text('🏆', style: TextStyle(fontSize: 52)),
          const SizedBox(height: 12),
          const Text(
            'Edzés kész!',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5),
          ),
          const SizedBox(height: 6),
          Text(
            widget.edzes.title,
            style: TextStyle(fontSize: 16, color: Colors.white.withValues(alpha: 0.6)),
          ),
        ],
      ),
    );
  }

  // ─── Stat kártyák ─────────────────────────────────────────────────────────

  Widget _buildStatCards() {
    final ido = widget.edzes.elteltMasodperc;
    final perc = ido ~/ 60;
    final mp = ido % 60;
    final sorozat = widget.edzes.osszSorozatSzam;
    final tomeg = widget.edzes.osszTomegKg;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          _StatKartya(
            emoji: '⏱️',
            ertek: '${perc}p ${mp.toString().padLeft(2, '0')}mp',
            cimke: 'Edzésidő',
            szin: const Color(0xFF1E88E5),
          ),
          const SizedBox(width: 10),
          _StatKartya(
            emoji: '🔁',
            ertek: '$sorozat',
            cimke: 'Sorozat',
            szin: const Color(0xFF34C759),
          ),
          const SizedBox(width: 10),
          _StatKartya(
            emoji: '🏋️',
            ertek: '${tomeg.toStringAsFixed(0)} kg',
            cimke: 'Térfogat',
            szin: const Color(0xFFFF9F43),
          ),
        ],
      ),
    );
  }

  // ─── Edzés neve ───────────────────────────────────────────────────────────

  Widget _buildEdzesNev() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SzekcioFejlec(cim: 'Edzés neve'),
          const SizedBox(height: 8),
          TextField(
            controller: _cimCtrl,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.08),
              hintText: 'pl. Push, Melledzés...',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              prefixIcon: Icon(Icons.edit_rounded, color: Colors.white.withValues(alpha: 0.5), size: 18),
            ),
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: () => setState(() => _mentRutin = !_mentRutin),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _mentRutin
                    ? const Color(0xFF34C759).withValues(alpha: 0.15)
                    : Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _mentRutin ? const Color(0xFF34C759).withValues(alpha: 0.4) : Colors.transparent,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _mentRutin ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                    color: _mentRutin ? const Color(0xFF34C759) : Colors.white.withValues(alpha: 0.4),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Mentés saját rutinként',
                    style: TextStyle(
                      color: _mentRutin ? const Color(0xFF34C759) : Colors.white.withValues(alpha: 0.7),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Progresszió szekció ──────────────────────────────────────────────────

  Widget _buildProgresszioSzekcio(_ProgresszioSzint szint) {
    final szin = szint.szin;
    final terheles = widget.edzes.osszTomegKg;
    final jovoheti = terheles * (1 + _progresszio / 100);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SzekcioFejlec(cim: 'Progresszió jövő hétre'),
          const SizedBox(height: 14),

          // Progresszió érték kiemelő
          Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: BoxDecoration(
                color: szin.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: szin.withValues(alpha: 0.4), width: 1.5),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _progresszio == 0 ? '0' : '+${_progresszio.toStringAsFixed(1)}',
                        style: TextStyle(
                          fontSize: 42,
                          fontWeight: FontWeight.w900,
                          color: szin,
                          height: 1,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text('%', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: szin)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    szint.cimke,
                    style: TextStyle(fontSize: 13, color: szin, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Csúszka
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: szin,
              thumbColor: szin,
              inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
              overlayColor: szin.withValues(alpha: 0.2),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 14),
              trackHeight: 6,
            ),
            child: Slider(
              min: 0,
              max: 20,
              divisions: 40,
              value: _progresszio,
              onChanged: (v) => setState(() => _progresszio = (v * 2).round() / 2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('0% (Pihenő)', style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.35))),
                Text('20% (Max)', style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.35))),
              ],
            ),
          ),

          // Előrejelzés
          if (terheles > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Mai térfogat', style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.5))),
                  Text('${terheles.toStringAsFixed(0)} kg', style: const TextStyle(fontSize: 13, color: Colors.white)),
                  const Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.white38),
                  Text(
                    '${jovoheti.toStringAsFixed(0)} kg',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: szin),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── Pro/Kon érvek ────────────────────────────────────────────────────────

  Widget _buildProKon(_ProgresszioSzint szint) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        children: [
          ...szint.pro.map((s) => _ProKonSor(szoveg: s, pro: true)),
          ...szint.kon.map((s) => _ProKonSor(szoveg: s, pro: false)),
        ],
      ),
    );
  }

  // ─── Gyakorlatok összefoglaló ─────────────────────────────────────────────

  Widget _buildGiakorlatok() {
    if (widget.edzes.exercises.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SzekcioFejlec(cim: 'Elvégzett gyakorlatok'),
          const SizedBox(height: 10),
          ...widget.edzes.exercises.map((gy) {
            final elvegzett = gy.sets.where((s) => s.elvegezve).toList();
            if (elvegzett.isEmpty) return const SizedBox.shrink();
            final maxSuly = elvegzett.map((s) => s.weight).fold(0.0, max);
            final osszIsmIndex = elvegzett.fold(0, (sum, s) => sum + s.reps);
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      gy.exerciseName,
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text(
                    '${elvegzett.length} × ${maxSuly > 0 ? "${maxSuly.toStringAsFixed(1)} kg · " : ""}$osszIsmIndex ism.',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ─── Mentés gomb ──────────────────────────────────────────────────────────

  Widget _buildMentesGomb() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: FilledButton(
          onPressed: _mentes ? null : _onMentes,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF34C759),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: _mentes
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
              : const Text('Edzés mentése', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        ),
      ),
    );
  }

  Future<void> _onMentes() async {
    setState(() => _mentes = true);
    await _savePreferences();
    try {
      final cim = _cimCtrl.text.trim().isEmpty ? widget.edzes.title : _cimCtrl.text.trim();
      await widget.onMentes(cim, _mentRutin, _progresszio);
    } catch (e) {
      if (mounted) {
        setState(() => _mentes = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hiba: $e'), backgroundColor: Colors.red.shade700),
        );
      }
    }
  }
}

// ─── Progresszió szintek ──────────────────────────────────────────────────────

enum _ProgresszioSzint {
  deload,
  mikro,
  ajanlott,
  aggressziv,
  tulterheles,
}

extension _ProgresszioSzintExt on _ProgresszioSzint {
  Color get szin => switch (this) {
        _ProgresszioSzint.deload      => const Color(0xFF1E88E5),
        _ProgresszioSzint.mikro       => const Color(0xFF34C759),
        _ProgresszioSzint.ajanlott    => const Color(0xFF00BFA5),
        _ProgresszioSzint.aggressziv  => const Color(0xFFFF9F43),
        _ProgresszioSzint.tulterheles => const Color(0xFFFF4757),
      };

  String get cimke => switch (this) {
        _ProgresszioSzint.deload      => 'Pihenő / visszaállás',
        _ProgresszioSzint.mikro       => 'Mikro-progresszió',
        _ProgresszioSzint.ajanlott    => '⭐ Ajánlott progresszió',
        _ProgresszioSzint.aggressziv  => 'Agresszív növelés',
        _ProgresszioSzint.tulterheles => '⚠️ Túlterhelés veszélye',
      };

  List<String> get pro => switch (this) {
        _ProgresszioSzint.deload => [
            '✅ Tökéletes visszaállás után vagy sérülés-megelőzésre.',
            '✅ Az izmok regenerálódnak, így jövő héten erősebbek lesznek.',
          ],
        _ProgresszioSzint.mikro => [
            '✅ Hosszú távon is fenntartható, folyamatos fejlődés.',
            '✅ Alacsony sérülésveszély, különösen haladóbbaknak ideális.',
          ],
        _ProgresszioSzint.ajanlott => [
            '✅ Ez az iparági arany standard — legtöbb edzőnek ez a legjobb.',
            '✅ Elég inger az izomfejlődéshez, de nem terheli túl az ízületeket.',
            '✅ Kezdő és haladó sportolóknak egyaránt megfelelő.',
          ],
        _ProgresszioSzint.aggressziv => [
            '✅ Gyors erő- és izomnövekedés lehetséges rövid időn belül.',
            '✅ Tapasztalt sportolóknak (2+ év edzéstapasztalat) hatékony.',
          ],
        _ProgresszioSzint.tulterheles => [
            '✅ Extrém körülmények közt (olimpiai felkészülés, profi sport) indokolt lehet.',
          ],
      };

  List<String> get kon => switch (this) {
        _ProgresszioSzint.deload => [
            '⚠️ Ha nem sérülés vagy fáradás miatt csinálod, lassíthatja a fejlődést.',
          ],
        _ProgresszioSzint.mikro => [
            '⚠️ Lassan látható az eredmény — türelem szükséges.',
          ],
        _ProgresszioSzint.ajanlott => [],
        _ProgresszioSzint.aggressziv => [
            '⚠️ Megnövekedett sérülésveszély az ízületeken és inszalagokon.',
            '⚠️ Kezdőknek nem ajánlott — a forma romolhat a nagy súly miatt.',
            '⚠️ Több regenerálódási időt igényel az izmoknak.',
          ],
        _ProgresszioSzint.tulterheles => [
            '❌ Nagy az izomlázás, sérülés és kiégés (overtraining) kockázata.',
            '❌ Nem fenntartható — a szervezet előbb-utóbb visszacsap.',
            '❌ Kifejezetten nem ajánlott, ha 5-10%-nál eddig is jól halaadtál.',
          ],
      };
}

// ─── Segéd widgetek ────────────────────────────────────────────────────────────

class _StatKartya extends StatelessWidget {
  const _StatKartya({required this.emoji, required this.ertek, required this.cimke, required this.szin});
  final String emoji;
  final String ertek;
  final String cimke;
  final Color szin;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: szin.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: szin.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 6),
            Text(ertek, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: szin)),
            const SizedBox(height: 2),
            Text(cimke, style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.5))),
          ],
        ),
      ),
    );
  }
}

class _SzekcioFejlec extends StatelessWidget {
  const _SzekcioFejlec({required this.cim});
  final String cim;

  @override
  Widget build(BuildContext context) {
    return Text(
      cim.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: Colors.white.withValues(alpha: 0.4),
      ),
    );
  }
}

class _ProKonSor extends StatelessWidget {
  const _ProKonSor({required this.szoveg, required this.pro});
  final String szoveg;
  final bool pro;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: pro
              ? const Color(0xFF34C759).withValues(alpha: 0.08)
              : const Color(0xFFFF4757).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          szoveg,
          style: TextStyle(
            fontSize: 13,
            color: Colors.white.withValues(alpha: 0.8),
            height: 1.4,
          ),
        ),
      ),
    );
  }
}
