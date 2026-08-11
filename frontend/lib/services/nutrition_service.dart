import 'dart:convert';

import '../config/api_config.dart';
import '../models/nutrition_models.dart';
import 'api_http.dart';

class NutritionService {
  NutritionService._();
  static final NutritionService instance = NutritionService._();

  final String _base = ApiConfig.baseUrl;

  Future<List<FoodItemModel>> search(String query) async {
    if (query.trim().isEmpty) return [];
    final uri = Uri.parse('$_base/api/nutrition/search').replace(
      queryParameters: {'q': query.trim()},
    );
    final response = await ApiHttp.get(uri, timeout: const Duration(seconds: 20));
    _check(response);
    final list = jsonDecode(response.body) as List<dynamic>;
    return list.map((e) => FoodItemModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<FoodItemModel> barcode(String code) async {
    final response = await ApiHttp.get(
      Uri.parse('$_base/api/nutrition/barcode/$code'),
      timeout: const Duration(seconds: 20),
    );
    _check(response);
    return FoodItemModel.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<DailyNutritionModel> logToday() async {
    final response = await ApiHttp.get(
      Uri.parse('$_base/api/nutrition/log/today'),
      timeout: const Duration(seconds: 10),
    );
    _check(response);
    return DailyNutritionModel.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<DailyNutritionModel> addFood(LoggedFoodModel food) async {
    final response = await ApiHttp.post(
      Uri.parse('$_base/api/nutrition/food'),
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

    final response = await ApiHttp.post(
      Uri.parse('$_base/api/nutrition/recipe'),
      body: jsonEncode(body),
    );
    _check(response);
    return DailyNutritionModel.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<DailyNutritionModel> updateFood(int index, LoggedFoodModel food) async {
    final response = await ApiHttp.put(
      Uri.parse('$_base/api/nutrition/food/$index'),
      body: jsonEncode(food.toJson()),
    );
    _check(response);
    return DailyNutritionModel.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<DailyNutritionModel> deleteFood(int index) async {
    final response = await ApiHttp.delete(Uri.parse('$_base/api/nutrition/food/$index'));
    _check(response);
    return DailyNutritionModel.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<DailyNutritionModel> setTargetCalories(double target) async {
    final response = await ApiHttp.put(
      Uri.parse('$_base/api/nutrition/target-calories'),
      body: jsonEncode(target),
    );
    _check(response);
    return DailyNutritionModel.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<List<FoodItemModel>> listCustomFoods() async {
    final response = await ApiHttp.get(Uri.parse('$_base/api/nutrition/custom-foods'));
    _check(response);
    final list = jsonDecode(response.body) as List<dynamic>;
    return list.map((e) {
      final m = e as Map<String, dynamic>;
      return FoodItemModel(
        id: m['id'] as String? ?? '',
        name: m['name'] as String? ?? '',
        calories: (m['calories'] as num?)?.toDouble() ?? 0,
        protein: (m['protein'] as num?)?.toDouble() ?? 0,
        carbs: (m['carbs'] as num?)?.toDouble() ?? 0,
        fat: (m['fat'] as num?)?.toDouble() ?? 0,
      );
    }).toList();
  }

  Future<FoodItemModel> createCustomFood({
    required String name,
    required double calories,
    required double protein,
    required double carbs,
    required double fat,
  }) async {
    final response = await ApiHttp.post(
      Uri.parse('$_base/api/nutrition/custom-foods'),
      body: jsonEncode({
        'name': name,
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
      }),
    );
    _check(response);
    final m = jsonDecode(response.body) as Map<String, dynamic>;
    return FoodItemModel(
      id: m['id'] as String? ?? '',
      name: m['name'] as String? ?? name,
      calories: (m['calories'] as num?)?.toDouble() ?? calories,
      protein: (m['protein'] as num?)?.toDouble() ?? protein,
      carbs: (m['carbs'] as num?)?.toDouble() ?? carbs,
      fat: (m['fat'] as num?)?.toDouble() ?? fat,
    );
  }

  Future<void> deleteCustomFood(String id) async {
    final response = await ApiHttp.delete(Uri.parse('$_base/api/nutrition/custom-foods/$id'));
    _check(response);
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

  void _check(dynamic response) {
    final status = response.statusCode as int;
    final body = response.body as String;
    if (status < 200 || status >= 300) {
      throw Exception('Nutrition API hiba ($status): $body');
    }
  }
}
