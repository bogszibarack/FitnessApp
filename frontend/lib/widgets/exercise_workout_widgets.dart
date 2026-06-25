import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/exercise_model.dart';
import '../models/workout_models.dart';
import '../services/exercise_service.dart';
import '../services/sound_service.dart';
import '../services/workout_service.dart';

/// Kép / animáció a gyakorlatról (GitHub képkockák).
class ExerciseMediaPreview extends StatefulWidget {
  const ExerciseMediaPreview({
    super.key,
    required this.images,
    this.compact = false,
  });

  final List<String> images;
  final bool compact;

  @override
  State<ExerciseMediaPreview> createState() => _ExerciseMediaPreviewState();
}

class _ExerciseMediaPreviewState extends State<ExerciseMediaPreview> {
  int _kepIndex = 0;
  Timer? _animTimer;

  @override
  void initState() {
    super.initState();
    _animacioInditasa();
  }

  @override
  void didUpdateWidget(covariant ExerciseMediaPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.images.length != widget.images.length) {
      _animacioInditasa();
    }
  }

  void _animacioInditasa() {
    _animTimer?.cancel();
    if (widget.images.length <= 1) return;
    _animTimer = Timer.periodic(const Duration(milliseconds: 900), (_) {
      if (!mounted) return;
      setState(() => _kepIndex = (_kepIndex + 1) % widget.images.length);
    });
  }

  @override
  void dispose() {
    _animTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.images.isEmpty) {
      return AspectRatio(
        aspectRatio: widget.compact ? 2.2 : 16 / 10,
        child: ColoredBox(
          color: Colors.grey.shade100,
          child: Icon(Icons.fitness_center, size: widget.compact ? 40 : 64, color: Colors.grey.shade400),
        ),
      );
    }

    return Column(
      children: [
        AspectRatio(
          aspectRatio: widget.compact ? 2.2 : 16 / 10,
          child: Image.network(
            widget.images[_kepIndex % widget.images.length],
            fit: BoxFit.contain,
            loadingBuilder: (_, child, progress) {
              if (progress == null) return child;
              return const Center(child: CircularProgressIndicator(strokeWidth: 2));
            },
            errorBuilder: (_, e, st) => Center(
              child: Icon(Icons.fitness_center, size: widget.compact ? 40 : 64, color: Colors.grey.shade400),
            ),
          ),
        ),
        if (widget.images.length > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 6, top: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.play_circle_outline, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  'Animáció (${_kepIndex + 1}/${widget.images.length})',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Teljes gyakorlat leírás — minden instruction lépés.
class ExerciseTamLeiras extends StatelessWidget {
  const ExerciseTamLeiras({super.key, required this.meta});

  final ExerciseModel meta;

  @override
  Widget build(BuildContext context) {
    if (meta.instructions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
        child: Text('Nincs részletes leírás.', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Leírás', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey.shade700)),
          const SizedBox(height: 6),
          ...meta.instructions.asMap().entries.map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '${e.key + 1}. ${e.value}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade800, height: 1.4),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

/// Gyakorlat infó sor (izom, eszköz, rövid leírás).
class ExerciseInfoSor extends StatelessWidget {
  const ExerciseInfoSor({super.key, required this.meta});

  final ExerciseModel meta;

  @override
  Widget build(BuildContext context) {
    final cimkek = [meta.muscleGroup, meta.equipment, meta.category].where((s) => s.isNotEmpty).join(' · ');
    final elsoUtasitas = meta.instructions.isNotEmpty ? meta.instructions.first : '';

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (cimkek.isNotEmpty)
            Text(cimkek, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          if (elsoUtasitas.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              elsoUtasitas,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700, height: 1.3),
            ),
          ],
        ],
      ),
    );
  }
}

/// Sorozat fejléc.
class SorozatFejlec extends StatelessWidget {
  const SorozatFejlec({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
      child: Row(
        children: [
          const SizedBox(width: 36, child: Text('SET', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11))),
          const Expanded(flex: 2, child: Text('ELŐZŐ', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11))),
          const Expanded(child: Text('KG', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11), textAlign: TextAlign.center)),
          const Expanded(child: Text('ISM', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11), textAlign: TextAlign.center)),
          const SizedBox(width: 44),
        ],
      ),
    );
  }
}

/// Egy sorozat sora — súly/ismétlés mentés + pipa.
class SorozatSor extends StatefulWidget {
  const SorozatSor({
    super.key,
    required this.sorozat,
    required this.onPipa,
    required this.onMent,
    this.onTorles,
  });

