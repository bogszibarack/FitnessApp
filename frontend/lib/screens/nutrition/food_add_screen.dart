import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/nutrition_models.dart';
import '../../services/nutrition_service.dart';
import '../../widgets/nutrition_diary_widgets.dart';
import 'recipes_screen.dart';

/// Étel keresés és hozzáadás étkezéshez (Open Food Facts API).
class FoodAddScreen extends StatefulWidget {
  const FoodAddScreen({super.key, required this.etkezesTipus});

  final String etkezesTipus;

  @override
  State<FoodAddScreen> createState() => _FoodAddScreenState();
}

class _FoodAddScreenState extends State<FoodAddScreen> {
  final _service = NutritionService.instance;
  final _keresoController = TextEditingController();

  List<FoodItemModel> _talalatok = [];
  bool _betolt = false;
  String? _hiba;
  String? _kivalasztottId;
  double _gramm = 100;
  bool _mentes = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _kereses('alma');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _keresoController.dispose();
    super.dispose();
  }

  void _onKereses(String szoveg) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _kereses(szoveg));
  }

  Future<void> _kereses(String szoveg) async {
    if (szoveg.trim().isEmpty) return;
    setState(() {
      _betolt = true;
      _hiba = null;
    });
    try {
      final lista = await _service.kereses(szoveg);
      if (!mounted) return;
      setState(() {
        _talalatok = lista;
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

  Future<void> _hozzaadas(FoodItemModel etel) async {
    setState(() => _mentes = true);
    try {
      final bejegyzes = _service.etelbolNaploBejegyzes(
        etel: etel,
        etkezesTipus: widget.etkezesTipus,
        gramm: _gramm,
      );
      await _service.etelHozzaadasa(bejegyzes);
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

  Future<void> _receptek() async {
    final friss = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => RecipesScreen(etkezesTipus: widget.etkezesTipus),
      ),
    );
    if (friss == true && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('${EtkezesTipus.cimke(widget.etkezesTipus)} — étel', style: const TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        actions: [
          TextButton.icon(
            onPressed: _receptek,
            icon: const Icon(Icons.menu_book_outlined, size: 18),
            label: const Text('Receptek'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _keresoController,
              decoration: InputDecoration(
                hintText: 'Keresés: alma, csirke, joghurt...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                isDense: true,
              ),
              onChanged: _onKereses,
              onSubmitted: _kereses,
            ),
          ),
          Expanded(child: _lista()),
        ],
      ),
    );
  }

  Widget _lista() {
    if (_betolt) return const Center(child: CircularProgressIndicator());
    if (_hiba != null) {
      return Center(child: Padding(padding: const EdgeInsets.all(20), child: Text(_hiba!, textAlign: TextAlign.center)));
    }
    if (_talalatok.isEmpty) return const Center(child: Text('Írj be egy ételt a kereséshez'));

    return ListView.separated(
      itemCount: _talalatok.length,
      separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade200),
      itemBuilder: (context, index) {
        final etel = _talalatok[index];
        final kinyitott = _kivalasztottId == etel.id;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: () => setState(() {
                _kivalasztottId = kinyitott ? null : etel.id;
                _gramm = 100;
              }),
              child: Padding(
                padding: EdgeInsets.fromLTRB(12, 12, 12, kinyitott ? 4 : 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (etel.imageUrl.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          etel.imageUrl,
                          width: 52,
                          height: 52,
                          fit: BoxFit.cover,
                          errorBuilder: (_, e, st) => _kepPlaceholder(),
                        ),
                      )
                    else
                      _kepPlaceholder(),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(etel.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          Text('100 g-ra', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                          const SizedBox(height: 4),
                          const MakroFejlec(cim: ''),
                          MakroErtekSor(
                            kcal: etel.calories,
                            feherje: etel.protein,
                            szenhidrat: etel.carbs,
                            zsir: etel.fat,
                            balOszlop: false,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      kinyitott ? Icons.expand_less : Icons.add_circle_outline,
                      color: const Color(0xFF34C759),
                      size: 28,
                    ),
                  ],
                ),
              ),
            ),
            if (kinyitott)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Mennyiség', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey.shade700)),
                      Row(
                        children: [
                          Expanded(
                            child: Slider(
                              value: _gramm,
                              min: 10,
                              max: 500,
                              divisions: 49,
                              label: '${_gramm.round()} g',
                              activeColor: const Color(0xFF34C759),
                              onChanged: (v) => setState(() => _gramm = v),
                            ),
                          ),
                          SizedBox(
                            width: 56,
                            child: Text(
                              '${_gramm.round()} g',
                              textAlign: TextAlign.right,
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      MakroBontasPanel(
                        per100Kcal: etel.calories,
                        per100Feherje: etel.protein,
                        per100Szenhidrat: etel.carbs,
                        per100Zsir: etel.fat,
                        osszGramm: _gramm,
                      ),
                      const SizedBox(height: 14),
                      FilledButton(
                        onPressed: _mentes ? null : () => _hozzaadas(etel),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF34C759),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: _mentes
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Hozzáadás a naplóhoz', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _kepPlaceholder() {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
      child: Icon(Icons.fastfood, color: Colors.grey.shade400),
    );
  }
}
