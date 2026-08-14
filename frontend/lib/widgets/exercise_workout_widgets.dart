import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/exercise_model.dart';
import '../models/workout_models.dart';
import '../services/exercise_service.dart';
import '../services/sound_service.dart';
import '../services/workout_service.dart';
import '../theme/app_theme.dart';
import 'modern_button.dart';
import 'pr_popup.dart';

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
          color: AppColors.halvanyKitoltes,
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
  const SorozatFejlec({super.key, this.trackRpe = false});

  final bool trackRpe;

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
          if (trackRpe)
            const SizedBox(width: 36, child: Text('RPE', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11), textAlign: TextAlign.center)),
          const SizedBox(width: 44),
        ],
      ),
    );
  }
}

/// RPE választó (1–10) — alsó lap vagy sor gomb.
Future<int?> rpeValasztoMutat(BuildContext context, {int? jelenlegi}) {
  return showModalBottomSheet<int>(
    context: context,
    backgroundColor: AppColors.felulet,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'RPE — erőfeszítés',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.szoveg),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                '1 = nagyon könnyű · 10 = maximális',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: List.generate(10, (i) {
                  final ertek = i + 1;
                  final kivalasztott = jelenlegi == ertek;
                  return InkWell(
                    onTap: () {
                      Haptics.selection();
                      Navigator.pop(ctx, ertek);
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 52,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: kivalasztott
                            ? const Color(0xFF8E24AA).withValues(alpha: 0.15)
                            : AppColors.halvanyKitoltes,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: kivalasztott ? const Color(0xFF8E24AA) : AppColors.szegely,
                          width: kivalasztott ? 1.5 : 1,
                        ),
                      ),
                      child: Text(
                        '$ertek',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: kivalasztott ? const Color(0xFF8E24AA) : AppColors.szoveg,
                        ),
                      ),
                    ),
                  );
                }),
              ),
              if (jelenlegi != null && jelenlegi > 0) ...[
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, 0),
                  child: const Text('RPE törlése'),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}

/// Pihenő időzítő sáv — alsó overlay a képernyőn.
class PihenoIdozitoBanner extends StatelessWidget {
  const PihenoIdozitoBanner({
    super.key,
    required this.hatralevoMp,
    required this.osszesMp,
    required this.onKihagyas,
  });

  final int hatralevoMp;
  final int osszesMp;
  final VoidCallback onKihagyas;

  String get _idoSzoveg {
    final perc = hatralevoMp ~/ 60;
    final mp = hatralevoMp % 60;
    return '${perc.toString().padLeft(2, '0')}:${mp.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final progress = osszesMp > 0 ? hatralevoMp / osszesMp : 0.0;

    return Material(
      elevation: 8,
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.felulet,
          border: Border(top: BorderSide(color: AppColors.szegely)),
          boxShadow: [
            BoxShadow(
              color: AppColors.arnyek,
              blurRadius: 12,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF00897B).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.timer_rounded, color: Color(0xFF00897B), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Pihenő',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                    ),
                    Text(
                      _idoSzoveg,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF00897B)),
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress.clamp(0.0, 1.0),
                        minHeight: 4,
                        backgroundColor: AppColors.halvanyKitoltes,
                        color: const Color(0xFF00897B),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () {
                  Haptics.light();
                  onKihagyas();
                },
                child: const Text('Kihagyás'),
              ),
            ],
          ),
        ),
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
    this.trackRpe = false,
    this.onRpeMent,
    this.onSorozatKesz,
  });

  final LoggedSetModel sorozat;
  final Future<void> Function(double suly, int ismetles, {int? rpe}) onPipa;
  final Future<void> Function(double suly, int ismetles, {int? rpe}) onMent;
  final VoidCallback? onTorles;
  final bool trackRpe;
  final Future<void> Function(int rpe)? onRpeMent;
  /// Meghívódik, ha a sorozat most lett készre pipálva (nem visszavonás).
  final VoidCallback? onSorozatKesz;

  @override
  State<SorozatSor> createState() => _SorozatSorState();
}

class _SorozatSorState extends State<SorozatSor> {
  late final TextEditingController _sulyController;
  late final TextEditingController _ismController;
  bool _mentes = false;
  Timer? _debounce;

