import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/daily_health_data.dart';
import '../../models/nutrition_models.dart';
import '../../services/home_service.dart';
import '../../services/streak_service.dart';
import '../../widgets/health_data_panel.dart';
import '../../widgets/nutrition_diary_widgets.dart';
import 'food_add_screen.dart';
import 'meal_detail_screen.dart';
import 'recipes_screen.dart';

/// Külön Napló oldal — táplálkozás, étkezések, receptek (Yazio-stílus).
class NaploScreen extends StatefulWidget {
  const NaploScreen({super.key});

  @override
  State<NaploScreen> createState() => _NaploScreenState();
}

class _NaploScreenState extends State<NaploScreen> {
  static const _accentGreen = Color(0xFF34C759);

  final _homeService = HomeService.instance;
  final _streakService = StreakService.instance;
  DailyHealthData _data = DailyHealthData.empty();
  DailyNutritionModel? _naplo;
  bool _loading = true;
  String? _error;
  String _dataSource = '';
  int _streak = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadStreak();
  }

  Future<void> _loadStreak() async {
    final s = await _streakService.getStreak();
    if (mounted) setState(() => _streak = s);
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await _homeService.loadToday();
      if (!mounted) return;
      setState(() {
        _data = result.data;
        _naplo = result.naplo;
        _dataSource = result.source;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _data = DailyHealthData.empty();
        _naplo = null;
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _etkezesMegnyitasa(String tipus) async {
    if (_naplo == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MealDetailScreen(
          etkezesTipus: tipus,
          naplo: _naplo!,
          celKcal: (_data.calorieGoal * EtkezesTipus.celArany(tipus)).round(),
        ),
      ),
    );
    await _loadData();
  }

  Future<void> _etelHozzaadasa(String tipus) async {
    final friss = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => FoodAddScreen(etkezesTipus: tipus)),
    );
    if (friss == true) {
      final ujStreak = await _streakService.onFoodLogged();
      if (mounted) setState(() => _streak = ujStreak);
      await _loadData();
    }
  }

  Future<void> _receptek() async {
    final friss = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => RecipesScreen(etkezesTipus: EtkezesTipus.ebed)),
    );
    if (friss == true) await _loadData();
  }

  String _napRovid() {
    const napok = ['H', 'K', 'Sze', 'Cs', 'P', 'Szo', 'V'];
    return napok[DateTime.now().weekday - 1];
  }

  String _formatNumber(int value) => NumberFormat('#,###', 'hu').format(value).replaceAll(',', ' ');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          color: _accentGreen,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTopBar(),
                      const SizedBox(height: 16),
                      Text(
                        _napRovid(),
                        style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: Colors.black87),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        _buildErrorBanner(),
                      ],
                      const SizedBox(height: 20),
                      if (_loading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 48),
                          child: Center(child: CircularProgressIndicator(color: _accentGreen)),
                        )
                      else if (_naplo != null) ...[
                        _buildSectionHeader('Összefoglaló', 'Részletek', onTap: () => _etkezesMegnyitasa(EtkezesTipus.ebed)),
                        const SizedBox(height: 10),
                        NutritionDiarySummaryCard(
                          consumed: _data.caloriesConsumed,
                          burned: _data.caloriesBurned,
                          goal: _data.calorieGoal,
                          remaining: _data.caloriesRemaining,
                          carbs: _data.carbsGrams,
                          carbsGoal: _data.carbsGoalGrams,
                          protein: _data.proteinGrams,
                          proteinGoal: _data.proteinGoalGrams,
                          fat: _data.fatGrams,
                          fatGoal: _data.fatGoalGrams,
                        ),
                        const SizedBox(height: 24),
                        _buildSectionHeader('Táplálkozás', 'Receptek', onTap: _receptek),
                        const SizedBox(height: 10),
                        NutritionMealsCard(
                          naplo: _naplo!,
                          celKcal: _data.calorieGoal,
                          onMealTap: _etkezesMegnyitasa,
                          onMealAdd: _etelHozzaadasa,
                        ),
                        const SizedBox(height: 24),
                        _buildSectionHeader('Tevékenységek', 'Több'),
                        const SizedBox(height: 10),
                        _buildActivityCard(),
                        const SizedBox(height: 16),
                        HealthDataPanel(
                          data: _data,
                          isLiveAppleHealth: _dataSource == 'merged',
                          formatNumber: _formatNumber,
                          formatDistance: (km) => '${km.toStringAsFixed(1).replaceAll('.', ',')} km',
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActivityCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_formatNumber(_data.steps)} lépés',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            '${_data.distanceKm.toStringAsFixed(1).replaceAll('.', ',')} km, ${_data.caloriesBurned} kcal',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: _data.steps > 0 ? (_data.steps / 10000).clamp(0.0, 1.0) : 0,
              minHeight: 8,
              backgroundColor: _accentGreen.withValues(alpha: 0.15),
              color: _accentGreen,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_error!, style: TextStyle(color: Colors.red.shade800, fontSize: 13)),
          const SizedBox(height: 6),
          const Text('Ellenőrizd: dotnet run fut-e a 5150-es porton?', style: TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Row(
      children: [
        _buildStreakChip(),
        const Spacer(),
        IconButton(onPressed: _loadData, icon: const Icon(Icons.refresh), color: Colors.black87),
      ],
    );
  }

  Widget _buildStreakChip() {
    final color = _streak > 0 ? const Color(0xFFFF6D00) : Colors.grey.shade400;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _streak > 0 ? const Color(0xFFFFF3E0) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _streak > 0 ? const Color(0xFFFF9800) : Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _streak > 0 ? Icons.local_fire_department : Icons.local_fire_department_outlined,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            '$_streak nap',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, String action, {VoidCallback? onTap}) {
    return Row(
      children: [
        Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.black87)),
        const Spacer(),
        if (action.isNotEmpty)
          GestureDetector(
            onTap: onTap,
            child: Text(action, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _accentGreen)),
          ),
      ],
    );
  }
}