  final LoggedSetModel sorozat;
  final Future<void> Function(double suly, int ismetles) onPipa;
  final Future<void> Function(double suly, int ismetles) onMent;
  final VoidCallback? onTorles;

  @override
  State<SorozatSor> createState() => _SorozatSorState();
}

class _SorozatSorState extends State<SorozatSor>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _sulyController;
  late final TextEditingController _ismController;
  bool _mentes = false;
  Timer? _debounce;
  late final AnimationController _prAnim;
  late final Animation<Color?> _prSzin;

  @override
  void initState() {
    super.initState();
    _sulyController = TextEditingController(text: _sulySzoveg(widget.sorozat.weight));
    _ismController = TextEditingController(text: widget.sorozat.reps > 0 ? '${widget.sorozat.reps}' : '');
    _sulyController.addListener(_autoMentes);
    _ismController.addListener(_autoMentes);
    _prAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _prSzin = ColorTween(
      begin: const Color(0xFFFFD700),
      end: Colors.transparent,
    ).animate(CurvedAnimation(parent: _prAnim, curve: Curves.easeOut));
    SoundService.instance.inicializalas();
  }

  @override
  void didUpdateWidget(covariant SorozatSor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sorozat.weight != widget.sorozat.weight && !_sulyController.text.contains('.')) {
      final uj = _sulySzoveg(widget.sorozat.weight);
      if (_sulyErtek() != widget.sorozat.weight) _sulyController.text = uj;
    }
    if (oldWidget.sorozat.reps != widget.sorozat.reps) {
      final uj = widget.sorozat.reps > 0 ? '${widget.sorozat.reps}' : '';
      if (_ismErtek() != widget.sorozat.reps) _ismController.text = uj;
    }
    if (oldWidget.sorozat.elvegezve != widget.sorozat.elvegezve) {
      _sulyController.text = _sulySzoveg(widget.sorozat.weight);
      _ismController.text = widget.sorozat.reps > 0 ? '${widget.sorozat.reps}' : '';
    }
  }

  void _autoMentes() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), _mentesHaKell);
  }

  String _sulySzoveg(double suly) {
    if (suly <= 0) return '';
    return suly % 1 == 0 ? suly.toInt().toString() : suly.toString();
  }

  double _sulyErtek() => double.tryParse(_sulyController.text.replaceAll(',', '.')) ?? 0;
  int _ismErtek() => int.tryParse(_ismController.text) ?? 0;

  Future<void> _mentesHaKell() async {
    if (_mentes) return;
    _mentes = true;
    try {
      await widget.onMent(_sulyErtek(), _ismErtek());
    } finally {
      _mentes = false;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _sulyController.dispose();
    _ismController.dispose();
    _prAnim.dispose();
    super.dispose();
  }

  bool _prErzekeles(double suly) {
    final elozo = widget.sorozat.elozoSulyKg;
    return !widget.sorozat.elvegezve && suly > 0 && elozo > 0 && suly > elozo;
  }

  Future<void> _prCelebracio() async {
    _prAnim.forward(from: 0);
    await SoundService.instance.prHangJatszas();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.sorozat;
    final kesz = s.elvegezve;
    final hatter = kesz ? Colors.green.shade50 : Colors.white;

    Widget sor = Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: hatter,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kesz ? Colors.green.shade200 : Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          children: [
            SizedBox(
              width: 36,
              child: Text(
                s.setLabel,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: s.bemelegites ? Colors.orange.shade700 : Colors.black87,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(s.elozoSzoveg, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            ),
            Expanded(
              child: TextField(
                controller: _sulyController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.center,
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))],
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: 'kg',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  border: InputBorder.none,
                ),
                onSubmitted: (_) => _mentesHaKell(),
              ),
            ),
            Expanded(
              child: TextField(
                controller: _ismController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: s.celIsmetles.isNotEmpty ? s.celIsmetles : 'ism',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  border: InputBorder.none,
                ),
                onSubmitted: (_) => _mentesHaKell(),
              ),
            ),
            SizedBox(
              width: 44,
              child: IconButton(
                padding: EdgeInsets.zero,
                onPressed: () async {
                  final suly = _sulyErtek();
                  final prDetek = _prErzekeles(suly);
                  await _mentesHaKell();
                  await widget.onPipa(suly, _ismErtek());
                  if (prDetek) await _prCelebracio();
                },
                icon: Icon(
                  kesz ? Icons.check_circle : Icons.check_circle_outline,
                  color: kesz ? Colors.green.shade600 : Colors.grey.shade400,
                  size: 26,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    // PR arany villanás overlay
    final sorPrrel = AnimatedBuilder(
      animation: _prAnim,
      builder: (ctx, child) {
        final szin = _prSzin.value;
        if (szin == null || szin.a == 0) return child!;
        return Stack(
          children: [
            child!,
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: szin.withValues(alpha: szin.a * 0.35),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFFD700), width: 1.5),
                  ),
                  child: szin.a > 0.5
                      ? Center(
                          child: Text(
                            '🏆 ÚJ REKORD!',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                              color: const Color(0xFFB8860B).withValues(alpha: szin.a),
                              letterSpacing: 1,
                            ),
                          ),
                        )
                      : null,
                ),
              ),
            ),
          ],
        );
      },
      child: sor,
    );

    if (widget.onTorles == null) return sorPrrel;

    return Dismissible(
      key: ValueKey('dismiss-${s.setNumber}-${s.bemelegites}'),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(color: Colors.red.shade400, borderRadius: BorderRadius.circular(8)),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        widget.onTorles!();
        return false;
      },
      child: sorPrrel,
    );
  }
}

