import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/beallitas_models.dart';

class BeallitasokService {
  BeallitasokService({String? userName}) : userName = userName ?? ApiConfig.defaultUserName;

  final String userName;
  final String _base = ApiConfig.baseUrl;

  Future<List<BeallitasMenuSzekcio>> menuLekerdezes() async {
    final response = await http.get(
      Uri.parse('$_base/api/beallitasok/menu/$userName'),
    );
    _ellenorzes(response);
    final lista = jsonDecode(response.body) as List<dynamic>;
    return lista
        .map((e) => BeallitasMenuSzekcio.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, dynamic>> getSzekcio(String ut) async {
    final response = await http.get(Uri.parse('$_base$ut'));
    _ellenorzes(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> putSzekcio(String ut, Map<String, dynamic> body) async {
    final response = await http.put(
      Uri.parse('$_base$ut'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    _ellenorzes(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<List<ValasztasiOpcio>> nyelvek() => _opcioLista('/api/beallitasok/seged/nyelvek');
  Future<List<ValasztasiOpcio>> temak() => _opcioLista('/api/beallitasok/seged/temak');
  Future<List<ValasztasiOpcio>> hetNapjai() => _opcioLista('/api/beallitasok/seged/het-napjai');
  Future<List<ValasztasiOpcio>> lathatosag() => _opcioLista('/api/beallitasok/seged/lathatosag');

  Future<Map<String, dynamic>> egysegOpcio() async {
    final response = await http.get(Uri.parse('$_base/api/beallitasok/seged/egysegek'));
    _ellenorzes(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<dynamic> statikusTartalom(String ut) async {
    final response = await http.get(Uri.parse('$_base$ut'));
    _ellenorzes(response);
    return jsonDecode(response.body);
  }

  Future<void> kapcsolatUzenet({
    required String email,
    required String uzenet,
    String targy = 'Segitsegkeres',
  }) async {
    final response = await http.post(
      Uri.parse('$_base/api/beallitasok/kapcsolat'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'userName': userName,
        'email': email,
        'targy': targy,
        'uzenet': uzenet,
      }),
    );
    _ellenorzes(response);
  }

  Future<Map<String, dynamic>> exportAdatok() async {
    final response = await http.get(Uri.parse('$_base/api/beallitasok/$userName/export'));
    _ellenorzes(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<List<ValasztasiOpcio>> _opcioLista(String ut) async {
    final response = await http.get(Uri.parse('$_base$ut'));
    _ellenorzes(response);
    final lista = jsonDecode(response.body) as List<dynamic>;
    return lista
        .map((e) => ValasztasiOpcio.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  void _ellenorzes(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('API hiba (${response.statusCode}): ${response.body}');
    }
  }
}
