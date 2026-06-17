class DailyHealthData {
  const DailyHealthData({
    required this.moveKcal,
    required this.moveGoalKcal,
    required this.exerciseMinutes,
    required this.exerciseGoalMinutes,
    required this.standHours,
    required this.standGoalHours,
    required this.steps,
    required this.distanceKm,
    required this.caloriesConsumed,
    required this.caloriesBurned,
    required this.calorieGoal,
    required this.carbsGrams,
    required this.proteinGrams,
    required this.fatGrams,
    required this.carbsGoalGrams,
    required this.proteinGoalGrams,
    required this.fatGoalGrams,
    required this.isFromAppleHealth,
  });

  final int moveKcal;
  final int moveGoalKcal;
  final int exerciseMinutes;
  final int exerciseGoalMinutes;
  final int standHours;
  final int standGoalHours;
  final int steps;
  final double distanceKm;
  final int caloriesConsumed;
  final int caloriesBurned;
  final int calorieGoal;
  final int carbsGrams;
  final int proteinGrams;
  final int fatGrams;
  final int carbsGoalGrams;
  final int proteinGoalGrams;
  final int fatGoalGrams;
  final bool isFromAppleHealth;

  int get caloriesRemaining => (calorieGoal - caloriesConsumed).clamp(0, calorieGoal);

  double get moveProgress => moveGoalKcal > 0 ? moveKcal / moveGoalKcal : 0;
  double get exerciseProgress => exerciseGoalMinutes > 0 ? exerciseMinutes / exerciseGoalMinutes : 0;
  double get standProgress => standGoalHours > 0 ? standHours / standGoalHours : 0;
  double get calorieProgress => calorieGoal > 0 ? caloriesConsumed / calorieGoal : 0;
  double get carbsProgress => carbsGoalGrams > 0 ? carbsGrams / carbsGoalGrams : 0;
  double get proteinProgress => proteinGoalGrams > 0 ? proteinGrams / proteinGoalGrams : 0;
  double get fatProgress => fatGoalGrams > 0 ? fatGrams / fatGoalGrams : 0;

  static DailyHealthData empty({bool isFromAppleHealth = false}) {
    return DailyHealthData(
      moveKcal: 0,
      moveGoalKcal: 500,
      exerciseMinutes: 0,
      exerciseGoalMinutes: 30,
      standHours: 0,
      standGoalHours: 12,
      steps: 0,
      distanceKm: 0,
      caloriesConsumed: 0,
      caloriesBurned: 0,
      calorieGoal: 2000,
      carbsGrams: 0,
      proteinGrams: 0,
      fatGrams: 0,
      carbsGoalGrams: 250,
      proteinGoalGrams: 125,
      fatGoalGrams: 67,
      isFromAppleHealth: isFromAppleHealth,
    );
  }
}
