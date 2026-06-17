import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/routine_model.dart';
import '../models/workout_models.dart';

class WorkoutService {
  WorkoutService._();
  static final WorkoutService instance = WorkoutService._();

  final String _base = ApiConfig.baseUrl;

  Future<List<RoutineModel>> aiAjanlatok({
    String difficulty = 'beginner',
    String targetMuscle = 'Chest',
    String sportCategory = 'gym',
  }) async {
    final response = await http.post(
      Uri.parse('$_base/api/routine/ai-generalas'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'difficulty': difficulty,
        'targetMuscle': targetMuscle,
        'sportCategory': sportCategory,
      }),
    );
    _ellenorzes(response);
    final lista = jsonDecode(response.body) as List<dynamic>;
    return lista.map((e) => RoutineModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<RoutineModel>> sajatRutinok() async {
    return _getLista('/api/routine/sajatok');
  }

  Future<List<WorkoutSessionModel>> edzesTortenet() async {
    final response = await http.get(Uri.parse('$_base/api/workout/history'));
    _ellenorzes(response);
    final lista = jsonDecode(response.body) as List<dynamic>;
    return lista
        .map((e) => WorkoutSessionModel.fromJson(e as Map<String, dynamic>))
        .toList()
        .reversed
        .toList();
  }

  Future<List<RoutineModel>> _getLista(String ut) async {
    final response = await http.get(Uri.parse('$_base$ut'));
    _ellenorzes(response);
    final lista = jsonDecode(response.body) as List<dynamic>;
    return lista.map((e) => RoutineModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<WorkoutSessionModel> uresEdzesInditasa() async {
    final response = await http.post(Uri.parse('$_base/api/workout/uj-ures-edzes'));
    _ellenorzes(response);
    return WorkoutSessionModel.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<WorkoutSessionModel> rutinInditasa(RoutineModel rutin, {bool mentett = false}) async {
    final uri = mentett && rutin.id.isNotEmpty
        ? Uri.parse('$_base/api/workout/inditas-rutinbol/${rutin.id}')
        : Uri.parse('$_base/api/workout/inditas-rutinbol');

    final response = mentett && rutin.id.isNotEmpty
        ? await http.post(uri)
        : await http.post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(rutin.toJson()),
          );

    _ellenorzes(response);
    return WorkoutSessionModel.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<WorkoutSessionModel?> aktivEdzes() async {
    final response = await http.get(Uri.parse('$_base/api/workout/aktiv'));
    if (response.statusCode == 404) return null;
    _ellenorzes(response);
    return WorkoutSessionModel.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<WorkoutSessionModel> edzesBefejezese() async {
    final response = await http.post(Uri.parse('$_base/api/workout/aktiv/befejezes'));
    _ellenorzes(response);
    return WorkoutSessionModel.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> edzesElvetese() async {
    final response = await http.delete(Uri.parse('$_base/api/workout/aktiv'));
    _ellenorzes(response);
  }

  Future<void> edzesCimFrissitese(String cim) async {
    final response = await http.put(
      Uri.parse('$_base/api/workout/aktiv'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'title': cim}),
    );
    _ellenorzes(response);
  }

  Future<LoggedExerciseModel> gyakorlatHozzaadasa({
    required String exerciseId,
    required String exerciseName,
    List<LoggedSetModel>? sets,
  }) async {
    final response = await http.post(
      Uri.parse('$_base/api/workout/aktiv/gyakorlat-hozzaadas'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'exerciseId': exerciseId,
        'exerciseName': exerciseName,
        'sets': (sets ?? []).map((s) => s.toJson()).toList(),
      }),
    );
    _ellenorzes(response);
    var gyakorlat = LoggedExerciseModel.fromJson(jsonDecode(response.body) as Map<String, dynamic>);

    if (sets != null && sets.isNotEmpty) {
      gyakorlat = await sorozatokFrissitese(exerciseId, sets);
    }

    return gyakorlat;
  }

  Future<LoggedExerciseModel> gyakorlatLekerdezese(String exerciseId) async {
    final response = await http.get(Uri.parse('$_base/api/workout/aktiv/gyakorlat/${Uri.encodeComponent(exerciseId)}'));
    _ellenorzes(response);
    return LoggedExerciseModel.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<LoggedExerciseModel> sorozatokFrissitese(String exerciseId, List<LoggedSetModel> sorozatok) async {
    final response = await http.put(
      Uri.parse('$_base/api/workout/aktiv/gyakorlat/${Uri.encodeComponent(exerciseId)}/sorozatok'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(sorozatok.map((s) => s.toJson()).toList()),
    );
    _ellenorzes(response);
    return LoggedExerciseModel.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<LoggedSetModel> sorozatHozzaadasa(String exerciseId, {bool bemelegites = false}) async {
    final response = await http.post(
      Uri.parse('$_base/api/workout/aktiv/gyakorlat/${Uri.encodeComponent(exerciseId)}/sorozat'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'setNumber': 0,
        'bemelegites': bemelegites,
        'weight': 0,
        'reps': 0,
        'celIsmetles': bemelegites ? '10' : '10-12',
        'elvegezve': false,
      }),
    );
    _ellenorzes(response);
    return LoggedSetModel.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<LoggedSetModel> sorozatModositasa(
    String exerciseId,
    int sorozatSzam, {
    required double weight,
    required int reps,
    String? celIsmetles,
  }) async {
    final response = await http.put(
      Uri.parse('$_base/api/workout/aktiv/gyakorlat/${Uri.encodeComponent(exerciseId)}/sorozat/$sorozatSzam'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'weight': weight,
        'reps': reps,
        if (celIsmetles != null) 'celIsmetles': celIsmetles,
      }),
    );
    _ellenorzes(response);
    return LoggedSetModel.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<LoggedSetModel> sorozatPipalasa(
    String exerciseId,
    int sorozatSzam, {
    required double weight,
    required int reps,
  }) async {
    final response = await http.post(
      Uri.parse('$_base/api/workout/aktiv/gyakorlat/${Uri.encodeComponent(exerciseId)}/sorozat/$sorozatSzam/pipa'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'weight': weight, 'reps': reps}),
    );
    _ellenorzes(response);
    return LoggedSetModel.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<LoggedSetModel> sorozatPipaVisszavonasa(String exerciseId, int sorozatSzam) async {
    final response = await http.delete(
      Uri.parse('$_base/api/workout/aktiv/gyakorlat/${Uri.encodeComponent(exerciseId)}/sorozat/$sorozatSzam/pipa'),
    );
    _ellenorzes(response);
    return LoggedSetModel.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> sorozatTorlese(String exerciseId, int sorozatSzam) async {
    final response = await http.delete(
      Uri.parse('$_base/api/workout/aktiv/gyakorlat/${Uri.encodeComponent(exerciseId)}/sorozat/$sorozatSzam'),
    );
    _ellenorzes(response);
  }

  Future<void> gyakorlatTorlese(String exerciseId) async {
    final response = await http.delete(
      Uri.parse('$_base/api/workout/aktiv/gyakorlat/${Uri.encodeComponent(exerciseId)}'),
    );
    _ellenorzes(response);
  }

  Future<RoutineModel> rutinMentese(RoutineModel rutin) async {
    final response = await http.post(
      Uri.parse('$_base/api/routine/mentes'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(rutin.toJson()),
    );
    _ellenorzes(response);
    return RoutineModel.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<RoutineModel> rutinMenteseEdzesbol({
    required WorkoutSessionModel edzes,
    required String rutinCim,
  }) async {
    final gyakorlatok = edzes.exercises;
    final rutin = {
      'title': rutinCim,
      'difficulty': 'beginner',
      'targetMuscle': gyakorlatok.isNotEmpty ? 'Full Body' : 'General',
      'sportCategory': 'gym',
      'creatorName': ApiConfig.defaultUserName,
      'exerciseIds': gyakorlatok.map((g) => g.exerciseId).toList(),
      'exerciseNames': gyakorlatok.map((g) => g.exerciseName).toList(),
      'gyakorlatSablonok': gyakorlatok.map((g) => g.toJson()).toList(),
    };

    final response = await http.post(
      Uri.parse('$_base/api/routine/mentes'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(rutin),
    );
    _ellenorzes(response);
    return RoutineModel.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<RoutineModel> rutinModositas(RoutineModel rutin) async {
    final response = await http.put(
      Uri.parse('$_base/api/routine/${rutin.id}'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(rutin.toJson()),
    );
    _ellenorzes(response);
    return RoutineModel.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> rutinTorlese(String rutinId) async {
    final response = await http.delete(Uri.parse('$_base/api/routine/$rutinId'));
    _ellenorzes(response);
  }

  Future<WorkoutSessionModel> edzesTortenetModositas(WorkoutSessionModel edzes) async {
    final response = await http.put(
      Uri.parse('$_base/api/workout/history/${edzes.id}'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(edzes.toJson()),
    );
    _ellenorzes(response);
    return WorkoutSessionModel.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> edzesTortenetTorlese(int edzesId) async {
    final response = await http.delete(Uri.parse('$_base/api/workout/history/$edzesId'));
    _ellenorzes(response);
  }

  Future<WorkoutSessionModel?> aktivEdzesVagyNull() => aktivEdzes();

  void _ellenorzes(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('API hiba (${response.statusCode}): ${response.body}');
    }
  }
}