  void _billentyuzetElrejtese() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  @override
  void initState() {
    super.initState();
    // Ha a jelenlegi súly 0, de van előző adat, azt mutatjuk előre kitöltve
    final megjelenitesSuly = widget.sorozat.weight > 0
        ? widget.sorozat.weight
        : widget.sorozat.prevWeightKg;
    _sulyController = TextEditingController(text: _sulySzoveg(megjelenitesSuly));
    _ismController = TextEditingController(text: widget.sorozat.reps > 0 ? '${widget.sorozat.reps}' : '');
    _sulyController.addListener(_autoMentes);
    _ismController.addListener(_autoMentes);
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
    if (oldWidget.sorozat.isDone != widget.sorozat.isDone) {
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
      await widget.onMent(_sulyErtek(), _ismErtek(), rpe: widget.sorozat.rpe > 0 ? widget.sorozat.rpe : null);
    } finally {
      _mentes = false;
    }
  }

  Future<void> _rpeValasztas() async {
    if (!widget.trackRpe || widget.onRpeMent == null) return;
    _billentyuzetElrejtese();
    await _mentesHaKell();
    if (!mounted) return;
    final valasztott = await rpeValasztoMutat(context, jelenlegi: widget.sorozat.rpe > 0 ? widget.sorozat.rpe : null);
    if (valasztott == null) return;
    await widget.onRpeMent!(valasztott);
  }

