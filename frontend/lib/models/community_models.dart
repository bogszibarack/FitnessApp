import '../models/workout_models.dart';

class CommunityPosztModel {
  const CommunityPosztModel({
    required this.id,
    required this.userName,
    required this.megye,
    required this.regio,
    required this.selfieUrl,
    required this.megosztva,
    required this.edzes,
    required this.likeSzam,
    required this.likeolok,
    required this.kommentek,
  });

  final String id;
  final String userName;
  final String megye;
  final String regio;
  final String selfieUrl;
  final DateTime megosztva;
  final WorkoutSessionModel edzes;
  final int likeSzam;
  final List<String> likeolok;
  final List<CommunityKommentModel> kommentek;

  bool likeolt(String userName) => likeolok.contains(userName);

  String get idoSzoveg {
    final kulonbseg = DateTime.now().difference(megosztva);
    if (kulonbseg.inMinutes < 1) return 'Most';
    if (kulonbseg.inMinutes < 60) return '${kulonbseg.inMinutes} perce';
    if (kulonbseg.inHours < 24) return '${kulonbseg.inHours} órája';
    if (kulonbseg.inDays < 7) return '${kulonbseg.inDays} napja';
    return '${kulonbseg.inDays ~/ 7} hete';
  }

  CommunityPosztModel copyWith({int? likeSzam, List<String>? likeolok, List<CommunityKommentModel>? kommentek}) {
    return CommunityPosztModel(
      id: id,
      userName: userName,
      megye: megye,
      regio: regio,
      selfieUrl: selfieUrl,
      megosztva: megosztva,
      edzes: edzes,
      likeSzam: likeSzam ?? this.likeSzam,
      likeolok: likeolok ?? this.likeolok,
      kommentek: kommentek ?? this.kommentek,
    );
  }

  factory CommunityPosztModel.fromJson(Map<String, dynamic> json) {
    return CommunityPosztModel(
      id: json['id'] as String? ?? '',
      userName: json['userName'] as String? ?? '',
      megye: json['megye'] as String? ?? '',
      regio: json['regio'] as String? ?? '',
      selfieUrl: json['selfieUrl'] as String? ?? '',
      megosztva: json['megosztva'] != null
          ? DateTime.tryParse(json['megosztva'] as String) ?? DateTime.now()
          : DateTime.now(),
      edzes: json['edzes'] != null
          ? WorkoutSessionModel.fromJson(json['edzes'] as Map<String, dynamic>)
          : WorkoutSessionModel(
              title: '',
              startTime: null,
              isActive: false,
              exercises: [],
            ),
      likeSzam: json['likeSzam'] as int? ?? 0,
      likeolok: (json['likeolok'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
      kommentek: (json['kommentek'] as List<dynamic>? ?? [])
          .map((e) => CommunityKommentModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class CommunityKommentModel {
  const CommunityKommentModel({
    required this.id,
    required this.userName,
    required this.szoveg,
    required this.idobelyeg,
  });

  final String id;
  final String userName;
  final String szoveg;
  final DateTime idobelyeg;

  String get idoSzoveg {
    final kulonbseg = DateTime.now().difference(idobelyeg);
    if (kulonbseg.inMinutes < 60) return '${kulonbseg.inMinutes}p';
    if (kulonbseg.inHours < 24) return '${kulonbseg.inHours}ó';
    return '${kulonbseg.inDays}n';
  }

  factory CommunityKommentModel.fromJson(Map<String, dynamic> json) {
    return CommunityKommentModel(
      id: json['id'] as String? ?? '',
      userName: json['userName'] as String? ?? '',
      szoveg: json['szoveg'] as String? ?? '',
      idobelyeg: json['idobelyeg'] != null
          ? DateTime.tryParse(json['idobelyeg'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class CommunityFelhasznaloModel {
  const CommunityFelhasznaloModel({
    required this.userName,
    required this.posztSzam,
    required this.osszLike,
    required this.legutobbiEdzesCim,
    required this.utolsoEdzes,
  });

  final String userName;
  final int posztSzam;
  final int osszLike;
  final String legutobbiEdzesCim;
  final DateTime utolsoEdzes;

  String get inicialeK {
    final reszek = userName.split(RegExp(r'[_.\-]'));
    if (reszek.length >= 2) {
      return '${reszek[0][0]}${reszek[1][0]}'.toUpperCase();
    }
    return userName.substring(0, userName.length.clamp(0, 2)).toUpperCase();
  }

  factory CommunityFelhasznaloModel.fromJson(Map<String, dynamic> json) {
    return CommunityFelhasznaloModel(
      userName: json['userName'] as String? ?? '',
      posztSzam: json['posztSzam'] as int? ?? 0,
      osszLike: json['osszLike'] as int? ?? 0,
      legutobbiEdzesCim: json['legutobbiEdzesCim'] as String? ?? '',
      utolsoEdzes: json['utolsoEdzes'] != null
          ? DateTime.tryParse(json['utolsoEdzes'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
