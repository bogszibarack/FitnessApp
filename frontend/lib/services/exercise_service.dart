import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/exercise_model.dart';

class ExerciseService {
  ExerciseService._();
  static final ExerciseService instance = ExerciseService._();

  final String _base = ApiConfig.baseUrl;

  Future<List<ExerciseModel>> search(String query) async {
    return filter(q: query.trim().isEmpty ? null : query.trim());
  }

  Future<ExerciseModel?> getById(String id) async {
    if (id.isEmpty) return null;
    final uri = Uri.parse('$_base/api/exercise/${Uri.encodeComponent(id)}');
    final response = await http.get(uri).timeout(const Duration(seconds: 60));
    if (response.statusCode == 404) return null;
    _check(response);
    return ExerciseModel.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<List<ExerciseModel>> filter({
    String? q,
    String? muscle,
    String? equipment,
    String? category,
  }) async {
    final params = <String, String>{};
    if (q != null && q.isNotEmpty) params['q'] = q;
    if (muscle != null && muscle.isNotEmpty) params['muscle'] = muscle;
    if (equipment != null && equipment.isNotEmpty) params['equipment'] = equipment;
    if (category != null && category.isNotEmpty) params['category'] = category;

    final uri = Uri.parse('$_base/api/exercise/search').replace(queryParameters: params);
    final response = await http.get(uri).timeout(const Duration(seconds: 60));
    _check(response);

    final list = jsonDecode(response.body) as List<dynamic>;
    return list.map((e) => ExerciseModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  // Legacy aliases for call sites not yet renamed
  Future<List<ExerciseModel>> kereses(String keresoszo) => search(keresoszo);

  Future<ExerciseModel?> gyakorlatLekerdezese(String id) => getById(id);

  Future<List<ExerciseModel>> szures({
    String? kereses,
    String? izomcsoport,
    String? felszereles,
    String? kategoria,
  }) =>
      filter(q: kereses, muscle: izomcsoport, equipment: felszereles, category: kategoria);

  void _check(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Gyakorlat API hiba (${response.statusCode}): ${response.body}');
    }
  }
}