/// Sorozatok szerkesztése hozzáadás előtt (helyi állapot, nincs API).
class HelyiSorozatSzerkeszto extends StatelessWidget {
  const HelyiSorozatSzerkeszto({
    super.key,
    required this.sorozatok,
    required this.onValtozas,
  });

  final List<LoggedSetModel> sorozatok;
  final ValueChanged<List<LoggedSetModel>> onValtozas;

  void _sorFrissites(int index, {double? suly, int? ismetles}) {
    final lista = List<LoggedSetModel>.from(sorozatok);
    lista[index] = lista[index].copyWith(
      weight: suly ?? lista[index].weight,
      reps: ismetles ?? lista[index].reps,
    );
    onValtozas(lista);
  }

  void _sorTorlese(int index) {
    final lista = List<LoggedSetModel>.from(sorozatok)..removeAt(index);
    for (var i = 0; i < lista.length; i++) {
      lista[i] = lista[i].copyWith(setNumber: i + 1);
    }
    onValtozas(lista);
  }

  void _ujSorozat() {
    final lista = List<LoggedSetModel>.from(sorozatok);
    lista.add(LoggedSetModel(
      setNumber: lista.length + 1,
      celIsmetles: '10-12',
    ));
    onValtozas(lista);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SorozatFejlec(),
        ...sorozatok.asMap().entries.map((e) => _HelyiSorozatSor(
              key: ValueKey('helyi-${e.key}-${e.value.setNumber}'),
              sorozat: e.value,
              onSuly: (suly) => _sorFrissites(e.key, suly: suly),
              onIsmetles: (ism) => _sorFrissites(e.key, ismetles: ism),
              onTorles: sorozatok.length > 1 ? () => _sorTorlese(e.key) : null,
            )),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
          child: OutlinedButton.icon(
            onPressed: _ujSorozat,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Sorozat hozzáadása', style: TextStyle(fontSize: 13)),
          ),
        ),
      ],
    );
  }
}

class _HelyiSorozatSor extends StatefulWidget {
  const _HelyiSorozatSor({
    super.key,
    required this.sorozat,
    required this.onSuly,
    required this.onIsmetles,
    this.onTorles,
  });

  final LoggedSetModel sorozat;
  final ValueChanged<double> onSuly;
  final ValueChanged<int> onIsmetles;
  final VoidCallback? onTorles;

  @override
  State<_HelyiSorozatSor> createState() => _HelyiSorozatSorState();
}

class _HelyiSorozatSorState extends State<_HelyiSorozatSor> {
  late final TextEditingController _sulyController;
  late final TextEditingController _ismController;

  @override
  void initState() {
    super.initState();
    _sulyController = TextEditingController(text: _sulySzoveg(widget.sorozat.weight));
    _ismController = TextEditingController(text: widget.sorozat.reps > 0 ? '${widget.sorozat.reps}' : '');
  }

