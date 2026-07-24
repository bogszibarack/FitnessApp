import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/nutrition_models.dart';

class NutritionService {
  NutritionService._();
  static final NutritionService instance = NutritionService._();

  final String _base = ApiConfig.baseUrl;

  Future<List<FoodItemModel>> search(String query) async {
    if (query.trim().isEmpty) return [];
    final uri = Uri.parse('$_base/api/nutrition/search').replace(
      queryParameters: {'q': query.trim()},
    );
    final response = await http.get(uri).timeout(const Duration(seconds: 20));
    _check(response);
    final list = jsonDecode(response.body) as List<dynamic>;
    return list.map((e) => FoodItemModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<FoodItemModel> barcode(String code) async {
    final response = await http
        .get(Uri.parse('$_base/api/nutrition/barcode/$code'))
        .timeout(const Duration(seconds: 20));
    _check(response);
    return FoodItemModel.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<DailyNutritionModel> logToday() async {
    final response =
        await http.get(Uri.parse('$_base/api/nutrition/log/today')).timeout(const Duration(seconds: 10));
    _check(response);
    return DailyNutritionModel.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<DailyNutritionModel> addFood(LoggedFoodModel food) async {
    final response = await http.post(
      Uri.parse('$_base/api/nutrition/food'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(food.toJson()),
    );
    _check(response);
    return DailyNutritionModel.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<DailyNutritionModel> addRecipe({
    required String recipeId,
    required String mealType,
    double servings = 1,
    String? recipeName,
    double? caloriesPerServing,
    double? proteinPerServing,
    double? carbsPerServing,
    double? fatPerServing,
  }) async {
    final body = <String, dynamic>{
      'recipeId': recipeId,
      'servings': servings,
      'mealType': mealType,
    };
    if (recipeName != null) body['recipeName'] = recipeName;
    if (caloriesPerServing != null) body['caloriesPerServing'] = caloriesPerServing;
    if (proteinPerServing != null) body['proteinPerServing'] = proteinPerServing;
    if (carbsPerServing != null) body['carbsPerServing'] = carbsPerServing;
    if (fatPerServing != null) body['fatPerServing'] = fatPerServing;

    final response = await http.post(
      Uri.parse('$_base/api/nutrition/recipe'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    _check(response);
    return DailyNutritionModel.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<DailyNutritionModel> updateFood(int index, LoggedFoodModel food) async {
    final response = await http.put(
      Uri.parse('$_base/api/nutrition/food/$index'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(food.toJson()),
    );
    _check(response);
    return DailyNutritionModel.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<DailyNutritionModel> deleteFood(int index) async {
    final response = await http.delete(Uri.parse('$_base/api/nutrition/food/$index'));
    _check(response);
    return DailyNutritionModel.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<DailyNutritionModel> setTargetCalories(double target) async {
    final response = await http.put(
      Uri.parse('$_base/api/nutrition/target-calories'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(target),
    );
    _check(response);
    return DailyNutritionModel.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  LoggedFoodModel toLoggedFood({
    required FoodItemModel food,
    required String mealType,
    required double grams,
  }) {
    return LoggedFoodModel(
      foodId: food.id,
      foodName: food.name,
      amountGrams: grams,
      mealType: mealType,
      imageUrl: food.imageUrl,
      caloriesPer100g: food.calories,
      proteinPer100g: food.protein,
      carbsPer100g: food.carbs,
      fatPer100g: food.fat,
    );
  }

  // Legacy aliases for call sites not yet renamed
  Future<List<FoodItemModel>> kereses(String keresoszo) => search(keresoszo);
  Future<FoodItemModel> vonalkodKereses(String vonalkod) => barcode(vonalkod);
  Future<DailyNutritionModel> maiNaplo() => logToday();
  Future<DailyNutritionModel> etelHozzaadasa(LoggedFoodModel etel) => addFood(etel);
  Future<DailyNutritionModel> etelModositas(int index, LoggedFoodModel etel) => updateFood(index, etel);
  Future<DailyNutritionModel> etelTorlese(int index) => deleteFood(index);
  Future<DailyNutritionModel> celKaloriaBeallitasa(double cel) => setTargetCalories(cel);

  Future<DailyNutritionModel> receptHozzaadasa({
    required String receptId,
    required String etkezesTipus,
    double adagSzam = 1,
    String? receptNev,
    double? kaloriaAdagonkent,
    double? feherjeAdagonkent,
    double? szenhidratAdagonkent,
    double? zsirAdagonkent,
  }) =>
      addRecipe(
        recipeId: receptId,
        mealType: etkezesTipus,
        servings: adagSzam,
        recipeName: receptNev,
        caloriesPerServing: kaloriaAdagonkent,
        proteinPerServing: feherjeAdagonkent,
        carbsPerServing: szenhidratAdagonkent,
        fatPerServing: zsirAdagonkent,
      );

  LoggedFoodModel etelbolNaploBejegyzes({
    required FoodItemModel etel,
    required String etkezesTipus,
    required double gramm,
  }) =>
      toLoggedFood(food: etel, mealType: etkezesTipus, grams: gramm);

  void _check(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Nutrition API hiba (${response.statusCode}): ${response.body}');
    }
  }
}
