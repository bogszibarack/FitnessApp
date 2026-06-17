import 'workout_models.dart';

class RoutineModel {
  RoutineModel({
    required this.id,
    required this.title,
    required this.difficulty,
    required this.targetMuscle,
    required this.sportCategory,
    required this.exerciseIds,
    required this.exerciseNames,
    this.creatorName = '',
    this.gyakorlatSablonok = const [],
  });

  final String id;
  final String title;
  final String difficulty;
  final String targetMuscle;
  final String sportCategory;
  final List<String> exerciseIds;
  final List<String> exerciseNames;
  final String creatorName;
  final List<LoggedExerciseModel> gyakorlatSablonok;

  String get previewText {
    if (exerciseNames.isEmpty) return 'Nincs gyakorlat';
    final joined = exerciseNames.join(', ');
    return joined.length > 72 ? '${joined.substring(0, 72)}...' : joined;
  }

  String get magyarCim {
    switch (title.toLowerCase()) {
      case 'push':
        return 'Nyomás';
      case 'pull':
        return 'Húzás';
      case 'legs':
        return 'Láb';
      default:
        return title;
    }
  }

  factory RoutineModel.fromJson(Map<String, dynamic> json) {
    return RoutineModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      difficulty: json['difficulty'] as String? ?? 'beginner',
      targetMuscle: json['targetMuscle'] as String? ?? '',
      sportCategory: json['sportCategory'] as String? ?? 'gym',
      exerciseIds: (json['exerciseIds'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
      exerciseNames: (json['exerciseNames'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
      creatorName: json['creatorName'] as String? ?? '',
      gyakorlatSablonok: (json['gyakorlatSablonok'] as List<dynamic>? ?? [])
          .map((e) => LoggedExerciseModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'difficulty': difficulty,
        'targetMuscle': targetMuscle,
        'sportCategory': sportCategory,
        'exerciseIds': exerciseIds,
        'exerciseNames': exerciseNames,
        'creatorName': creatorName,
        if (gyakorlatSablonok.isNotEmpty)
          'gyakorlatSablonok': gyakorlatSablonok.map((g) => g.toJson()).toList(),
      };

  RoutineModel copyWith({
    String? title,
    List<String>? exerciseIds,
    List<String>? exerciseNames,
    List<LoggedExerciseModel>? gyakorlatSablonok,
  }) {
    return RoutineModel(
      id: id,
      title: title ?? this.title,
      difficulty: difficulty,
      targetMuscle: targetMuscle,
      sportCategory: sportCategory,
      exerciseIds: exerciseIds ?? this.exerciseIds,
      exerciseNames: exerciseNames ?? this.exerciseNames,
      creatorName: creatorName,
      gyakorlatSablonok: gyakorlatSablonok ?? this.gyakorlatSablonok,
    );
  }
}

class RoutineGroup {
  RoutineGroup({
    required this.cim,
    required this.rutinok,
    this.alapSablon = false,
  });

  final String cim;
  final List<RoutineModel> rutinok;
  final bool alapSablon;
}
