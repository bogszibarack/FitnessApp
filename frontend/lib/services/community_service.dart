import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/community_models.dart';

class CommunityService {
  CommunityService._();
  static final CommunityService instance = CommunityService._();

  final String _base = ApiConfig.baseUrl;
  final String _userName = ApiConfig.defaultUserName;

  void _ellenorzes(http.Response r) {
    if (r.statusCode < 200 || r.statusCode >= 300) {
      throw Exception('Hiba ${r.statusCode}: ${r.body}');
    }
  }

  // ─── Feed ────────────────────────────────────────────────────────────────

  Future<List<CommunityPosztModel>> feed() async {
    final r = await http.get(Uri.parse('$_base/api/community/feed'));
    _ellenorzes(r);
    final lista = jsonDecode(r.body) as List<dynamic>;
    return lista.map((e) => CommunityPosztModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<CommunityPosztModel>> feedMegyeSzerint(String megye) async {
    final r = await http.get(Uri.parse('$_base/api/community/feed/megye/$megye'));
    _ellenorzes(r);
    final lista = jsonDecode(r.body) as List<dynamic>;
    return lista.map((e) => CommunityPosztModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ─── Like ─────────────────────────────────────────────────────────────────

  Future<CommunityPosztModel> like(String posztId) async {
    final r = await http.post(
      Uri.parse('$_base/api/community/$posztId/like'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'userName': _userName}),
    );
    _ellenorzes(r);
    return CommunityPosztModel.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  Future<CommunityPosztModel> unlike(String posztId) async {
    final r = await http.delete(
      Uri.parse('$_base/api/community/$posztId/like?userName=${Uri.encodeComponent(_userName)}'),
    );
    _ellenorzes(r);
    return CommunityPosztModel.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  // ─── Kommentek ────────────────────────────────────────────────────────────

  Future<List<CommunityKommentModel>> kommentek(String posztId) async {
    final r = await http.get(Uri.parse('$_base/api/community/$posztId/kommentek'));
    _ellenorzes(r);
    final lista = jsonDecode(r.body) as List<dynamic>;
    return lista.map((e) => CommunityKommentModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<CommunityKommentModel> kommentIrasa(String posztId, String szoveg) async {
    final r = await http.post(
      Uri.parse('$_base/api/community/$posztId/komment'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'userName': _userName, 'szoveg': szoveg}),
    );
    _ellenorzes(r);
    return CommunityKommentModel.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  // ─── Rutinmentés ─────────────────────────────────────────────────────────

  Future<void> mentesRutinkent(String posztId) async {
    final r = await http.post(
      Uri.parse('$_base/api/community/$posztId/mentes-rutinkent?userName=${Uri.encodeComponent(_userName)}'),
    );
    _ellenorzes(r);
  }

  // ─── Felhasználó-keresés ──────────────────────────────────────────────────

  Future<List<CommunityFelhasznaloModel>> felhasznalokKeresese([String? kereses]) async {
    final url = kereses != null && kereses.isNotEmpty
        ? '$_base/api/community/felhasznalok?kereses=${Uri.encodeComponent(kereses)}'
        : '$_base/api/community/felhasznalok';
    final r = await http.get(Uri.parse(url));
    _ellenorzes(r);
    final lista = jsonDecode(r.body) as List<dynamic>;
    return lista.map((e) => CommunityFelhasznaloModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<CommunityPosztModel>> felhasznaloPosztjai(String userName) async {
    final r = await http.get(Uri.parse('$_base/api/community/felhasznalo/${Uri.encodeComponent(userName)}'));
    _ellenorzes(r);
    final lista = jsonDecode(r.body) as List<dynamic>;
    return lista.map((e) => CommunityPosztModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ─── Követés ──────────────────────────────────────────────────────────────

  Future<void> kovet(String kovetett) async {
    final r = await http.post(
      Uri.parse('$_base/api/community/kovet/${Uri.encodeComponent(kovetett)}?koveto=${Uri.encodeComponent(_userName)}'),
    );
    _ellenorzes(r);
  }

  Future<void> kovetesVisszavon(String kovetett) async {
    final r = await http.delete(
      Uri.parse('$_base/api/community/kovet/${Uri.encodeComponent(kovetett)}?koveto=${Uri.encodeComponent(_userName)}'),
    );
    _ellenorzes(r);
  }

  Future<Map<String, dynamic>> kovetesek() async {
    final r = await http.get(
      Uri.parse('$_base/api/community/kovetesek?userName=${Uri.encodeComponent(_userName)}'),
    );
    _ellenorzes(r);
    return jsonDecode(r.body) as Map<String, dynamic>;
  }
}
