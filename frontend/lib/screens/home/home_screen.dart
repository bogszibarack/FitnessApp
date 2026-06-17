import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/daily_health_data.dart';
import '../../services/apple_health_service.dart';
import '../../widgets/activity_rings.dart';
import '../../widgets/calorie_ring.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _moveColor = Color(0xFFFA114F);
  static const _exerciseColor = Color(0xFF92E82A);
  static const _standColor = Color(0xFF41CFFF);
  static const _accentGreen = Color(0xFF34C759);

  final _healthService = AppleHealthService.instance;
  DailyHealthData _data = DailyHealthData.empty();
  bool _loading = true;
  bool _permissionNeeded = false;
  String? _error;

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

    if (!_healthService.isSupported) {
      setState(() {
        _data = DailyHealthData.empty();
        _loading = false;
        _permissionNeeded = false;
      });
      return;
    }

    try {
      final hasPermission = await _healthService.hasPermissions();
      if (!hasPermission) {
        setState(() {
          _data = DailyHealthData.empty();
          _loading = false;
          _permissionNeeded = true;
        });
        return;
      }

      final data = await _healthService.fetchToday();
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
        _permissionNeeded = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
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
        const SnackBar(content: Text('Apple Health hozzaferes megtagadva.')),
      );
    }
  }

  String _formatNumber(int value) => NumberFormat('#,###', 'hu').format(value).replaceAll(',', ' ');

  String _formatDistance(double km) {
    if (km < 10) return '${km.toStringAsFixed(2).replaceAll('.', ',')} KM';
    return '${km.toStringAsFixed(1).replaceAll('.', ',')} KM';
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
                        _buildHealthBanner(),
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
                        _buildActivityCard(),
                        const SizedBox(height: 28),
                        _buildSectionHeader('Összefoglaló', 'Részletek'),
                        const SizedBox(height: 12),
                        _buildCalorieSummaryCard(),
                        const SizedBox(height: 28),
                        _buildSectionHeader('Táplálkozás', 'Több'),
                        const SizedBox(height: 12),
                        _buildMealsCard(),
                        const SizedBox(height: 28),
                        _buildDiscoverHeader(),
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

  Widget _buildHealthBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.favorite, color: _moveColor, size: 20),
              SizedBox(width: 8),
              Text(
                'Apple Health csatlakoztatása',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Engedélyezd a hozzáférést, hogy a valós aktivitás- és kalóriaadataid jelenjenek meg.',
            style: TextStyle(color: Colors.grey.shade400, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _connectAppleHealth,
            style: FilledButton.styleFrom(backgroundColor: _accentGreen),
            child: const Text('Csatlakozás'),
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
      child: Text(_error!, style: TextStyle(color: Colors.red.shade800, fontSize: 13)),
    );
  }

  Widget _buildTopBar() {
    return Row(
      children: [
        _buildStatChip(
          Icons.local_fire_department_outlined,
          '${_data.moveKcal}',
          Colors.orange.shade700,
        ),
        const SizedBox(width: 12),
        if (_data.isFromAppleHealth)
          _buildStatChip(Icons.favorite, 'Health', _moveColor),
        const Spacer(),
        IconButton(
          onPressed: _loadData,
          icon: const Icon(Icons.refresh),
          color: Colors.black87,
        ),
        IconButton(
          onPressed: () {},
          icon: const Icon(Icons.calendar_today_outlined),
          color: Colors.black87,
        ),
      ],
    );
  }

  Widget _buildStatChip(IconData icon, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 4),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: Colors.black87),
        ),
      ],
    );
  }

  Widget _buildActivityCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Tevékenységgyűrűk',
                style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              if (_data.isFromAppleHealth)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _accentGreen.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Apple Health',
                    style: TextStyle(color: _accentGreen, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
              Icon(Icons.chevron_right, color: Colors.grey.shade600, size: 22),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              ActivityRings(
                size: 130,
                strokeWidth: 13,
                gap: 5,
                rings: [
                  ActivityRingData(
                    label: 'Mozgás',
                    current: '${_data.moveKcal}',
                    goal: '${_data.moveGoalKcal}',
                    unit: 'KCAL',
                    color: _moveColor,
                    progress: _data.moveProgress,
                  ),
                  ActivityRingData(
                    label: 'Gyakorlat',
                    current: '${_data.exerciseMinutes}',
                    goal: '${_data.exerciseGoalMinutes}',
                    unit: 'PERC',
                    color: _exerciseColor,
                    progress: _data.exerciseProgress,
                  ),
                  ActivityRingData(
                    label: 'Állás',
                    current: '${_data.standHours}',
                    goal: '${_data.standGoalHours}',
                    unit: 'ÓRA',
                    color: _standColor,
                    progress: _data.standProgress,
                  ),
                ],
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  children: [
                    _buildRingStat('Mozgás', '${_data.moveKcal}/${_data.moveGoalKcal} KCAL', _moveColor),
                    const SizedBox(height: 14),
                    _buildRingStat(
                      'Gyakorlat',
                      '${_data.exerciseMinutes}/${_data.exerciseGoalMinutes} PERC',
                      _exerciseColor,
                    ),
                    const SizedBox(height: 14),
                    _buildRingStat(
                      'Állás',
                      '${_data.standHours}/${_data.standGoalHours} ÓRA',
                      _standColor,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildMiniMetricCard(
                  'Lépésszám',
                  _formatNumber(_data.steps),
                  const Color(0xFFBF5AF2),
                  Icons.directions_walk,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMiniMetricCard(
                  'Távolság',
                  _formatDistance(_data.distanceKm),
                  const Color(0xFF0A84FF),
                  Icons.route,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRingStat(String label, String value, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
              Text(
                value,
                style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMiniMetricCard(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2E),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w700),
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
        Text(
          action,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _accentGreen),
        ),
      ],
    );
  }

  Widget _buildCalorieSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildCalorieSideStat('${_data.caloriesConsumed}', 'Elfogyasztott'),
              CalorieRing(
                remaining: _data.caloriesRemaining,
                progress: _data.calorieProgress,
                color: _accentGreen,
              ),
              _buildCalorieSideStat('${_data.caloriesBurned}', 'Elégetett'),
            ],
          ),
          const SizedBox(height: 24),
          MacroBar(
            label: 'Szénhidrátok',
            current: _data.carbsGrams,
            goal: _data.carbsGoalGrams,
            progress: _data.carbsProgress,
          ),
          const SizedBox(height: 14),
          MacroBar(
            label: 'Fehérje',
            current: _data.proteinGrams,
            goal: _data.proteinGoalGrams,
            progress: _data.proteinProgress,
          ),
          const SizedBox(height: 14),
          MacroBar(
            label: 'Zsír',
            current: _data.fatGrams,
            goal: _data.fatGoalGrams,
            progress: _data.fatProgress,
          ),
        ],
      ),
    );
  }

  Widget _buildCalorieSideStat(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.black87),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildMealsCard() {
    final mealBudget = (_data.calorieGoal / 3).round();
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          _buildMealRow(Icons.free_breakfast_outlined, 'Reggeli', 0, mealBudget, showDivider: true),
          _buildMealRow(Icons.lunch_dining_outlined, 'Ebéd', 0, mealBudget, showDivider: true),
          _buildMealRow(Icons.dinner_dining_outlined, 'Vacsora', 0, mealBudget, showDivider: false),
        ],
      ),
    );
  }

  Widget _buildMealRow(IconData icon, String name, int current, int goal, {required bool showDivider}) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, size: 22, color: Colors.grey.shade700),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                        Icon(Icons.chevron_right, size: 18, color: Colors.grey.shade500),
                      ],
                    ),
                    Text(
                      '$current / $goal kcal',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(color: Colors.black87, shape: BoxShape.circle),
                child: const Icon(Icons.add, color: Colors.white, size: 20),
              ),
            ],
          ),
        ),
        if (showDivider) Divider(height: 1, indent: 50, color: Colors.grey.shade200),
      ],
    );
  }

  Widget _buildDiscoverHeader() {
    return Row(
      children: [
        const Text(
          'Felfedezés',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.black87),
        ),
        Icon(Icons.keyboard_arrow_down, color: Colors.grey.shade700),
        const Spacer(),
        IconButton(onPressed: () {}, icon: const Icon(Icons.search), color: Colors.black87),
        IconButton(onPressed: () {}, icon: const Icon(Icons.notifications_outlined), color: Colors.black87),
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
                    foregroundColor: const Color(0xFF1E88E5),
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

  int _weekOfYear(DateTime date) {
    final dayOfYear = date.difference(DateTime(date.year, 1, 1)).inDays + 1;
    return ((dayOfYear - date.weekday + 10) / 7).floor();
  }
}
