import 'package:flutter/material.dart';

import 'calorie_ring.dart';
import '../models/nutrition_models.dart';

/// Yazio-stílusú összefoglaló kártya.
class NutritionDiarySummaryCard extends StatelessWidget {
  const NutritionDiarySummaryCard({
    super.key,
    required this.consumed,
    required this.burned,
    required this.goal,
    required this.remaining,
    required this.carbs,
    required this.carbsGoal,
    required this.protein,
    required this.proteinGoal,
    required this.fat,
    required this.fatGoal,
    this.onReszletek,
  });

  final int consumed;
  final int burned;
  final int goal;
  final int remaining;
  final int carbs;
  final int carbsGoal;
  final int protein;
  final int proteinGoal;
  final int fat;
  final int fatGoal;
  final VoidCallback? onReszletek;

  static const _green = Color(0xFF34C759);

  @override
  Widget build(BuildContext context) {
    final progress = goal > 0 ? consumed / goal : 0.0;
    final ringSize = MediaQuery.sizeOf(context).width > 400 ? 140.0 : 120.0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Összefoglaló', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              const Spacer(),
              if (onReszletek != null)
                GestureDetector(
                  onTap: onReszletek,
                  child: const Text('Részletek', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _green)),
                ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 340) {
                return Column(
                  children: [
                    CalorieRing(remaining: remaining, progress: progress, size: ringSize, color: _green),
                    const SizedBox(height: 16),
                    _oldalStat(consumed, burned),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: _oldalStatOszlop('$consumed', 'Elfogyasztott')),
                  CalorieRing(remaining: remaining, progress: progress, size: ringSize, color: _green),
                  Expanded(child: _oldalStatOszlop('$burned', 'Elégetett')),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          MacroBar(label: 'Szénhidrátok', current: carbs, goal: carbsGoal, progress: carbsGoal > 0 ? carbs / carbsGoal : 0, color: _green),
          const SizedBox(height: 10),
          MacroBar(label: 'Fehérje', current: protein, goal: proteinGoal, progress: proteinGoal > 0 ? protein / proteinGoal : 0, color: _green),
          const SizedBox(height: 10),
          MacroBar(label: 'Zsír', current: fat, goal: fatGoal, progress: fatGoal > 0 ? fat / fatGoal : 0, color: _green),
        ],
      ),
    );
  }

  Widget _oldalStat(int consumed, int burned) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _oldalStatOszlop('$consumed', 'Elfogyasztott'),
        _oldalStatOszlop('$burned', 'Elégetett'),
      ],
    );
  }

  Widget _oldalStatOszlop(String value, String label) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
      ],
    );
  }
}

class NutritionMealsCard extends StatelessWidget {
  const NutritionMealsCard({
    super.key,
    required this.naplo,
    required this.celKcal,
    required this.onMealTap,
    required this.onMealAdd,
  });

  final DailyNutritionModel naplo;
  final int celKcal;
  final void Function(String etkezesTipus) onMealTap;
  final void Function(String etkezesTipus) onMealAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: EtkezesTipus.osszes.asMap().entries.map((e) {
          final tipus = e.value;
          final utolso = e.key == EtkezesTipus.osszes.length - 1;
          final aktualis = naplo.kcalEtkezeshez(tipus);
          final cel = (celKcal * EtkezesTipus.celArany(tipus)).round();

          return Column(
            children: [
              InkWell(
                onTap: () => onMealTap(tipus),
                borderRadius: utolso
                    ? const BorderRadius.vertical(bottom: Radius.circular(16))
                    : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Icon(EtkezesTipus.ikon(tipus), size: 22, color: Colors.grey.shade700),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(EtkezesTipus.cimke(tipus), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                                Icon(Icons.chevron_right, size: 18, color: Colors.grey.shade500),
                              ],
                            ),
                            Text('$aktualis / $cel kcal', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => onMealAdd(tipus),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: const BoxDecoration(color: Colors.black87, shape: BoxShape.circle),
                          child: const Icon(Icons.add, color: Colors.white, size: 20),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (!utolso) Divider(height: 1, indent: 50, color: Colors.grey.shade200),
            ],
          );
        }).toList(),
      ),
    );
  }
}

/// Makró fejléc — mint a sorozat táblázat (KG / ISM) az edzésnél.
class MakroFejlec extends StatelessWidget {
  const MakroFejlec({super.key, this.cim = '100 g-ra'});

  final String cim;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
      child: Row(
        children: [
          if (cim.isNotEmpty)
            Expanded(
              flex: 2,
              child: Text(cim, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
            ),
          Expanded(child: _fejlecCell('Kcal')),
          Expanded(child: _fejlecCell('Fehérje')),
          Expanded(child: _fejlecCell('Szénh.')),
          Expanded(child: _fejlecCell('Zsír')),
        ],
      ),
    );
  }

  Widget _fejlecCell(String text) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 10),
    );
  }
}

/// Egy sor makró értékek — kcal + fehérje + szénhidrát + zsír.
class MakroErtekSor extends StatelessWidget {
  const MakroErtekSor({
    super.key,
    required this.kcal,
    required this.feherje,
    required this.szenhidrat,
    required this.zsir,
    this.kiemelt = false,
    this.balOszlop = true,
  });

  final double kcal;
  final double feherje;
  final double szenhidrat;
  final double zsir;
  final bool kiemelt;
  final bool balOszlop;

  String _fmt(double v) => v % 1 == 0 ? '${v.round()}' : v.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      decoration: BoxDecoration(
        color: kiemelt ? const Color(0xFF34C759).withValues(alpha: 0.08) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kiemelt ? const Color(0xFF34C759).withValues(alpha: 0.25) : Colors.grey.shade200),
      ),
      child: Row(
        children: [
          if (balOszlop) const Expanded(flex: 2, child: SizedBox.shrink()),
          Expanded(child: _cell(_fmt(kcal))),
          Expanded(child: _cell('${_fmt(feherje)} g')),
          Expanded(child: _cell('${_fmt(szenhidrat)} g')),
          Expanded(child: _cell('${_fmt(zsir)} g')),
        ],
      ),
    );
  }

  Widget _cell(String text) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 13,
        fontWeight: kiemelt ? FontWeight.w800 : FontWeight.w600,
        color: Colors.black87,
      ),
    );
  }
}

/// Teljes makró panel — 100 g + opcionális összesítés adott grammra.
class MakroBontasPanel extends StatelessWidget {
  const MakroBontasPanel({
    super.key,
    required this.per100Kcal,
    required this.per100Feherje,
    required this.per100Szenhidrat,
    required this.per100Zsir,
    this.osszGramm,
  });

  final double per100Kcal;
  final double per100Feherje;
  final double per100Szenhidrat;
  final double per100Zsir;
  final double? osszGramm;

  double _arany(double per100) {
    if (osszGramm == null || osszGramm! <= 0) return per100;
    return (per100 * osszGramm!) / 100;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const MakroFejlec(cim: '100 g-ra'),
        MakroErtekSor(
          kcal: per100Kcal,
          feherje: per100Feherje,
          szenhidrat: per100Szenhidrat,
          zsir: per100Zsir,
        ),
        if (osszGramm != null && osszGramm! > 0) ...[
          const SizedBox(height: 8),
          MakroFejlec(cim: 'Összesen (${osszGramm!.round()} g)'),
          MakroErtekSor(
            kcal: _arany(per100Kcal),
            feherje: _arany(per100Feherje),
            szenhidrat: _arany(per100Szenhidrat),
            zsir: _arany(per100Zsir),
            kiemelt: true,
          ),
        ],
      ],
    );
  }
}
