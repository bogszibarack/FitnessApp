import 'package:flutter/material.dart';

class FoodItemModel {
  FoodItemModel({
    required this.id,
    required this.name,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.imageUrl = '',
  });

  final String id;
  final String name;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final String imageUrl;

  factory FoodItemModel.fromJson(Map<String, dynamic> json) {
    return FoodItemModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      calories: (json['calories'] as num?)?.toDouble() ?? 0,
      protein: (json['protein'] as num?)?.toDouble() ?? 0,
      carbs: (json['carbs'] as num?)?.toDouble() ?? 0,
      fat: (json['fat'] as num?)?.toDouble() ?? 0,
      imageUrl: json['imageUrl'] as String? ?? '',
    );
  }
}

class LoggedFoodModel {
  LoggedFoodModel({
    required this.foodId,
    required this.foodName,
    this.amountGrams = 0,
    this.mealType = '',
    this.imageUrl = '',
    this.fromRecipe = false,
    this.recipeId = '',
    this.servings = 1,
    this.caloriesPer100g = 0,
    this.proteinPer100g = 0,
    this.carbsPer100g = 0,
    this.fatPer100g = 0,
  });

  final String foodId;
  final String foodName;
  final double amountGrams;
  final String mealType;
  final String imageUrl;
  final bool fromRecipe;
  final String recipeId;
  final double servings;
  final double caloriesPer100g;
  final double proteinPer100g;
  final double carbsPer100g;
  final double fatPer100g;

  // Legacy aliases
  String get kepUrl => imageUrl;
  bool get receptbol => fromRecipe;
  String get receptId => recipeId;
  double get adagSzam => servings;

  double get calculatedCalories => fromRecipe
      ? caloriesPer100g * servings
      : (caloriesPer100g * amountGrams) / 100;

  double get calculatedProtein => fromRecipe
      ? proteinPer100g * servings
      : (proteinPer100g * amountGrams) / 100;

  double get calculatedCarbs => fromRecipe
      ? carbsPer100g * servings
      : (carbsPer100g * amountGrams) / 100;

  double get calculatedFat => fromRecipe
      ? fatPer100g * servings
      : (fatPer100g * amountGrams) / 100;

