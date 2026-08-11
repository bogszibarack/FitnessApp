import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/community_models.dart';
import 'api_http.dart';
import 'local_store.dart';

class CommunityService {
  CommunityService._();
  static final CommunityService instance = CommunityService._();

  final String _base = ApiConfig.baseUrl;

  void check(http.Response r) {
    if (r.statusCode < 200 || r.statusCode >= 300) {
      throw Exception('Hiba ${r.statusCode}: ${r.body}');
    }
  }

  // ─── Feed ────────────────────────────────────────────────────────────────

  Future<List<CommunityPostModel>> feed() async {
    final r = await ApiHttp.get(Uri.parse('$_base/api/community/feed'));
    check(r);
    final lista = jsonDecode(r.body) as List<dynamic>;
    return lista
        .map((e) => CommunityPostModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<CommunityPostModel>> feedByCounty(String countyId) async {
    final r = await ApiHttp.get(
        Uri.parse('$_base/api/community/feed/county/$countyId'));
    check(r);
    final lista = jsonDecode(r.body) as List<dynamic>;
    return lista
        .map((e) => CommunityPostModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<CommunityPostModel>> feedByRegion(String region) async {
    final r = await ApiHttp.get(
      Uri.parse(
          '$_base/api/community/feed/region/${Uri.encodeComponent(region)}'),
    );
    check(r);
    final lista = jsonDecode(r.body) as List<dynamic>;
    return lista
        .map((e) => CommunityPostModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<CountyInfoModel>> counties() async {
    final r = await ApiHttp.get(Uri.parse('$_base/api/community/counties'));
    check(r);
    final lista = jsonDecode(r.body) as List<dynamic>;
    return lista
        .map((e) => CountyInfoModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<String>> regions() async {
    final r = await ApiHttp.get(Uri.parse('$_base/api/community/regions'));
    check(r);
    final lista = jsonDecode(r.body) as List<dynamic>;
    return lista.map((e) => e.toString()).toList();
  }

  // ─── Like ─────────────────────────────────────────────────────────────────

  Future<CommunityPostModel> like(String postId) async {
    final r =
        await ApiHttp.post(Uri.parse('$_base/api/community/$postId/like'));
    check(r);
    return CommunityPostModel.fromJson(
        jsonDecode(r.body) as Map<String, dynamic>);
  }

  Future<CommunityPostModel> unlike(String postId) async {
    final r =
        await ApiHttp.delete(Uri.parse('$_base/api/community/$postId/like'));
    check(r);
    return CommunityPostModel.fromJson(
        jsonDecode(r.body) as Map<String, dynamic>);
  }

  // ─── Comments ────────────────────────────────────────────────────────────

  Future<List<CommunityCommentModel>> comments(String postId) async {
    final r =
        await ApiHttp.get(Uri.parse('$_base/api/community/$postId/comments'));
    check(r);
    final lista = jsonDecode(r.body) as List<dynamic>;
    return lista
        .map((e) => CommunityCommentModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<CommunityCommentModel> addComment(String postId, String text) async {
    final r = await ApiHttp.post(
      Uri.parse('$_base/api/community/$postId/comment'),
      body: jsonEncode({'text': text}),
    );
    check(r);
    return CommunityCommentModel.fromJson(
        jsonDecode(r.body) as Map<String, dynamic>);
  }

  // ─── Save as plan ─────────────────────────────────────────────────────────

  Future<void> saveAsPlan(String postId) async {
    final r = await ApiHttp.post(
      Uri.parse('$_base/api/community/$postId/save-as-plan'),
    );
    check(r);
  }

  // ─── People / friends ──────────────────────────────────────────────────────

  Future<List<PeopleListItemModel>> people([String? query]) async {
    final url = query != null && query.isNotEmpty
        ? '$_base/api/community/people?q=${Uri.encodeComponent(query)}'
        : '$_base/api/community/people';
    final r = await ApiHttp.get(Uri.parse(url));
    check(r);
    final lista = jsonDecode(r.body) as List<dynamic>;
    return lista
        .map((e) => PeopleListItemModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Backward-compatible alias used by older screens.
  Future<List<PeopleListItemModel>> searchUsers([String? query]) =>
      people(query);

  Future<List<PeopleListItemModel>> friends() async {
    final r = await ApiHttp.get(Uri.parse('$_base/api/community/friends'));
    check(r);
    final lista = jsonDecode(r.body) as List<dynamic>;
    return lista
        .map((e) => PeopleListItemModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<PeopleListItemModel>> pendingFriends() async {
    final r =
        await ApiHttp.get(Uri.parse('$_base/api/community/friends/pending'));
    check(r);
    final lista = jsonDecode(r.body) as List<dynamic>;
    return lista
        .map((e) => PeopleListItemModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> requestFriend(String username) async {
    final r = await ApiHttp.post(Uri.parse(
        '$_base/api/community/friends/request/${Uri.encodeComponent(username)}'));
    check(r);
  }

  Future<void> acceptFriend(String requestId) async {
    final r = await ApiHttp.post(
        Uri.parse('$_base/api/community/friends/accept/$requestId'));
    check(r);
  }

  Future<void> rejectFriend(String requestId) async {
    final r = await ApiHttp.post(
        Uri.parse('$_base/api/community/friends/reject/$requestId'));
    check(r);
  }

  Future<void> unfriend(String username) async {
    final r = await ApiHttp.delete(Uri.parse(
        '$_base/api/community/friends/${Uri.encodeComponent(username)}'));
    check(r);
  }

  Future<CommunityProfileModel> profile(String userName) async {
    final r = await ApiHttp.get(Uri.parse(
        '$_base/api/community/profile/${Uri.encodeComponent(userName)}'));
    check(r);
    return CommunityProfileModel.fromJson(
        jsonDecode(r.body) as Map<String, dynamic>);
  }

  Future<List<CommunityPostModel>> userPosts(String userName) async {
    final r = await ApiHttp.get(Uri.parse(
        '$_base/api/community/user/${Uri.encodeComponent(userName)}'));
    check(r);
    final lista = jsonDecode(r.body) as List<dynamic>;
    return lista
        .map((e) => CommunityPostModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<String> uploadSelfie(List<int> bytes, String filename) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_base/api/community/selfie-upload'),
    );
    final token = await LocalStore.instance.getAccessToken();
    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    request.files.add(
      http.MultipartFile.fromBytes('file', bytes, filename: filename),
    );
    final streamed = await request.send().timeout(const Duration(seconds: 30));
    final r = await http.Response.fromStream(streamed);
    check(r);
    final data = jsonDecode(r.body) as Map<String, dynamic>;
    return data['selfieUrl'] as String? ?? '';
  }

  Future<CommunityPostModel> shareWorkout({
    required Map<String, dynamic> workoutJson,
    String? county,
    String? selfieUrl,
  }) async {
    final r = await ApiHttp.post(
      Uri.parse('$_base/api/community/share'),
      body: jsonEncode({
        'workout': workoutJson,
        if (county != null && county.isNotEmpty) 'county': county,
        if (selfieUrl != null && selfieUrl.isNotEmpty) 'selfieUrl': selfieUrl,
      }),
    );
    check(r);
    return CommunityPostModel.fromJson(
        jsonDecode(r.body) as Map<String, dynamic>);
  }
}
