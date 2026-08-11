/// Edzés beállítások — GET /api/settings/{userName}/workout
class WorkoutSettings {
  const WorkoutSettings({
    this.restTimerSeconds = 90,
    this.trackRpe = true,
    this.smartSuperset = true,
    this.sounds = true,
    this.prSound = true,
  });

  final int restTimerSeconds;
  final bool trackRpe;
  final bool smartSuperset;
  final bool sounds;
  final bool prSound;

  bool get restTimerEnabled => restTimerSeconds > 0;

  factory WorkoutSettings.fromJson(Map<String, dynamic> json) {
    return WorkoutSettings(
      restTimerSeconds: json['restTimerSeconds'] as int? ?? 90,
      trackRpe: json['trackRpe'] as bool? ?? true,
      smartSuperset: json['smartSuperset'] as bool? ?? true,
      sounds: json['sounds'] as bool? ?? true,
      prSound: json['prSound'] as bool? ?? true,
    );
  }

  static const alap = WorkoutSettings();
}

class ProgressSettings {
  const ProgressSettings({
    this.mode = 'szazalek',
    this.percent = 5.0,
    this.kg = 2.5,
    this.repBoost = 0,
  });

  final String mode;
  final double percent;
  final double kg;
  final int repBoost;

  factory ProgressSettings.fromJson(Map<String, dynamic> json) {
    return ProgressSettings(
      mode: json['mode'] as String? ?? json['novelesModja'] as String? ?? 'szazalek',
      percent: (json['percent'] ?? json['sulySzazalek'] as num?)?.toDouble() ?? 5.0,
      kg: (json['kg'] ?? json['sulyKg'] as num?)?.toDouble() ?? 2.5,
      repBoost: json['repBoost'] as int? ?? json['ismetlesNoveles'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'mode': mode,
        'percent': percent.clamp(0.0, 20.0),
        'kg': kg,
        'repBoost': repBoost,
      };
}

class LoggedSetModel {
  LoggedSetModel({
    required this.setNumber,
    this.isWarmup = false,
    this.weight = 0,
    this.reps = 0,
    this.targetReps = '',
    this.rpe = 0,
    this.isDone = false,
    this.prevWeightKg = 0,
    this.prevReps = 0,
  });

  final int setNumber;
  final bool isWarmup;
  final double weight;
  final int reps;
  final String targetReps;
  final int rpe;
  final bool isDone;
  final double prevWeightKg;
  final int prevReps;

  String get setLabel => isWarmup ? 'W' : '$setNumber';

  String get elozoSzoveg {
    if (prevWeightKg > 0 || prevReps > 0) {
      return '${prevWeightKg == prevWeightKg.roundToDouble() ? prevWeightKg.toInt() : prevWeightKg} × $prevReps';
    }
    return '-';
  }

  factory LoggedSetModel.fromJson(Map<String, dynamic> json) {
    return LoggedSetModel(
      setNumber: json['setNumber'] as int? ?? 0,
      isWarmup: json['isWarmup'] as bool? ?? json['bemelegites'] as bool? ?? false,
      weight: (json['weight'] as num?)?.toDouble() ?? 0,
      reps: json['reps'] as int? ?? 0,
      targetReps: json['targetReps'] as String? ?? json['celIsmetles'] as String? ?? '',
      rpe: json['rpe'] as int? ?? 0,
      isDone: json['isDone'] as bool? ?? json['elvegezve'] as bool? ?? false,
      prevWeightKg: (json['prevWeightKg'] as num?)?.toDouble()
          ?? (json['elozoSulyKg'] as num?)?.toDouble()
          ?? 0,
      prevReps: json['prevReps'] as int? ?? json['elozoIsmetles'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'setNumber': setNumber,
        'isWarmup': isWarmup,
        'weight': weight,
        'reps': reps,
        'targetReps': targetReps,
        'rpe': rpe,
        'isDone': isDone,
        'prevWeightKg': prevWeightKg,
        'prevReps': prevReps,
      };

  LoggedSetModel copyWith({
    int? setNumber,
    bool? isWarmup,
    double? weight,
    int? reps,
    String? targetReps,
    int? rpe,
    bool? isDone,
    double? prevWeightKg,
    int? prevReps,
  }) {
    return LoggedSetModel(
      setNumber: setNumber ?? this.setNumber,
      isWarmup: isWarmup ?? this.isWarmup,
      weight: weight ?? this.weight,
      reps: reps ?? this.reps,
      targetReps: targetReps ?? this.targetReps,
      rpe: rpe ?? this.rpe,
      isDone: isDone ?? this.isDone,
      prevWeightKg: prevWeightKg ?? this.prevWeightKg,
      prevReps: prevReps ?? this.prevReps,
    );
  }
}

class LoggedExerciseModel {
  LoggedExerciseModel({
    required this.exerciseId,
    required this.exerciseName,
    required this.sets,
  });

  final String exerciseId;
  final String exerciseName;
  final List<LoggedSetModel> sets;

  int get elvegzettSorozatok => sets.where((s) => s.isDone).length;

  factory LoggedExerciseModel.fromJson(Map<String, dynamic> json) {
    return LoggedExerciseModel(
      exerciseId: json['exerciseId'] as String? ?? '',
      exerciseName: json['exerciseName'] as String? ?? '',
      sets: (json['sets'] as List<dynamic>? ?? [])
          .map((e) => LoggedSetModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'exerciseId': exerciseId,
        'exerciseName': exerciseName,
        'sets': sets.map((s) => s.toJson()).toList(),
      };
}

class WorkoutSessionModel {
  WorkoutSessionModel({
    required this.title,
    required this.startTime,
    required this.isActive,
    required this.exercises,
    this.id = 0,
    this.durationSeconds = 0,
    this.totalVolumeKg = 0,
    this.completedSets = 0,
    this.elapsedSeconds = 0,
  });

  final int id;
  final String title;
  final DateTime? startTime;
  final int durationSeconds;
  final bool isActive;
  final List<LoggedExerciseModel> exercises;
  final double totalVolumeKg;
  final int completedSets;
  final int elapsedSeconds;

  // Legacy aliases
  double get osszTomegKg => totalVolumeKg;
  int get osszSorozatSzam => completedSets;
  int get elteltMasodperc => elapsedSeconds;

  factory WorkoutSessionModel.fromJson(Map<String, dynamic> json) {
    return WorkoutSessionModel(
      id: json['id'] as int? ?? 0,
      title: json['title'] as String? ?? 'Üres edzés',
      startTime: json['startTime'] != null ? DateTime.tryParse(json['startTime'] as String) : null,
      durationSeconds: json['durationSeconds'] as int? ?? 0,
      isActive: json['isActive'] as bool? ?? true,
      exercises: (json['exercises'] as List<dynamic>? ?? [])
          .map((e) => LoggedExerciseModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalVolumeKg: ((json['totalVolumeKg'] ?? json['osszTomegKg']) as num?)?.toDouble() ?? 0,
      completedSets: (json['completedSets'] ?? json['osszSorozatSzam']) as int? ?? 0,
      elapsedSeconds: (json['elapsedSeconds'] ?? json['elteltMasodperc']) as int? ?? 0,
    );
  }

  static List<LoggedSetModel> alapSorozatok() {
    return [
      LoggedSetModel(setNumber: 1, isWarmup: true, targetReps: '10'),
      LoggedSetModel(setNumber: 2, isWarmup: true, targetReps: '4-6'),
      LoggedSetModel(setNumber: 3, isWarmup: false, targetReps: '10-12'),
      LoggedSetModel(setNumber: 4, isWarmup: false, targetReps: '10-12'),
    ];
  }

  String get megjelenitettCim => title == 'Empty Workout' ? 'Üres edzés' : title;

  String get datumSzoveg {
    if (startTime == null) return 'Ismeretlen dátum';
    final d = startTime!.toLocal();
    return '${d.year}. ${d.month.toString().padLeft(2, '0')}. ${d.day.toString().padLeft(2, '0')}. '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  String get idoSzoveg {
    final mp = durationSeconds > 0 ? durationSeconds : elapsedSeconds;
    final perc = mp ~/ 60;
    final masodperc = mp % 60;
    return '${perc.toString().padLeft(2, '0')}:${masodperc.toString().padLeft(2, '0')}';
  }

  String get gyakorlatOsszefoglalo {
    if (exercises.isEmpty) return 'Nincs gyakorlat';
    final nevek = exercises.map((e) => e.exerciseName).take(3).join(', ');
    return exercises.length > 3 ? '$nevek...' : nevek;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        if (startTime != null) 'startTime': startTime!.toIso8601String(),
        'durationSeconds': durationSeconds,
        'isActive': false,
        'exercises': exercises.map((e) => e.toJson()).toList(),
      };

  WorkoutSessionModel copyWith({
    String? title,
    List<LoggedExerciseModel>? exercises,
  }) {
    return WorkoutSessionModel(
      id: id,
      title: title ?? this.title,
      startTime: startTime,
      durationSeconds: durationSeconds,
      isActive: isActive,
      exercises: exercises ?? this.exercises,
      totalVolumeKg: totalVolumeKg,
      completedSets: completedSets,
      elapsedSeconds: elapsedSeconds,
    );
  }
}
