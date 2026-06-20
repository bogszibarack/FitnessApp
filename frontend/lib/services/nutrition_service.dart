import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/nutrition_models.dart';

class NutritionService {
  NutritionService._();
  static final NutritionService instance = NutritionService._();

  final String _base = ApiConfig.baseUrl;

  Future<List<FoodItemModel>> kereses(String keresoszo) async {
    if (keresoszo.trim().isEmpty) return [];
    final uri = Uri.parse('$_base/api/nutrition/kereso').replace(
      queryParameters: {'keresoszo': keresoszo.trim()},
    );
    final response = await http.get(uri).timeout(const Duration(seconds: 20));
    _ellenorzes(response);
    final lista = jsonDecode(response.body) as List<dynamic>;
    return lista.map((e) => FoodItemModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Termék lekérése vonalkód alapján (Open Food Facts a backenden át).
  Future<FoodItemModel> vonalkodKereses(String vonalkod) async {
    final response = await http
        .get(Uri.parse('$_base/api/nutrition/vonalkod/$vonalkod'))
        .timeout(const Duration(seconds: 20));
    _ellenorzes(response);
    return FoodItemModel.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<DailyNutritionModel> maiNaplo() async {
    final response = await http.get(Uri.parse('$_base/api/nutrition/mai-naplo')).timeout(const Duration(seconds: 10));
    _ellenorzes(response);
    return DailyNutritionModel.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<DailyNutritionModel> etelHozzaadasa(LoggedFoodModel etel) async {
    final response = await http.post(
      Uri.parse('$_base/api/nutrition/etel-hozzaadas'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(etel.toJson()),
    );
    _ellenorzes(response);
    return DailyNutritionModel.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<DailyNutritionModel> receptHozzaadasa({
    required String receptId,
    required String etkezesTipus,
    double adagSzam = 1,
  }) async {
    final response = await http.post(
      Uri.parse('$_base/api/nutrition/recept-hozzaadas'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'receptId': receptId,
        'adagSzam': adagSzam,
        'etkezesTipus': etkezesTipus,
      }),
    );
    _ellenorzes(response);
    return DailyNutritionModel.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<DailyNutritionModel> etelModositas(int index, LoggedFoodModel etel) async {
    final response = await http.put(
      Uri.parse('$_base/api/nutrition/etel-modositas/$index'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(etel.toJson()),
    );
    _ellenorzes(response);
    return DailyNutritionModel.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<DailyNutritionModel> etelTorlese(int index) async {
    final response = await http.delete(Uri.parse('$_base/api/nutrition/etel-torles/$index'));
    _ellenorzes(response);
    return DailyNutritionModel.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<DailyNutritionModel> celKaloriaBeallitasa(double cel) async {
    final response = await http.put(
      Uri.parse('$_base/api/nutrition/cel-kaloria'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(cel),
    );
    _ellenorzes(response);
    return DailyNutritionModel.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  LoggedFoodModel etelbolNaploBejegyzes({
    required FoodItemModel etel,
    required String etkezesTipus,
    required double gramm,
  }) {
    return LoggedFoodModel(
      foodId: etel.id,
      foodName: etel.name,
      amountGrams: gramm,
      mealType: etkezesTipus,
      kepUrl: etel.imageUrl,
      caloriesPer100g: etel.calories,
      proteinPer100g: etel.protein,
      carbsPer100g: etel.carbs,
      fatPer100g: etel.fat,
    );
  }

  void _ellenorzes(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Nutrition API hiba (${response.statusCode}): ${response.body}');
    }
  }
}
