class SettingsMenuSection {
  SettingsMenuSection({required this.title, required this.items});

  final String title;
  final List<SettingsMenuItem> items;

  factory SettingsMenuSection.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] ?? json['elemek'] ?? [];
    return SettingsMenuSection(
      title: json['title'] as String? ?? json['cim'] as String? ?? '',
      items: (rawItems as List<dynamic>)
          .map((e) => SettingsMenuItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  // Legacy aliases
  String get cim => title;
  List<SettingsMenuItem> get elemek => items;
}

class SettingsMenuItem {
  SettingsMenuItem({
    required this.id,
    required this.label,
    required this.icon,
    required this.apiPath,
    this.isPro = false,
  });

  final String id;
  final String label;
  final String icon;
  final String apiPath;
  final bool isPro;

  factory SettingsMenuItem.fromJson(Map<String, dynamic> json) {
    return SettingsMenuItem(
      id: json['id'] as String? ?? '',
      label: json['label'] as String? ?? json['cimke'] as String? ?? '',
      icon: json['icon'] as String? ?? json['ikon'] as String? ?? 'settings',
      apiPath: json['apiPath'] as String? ?? json['apiUt'] as String? ?? '',
      isPro: json['isPro'] as bool? ?? json['proFunkcio'] as bool? ?? false,
    );
  }

  String get cimke => label;
  String get ikon => icon;
  String get apiUt => apiPath;
  bool get proFunkcio => isPro;
}

class ChoiceOption {
  ChoiceOption({required this.id, required this.label});

  ChoiceOption.named({required this.id, required String cimke}) : label = cimke;

  final String id;
  final String label;

  factory ChoiceOption.fromJson(Map<String, dynamic> json) {
    return ChoiceOption(
      id: json['id'] as String? ?? '',
      label: json['label'] as String? ?? json['cimke'] as String? ?? '',
    );
  }

  String get cimke => label;
}

/// Legacy constructor name used by older screens.
class ValasztasiOpcio extends ChoiceOption {
  ValasztasiOpcio({required super.id, required String cimke}) : super(label: cimke);

  factory ValasztasiOpcio.fromJson(Map<String, dynamic> json) =>
      ValasztasiOpcio(
        id: json['id'] as String? ?? '',
        cimke: json['label'] as String? ?? json['cimke'] as String? ?? '',
      );
}

typedef BeallitasMenuSzekcio = SettingsMenuSection;
typedef BeallitasMenuElem = SettingsMenuItem;
