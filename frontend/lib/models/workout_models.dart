class LoggedSetModel {
  LoggedSetModel({
    required this.setNumber,
    this.bemelegites = false,
    this.weight = 0,
    this.reps = 0,
    this.celIsmetles = '',
    this.rpe = 0,
    this.elvegezve = false,
    this.elozoSulyKg = 0,
    this.elozoIsmetles = 0,
  });

  final int setNumber;
  final bool bemelegites;
  final double weight;
  final int reps;
  final String celIsmetles;
  final int rpe;
  final bool elvegezve;
  final double elozoSulyKg;
  final int elozoIsmetles;

  String get setLabel => bemelegites ? 'W' : '$setNumber';

  String get elozoSzoveg {
    if (elozoSulyKg > 0 || elozoIsmetles > 0) {
      return '${elozoSulyKg == elozoSulyKg.roundToDouble() ? elozoSulyKg.toInt() : elozoSulyKg} × $elozoIsmetles';
    }
    return '-';
  }

  factory LoggedSetModel.fromJson(Map<String, dynamic> json) {
    return LoggedSetModel(
      setNumber: json['setNumber'] as int? ?? 0,
      bemelegites: json['bemelegites'] as bool? ?? false,
      weight: (json['weight'] as num?)?.toDouble() ?? 0,
      reps: json['reps'] as int? ?? 0,
      celIsmetles: json['celIsmetles'] as String? ?? '',
      rpe: json['rpe'] as int? ?? 0,
      elvegezve: json['elvegezve'] as bool? ?? false,
      elozoSulyKg: (json['elozoSulyKg'] as num?)?.toDouble() ?? 0,
      elozoIsmetles: json['elozoIsmetles'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'setNumber': setNumber,
        'bemelegites': bemelegites,
        'weight': weight,
        'reps': reps,
        'celIsmetles': celIsmetles,
        'rpe': rpe,
        'elvegezve': elvegezve,
        'elozoSulyKg': elozoSulyKg,
        'elozoIsmetles': elozoIsmetles,
      };

  LoggedSetModel copyWith({
    int? setNumber,
    bool? bemelegites,
    double? weight,
    int? reps,
    String? celIsmetles,
    int? rpe,
    bool? elvegezve,
    double? elozoSulyKg,
    int? elozoIsmetles,
  }) {
    return LoggedSetModel(
      setNumber: setNumber ?? this.setNumber,
      bemelegites: bemelegites ?? this.bemelegites,
      weight: weight ?? this.weight,
      reps: reps ?? this.reps,
      celIsmetles: celIsmetles ?? this.celIsmetles,
      rpe: rpe ?? this.rpe,
      elvegezve: elvegezve ?? this.elvegezve,
      elozoSulyKg: elozoSulyKg ?? this.elozoSulyKg,
      elozoIsmetles: elozoIsmetles ?? this.elozoIsmetles,
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

  int get elvegzettSorozatok => sets.where((s) => s.elvegezve).length;

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
    this.osszTomegKg = 0,
    this.osszSorozatSzam = 0,
    this.elteltMasodperc = 0,
  });

  final int id;
  final String title;
  final DateTime? startTime;
  final int durationSeconds;
  final bool isActive;
  final List<LoggedExerciseModel> exercises;
  final double osszTomegKg;
  final int osszSorozatSzam;
  final int elteltMasodperc;

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
      osszTomegKg: (json['osszTomegKg'] as num?)?.toDouble() ?? 0,
      osszSorozatSzam: json['osszSorozatSzam'] as int? ?? 0,
      elteltMasodperc: json['elteltMasodperc'] as int? ?? 0,
    );
  }

  static List<LoggedSetModel> alapSorozatok() {
    return [
      LoggedSetModel(setNumber: 1, bemelegites: true, celIsmetles: '10'),
      LoggedSetModel(setNumber: 2, bemelegites: true, celIsmetles: '4-6'),
      LoggedSetModel(setNumber: 3, bemelegites: false, celIsmetles: '10-12'),
      LoggedSetModel(setNumber: 4, bemelegites: false, celIsmetles: '10-12'),
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
    final mp = durationSeconds > 0 ? durationSeconds : elteltMasodperc;
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
      osszTomegKg: osszTomegKg,
      osszSorozatSzam: osszSorozatSzam,
      elteltMasodperc: elteltMasodperc,
    );
  }
}
