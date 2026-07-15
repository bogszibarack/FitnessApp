import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/nutrition_models.dart';

class ReceptService {
  ReceptService._();
  static final ReceptService instance = ReceptService._();

  final String _base = ApiConfig.baseUrl;

  Future<List<ReceptKategoriaModel>> kategoriak() async {
    final response = await http.get(Uri.parse('$_base/api/recept/kategoriak'));
    _ellenorzes(response);
    final lista = jsonDecode(response.body) as List<dynamic>;
    return lista.map((e) => ReceptKategoriaModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<KaloriaTartomanyModel>> kaloriaTartomanyok() async {
    final response = await http.get(Uri.parse('$_base/api/recept/kaloria-tartomanyok'));
    _ellenorzes(response);
    final lista = jsonDecode(response.body) as List<dynamic>;
    return lista.map((e) => KaloriaTartomanyModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<ReceptListaElemModel>> kereses(String keresoszo) async {
    if (keresoszo.trim().isEmpty) return [];
    final uri = Uri.parse('$_base/api/recept/kereso').replace(queryParameters: {'keresoszo': keresoszo.trim()});
    final response = await http.get(uri).timeout(const Duration(seconds: 25));
    _ellenorzes(response);
    final lista = jsonDecode(response.body) as List<dynamic>;
    return lista.map((e) => ReceptListaElemModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<ReceptListaElemModel>> kategoriaSzerint(String kategoriaId) async {
    final uri = Uri.parse(_base).replace(
      pathSegments: ['api', 'recept', 'kategoria', ...kategoriaId.split('/')],
    );
    final response = await http.get(uri).timeout(const Duration(seconds: 30));
    _ellenorzes(response);
    final lista = jsonDecode(response.body) as List<dynamic>;
    return lista.map((e) => ReceptListaElemModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<ReceptListaElemModel>> kaloriaSzerint(int min, int max) async {
    final uri = Uri.parse('$_base/api/recept/kaloria').replace(queryParameters: {'min': '$min', 'max': '$max'});
    final response = await http.get(uri).timeout(const Duration(seconds: 30));
    _ellenorzes(response);
    final lista = jsonDecode(response.body) as List<dynamic>;
    return lista.map((e) => ReceptListaElemModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<ReceptListaElemModel>> felfedezes({int darab = 8}) async {
    final uri = Uri.parse('$_base/api/recept/felfedezes').replace(queryParameters: {'darab': '$darab'});
    final response = await http.get(uri).timeout(const Duration(seconds: 30));
    _ellenorzes(response);
    final lista = jsonDecode(response.body) as List<dynamic>;
    return lista.map((e) => ReceptListaElemModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<ReceptReszletesModel> reszletek(String receptId) async {
    final uri = Uri.parse('$_base/api/recept/${Uri.encodeComponent(receptId)}');
    final response = await http.get(uri).timeout(const Duration(seconds: 20));
    _ellenorzes(response);
    return ReceptReszletesModel.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  void _ellenorzes(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (response.statusCode == 429) {
        throw Exception('429: Túl sok kérés');
      }
      if (response.statusCode == 503) {
        throw Exception('503: A recept szolgáltatás nem elérhető');
      }
      throw Exception('Recept API hiba (${response.statusCode})');
    }
  }
}
