import 'workout_models.dart';

class PlanModel {
  PlanModel({
    required this.id,
    required this.title,
    required this.difficulty,
    required this.targetMuscle,
    required this.sportCategory,
    required this.exerciseIds,
    required this.exerciseNames,
    this.creatorName = '',
    this.exerciseTemplates = const [],
    this.sourcePostId = '',
  });

  final String id;
  final String title;
  final String difficulty;
  final String targetMuscle;
  final String sportCategory;
  final List<String> exerciseIds;
  final List<String> exerciseNames;
  final String creatorName;
  final List<LoggedExerciseModel> exerciseTemplates;
  final String sourcePostId;

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

  factory PlanModel.fromJson(Map<String, dynamic> json) {
    return PlanModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      difficulty: json['difficulty'] as String? ?? 'beginner',
      targetMuscle: json['targetMuscle'] as String? ?? '',
      sportCategory: json['sportCategory'] as String? ?? 'gym',
      exerciseIds: (json['exerciseIds'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
      exerciseNames: (json['exerciseNames'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
      creatorName: json['creatorName'] as String? ?? '',
      exerciseTemplates: (json['exerciseTemplates'] as List<dynamic>? ?? [])
          .map((e) => LoggedExerciseModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      sourcePostId: json['sourcePostId'] as String? ?? '',
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
        if (sourcePostId.isNotEmpty) 'sourcePostId': sourcePostId,
        if (exerciseTemplates.isNotEmpty)
          'exerciseTemplates': exerciseTemplates.map((g) => g.toJson()).toList(),
      };

  PlanModel copyWith({
    String? title,
    List<String>? exerciseIds,
    List<String>? exerciseNames,
    List<LoggedExerciseModel>? exerciseTemplates,
    String? sourcePostId,
  }) {
    return PlanModel(
      id: id,
      title: title ?? this.title,
      difficulty: difficulty,
      targetMuscle: targetMuscle,
      sportCategory: sportCategory,
      exerciseIds: exerciseIds ?? this.exerciseIds,
      exerciseNames: exerciseNames ?? this.exerciseNames,
      creatorName: creatorName,
      exerciseTemplates: exerciseTemplates ?? this.exerciseTemplates,
      sourcePostId: sourcePostId ?? this.sourcePostId,
    );
  }
}

class PlanGroup {
  PlanGroup({
    required this.cim,
    required this.plans,
    this.alapSablon = false,
  });

  final String cim;
  final List<PlanModel> plans;
  final bool alapSablon;
}
