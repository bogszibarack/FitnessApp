import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../config/api_config.dart';
import '../models/beallitas_models.dart';

class SettingsService {
  SettingsService({String? userName}) : userName = userName ?? ApiConfig.defaultUserName;

  final String userName;
  final String _base = ApiConfig.baseUrl;

  Future<List<BeallitasMenuSzekcio>> menuLekerdezes() async {
    final response = await http.get(
      Uri.parse('$_base/api/settings/menu/$userName'),
    );
    _check(response);
    final lista = jsonDecode(response.body) as List<dynamic>;
    return lista
        .map((e) => BeallitasMenuSzekcio.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, dynamic>> getSzekcio(String path) async {
    final response = await http.get(Uri.parse('$_base$path'));
    _check(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> putSzekcio(String path, Map<String, dynamic> body) async {
    final response = await http.put(
      Uri.parse('$_base$path'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    _check(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<List<ValasztasiOpcio>> nyelvek() => _opcioLista('/api/settings/options/languages');
  Future<List<ValasztasiOpcio>> temak() => _opcioLista('/api/settings/options/themes');
  Future<List<ValasztasiOpcio>> hetNapjai() => _opcioLista('/api/settings/options/week-start');
  Future<List<ValasztasiOpcio>> lathatosag() => _opcioLista('/api/settings/options/visibility');

  Future<Map<String, dynamic>> egysegOpcio() async {
    final response = await http.get(Uri.parse('$_base/api/settings/options/units'));
    _check(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<dynamic> statikusTartalom(String path) async {
    final response = await http.get(Uri.parse('$_base$path'));
    _check(response);
    return jsonDecode(response.body);
  }

  Future<void> kapcsolatUzenet({
    required String email,
    required String uzenet,
    String targy = 'Segitsegkeres',
  }) async {
    final response = await http.post(
      Uri.parse('$_base/api/settings/contact'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'userName': userName,
        'email': email,
        'subject': targy,
        'message': uzenet,
        'targy': targy,
        'uzenet': uzenet,
      }),
    );
    _check(response);
  }

  Future<String> profilKepFeltoltes(XFile kep) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_base/api/settings/$userName/profile/photo'),
    );
    final bytes = await kep.readAsBytes();
    final nev = kep.name.isNotEmpty ? kep.name : 'profil.jpg';
    request.files.add(http.MultipartFile.fromBytes('kep', bytes, filename: nev));

    final streamed = await request.send().timeout(const Duration(seconds: 30));
    final response = await http.Response.fromStream(streamed);
    _check(response);
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['imageUrl'] ?? data['kepUrl'] as String? ?? '';
  }

  Future<Map<String, dynamic>> exportAdatok() async {
    final response = await http.get(Uri.parse('$_base/api/settings/$userName/export'));
    _check(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<List<ValasztasiOpcio>> _opcioLista(String path) async {
    final response = await http.get(Uri.parse('$_base$path'));
    _check(response);
    final lista = jsonDecode(response.body) as List<dynamic>;
    return lista
        .map((e) => ValasztasiOpcio.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  void _check(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('API hiba (${response.statusCode}): ${response.body}');
    }
  }
}
