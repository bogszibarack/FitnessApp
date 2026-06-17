import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/daily_health_data.dart';
import '../../models/nutrition_models.dart';
import '../../services/apple_health_service.dart';
import '../../services/home_service.dart';
import '../../utils/platform_utils.dart';
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
  final _healthService = AppleHealthService.instance;
  DailyHealthData _data = DailyHealthData.empty();
  DailyNutritionModel? _naplo;
  bool _loading = true;
  bool _permissionNeeded = false;
  String? _error;
  String _dataSource = '';

  @override
  void initState() {
    super.initState();
    _loadData();
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
        _permissionNeeded = result.permissionNeeded;
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

  Future<void> _connectAppleHealth() async {
    final granted = await _healthService.requestPermissions();
    if (!mounted) return;
    if (granted) {
      await _loadData();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Apple Health hozzáférés megtagadva.')),
      );
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
    if (friss == true) await _loadData();
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
                      if (_permissionNeeded) ...[
                        const SizedBox(height: 16),
                        _buildHealthPermissionCard(),
                      ],
                      if (!_loading && !isAppleHealthPlatform) ...[
                        const SizedBox(height: 12),
                        _buildPlatformInfoCard(),
                      ],
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

  Widget _buildHealthPermissionCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _accentGreen.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _accentGreen.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Apple Health', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 8),
          const Text('Engedélyezd a lépések és elégetett kalória megjelenítéséhez.', style: TextStyle(fontSize: 13, height: 1.4)),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _connectAppleHealth,
            style: FilledButton.styleFrom(backgroundColor: _accentGreen),
            child: const Text('Engedély megadása'),
          ),
        ],
      ),
    );
  }

  Widget _buildPlatformInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Text(
        'A táplálkozás a backendről jön. Mozgás: ${isAppleHealthPlatform ? "Apple Health" : "demo (0)"}.',
        style: TextStyle(fontSize: 12, color: Colors.grey.shade700, height: 1.4),
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
        _buildStatChip(Icons.diamond_outlined, '20', Colors.blue.shade400),
        const SizedBox(width: 12),
        _buildStatChip(Icons.local_fire_department_outlined, '${_data.caloriesBurned}', Colors.grey.shade600),
        const Spacer(),
        IconButton(onPressed: _loadData, icon: const Icon(Icons.refresh), color: Colors.black87),
        IconButton(onPressed: () {}, icon: const Icon(Icons.calendar_today_outlined), color: Colors.black87),
      ],
    );
  }

  Widget _buildStatChip(IconData icon, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
      ],
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