  factory LoggedFoodModel.fromJson(Map<String, dynamic> json) {
    return LoggedFoodModel(
      foodId: json['foodId'] as String? ?? '',
      foodName: json['foodName'] as String? ?? '',
      amountGrams: (json['amountGrams'] as num?)?.toDouble() ?? 0,
      mealType: json['mealType'] as String? ?? '',
      imageUrl: json['imageUrl'] as String? ?? json['kepUrl'] as String? ?? '',
      fromRecipe: json['fromRecipe'] as bool? ?? json['receptbol'] as bool? ?? false,
      recipeId: json['recipeId'] as String? ?? json['receptId'] as String? ?? '',
      servings: (json['servings'] as num?)?.toDouble() ?? (json['adagSzam'] as num?)?.toDouble() ?? 1,
      caloriesPer100g: (json['caloriesPer100g'] as num?)?.toDouble() ?? 0,
      proteinPer100g: (json['proteinPer100g'] as num?)?.toDouble() ?? 0,
      carbsPer100g: (json['carbsPer100g'] as num?)?.toDouble() ?? 0,
      fatPer100g: (json['fatPer100g'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'foodId': foodId,
        'foodName': foodName,
        'amountGrams': amountGrams,
        'mealType': mealType,
        'imageUrl': imageUrl,
        'fromRecipe': fromRecipe,
        'recipeId': recipeId,
        'servings': servings,
        'caloriesPer100g': caloriesPer100g,
        'proteinPer100g': proteinPer100g,
        'carbsPer100g': carbsPer100g,
        'fatPer100g': fatPer100g,
      };

  LoggedFoodModel copyWith({
    double? amountGrams,
    double? servings,
    double? adagSzam,
    String? mealType,
  }) {
    return LoggedFoodModel(
      foodId: foodId,
      foodName: foodName,
      amountGrams: amountGrams ?? this.amountGrams,
      mealType: mealType ?? this.mealType,
      imageUrl: imageUrl,
      fromRecipe: fromRecipe,
      recipeId: recipeId,
      servings: servings ?? adagSzam ?? this.servings,
      caloriesPer100g: caloriesPer100g,
      proteinPer100g: proteinPer100g,
      carbsPer100g: carbsPer100g,
      fatPer100g: fatPer100g,
    );
  }
}

class DailyNutritionModel {
  DailyNutritionModel({
    required this.date,
    required this.targetCalories,
    required this.eatenFoods,
    required this.totalCalories,
    required this.totalProtein,
    required this.totalCarbs,
    required this.totalFat,
    required this.remainingCalories,
  });

  final DateTime date;
  final double targetCalories;
  final List<LoggedFoodModel> eatenFoods;
  final double totalCalories;
  final double totalProtein;
  final double totalCarbs;
  final double totalFat;
  final double remainingCalories;

  factory DailyNutritionModel.fromJson(Map<String, dynamic> json) {
    final eaten = (json['eatenFoods'] as List<dynamic>? ?? [])
        .map((e) => LoggedFoodModel.fromJson(e as Map<String, dynamic>))
        .toList();

    return DailyNutritionModel(
      date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
      targetCalories: (json['targetCalories'] as num?)?.toDouble() ?? 2000,
      eatenFoods: eaten,
      totalCalories: (json['totalCalories'] as num?)?.toDouble() ?? 0,
      totalProtein: (json['totalProtein'] as num?)?.toDouble() ?? 0,
      totalCarbs: (json['totalCarbs'] as num?)?.toDouble() ?? 0,
      totalFat: (json['totalFat'] as num?)?.toDouble() ?? 0,
      remainingCalories: (json['remainingCalories'] as num?)?.toDouble() ?? 0,
    );
  }

  int kcalEtkezeshez(String mealType) {
    return eatenFoods
        .where((f) => f.mealType.toLowerCase() == mealType.toLowerCase())
        .fold(0, (sum, f) => sum + f.calculatedCalories.round());
  }

  List<MapEntry<int, LoggedFoodModel>> etelekEtkezeshez(String mealType) {
    final lista = <MapEntry<int, LoggedFoodModel>>[];
    for (var i = 0; i < eatenFoods.length; i++) {
      if (eatenFoods[i].mealType.toLowerCase() == mealType.toLowerCase()) {
        lista.add(MapEntry(i, eatenFoods[i]));
      }
    }
    return lista;
  }
}

class RecipeListItemModel {
  RecipeListItemModel({
    required this.id,
    required this.name,
    required this.category,
    required this.imageUrl,
    required this.estimatedCalories,
    this.estimatedProtein = 0,
    this.estimatedCarbs = 0,
    this.estimatedFat = 0,
    this.ingredientCount = 0,
    this.yazioTags = const [],
  });

  final String id;
  final String name;
  final String category;
  final String imageUrl;
  final int estimatedCalories;
  final double estimatedProtein;
  final double estimatedCarbs;
  final double estimatedFat;
  final int ingredientCount;
  final List<String> yazioTags;

  // Legacy getters for screens still mid-migrate
  String get nev => name;
  String get kategoria => category;
  String get kepUrl => imageUrl;
  int get becsultKaloria => estimatedCalories;
  double get becsultFeherje => estimatedProtein;
  double get becsultSzenhidrat => estimatedCarbs;
  double get becsultZsir => estimatedFat;
  int get hozzavaloSzam => ingredientCount;
  List<String> get yazioCimkek => yazioTags;

  factory RecipeListItemModel.fromJson(Map<String, dynamic> json) {
    return RecipeListItemModel(
      id: json['id'] as String? ?? '',
      name: (json['name'] ?? json['nev']) as String? ?? '',
      category: (json['category'] ?? json['kategoria']) as String? ?? '',
      imageUrl: (json['imageUrl'] ?? json['kepUrl']) as String? ?? '',
      estimatedCalories: ((json['estimatedCalories'] ?? json['becsultKaloria']) as num?)?.round() ?? 0,
      estimatedProtein: ((json['estimatedProtein'] ?? json['becsultFeherje']) as num?)?.toDouble() ?? 0,
      estimatedCarbs: ((json['estimatedCarbs'] ?? json['becsultSzenhidrat']) as num?)?.toDouble() ?? 0,
      estimatedFat: ((json['estimatedFat'] ?? json['becsultZsir']) as num?)?.toDouble() ?? 0,
      ingredientCount: ((json['ingredientCount'] ?? json['hozzavaloSzam']) as num?)?.round() ?? 0,
      yazioTags: [
        ...(json['yazioTags'] as List<dynamic>? ?? []).map((e) => e.toString()),
        ...(json['yazioCimkek'] as List<dynamic>? ?? []).map((e) => e.toString()),
        ...(json['tags'] as List<dynamic>? ?? []).map((e) => e.toString()),
        ...(json['cimkek'] as List<dynamic>? ?? []).map((e) => e.toString()),
      ],
    );
  }
}

typedef ReceptListaElemModel = RecipeListItemModel;

class RecipeDetailModel extends RecipeListItemModel {
  RecipeDetailModel({
    required super.id,
    required super.name,
    required super.category,
    required super.imageUrl,
    required super.estimatedCalories,
    super.estimatedProtein,
    super.estimatedCarbs,
    super.estimatedFat,
    super.ingredientCount,
    super.yazioTags,
    this.description = '',
    this.youtubeUrl = '',
    this.origin = '',
    this.ingredients = const [],
  });

  final String description;
  final String youtubeUrl;
  final String origin;
  final List<RecipeIngredientModel> ingredients;

  String get leiras => description;
  String get szarmazasiTerulet => origin;
  List<RecipeIngredientModel> get osszetevok => ingredients;

  factory RecipeDetailModel.fromJson(Map<String, dynamic> json) {
    final ingredientsRaw = json['ingredients'] ?? json['osszetevok'];
    return RecipeDetailModel(
      id: json['id'] as String? ?? '',
      name: (json['name'] ?? json['nev']) as String? ?? '',
      category: (json['category'] ?? json['kategoria']) as String? ?? '',
      imageUrl: (json['imageUrl'] ?? json['kepUrl']) as String? ?? '',
      estimatedCalories: ((json['estimatedCalories'] ?? json['becsultKaloria']) as num?)?.round() ?? 0,
      estimatedProtein: ((json['estimatedProtein'] ?? json['becsultFeherje']) as num?)?.toDouble() ?? 0,
      estimatedCarbs: ((json['estimatedCarbs'] ?? json['becsultSzenhidrat']) as num?)?.toDouble() ?? 0,
      estimatedFat: ((json['estimatedFat'] ?? json['becsultZsir']) as num?)?.toDouble() ?? 0,
      ingredientCount: ((json['ingredientCount'] ?? json['hozzavaloSzam']) as num?)?.round() ?? 0,
      yazioTags: [
        ...(json['yazioTags'] as List<dynamic>? ?? []).map((e) => e.toString()),
        ...(json['yazioCimkek'] as List<dynamic>? ?? []).map((e) => e.toString()),
        ...(json['tags'] as List<dynamic>? ?? []).map((e) => e.toString()),
        ...(json['cimkek'] as List<dynamic>? ?? []).map((e) => e.toString()),
      ],
      description: (json['description'] ?? json['leiras']) as String? ?? '',
      youtubeUrl: json['youtubeUrl'] as String? ?? '',
      origin: (json['origin'] ?? json['szarmazasiTerulet']) as String? ?? '',
      ingredients: (ingredientsRaw as List<dynamic>? ?? [])
          .map((e) => RecipeIngredientModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

typedef ReceptReszletesModel = RecipeDetailModel;

class RecipeIngredientModel {
  RecipeIngredientModel({required this.name, required this.amount});

  final String name;
  final String amount;

  String get nev => name;
  String get mennyiseg => amount;

  factory RecipeIngredientModel.fromJson(Map<String, dynamic> json) {
    return RecipeIngredientModel(
      name: (json['name'] ?? json['nev']) as String? ?? '',
      amount: (json['amount'] ?? json['mennyiseg']) as String? ?? '',
    );
  }
}

typedef ReceptOsszetevoModel = RecipeIngredientModel;

class RecipeCategoryModel {
  RecipeCategoryModel({required this.id, required this.name, this.icon = ''});

  final String id;
  final String name;
  final String icon;

  String get nev => name;
  String get ikon => icon;

  factory RecipeCategoryModel.fromJson(Map<String, dynamic> json) {
    return RecipeCategoryModel(
      id: json['id'] as String? ?? '',
      name: (json['name'] ?? json['nev']) as String? ?? '',
      icon: (json['icon'] ?? json['ikon']) as String? ?? '',
    );
  }
}

typedef ReceptKategoriaModel = RecipeCategoryModel;

class CalorieRangeModel {
  CalorieRangeModel({required this.min, required this.max, required this.name});

  final int min;
  final int max;
  final String name;

  String get nev => name;

  factory CalorieRangeModel.fromJson(Map<String, dynamic> json) {
    return CalorieRangeModel(
      min: (json['min'] as num?)?.round() ?? 0,
      max: (json['max'] as num?)?.round() ?? 0,
      name: (json['name'] ?? json['nev']) as String? ?? '',
    );
  }
}

typedef KaloriaTartomanyModel = CalorieRangeModel;

/// Étkezés típusok — backend: reggeli / ebed / vacsora / nasi
class EtkezesTipus {
  static const reggeli = 'reggeli';
  static const ebed = 'ebed';
  static const vacsora = 'vacsora';
  static const nasi = 'nasi';

  static const osszes = [reggeli, ebed, vacsora, nasi];

  static String cimke(String tipus) {
    switch (tipus) {
      case reggeli:
        return 'Reggeli';
      case ebed:
        return 'Ebéd';
      case vacsora:
        return 'Vacsora';
      case nasi:
        return 'Nassolnivalók';
      default:
        return tipus;
    }
  }

  static IconData ikon(String tipus) {
    switch (tipus) {
      case reggeli:
        return Icons.free_breakfast_outlined;
      case ebed:
        return Icons.lunch_dining_outlined;
      case vacsora:
        return Icons.dinner_dining_outlined;
      case nasi:
        return Icons.apple_outlined;
      default:
        return Icons.restaurant_outlined;
    }
  }

  static double celArany(String tipus) {
    switch (tipus) {
      case reggeli:
        return 0.30;
      case ebed:
        return 0.40;
      case vacsora:
        return 0.25;
      case nasi:
        return 0.05;
      default:
        return 0.25;
    }
  }
}
