import 'package:flutter/material.dart';

import '../../models/nutrition_models.dart';
import '../../services/nutrition_service.dart';
import '../../services/recept_service.dart';

/// Recept részletei + hozzáadás a naplóhoz.
class RecipeDetailScreen extends StatefulWidget {
  const RecipeDetailScreen({
    super.key,
    required this.receptId,
    required this.etkezesTipus,
  });

  final String receptId;
  final String etkezesTipus;

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  final _receptService = ReceptService.instance;
  final _nutritionService = NutritionService.instance;

  ReceptReszletesModel? _recept;
  bool _betolt = true;
  String? _hiba;
  double _adag = 1;
  bool _mentes = false;

  @override
  void initState() {
    super.initState();
    _betoltes();
  }

  Future<void> _betoltes() async {
    try {
      final r = await _receptService.reszletek(widget.receptId);
      if (!mounted) return;
      setState(() {
        _recept = r;
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

  Future<void> _naplohozAdas() async {
    setState(() => _mentes = true);
    try {
      await _nutritionService.receptHozzaadasa(
        receptId: widget.receptId,
        etkezesTipus: widget.etkezesTipus,
        adagSzam: _adag,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red.shade700),
      );
      setState(() => _mentes = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_betolt) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_hiba != null || _recept == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(_hiba ?? 'Nincs recept')),
      );
    }

    final r = _recept!;
    final kcal = (r.becsultKaloria * _adag).round();

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: Colors.white,
            foregroundColor: Colors.black87,
            flexibleSpace: FlexibleSpaceBar(
              background: r.kepUrl.isNotEmpty
                  ? Image.network(r.kepUrl, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => ColoredBox(color: Colors.grey.shade300))
                  : ColoredBox(color: Colors.grey.shade300, child: const Icon(Icons.restaurant, size: 64)),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.nev, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text(
                    '${r.kategoria} · ${r.szarmazasiTerulet} · ~${r.becsultKaloria} kcal/adag',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                  if (r.yazioCimkek.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: r.yazioCimkek
                          .map((c) => Chip(label: Text(c, style: const TextStyle(fontSize: 11)), visualDensity: VisualDensity.compact))
                          .toList(),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _makro('Fehérje', '${(r.becsultFeherje * _adag).round()} g'),
                      _makro('Szénh.', '${(r.becsultSzenhidrat * _adag).round()} g'),
                      _makro('Zsír', '${(r.becsultZsir * _adag).round()} g'),
                      _makro('Kcal', '$kcal'),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text('Adag: ${_adag == _adag.roundToDouble() ? _adag.round() : _adag}', style: const TextStyle(fontWeight: FontWeight.w600)),
                  Slider(
                    value: _adag,
                    min: 0.5,
                    max: 3,
                    divisions: 5,
                    label: '$_adag',
                    activeColor: const Color(0xFF34C759),
                    onChanged: (v) => setState(() => _adag = v),
                  ),
                  const SizedBox(height: 8),
                  Text('Hozzávalók', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.grey.shade800)),
                  const SizedBox(height: 8),
                  ...r.osszetevok.map(
                    (o) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('• ${o.mennyiseg} ${o.nev}', style: const TextStyle(fontSize: 13, height: 1.35)),
                    ),
                  ),
                  if (r.leiras.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text('Elkészítés', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.grey.shade800)),
                    const SizedBox(height: 8),
                    Text(r.leiras, style: const TextStyle(fontSize: 13, height: 1.45)),
                  ],
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(
            onPressed: _mentes ? null : _naplohozAdas,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF34C759),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: _mentes
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text('Hozzáadás: ${EtkezesTipus.cimke(widget.etkezesTipus)} ($kcal kcal)'),
          ),
        ),
      ),
    );
  }

  Widget _makro(String cimke, String ertek) {
    return Expanded(
      child: Column(
        children: [
          Text(ertek, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          Text(cimke, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}
