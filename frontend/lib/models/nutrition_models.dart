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
    this.kepUrl = '',
    this.receptbol = false,
    this.receptId = '',
    this.adagSzam = 1,
    this.caloriesPer100g = 0,
    this.proteinPer100g = 0,
    this.carbsPer100g = 0,
    this.fatPer100g = 0,
  });

  final String foodId;
  final String foodName;
  final double amountGrams;
  final String mealType;
  final String kepUrl;
  final bool receptbol;
  final String receptId;
  final double adagSzam;
  final double caloriesPer100g;
  final double proteinPer100g;
  final double carbsPer100g;
  final double fatPer100g;

  double get calculatedCalories => receptbol
      ? caloriesPer100g * adagSzam
      : (caloriesPer100g * amountGrams) / 100;

  double get calculatedProtein => receptbol
      ? proteinPer100g * adagSzam
      : (proteinPer100g * amountGrams) / 100;

  double get calculatedCarbs => receptbol
      ? carbsPer100g * adagSzam
      : (carbsPer100g * amountGrams) / 100;

  double get calculatedFat => receptbol
      ? fatPer100g * adagSzam
      : (fatPer100g * amountGrams) / 100;

  factory LoggedFoodModel.fromJson(Map<String, dynamic> json) {
    return LoggedFoodModel(
      foodId: json['foodId'] as String? ?? '',
      foodName: json['foodName'] as String? ?? '',
      amountGrams: (json['amountGrams'] as num?)?.toDouble() ?? 0,
      mealType: json['mealType'] as String? ?? '',
      kepUrl: json['kepUrl'] as String? ?? '',
      receptbol: json['receptbol'] as bool? ?? false,
      receptId: json['receptId'] as String? ?? '',
      adagSzam: (json['adagSzam'] as num?)?.toDouble() ?? 1,
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
        'kepUrl': kepUrl,
        'receptbol': receptbol,
        'receptId': receptId,
        'adagSzam': adagSzam,
        'caloriesPer100g': caloriesPer100g,
        'proteinPer100g': proteinPer100g,
        'carbsPer100g': carbsPer100g,
        'fatPer100g': fatPer100g,
      };

  LoggedFoodModel copyWith({
    double? amountGrams,
    double? adagSzam,
    String? mealType,
  }) {
    return LoggedFoodModel(
      foodId: foodId,
      foodName: foodName,
      amountGrams: amountGrams ?? this.amountGrams,
      mealType: mealType ?? this.mealType,
      kepUrl: kepUrl,
      receptbol: receptbol,
      receptId: receptId,
      adagSzam: adagSzam ?? this.adagSzam,
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

class ReceptListaElemModel {
  ReceptListaElemModel({
    required this.id,
    required this.nev,
    required this.kategoria,
    required this.kepUrl,
    required this.becsultKaloria,
    this.becsultFeherje = 0,
    this.becsultSzenhidrat = 0,
    this.becsultZsir = 0,
    this.hozzavaloSzam = 0,
    this.yazioCimkek = const [],
  });

  final String id;
  final String nev;
  final String kategoria;
  final String kepUrl;
  final int becsultKaloria;
  final double becsultFeherje;
  final double becsultSzenhidrat;
  final double becsultZsir;
  final int hozzavaloSzam;
  final List<String> yazioCimkek;

  factory ReceptListaElemModel.fromJson(Map<String, dynamic> json) {
    return ReceptListaElemModel(
      id: json['id'] as String? ?? '',
      nev: json['nev'] as String? ?? '',
      kategoria: json['kategoria'] as String? ?? '',
      kepUrl: json['kepUrl'] as String? ?? '',
      becsultKaloria: (json['becsultKaloria'] as num?)?.round() ?? 0,
      becsultFeherje: (json['becsultFeherje'] as num?)?.toDouble() ?? 0,
      becsultSzenhidrat: (json['becsultSzenhidrat'] as num?)?.toDouble() ?? 0,
      becsultZsir: (json['becsultZsir'] as num?)?.toDouble() ?? 0,
      hozzavaloSzam: (json['hozzavaloSzam'] as num?)?.round() ?? 0,
      yazioCimkek: (json['yazioCimkek'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
    );
  }
}

class ReceptReszletesModel extends ReceptListaElemModel {
  ReceptReszletesModel({
    required super.id,
    required super.nev,
    required super.kategoria,
    required super.kepUrl,
    required super.becsultKaloria,
    super.becsultFeherje,
    super.becsultSzenhidrat,
    super.becsultZsir,
    super.hozzavaloSzam,
    super.yazioCimkek,
    this.leiras = '',
    this.youtubeUrl = '',
    this.szarmazasiTerulet = '',
    this.osszetevok = const [],
  });

  final String leiras;
  final String youtubeUrl;
  final String szarmazasiTerulet;
  final List<ReceptOsszetevoModel> osszetevok;

  factory ReceptReszletesModel.fromJson(Map<String, dynamic> json) {
    return ReceptReszletesModel(
      id: json['id'] as String? ?? '',
      nev: json['nev'] as String? ?? '',
      kategoria: json['kategoria'] as String? ?? '',
      kepUrl: json['kepUrl'] as String? ?? '',
      becsultKaloria: (json['becsultKaloria'] as num?)?.round() ?? 0,
      becsultFeherje: (json['becsultFeherje'] as num?)?.toDouble() ?? 0,
      becsultSzenhidrat: (json['becsultSzenhidrat'] as num?)?.toDouble() ?? 0,
      becsultZsir: (json['becsultZsir'] as num?)?.toDouble() ?? 0,
      hozzavaloSzam: (json['hozzavaloSzam'] as num?)?.round() ?? 0,
      yazioCimkek: (json['yazioCimkek'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
      leiras: json['leiras'] as String? ?? '',
      youtubeUrl: json['youtubeUrl'] as String? ?? '',
      szarmazasiTerulet: json['szarmazasiTerulet'] as String? ?? '',
      osszetevok: (json['osszetevok'] as List<dynamic>? ?? [])
          .map((e) => ReceptOsszetevoModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ReceptOsszetevoModel {
  ReceptOsszetevoModel({required this.nev, required this.mennyiseg});

  final String nev;
  final String mennyiseg;

  factory ReceptOsszetevoModel.fromJson(Map<String, dynamic> json) {
    return ReceptOsszetevoModel(
      nev: json['nev'] as String? ?? '',
      mennyiseg: json['mennyiseg'] as String? ?? '',
    );
  }
}

class ReceptKategoriaModel {
  ReceptKategoriaModel({required this.id, required this.nev, this.ikon = ''});

  final String id;
  final String nev;
  final String ikon;

  factory ReceptKategoriaModel.fromJson(Map<String, dynamic> json) {
    return ReceptKategoriaModel(
      id: json['id'] as String? ?? '',
      nev: json['nev'] as String? ?? '',
      ikon: json['ikon'] as String? ?? '',
    );
  }
}

class KaloriaTartomanyModel {
  KaloriaTartomanyModel({required this.min, required this.max, required this.nev});

  final int min;
  final int max;
  final String nev;

  factory KaloriaTartomanyModel.fromJson(Map<String, dynamic> json) {
    return KaloriaTartomanyModel(
      min: (json['min'] as num?)?.round() ?? 0,
      max: (json['max'] as num?)?.round() ?? 0,
      nev: json['nev'] as String? ?? '',
    );
  }
}

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
