class ExerciseModel {
  ExerciseModel({
    required this.id,
    required this.name,
    required this.muscleGroup,
    required this.equipment,
    required this.category,
    this.images = const [],
    this.instructions = const [],
    this.primaryMuscles = const [],
  });

  final String id;
  final String name;
  final String muscleGroup;
  final String equipment;
  final String category;
  final List<String> images;
  final List<String> instructions;
  final List<String> primaryMuscles;

  bool get vanAnimacio => images.length > 1;

  factory ExerciseModel.fromJson(Map<String, dynamic> json) {
    return ExerciseModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      muscleGroup: json['muscleGroup'] as String? ?? '',
      equipment: json['equipment'] as String? ?? '',
      category: json['category'] as String? ?? '',
      images: (json['images'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
      instructions: (json['instructions'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
      primaryMuscles: (json['primaryMuscles'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
    );
  }
}
