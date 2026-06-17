import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/exercise_model.dart';

class ExerciseService {
  ExerciseService._();
  static final ExerciseService instance = ExerciseService._();

  final String _base = ApiConfig.baseUrl;

  Future<List<ExerciseModel>> kereses(String keresoszo) async {
    return szures(kereses: keresoszo.trim().isEmpty ? null : keresoszo.trim());
  }

  Future<ExerciseModel?> gyakorlatLekerdezese(String id) async {
    if (id.isEmpty) return null;
    final uri = Uri.parse('$_base/api/exercise/${Uri.encodeComponent(id)}');
    final response = await http.get(uri).timeout(const Duration(seconds: 60));
    if (response.statusCode == 404) return null;
    _ellenorzes(response);
    return ExerciseModel.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<List<ExerciseModel>> szures({
    String? kereses,
    String? izomcsoport,
    String? felszereles,
    String? kategoria,
  }) async {
    final params = <String, String>{};
    if (kereses != null && kereses.isNotEmpty) params['kereses'] = kereses;
    if (izomcsoport != null && izomcsoport.isNotEmpty) params['izomcsoport'] = izomcsoport;
    if (felszereles != null && felszereles.isNotEmpty) params['felszereles'] = felszereles;
    if (kategoria != null && kategoria.isNotEmpty) params['kategoria'] = kategoria;

    final uri = Uri.parse('$_base/api/exercise/kereses').replace(queryParameters: params);
    final response = await http.get(uri).timeout(const Duration(seconds: 60));
    _ellenorzes(response);

    final lista = jsonDecode(response.body) as List<dynamic>;
    return lista.map((e) => ExerciseModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  void _ellenorzes(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Gyakorlat API hiba (${response.statusCode}): ${response.body}');
    }
  }
}
