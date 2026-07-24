import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/nutrition_models.dart';

class RecipeService {
  RecipeService._();
  static final RecipeService instance = RecipeService._();

  final String _base = ApiConfig.baseUrl;

  Future<List<RecipeCategoryModel>> categories() async {
    final response = await http.get(Uri.parse('$_base/api/recipe/categories'));
    _check(response);
    final list = jsonDecode(response.body) as List<dynamic>;
    return list.map((e) => RecipeCategoryModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<CalorieRangeModel>> calorieBands() async {
    final response = await http.get(Uri.parse('$_base/api/recipe/calorie-bands'));
    _check(response);
    final list = jsonDecode(response.body) as List<dynamic>;
    return list.map((e) => CalorieRangeModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<RecipeListItemModel>> search(String query) async {
    if (query.trim().isEmpty) return [];
    final uri = Uri.parse('$_base/api/recipe/search').replace(queryParameters: {'q': query.trim()});
    final response = await http.get(uri).timeout(const Duration(seconds: 25));
    _check(response);
    final list = jsonDecode(response.body) as List<dynamic>;
    return list.map((e) => RecipeListItemModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<RecipeListItemModel>> byCategory(String categoryId) async {
    final uri = Uri.parse(_base).replace(
      pathSegments: ['api', 'recipe', 'category', ...categoryId.split('/')],
    );
    final response = await http.get(uri).timeout(const Duration(seconds: 30));
    _check(response);
    final list = jsonDecode(response.body) as List<dynamic>;
    return list.map((e) => RecipeListItemModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<RecipeListItemModel>> byCalories(int min, int max) async {
    final uri = Uri.parse('$_base/api/recipe/by-calories').replace(
      queryParameters: {'min': '$min', 'max': '$max'},
    );
    final response = await http.get(uri).timeout(const Duration(seconds: 30));
    _check(response);
    final list = jsonDecode(response.body) as List<dynamic>;
    return list.map((e) => RecipeListItemModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<RecipeListItemModel>> discover({int count = 8}) async {
    final uri = Uri.parse('$_base/api/recipe/discover').replace(queryParameters: {'count': '$count'});
    final response = await http.get(uri).timeout(const Duration(seconds: 30));
    _check(response);
    final list = jsonDecode(response.body) as List<dynamic>;
    return list.map((e) => RecipeListItemModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<RecipeDetailModel> getById(String id) async {
    final uri = Uri.parse('$_base/api/recipe/${Uri.encodeComponent(id)}');
    final response = await http.get(uri).timeout(const Duration(seconds: 20));
    _check(response);
    return RecipeDetailModel.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  // Legacy aliases for call sites not yet renamed
  Future<List<RecipeCategoryModel>> kategoriak() => categories();
  Future<List<CalorieRangeModel>> kaloriaTartomanyok() => calorieBands();
  Future<List<RecipeListItemModel>> kereses(String keresoszo) => search(keresoszo);
  Future<List<RecipeListItemModel>> kategoriaSzerint(String kategoriaId) => byCategory(kategoriaId);
  Future<List<RecipeListItemModel>> kaloriaSzerint(int min, int max) => byCalories(min, max);
  Future<List<RecipeListItemModel>> felfedezes({int darab = 8}) => discover(count: darab);
  Future<RecipeDetailModel> reszletek(String receptId) => getById(receptId);

  void _check(http.Response response) {
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