  Future<void> _pipaNyomas() async {
    _billentyuzetElrejtese();
    final suly = _sulyErtek();
    final prDetek = _prErzekeles(suly);
    final keszrePipal = !widget.sorozat.isDone;
    Haptics.light();
    await _mentesHaKell();
    await widget.onPipa(
      suly,
      _ismErtek(),
      rpe: widget.sorozat.rpe > 0 ? widget.sorozat.rpe : null,
    );
    if (prDetek) await _prCelebracio(suly);
    if (keszrePipal) {
      widget.onSorozatKesz?.call();
      if (widget.trackRpe && widget.sorozat.rpe <= 0 && widget.onRpeMent != null && mounted) {
        final rpe = await rpeValasztoMutat(context);
        if (rpe != null && rpe > 0) await widget.onRpeMent!(rpe);
      }
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _sulyController.dispose();
    _ismController.dispose();
    super.dispose();
  }

  bool _prErzekeles(double suly) {
    final elozo = widget.sorozat.prevWeightKg;
    return !widget.sorozat.isDone && suly > 0 && elozo > 0 && suly > elozo;
  }

  Future<void> _prCelebracio(double suly) async {
    Haptics.heavy();
    if (mounted) PrPopup.mutat(context, suly: suly);
    await SoundService.instance.prHangJatszas();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.sorozat;
    final kesz = s.isDone;
    final hatter = kesz
        ? (AppColors.dark ? const Color(0xFF15351F) : Colors.green.shade50)
        : AppColors.kartya;

    Widget sor = Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: hatter,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: kesz
                ? (AppColors.dark ? const Color(0xFF2E6B3F) : Colors.green.shade200)
                : AppColors.szegely),
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
                  color: s.isWarmup ? Colors.orange.shade700 : AppColors.szoveg,
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
                textInputAction: TextInputAction.next,
                textAlign: TextAlign.center,
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))],
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                decoration: const InputDecoration(
                  hintText: 'kg',
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  border: InputBorder.none,
                ),
                onTapOutside: (_) {
                  _billentyuzetElrejtese();
                  _mentesHaKell();
                },
                onSubmitted: (_) => _mentesHaKell(),
              ),
            ),
            Expanded(
              child: TextField(
                controller: _ismController,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                textAlign: TextAlign.center,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: s.targetReps.isNotEmpty ? s.targetReps : 'ism',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  border: InputBorder.none,
                ),
                onTapOutside: (_) {
                  _billentyuzetElrejtese();
                  _mentesHaKell();
                },
                onEditingComplete: () {
                  _billentyuzetElrejtese();
                  _mentesHaKell();
                },
                onSubmitted: (_) {
                  _billentyuzetElrejtese();
                  _mentesHaKell();
                },
              ),
            ),
            if (widget.trackRpe)
              SizedBox(
                width: 36,
                child: InkWell(
                  onTap: _rpeValasztas,
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      s.rpe > 0 ? '${s.rpe}' : '–',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: s.rpe > 0 ? const Color(0xFF8E24AA) : Colors.grey.shade500,
                      ),
                    ),
                  ),
                ),
              ),
            SizedBox(
              width: 44,
              child: IconButton(
                padding: EdgeInsets.zero,
                onPressed: _pipaNyomas,
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

    if (widget.onTorles == null) return sor;

    return Dismissible(
      key: ValueKey('dismiss-${s.setNumber}-${s.isWarmup}'),
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
      child: sor,
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
      targetReps: '10-12',
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
          child: ModernButton(
            cimke: 'Sorozat hozzáadása',
            ikon: Icons.add,
            kicsi: true,
            kitoltott: false,
            teljesSzelesseg: true,
            onTap: _ujSorozat,
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

  void _billentyuzetElrejtese() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

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
        color: AppColors.kartya,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.szegely),
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
                  color: s.isWarmup ? Colors.orange.shade700 : AppColors.szoveg,
                ),
              ),
            ),
            const Expanded(flex: 2, child: Text('-', style: TextStyle(fontSize: 11, color: Colors.grey))),
            Expanded(
              child: TextField(
                controller: _sulyController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.next,
                textAlign: TextAlign.center,
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))],
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                decoration: const InputDecoration(
                  hintText: 'kg',
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  border: InputBorder.none,
                ),
                onTapOutside: (_) => _billentyuzetElrejtese(),
                onChanged: (v) => widget.onSuly(double.tryParse(v.replaceAll(',', '.')) ?? 0),
              ),
            ),
            Expanded(
              child: TextField(
                controller: _ismController,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                textAlign: TextAlign.center,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: s.targetReps.isNotEmpty ? s.targetReps : 'ism',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  border: InputBorder.none,
                ),
                onTapOutside: (_) => _billentyuzetElrejtese(),
                onEditingComplete: _billentyuzetElrejtese,
                onSubmitted: (_) => _billentyuzetElrejtese(),
                onChanged: (v) => widget.onIsmetles(int.tryParse(v) ?? 0),
              ),
            ),
            SizedBox(
              width: 36,
              child: widget.onTorles != null
                  ? IconButton(
                      padding: EdgeInsets.zero,
                      icon: Icon(Icons.close, size: 20, color: Colors.grey.shade500),
                      onPressed: () {
                        _billentyuzetElrejtese();
                        widget.onTorles!();
                      },
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
    this.trackRpe = false,
    this.onSorozatKesz,
  });

  final String exerciseId;
  final String exerciseName;
  final VoidCallback onFrissult;
  final bool csakSorozatok;
  final bool trackRpe;
  final VoidCallback? onSorozatKesz;

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
      var gyakorlat = await _workoutService.getExercise(widget.exerciseId);
      if (gyakorlat.sets.isEmpty) {
        gyakorlat = await _workoutService.updateSets(
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
    final gyakorlat = await _workoutService.getExercise(widget.exerciseId);
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
        SorozatFejlec(trackRpe: widget.trackRpe),
        ...gyakorlat.sets.map((s) => SorozatSor(
              key: ValueKey('${s.setNumber}-${s.isDone}'),
              sorozat: s,
              trackRpe: widget.trackRpe,
              onMent: (suly, ism, {rpe}) async {
                await _workoutService.updateSet(
                  widget.exerciseId,
                  s.setNumber,
                  weight: suly,
                  reps: ism,
                  rpe: rpe,
                );
              },
              onRpeMent: (rpe) async {
                await _workoutService.updateSet(
                  widget.exerciseId,
                  s.setNumber,
                  weight: s.weight,
                  reps: s.reps,
                  rpe: rpe,
                );
                await _frissit();
              },
              onPipa: (suly, ism, {rpe}) async {
                if (s.isDone) {
                  await _workoutService.uncompleteSet(widget.exerciseId, s.setNumber);
                } else {
                  await _workoutService.completeSet(
                    widget.exerciseId,
                    s.setNumber,
                    weight: suly,
                    reps: ism,
                    rpe: rpe,
                  );
                }
                await _frissit();
              },
              onSorozatKesz: widget.onSorozatKesz,
              onTorles: () async {
                await _workoutService.deleteSet(widget.exerciseId, s.setNumber);
                await _frissit();
              },
            )),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
          child: ModernButton(
            cimke: 'Sorozat hozzáadása',
            ikon: Icons.add,
            kicsi: true,
            kitoltott: false,
            teljesSzelesseg: true,
            onTap: () async {
              await _workoutService.addSet(widget.exerciseId);
              await _frissit();
            },
          ),
        ),
      ],
    );
  }
}
