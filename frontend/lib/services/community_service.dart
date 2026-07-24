import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/community_models.dart';

class CommunityService {
  CommunityService._();
  static final CommunityService instance = CommunityService._();

  final String _base = ApiConfig.baseUrl;
  final String _userName = ApiConfig.defaultUserName;

  void check(http.Response r) {
    if (r.statusCode < 200 || r.statusCode >= 300) {
      throw Exception('Hiba ${r.statusCode}: ${r.body}');
    }
  }

  // ─── Feed ────────────────────────────────────────────────────────────────

  Future<List<CommunityPostModel>> feed() async {
    final r = await http.get(Uri.parse('$_base/api/community/feed'));
    check(r);
    final lista = jsonDecode(r.body) as List<dynamic>;
    return lista.map((e) => CommunityPostModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<CommunityPostModel>> feedByCounty(String countyId) async {
    final r = await http.get(Uri.parse('$_base/api/community/feed/county/$countyId'));
    check(r);
    final lista = jsonDecode(r.body) as List<dynamic>;
    return lista.map((e) => CommunityPostModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<CommunityPostModel>> feedByRegion(String region) async {
    final r = await http.get(
      Uri.parse('$_base/api/community/feed/region/${Uri.encodeComponent(region)}'),
    );
    check(r);
    final lista = jsonDecode(r.body) as List<dynamic>;
    return lista.map((e) => CommunityPostModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ─── Like ─────────────────────────────────────────────────────────────────

  Future<CommunityPostModel> like(String postId) async {
    final r = await http.post(
      Uri.parse('$_base/api/community/$postId/like'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'userName': _userName}),
    );
    check(r);
    return CommunityPostModel.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  Future<CommunityPostModel> unlike(String postId) async {
    final r = await http.delete(
      Uri.parse('$_base/api/community/$postId/like?userName=${Uri.encodeComponent(_userName)}'),
    );
    check(r);
    return CommunityPostModel.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  // ─── Comments ────────────────────────────────────────────────────────────

  Future<List<CommunityCommentModel>> comments(String postId) async {
    final r = await http.get(Uri.parse('$_base/api/community/$postId/comments'));
    check(r);
    final lista = jsonDecode(r.body) as List<dynamic>;
    return lista.map((e) => CommunityCommentModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<CommunityCommentModel> addComment(String postId, String text) async {
    final r = await http.post(
      Uri.parse('$_base/api/community/$postId/comment'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'userName': _userName, 'text': text}),
    );
    check(r);
    return CommunityCommentModel.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  // ─── Save as plan ─────────────────────────────────────────────────────────

  Future<void> saveAsPlan(String postId) async {
    final r = await http.post(
      Uri.parse('$_base/api/community/$postId/save-as-plan?userName=${Uri.encodeComponent(_userName)}'),
    );
    check(r);
  }

  // ─── User search ──────────────────────────────────────────────────────────

  Future<List<CommunityUserModel>> searchUsers([String? query]) async {
    final url = query != null && query.isNotEmpty
        ? '$_base/api/community/users?q=${Uri.encodeComponent(query)}'
        : '$_base/api/community/users';
    final r = await http.get(Uri.parse(url));
    check(r);
    final lista = jsonDecode(r.body) as List<dynamic>;
    return lista.map((e) => CommunityUserModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<CommunityPostModel>> userPosts(String userName) async {
    final r = await http.get(Uri.parse('$_base/api/community/user/${Uri.encodeComponent(userName)}'));
    check(r);
    final lista = jsonDecode(r.body) as List<dynamic>;
    return lista.map((e) => CommunityPostModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ─── Follow ──────────────────────────────────────────────────────────────

  Future<void> follow(String target) async {
    final r = await http.post(
      Uri.parse('$_base/api/community/follow/${Uri.encodeComponent(target)}?follower=${Uri.encodeComponent(_userName)}'),
    );
    check(r);
  }

  Future<void> unfollow(String target) async {
    final r = await http.delete(
      Uri.parse('$_base/api/community/follow/${Uri.encodeComponent(target)}?follower=${Uri.encodeComponent(_userName)}'),
    );
    check(r);
  }

  Future<Map<String, dynamic>> follows() async {
    final r = await http.get(
      Uri.parse('$_base/api/community/follows?userName=${Uri.encodeComponent(_userName)}'),
    );
    check(r);
    return jsonDecode(r.body) as Map<String, dynamic>;
  }
}
