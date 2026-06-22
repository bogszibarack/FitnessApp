import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/daily_health_data.dart';
import '../../services/apple_health_service.dart';
import '../../services/home_service.dart';
import '../../services/streak_service.dart';
import '../../widgets/health_data_panel.dart';
import '../../widgets/nutrition_summary_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _accentGreen = Color(0xFF34C759);
  static const _primary = Color(0xFF1E88E5);

  final _homeService = HomeService.instance;
  final _healthService = AppleHealthService.instance;
  DailyHealthData _data = DailyHealthData.empty();
  MealCalories _meals = const MealCalories();
  bool _loading = true;
  bool _permissionNeeded = false;
  String? _error;
  String _dataSource = '';
  int _streak = 0;

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
      final streak = await StreakService.frissitEsKap(result.data.caloriesConsumed > 0);
      if (!mounted) return;
      setState(() {
        _data = result.data;
        _meals = result.meals;
        _permissionNeeded = result.permissionNeeded;
        _dataSource = result.source;
        _streak = streak;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _data = DailyHealthData.empty();
        _meals = const MealCalories();
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

  String _formatNumber(int value) => NumberFormat('#,###', 'hu').format(value).replaceAll(',', ' ');

  String _formatDistance(double km) {
    if (km < 10) return '${km.toStringAsFixed(2).replaceAll('.', ',')} KM';
    return '${km.toStringAsFixed(1).replaceAll('.', ',')} KM';
  }

  int _weekOfYear(DateTime date) {
    final dayOfYear = date.difference(DateTime(date.year, 1, 1)).inDays + 1;
    return ((dayOfYear - date.weekday + 10) / 7).floor();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final weekNumber = _weekOfYear(now);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTopBar(),
                      const SizedBox(height: 20),
                      Text(
                        'Ma',
                        style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: Colors.black87,
                              fontSize: 34,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$weekNumber. hét',
                        style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
                      ),
                      if (_permissionNeeded) ...[
                        const SizedBox(height: 16),
                        _buildHealthPermissionCard(),
                      ],
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        _buildErrorBanner(),
                      ],
                      const SizedBox(height: 24),
                      if (_loading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 48),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else ...[
                        HealthDataPanel(
                          data: _data,
                          isLiveAppleHealth: _dataSource == 'merged' || _dataSource == 'apple_health',
                          formatNumber: _formatNumber,
                          formatDistance: _formatDistance,
                        ),
                        const SizedBox(height: 28),
                        _buildSectionHeader('Táplálkozás', 'Naplóban'),
                        const SizedBox(height: 12),
                        NutritionSummaryCard(
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
                        const SizedBox(height: 12),
                        _buildMealsPreview(),
                        const SizedBox(height: 28),
                        _buildSectionHeader('Felfedezés', ''),
                        const SizedBox(height: 12),
                        _buildFeedPost(),
                        const SizedBox(height: 24),
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

  Widget _buildMealsPreview() {
    final vanAdat = _meals.reggeli > 0 || _meals.ebed > 0 || _meals.vacsora > 0 || _meals.nasi > 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.restaurant_menu, color: Color(0xFF34C759), size: 18),
              const SizedBox(width: 8),
              const Text('Étkezések', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              const Spacer(),
              if (!vanAdat)
                Text('Nincs adat', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _etkezesCsik('Reggeli', _meals.reggeli, const Color(0xFFFF9F43)),
              const SizedBox(width: 8),
              _etkezesCsik('Ebéd', _meals.ebed, const Color(0xFF4A90D9)),
              const SizedBox(width: 8),
              _etkezesCsik('Vacsora', _meals.vacsora, const Color(0xFF34C759)),
              if (_meals.nasi > 0) ...[
                const SizedBox(width: 8),
                _etkezesCsik('Nasi', _meals.nasi, const Color(0xFF9B59B6)),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _etkezesCsik(String cimke, int kcal, Color szin) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: szin.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(cimke, style: TextStyle(fontSize: 10, color: szin, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(
              '$kcal',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: szin),
            ),
            Text('kcal', style: TextStyle(fontSize: 9, color: szin.withValues(alpha: 0.7))),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthPermissionCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_primary, _primary.withValues(alpha: 0.85)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.health_and_safety_outlined, color: Colors.white, size: 22),
              SizedBox(width: 8),
              Text(
                'Apple Health hozzáférés',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'iPhone-on engedélyezd az Egészség appot a valós lépés, távolság és kalória adatokhoz.',
            style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.45),
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: _connectAppleHealth,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: _primary,
            ),
            child: const Text('Engedély megadása'),
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
          const SizedBox(height: 8),
          const Text('Ellenőrizd: fut-e a háttér szerver (dotnet run)?', style: TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Row(
      children: [
        _buildStreakChip(),
        const Spacer(),
        IconButton(
          onPressed: _loadData,
          icon: const Icon(Icons.refresh),
          color: Colors.black87,
        ),
      ],
    );
  }

  Widget _buildStreakChip() {
    final aktiv = _streak > 0;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: aktiv
            ? const LinearGradient(colors: [Color(0xFFFF6D00), Color(0xFFFFB300)])
            : null,
        color: aktiv ? null : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
        boxShadow: aktiv
            ? [BoxShadow(color: const Color(0xFFFF6D00).withValues(alpha: 0.35), blurRadius: 8, offset: const Offset(0, 2))]
            : [],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '🔥',
            style: TextStyle(fontSize: aktiv ? 18 : 16),
          ),
          const SizedBox(width: 5),
          Text(
            _streak > 0 ? '$_streak nap' : 'Streak',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: aktiv ? Colors.white : Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, String action) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.black87),
        ),
        const Spacer(),
        if (action.isNotEmpty)
          Text(
            action,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _accentGreen),
          ),
      ],
    );
  }

  Widget _buildFeedPost() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.grey.shade300,
                  child: Text('D', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.grey.shade700)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('domspill84', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      Text('egy órája', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () {},
                  style: TextButton.styleFrom(
                    foregroundColor: _primary,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  child: const Text('+ Követés', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Fan bike', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                SizedBox(height: 4),
                Text(
                  'Utolsó intervallum edzés: 8 kör, 10 mp munka, 20 mp pihenő.',
                  style: TextStyle(fontSize: 14, color: Colors.black87, height: 1.4),
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Text('Idő', style: TextStyle(fontSize: 13, color: Colors.black54)),
                    SizedBox(width: 6),
                    Text('27 perc', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            height: 200,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.grey.shade300, Colors.grey.shade400],
              ),
            ),
            child: Center(child: Icon(Icons.pedal_bike, size: 64, color: Colors.grey.shade600)),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _buildEngagementButton(Icons.thumb_up_outlined, '15'),
                const SizedBox(width: 20),
                _buildEngagementButton(Icons.chat_bubble_outline, null),
                const SizedBox(width: 20),
                _buildEngagementButton(Icons.ios_share, null),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEngagementButton(IconData icon, String? count) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade700),
        if (count != null) ...[
          const SizedBox(width: 4),
          Text(count, style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
        ],
      ],
    );
  }
}
