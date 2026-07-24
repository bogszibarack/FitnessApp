import '../models/workout_models.dart';

String? _jsonString(Map<String, dynamic> json, String en, String hu) =>
    json[en] as String? ?? json[hu] as String?;

int? _jsonInt(Map<String, dynamic> json, String en, String hu) =>
    json[en] as int? ?? json[hu] as int?;

DateTime _jsonDateTime(Map<String, dynamic> json, String en, String hu) {
  final raw = json[en] ?? json[hu];
  if (raw == null) return DateTime.now();
  return DateTime.tryParse(raw as String) ?? DateTime.now();
}

class CommunityPostModel {
  const CommunityPostModel({
    required this.id,
    required this.userName,
    required this.county,
    required this.region,
    required this.selfieUrl,
    required this.sharedAt,
    required this.workout,
    required this.likeCount,
    required this.likedBy,
    required this.comments,
  });

  final String id;
  final String userName;
  final String county;
  final String region;
  final String selfieUrl;
  final DateTime sharedAt;
  final WorkoutSessionModel workout;
  final int likeCount;
  final List<String> likedBy;
  final List<CommunityCommentModel> comments;

  bool likeolt(String userName) => likedBy.contains(userName);

  String get idoSzoveg {
    final kulonbseg = DateTime.now().difference(sharedAt);
    if (kulonbseg.inMinutes < 1) return 'Most';
    if (kulonbseg.inMinutes < 60) return '${kulonbseg.inMinutes} perce';
    if (kulonbseg.inHours < 24) return '${kulonbseg.inHours} órája';
    if (kulonbseg.inDays < 7) return '${kulonbseg.inDays} napja';
    return '${kulonbseg.inDays ~/ 7} hete';
  }

  CommunityPostModel copyWith({
    int? likeCount,
    List<String>? likedBy,
    List<CommunityCommentModel>? comments,
  }) {
    return CommunityPostModel(
      id: id,
      userName: userName,
      county: county,
      region: region,
      selfieUrl: selfieUrl,
      sharedAt: sharedAt,
      workout: workout,
      likeCount: likeCount ?? this.likeCount,
      likedBy: likedBy ?? this.likedBy,
      comments: comments ?? this.comments,
    );
  }

  factory CommunityPostModel.fromJson(Map<String, dynamic> json) {
    final workoutJson = json['workout'] ?? json['edzes'];
    return CommunityPostModel(
      id: json['id'] as String? ?? '',
      userName: json['userName'] as String? ?? '',
      county: _jsonString(json, 'county', 'megye') ?? '',
      region: _jsonString(json, 'region', 'regio') ?? '',
      selfieUrl: json['selfieUrl'] as String? ?? '',
      sharedAt: _jsonDateTime(json, 'sharedAt', 'megosztva'),
      workout: workoutJson != null
          ? WorkoutSessionModel.fromJson(workoutJson as Map<String, dynamic>)
          : WorkoutSessionModel(
              title: '',
              startTime: null,
              isActive: false,
              exercises: [],
            ),
      likeCount: _jsonInt(json, 'likeCount', 'likeSzam') ?? 0,
      likedBy: (json['likedBy'] as List<dynamic>? ?? json['likeolok'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      comments: (json['comments'] as List<dynamic>? ?? json['kommentek'] as List<dynamic>? ?? [])
          .map((e) => CommunityCommentModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class CommunityCommentModel {
  const CommunityCommentModel({
    required this.id,
    required this.userName,
    required this.text,
    required this.createdAt,
  });

  final String id;
  final String userName;
  final String text;
  final DateTime createdAt;

  String get idoSzoveg {
    final kulonbseg = DateTime.now().difference(createdAt);
    if (kulonbseg.inMinutes < 60) return '${kulonbseg.inMinutes}p';
    if (kulonbseg.inHours < 24) return '${kulonbseg.inHours}ó';
    return '${kulonbseg.inDays}n';
  }

  factory CommunityCommentModel.fromJson(Map<String, dynamic> json) {
    return CommunityCommentModel(
      id: json['id'] as String? ?? '',
      userName: json['userName'] as String? ?? '',
      text: _jsonString(json, 'text', 'szoveg') ?? '',
      createdAt: _jsonDateTime(json, 'createdAt', 'idobelyeg'),
    );
  }
}

class CommunityUserModel {
  const CommunityUserModel({
    required this.userName,
    required this.postCount,
    required this.totalLikes,
    required this.lastWorkoutTitle,
    required this.lastWorkout,
  });

  final String userName;
  final int postCount;
  final int totalLikes;
  final String lastWorkoutTitle;
  final DateTime lastWorkout;

  String get inicialeK {
    final reszek = userName.split(RegExp(r'[_.\-]'));
    if (reszek.length >= 2) {
      return '${reszek[0][0]}${reszek[1][0]}'.toUpperCase();
    }
    return userName.substring(0, userName.length.clamp(0, 2)).toUpperCase();
  }

  factory CommunityUserModel.fromJson(Map<String, dynamic> json) {
    return CommunityUserModel(
      userName: json['userName'] as String? ?? '',
      postCount: _jsonInt(json, 'postCount', 'posztSzam') ?? 0,
      totalLikes: _jsonInt(json, 'totalLikes', 'osszLike') ?? 0,
      lastWorkoutTitle:
          _jsonString(json, 'lastWorkoutTitle', 'legutobbiEdzesCim') ?? '',
      lastWorkout: _jsonDateTime(json, 'lastWorkout', 'utolsoEdzes'),
    );
  }
}
