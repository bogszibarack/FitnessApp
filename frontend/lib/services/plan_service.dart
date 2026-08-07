import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/plan_model.dart';
import '../models/workout_models.dart';
import 'api_http.dart';

class PlanService {
  PlanService._();
  static final PlanService instance = PlanService._();

  final String _base = ApiConfig.baseUrl;

  Future<List<PlanModel>> generateAi({
    String difficulty = 'beginner',
    String targetMuscle = 'Chest',
    String sportCategory = 'gym',
  }) async {
    final response = await ApiHttp.post(
      Uri.parse('$_base/api/plan/ai-generate'),
      body: jsonEncode({
        'difficulty': difficulty,
        'targetMuscle': targetMuscle,
        'sportCategory': sportCategory,
      }),
    );
    _check(response);
    final lista = jsonDecode(response.body) as List<dynamic>;
    return lista.map((e) => PlanModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<PlanModel>> listMine() async {
    final response = await ApiHttp.get(Uri.parse('$_base/api/plan/mine'));
    _check(response);
    final lista = jsonDecode(response.body) as List<dynamic>;
    return lista.map((e) => PlanModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<PlanModel> save(PlanModel plan) async {
    final response = await ApiHttp.post(
      Uri.parse('$_base/api/plan/save'),
      body: jsonEncode(plan.toJson()),
    );
    _check(response);
    return PlanModel.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<PlanModel> saveFromWorkout({
    required WorkoutSessionModel session,
    required String title,
  }) async {
    final exercises = session.exercises;
    final plan = PlanModel(
      id: '',
      title: title,
      difficulty: 'beginner',
      targetMuscle: exercises.isNotEmpty ? 'Full Body' : 'General',
      sportCategory: 'gym',
      creatorName: ApiConfig.defaultUserName,
      exerciseIds: exercises.map((g) => g.exerciseId).toList(),
      exerciseNames: exercises.map((g) => g.exerciseName).toList(),
      exerciseTemplates: exercises,
    );
    return save(plan);
  }

  Future<PlanModel> update(PlanModel plan) async {
    final response = await ApiHttp.put(
      Uri.parse('$_base/api/plan/${plan.id}'),
      body: jsonEncode(plan.toJson()),
    );
    _check(response);
    return PlanModel.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> delete(String planId) async {
    final response = await ApiHttp.delete(Uri.parse('$_base/api/plan/$planId'));
    _check(response);
  }

  Future<List<PlanModel>> listTemplates() async {
    final response = await ApiHttp.get(Uri.parse('$_base/api/plan/templates'));
    _check(response);
    final lista = jsonDecode(response.body) as List<dynamic>;
    return lista.map((e) => PlanModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<PlanModel> getShared(String id) async {
    final response = await ApiHttp.get(Uri.parse('$_base/api/plan/share/$id'));
    _check(response);
    return PlanModel.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  void _check(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('API hiba (${response.statusCode}): ${response.body}');
    }
  }
}
