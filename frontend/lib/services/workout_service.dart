import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/plan_model.dart';
import '../models/workout_models.dart';
import 'api_http.dart';

class WorkoutService {
  WorkoutService._();
  static final WorkoutService instance = WorkoutService._();

  final String _base = ApiConfig.baseUrl;

  Future<List<WorkoutSessionModel>> workoutHistory() async {
    final response = await ApiHttp.get(Uri.parse('$_base/api/workout/history'));
    _check(response);
    final lista = jsonDecode(response.body) as List<dynamic>;
    return lista
        .map((e) => WorkoutSessionModel.fromJson(e as Map<String, dynamic>))
        .toList()
        .reversed
        .toList();
  }

  Future<WorkoutSessionModel> startEmptyWorkout() async {
    final response = await ApiHttp.post(Uri.parse('$_base/api/workout/uj-ures-edzes'));
    _check(response);
    return WorkoutSessionModel.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<WorkoutSessionModel> startFromPlan(PlanModel plan, {bool saved = false}) async {
    final uri = saved && plan.id.isNotEmpty
        ? Uri.parse('$_base/api/workout/inditas-rutinbol/${plan.id}')
        : Uri.parse('$_base/api/workout/inditas-rutinbol');

    final response = saved && plan.id.isNotEmpty
        ? await ApiHttp.post(uri)
        : await ApiHttp.post(uri, body: jsonEncode(plan.toJson()));

    _check(response);
    return WorkoutSessionModel.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<WorkoutSessionModel?> activeWorkout() async {
    final response = await ApiHttp.get(Uri.parse('$_base/api/workout/aktiv'));
    if (response.statusCode == 404) return null;
    _check(response);
    return WorkoutSessionModel.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<WorkoutSessionModel?> activeWorkoutOrNull() => activeWorkout();

  Future<WorkoutSessionModel> finishWorkout() async {
    final response = await ApiHttp.post(Uri.parse('$_base/api/workout/aktiv/befejezes'));
    _check(response);
    return WorkoutSessionModel.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> discardWorkout() async {
    final response = await ApiHttp.delete(Uri.parse('$_base/api/workout/aktiv'));
    _check(response);
  }

  Future<void> updateWorkoutTitle(String title) async {
    final response = await ApiHttp.put(
      Uri.parse('$_base/api/workout/aktiv'),
      body: jsonEncode({'title': title}),
    );
    _check(response);
  }

  Future<LoggedExerciseModel> addExercise({
    required String exerciseId,
    required String exerciseName,
    List<LoggedSetModel>? sets,
  }) async {
    final response = await ApiHttp.post(
      Uri.parse('$_base/api/workout/aktiv/gyakorlat-hozzaadas'),
      body: jsonEncode({
        'exerciseId': exerciseId,
        'exerciseName': exerciseName,
        'sets': (sets ?? []).map((s) => s.toJson()).toList(),
      }),
    );
    _check(response);
    var exercise = LoggedExerciseModel.fromJson(jsonDecode(response.body) as Map<String, dynamic>);

    if (sets != null && sets.isNotEmpty) {
      exercise = await updateSets(exerciseId, sets);
    }

    return exercise;
  }

  Future<LoggedExerciseModel> getExercise(String exerciseId) async {
    final response = await ApiHttp.get(
      Uri.parse('$_base/api/workout/aktiv/gyakorlat/${Uri.encodeComponent(exerciseId)}'),
    );
    _check(response);
    return LoggedExerciseModel.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<LoggedExerciseModel> updateSets(String exerciseId, List<LoggedSetModel> sets) async {
    final response = await ApiHttp.put(
      Uri.parse('$_base/api/workout/aktiv/gyakorlat/${Uri.encodeComponent(exerciseId)}/sorozatok'),
      body: jsonEncode(sets.map((s) => s.toJson()).toList()),
    );
    _check(response);
    return LoggedExerciseModel.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<LoggedSetModel> addSet(String exerciseId, {bool isWarmup = false}) async {
    final response = await ApiHttp.post(
      Uri.parse('$_base/api/workout/aktiv/gyakorlat/${Uri.encodeComponent(exerciseId)}/sorozat'),
      body: jsonEncode({
        'setNumber': 0,
        'isWarmup': isWarmup,
        'weight': 0,
        'reps': 0,
        'targetReps': isWarmup ? '10' : '10-12',
        'isDone': false,
      }),
    );
    _check(response);
    return LoggedSetModel.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<LoggedSetModel> updateSet(
    String exerciseId,
    int setNumber, {
    required double weight,
    required int reps,
    String? targetReps,
  }) async {
    final response = await ApiHttp.put(
      Uri.parse('$_base/api/workout/aktiv/gyakorlat/${Uri.encodeComponent(exerciseId)}/sorozat/$setNumber'),
      body: jsonEncode({
        'weight': weight,
        'reps': reps,
        if (targetReps != null) 'targetReps': targetReps,
      }),
    );
    _check(response);
    return LoggedSetModel.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<LoggedSetModel> completeSet(
    String exerciseId,
    int setNumber, {
    required double weight,
    required int reps,
  }) async {
    final response = await ApiHttp.post(
      Uri.parse('$_base/api/workout/aktiv/gyakorlat/${Uri.encodeComponent(exerciseId)}/sorozat/$setNumber/pipa'),
      body: jsonEncode({'weight': weight, 'reps': reps}),
    );
    _check(response);
    return LoggedSetModel.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<LoggedSetModel> uncompleteSet(String exerciseId, int setNumber) async {
    final response = await ApiHttp.delete(
      Uri.parse('$_base/api/workout/aktiv/gyakorlat/${Uri.encodeComponent(exerciseId)}/sorozat/$setNumber/pipa'),
    );
    _check(response);
    return LoggedSetModel.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> deleteSet(String exerciseId, int setNumber) async {
    final response = await ApiHttp.delete(
      Uri.parse('$_base/api/workout/aktiv/gyakorlat/${Uri.encodeComponent(exerciseId)}/sorozat/$setNumber'),
    );
    _check(response);
  }

  Future<void> deleteExercise(String exerciseId) async {
    final response = await ApiHttp.delete(
      Uri.parse('$_base/api/workout/aktiv/gyakorlat/${Uri.encodeComponent(exerciseId)}'),
    );
    _check(response);
  }

  Future<WorkoutSessionModel> updateHistoryEntry(WorkoutSessionModel session) async {
    final response = await ApiHttp.put(
      Uri.parse('$_base/api/workout/history/${session.id}'),
      body: jsonEncode(session.toJson()),
    );
    _check(response);
    return WorkoutSessionModel.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> deleteHistoryEntry(int sessionId) async {
    final response = await ApiHttp.delete(Uri.parse('$_base/api/workout/history/$sessionId'));
    _check(response);
  }

  Future<ProgressSettings> getProgressSettings() async {
    final response = await ApiHttp.get(Uri.parse('$_base/api/workout/progress-settings'));
    _check(response);
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return ProgressSettings.fromJson(data);
  }

  Future<void> saveProgressSettings(ProgressSettings settings) async {
    final response = await ApiHttp.put(
      Uri.parse('$_base/api/workout/progress-settings'),
      body: jsonEncode(settings.toJson()),
    );
    _check(response);
  }

  Future<double> getProgressPercent() async {
    final settings = await getProgressSettings();
    return settings.percent.clamp(0.0, 20.0);
  }

  Future<void> saveProgressPercent(double percent) async {
    final current = await getProgressSettings();
    await saveProgressSettings(current.copyWith(percent: percent.clamp(0.0, 20.0)));
  }

  void _check(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('API hiba (${response.statusCode}): ${response.body}');
    }
  }
}

extension ProgressSettingsCopy on ProgressSettings {
  ProgressSettings copyWith({
    String? mode,
    double? percent,
    double? kg,
    int? repBoost,
  }) {
    return ProgressSettings(
      mode: mode ?? this.mode,
      percent: percent ?? this.percent,
      kg: kg ?? this.kg,
      repBoost: repBoost ?? this.repBoost,
    );
  }
}
