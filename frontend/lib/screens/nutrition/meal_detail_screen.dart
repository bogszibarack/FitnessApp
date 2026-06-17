import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/nutrition_models.dart';
import '../../services/nutrition_service.dart';
import '../../widgets/nutrition_diary_widgets.dart';
import 'food_add_screen.dart';

/// Egy étkezés naplója — szerkesztés, törlés.
class MealDetailScreen extends StatefulWidget {
  const MealDetailScreen({
    super.key,
    required this.etkezesTipus,
    required this.naplo,
    required this.celKcal,
  });

  final String etkezesTipus;
  final DailyNutritionModel naplo;
  final int celKcal;

  @override
  State<MealDetailScreen> createState() => _MealDetailScreenState();
}

class _MealDetailScreenState extends State<MealDetailScreen> {
  final _service = NutritionService.instance;
  late DailyNutritionModel _naplo;

  @override
  void initState() {
    super.initState();
    _naplo = widget.naplo;
  }

  List<MapEntry<int, LoggedFoodModel>> get _etelek => _naplo.etelekEtkezeshez(widget.etkezesTipus);

  int get _osszKcal => _naplo.kcalEtkezeshez(widget.etkezesTipus);

  Future<void> _hozzaadas() async {
    final friss = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => FoodAddScreen(etkezesTipus: widget.etkezesTipus)),
    );
    if (friss == true) {
      final uj = await _service.maiNaplo();
      if (!mounted) return;
      setState(() => _naplo = uj);
    }
  }

  Future<void> _torles(int index) async {
    try {
      final uj = await _service.etelTorlese(index);
      if (!mounted) return;
      setState(() => _naplo = uj);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red.shade700),
      );
    }
  }

  Future<void> _szerkesztes(int index, LoggedFoodModel etel) async {
    double ertek = etel.receptbol ? etel.adagSzam : etel.amountGrams;
    final controller = TextEditingController(text: ertek == ertek.roundToDouble() ? '${ertek.round()}' : '$ertek');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(etel.foodName),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))],
          decoration: InputDecoration(
            labelText: etel.receptbol ? 'Adag szám' : 'Gramm',
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Mégse')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Mentés')),
        ],
      ),
    );

    if (ok != true) return;

    final szam = double.tryParse(controller.text.replaceAll(',', '.')) ?? ertek;
    final modositott = etel.receptbol ? etel.copyWith(adagSzam: szam) : etel.copyWith(amountGrams: szam);

    try {
      final uj = await _service.etelModositas(index, modositott);
      if (!mounted) return;
      setState(() => _naplo = uj);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red.shade700),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(EtkezesTipus.cimke(widget.etkezesTipus), style: const TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _hozzaadas,
        backgroundColor: Colors.black87,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Icon(EtkezesTipus.ikon(widget.etkezesTipus), size: 28),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$_osszKcal / ${widget.celKcal} kcal', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                      Text('${EtkezesTipus.cimke(widget.etkezesTipus)} összesen', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_etelek.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Text(
                  'Még nincs étel. Nyomd meg a + gombot.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              )
            else
              ..._etelek.map((e) {
                final etel = e.value;
                final kcal = etel.calculatedCalories.round();
                return Dismissible(
                  key: ValueKey('meal-${e.key}-${etel.foodId}'),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(color: Colors.red.shade400, borderRadius: BorderRadius.circular(12)),
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  confirmDismiss: (_) async {
                    await _torles(e.key);
                    return false;
                  },
                  child: InkWell(
                    onTap: () => _szerkesztes(e.key, etel),
                    borderRadius: BorderRadius.circular(12),
                    child: Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (etel.kepUrl.isNotEmpty)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(etel.kepUrl, width: 44, height: 44, fit: BoxFit.cover,
                                      errorBuilder: (_, e, st) => Icon(Icons.restaurant, color: Colors.grey.shade500)),
                                )
                              else
                                Icon(etel.receptbol ? Icons.menu_book : Icons.fastfood, color: Colors.grey.shade600, size: 40),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(etel.foodName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                                    const SizedBox(height: 2),
                                    Text(
                                      etel.receptbol
                                          ? '${etel.adagSzam == etel.adagSzam.roundToDouble() ? etel.adagSzam.round() : etel.adagSzam} adag'
                                          : '${etel.amountGrams.round()} g',
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                    ),
                                  ],
                                ),
                              ),
                              Text('${kcal} kcal', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          const MakroFejlec(cim: 'Bevitt'),
                          MakroErtekSor(
                            kcal: etel.calculatedCalories,
                            feherje: etel.calculatedProtein,
                            szenhidrat: etel.calculatedCarbs,
                            zsir: etel.calculatedFat,
                            kiemelt: true,
                          ),
                          const SizedBox(height: 4),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text('Koppints a szerkesztéshez', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  ),
                );
              }),
          ],
        ),
    );
  }
}