  @override
  void didUpdateWidget(covariant _HelyiSorozatSor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sorozat.setNumber != widget.sorozat.setNumber) {
      _sulyController.text = _sulySzoveg(widget.sorozat.weight);
      _ismController.text = widget.sorozat.reps > 0 ? '${widget.sorozat.reps}' : '';
    }
  }

  String _sulySzoveg(double suly) {
    if (suly <= 0) return '';
    return suly % 1 == 0 ? suly.toInt().toString() : suly.toString();
  }

  @override
  void dispose() {
    _sulyController.dispose();
    _ismController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.sorozat;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          children: [
            SizedBox(
              width: 36,
              child: Text(
                s.setLabel,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: s.bemelegites ? Colors.orange.shade700 : Colors.black87,
                ),
              ),
            ),
            const Expanded(flex: 2, child: Text('-', style: TextStyle(fontSize: 11, color: Colors.grey))),
            Expanded(
              child: TextField(
                controller: _sulyController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.center,
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))],
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                decoration: const InputDecoration(
                  hintText: 'kg',
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  border: InputBorder.none,
                ),
                onChanged: (v) => widget.onSuly(double.tryParse(v.replaceAll(',', '.')) ?? 0),
              ),
            ),
            Expanded(
              child: TextField(
                controller: _ismController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: s.celIsmetles.isNotEmpty ? s.celIsmetles : 'ism',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  border: InputBorder.none,
                ),
                onChanged: (v) => widget.onIsmetles(int.tryParse(v) ?? 0),
              ),
            ),
            SizedBox(
              width: 36,
              child: widget.onTorles != null
                  ? IconButton(
                      padding: EdgeInsets.zero,
                      icon: Icon(Icons.close, size: 20, color: Colors.grey.shade500),
                      onPressed: widget.onTorles,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// Inline sorozat panel az edzés képernyőn — kép + súly mentés egy helyen.
class InlineGyakorlatPanel extends StatefulWidget {
  const InlineGyakorlatPanel({
    super.key,
    required this.exerciseId,
    required this.exerciseName,
    required this.onFrissult,
    this.csakSorozatok = false,
  });

  final String exerciseId;
  final String exerciseName;
  final VoidCallback onFrissult;
  final bool csakSorozatok;

  @override
  State<InlineGyakorlatPanel> createState() => _InlineGyakorlatPanelState();
}

class _InlineGyakorlatPanelState extends State<InlineGyakorlatPanel> {
  final _workoutService = WorkoutService.instance;
  final _exerciseService = ExerciseService.instance;

  LoggedExerciseModel? _gyakorlat;
  ExerciseModel? _meta;
  bool _betolt = true;

  @override
  void initState() {
    super.initState();
    _betoltes();
  }

  Future<void> _betoltes() async {
    setState(() => _betolt = true);
    try {
      final metaFuture = _exerciseService.gyakorlatLekerdezese(widget.exerciseId);
      var gyakorlat = await _workoutService.gyakorlatLekerdezese(widget.exerciseId);
      if (gyakorlat.sets.isEmpty) {
        gyakorlat = await _workoutService.sorozatokFrissitese(
          widget.exerciseId,
          WorkoutSessionModel.alapSorozatok(),
        );
      }
      final meta = await metaFuture;
      if (!mounted) return;
      setState(() {
        _gyakorlat = gyakorlat;
        _meta = meta;
        _betolt = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _betolt = false);
    }
  }

  Future<void> _frissit() async {
    final gyakorlat = await _workoutService.gyakorlatLekerdezese(widget.exerciseId);
    if (!mounted) return;
    setState(() => _gyakorlat = gyakorlat);
    widget.onFrissult();
  }

  @override
  Widget build(BuildContext context) {
    if (_betolt) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }

    final gyakorlat = _gyakorlat;
    if (gyakorlat == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_meta != null && !widget.csakSorozatok) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: ExerciseMediaPreview(images: _meta!.images, compact: true),
          ),
          ExerciseInfoSor(meta: _meta!),
        ],
        const SorozatFejlec(),
        ...gyakorlat.sets.map((s) => SorozatSor(
              key: ValueKey('${s.setNumber}-${s.elvegezve}'),
              sorozat: s,
              onMent: (suly, ism) => _workoutService.sorozatModositasa(
                widget.exerciseId,
                s.setNumber,
                weight: suly,
                reps: ism,
              ),
              onPipa: (suly, ism) async {
                if (s.elvegezve) {
                  await _workoutService.sorozatPipaVisszavonasa(widget.exerciseId, s.setNumber);
                } else {
                  await _workoutService.sorozatPipalasa(
                    widget.exerciseId,
                    s.setNumber,
                    weight: suly,
                    reps: ism,
                  );
                }
                await _frissit();
              },
              onTorles: () async {
                await _workoutService.sorozatTorlese(widget.exerciseId, s.setNumber);
                await _frissit();
              },
            )),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
          child: OutlinedButton.icon(
            onPressed: () async {
              await _workoutService.sorozatHozzaadasa(widget.exerciseId);
              await _frissit();
            },
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Sorozat hozzáadása', style: TextStyle(fontSize: 13)),
          ),
        ),
      ],
    );
  }
}
