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

  bool likeolt(String userName) =>
      likedBy.any((u) => u.toLowerCase() == userName.toLowerCase());

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
      likedBy: (json['likedBy'] as List<dynamic>? ??
              json['likeolok'] as List<dynamic>? ??
              [])
          .map((e) => e.toString())
          .toList(),
      comments: (json['comments'] as List<dynamic>? ??
              json['kommentek'] as List<dynamic>? ??
              [])
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

/// Registered user in "Kit ismerhetek" / friends directory.
class PeopleListItemModel {
  const PeopleListItemModel({
    required this.userId,
    required this.userName,
    required this.county,
    required this.profileImageUrl,
    required this.displayName,
    required this.bio,
    required this.postCount,
    required this.friendStatus,
    required this.sameCounty,
    this.requestId,
  });

  final String userId;
  final String userName;
  final String county;
  final String profileImageUrl;
  final String displayName;
  final String bio;
  final int postCount;
  /// none | outgoing | incoming | friends
  final String friendStatus;
  final bool sameCounty;
  final String? requestId;

  factory PeopleListItemModel.fromJson(Map<String, dynamic> json) {
    return PeopleListItemModel(
      userId: json['userId']?.toString() ?? '',
      userName: json['userName'] as String? ?? '',
      county: json['county'] as String? ?? '',
      profileImageUrl: json['profileImageUrl'] as String? ?? '',
      displayName: json['displayName'] as String? ??
          json['userName'] as String? ??
          '',
      bio: json['bio'] as String? ?? '',
      postCount: _jsonInt(json, 'postCount', 'posztSzam') ?? 0,
      friendStatus: json['friendStatus'] as String? ?? 'none',
      sameCounty: json['sameCounty'] as bool? ?? false,
      requestId: json['requestId']?.toString(),
    );
  }
}

class CommunityProfileModel {
  const CommunityProfileModel({
    required this.userId,
    required this.userName,
    required this.county,
    required this.displayName,
    required this.bio,
    required this.profileImageUrl,
    required this.friendStatus,
    required this.friendsCount,
    required this.postCount,
    required this.posts,
    required this.workoutHistory,
    this.incomingRequestId,
  });

  final String userId;
  final String userName;
  final String county;
  final String displayName;
  final String bio;
  final String profileImageUrl;
  final String friendStatus;
  final String? incomingRequestId;
  final int friendsCount;
  final int postCount;
  final List<CommunityPostModel> posts;
  final List<WorkoutSessionModel> workoutHistory;

  factory CommunityProfileModel.fromJson(Map<String, dynamic> json) {
    return CommunityProfileModel(
      userId: json['userId']?.toString() ?? '',
      userName: json['userName'] as String? ?? '',
      county: json['county'] as String? ?? '',
      displayName: json['displayName'] as String? ??
          json['userName'] as String? ??
          '',
      bio: json['bio'] as String? ?? '',
      profileImageUrl: json['profileImageUrl'] as String? ?? '',
      friendStatus: json['friendStatus'] as String? ?? 'none',
      incomingRequestId: json['incomingRequestId']?.toString(),
      friendsCount: json['friendsCount'] as int? ?? 0,
      postCount: json['postCount'] as int? ?? 0,
      posts: (json['posts'] as List<dynamic>? ?? [])
          .map((e) => CommunityPostModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      workoutHistory: (json['workoutHistory'] as List<dynamic>? ?? [])
          .map((e) => WorkoutSessionModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
