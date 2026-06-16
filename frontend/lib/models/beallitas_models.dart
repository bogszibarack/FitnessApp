class BeallitasMenuSzekcio {
  BeallitasMenuSzekcio({required this.cim, required this.elemek});

  final String cim;
  final List<BeallitasMenuElem> elemek;

  factory BeallitasMenuSzekcio.fromJson(Map<String, dynamic> json) {
    return BeallitasMenuSzekcio(
      cim: json['cim'] as String? ?? '',
      elemek: (json['elemek'] as List<dynamic>? ?? [])
          .map((e) => BeallitasMenuElem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class BeallitasMenuElem {
  BeallitasMenuElem({
    required this.id,
    required this.cimke,
    required this.ikon,
    required this.apiUt,
    this.proFunkcio = false,
  });

  final String id;
  final String cimke;
  final String ikon;
  final String apiUt;
  final bool proFunkcio;

  factory BeallitasMenuElem.fromJson(Map<String, dynamic> json) {
    return BeallitasMenuElem(
      id: json['id'] as String? ?? '',
      cimke: json['cimke'] as String? ?? '',
      ikon: json['ikon'] as String? ?? 'settings',
      apiUt: json['apiUt'] as String? ?? '',
      proFunkcio: json['proFunkcio'] as bool? ?? false,
    );
  }
}

class ValasztasiOpcio {
  ValasztasiOpcio({required this.id, required this.cimke});

  final String id;
  final String cimke;

  factory ValasztasiOpcio.fromJson(Map<String, dynamic> json) {
    return ValasztasiOpcio(
      id: json['id'] as String? ?? '',
      cimke: json['cimke'] as String? ?? '',
    );
  }
}
