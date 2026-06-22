import 'package:shared_preferences/shared_preferences.dart';

/// Napi étkezési streak nyilvántartása.
/// Ha az user minden nap bevesz legalább egy ételt, nő a streak.
/// Ha egy nap kimarad, nullázódik.
class StreakService {
  StreakService._();
  static final StreakService instance = StreakService._();

  // ─── Instance metódusok (naplo_screen kompatibilitás) ───

  Future<int> getStreak() => lekeres();

  /// Hívd meg, amikor az user éppen most naplózott egy ételt.
  Future<int> onFoodLogged() => frissitEsKap(true);
  static const _kStreak = 'naplo_streak';
  static const _kLastDate = 'streak_utolso_datum';

  static String _maiDatum() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  static String _tegunapiDatum() {
    final tegnap = DateTime.now().subtract(const Duration(days: 1));
    return '${tegnap.year}-${tegnap.month.toString().padLeft(2, '0')}-${tegnap.day.toString().padLeft(2, '0')}';
  }

  /// Frissíti a streakot, majd visszaadja az aktuális értéket.
  /// [vanMaiEtel]: igaz, ha ma legalább egy étel be lett naplózva.
  static Future<int> frissitEsKap(bool vanMaiEtel) async {
    final prefs = await SharedPreferences.getInstance();
    final streak = prefs.getInt(_kStreak) ?? 0;
    final utolsoDatum = prefs.getString(_kLastDate) ?? '';
    final mai = _maiDatum();
    final tegnapi = _tegunapiDatum();

    // Ha már feldolgoztuk a mai napot, visszaadjuk az aktuális értéket
    if (utolsoDatum == mai) {
      if (vanMaiEtel && streak == 0) {
        await prefs.setInt(_kStreak, 1);
        return 1;
      }
      return streak;
    }

    if (vanMaiEtel) {
      final ujStreak = utolsoDatum == tegnapi ? streak + 1 : 1;
      await prefs.setInt(_kStreak, ujStreak);
      await prefs.setString(_kLastDate, mai);
      return ujStreak;
    }

    // Nincs mai étel
    if (utolsoDatum == tegnapi) {
      // Ma még lehet bevinni, streak még él
      return streak;
    }

    // Több napja nem volt étel → streak nullázás
    if (streak > 0 && utolsoDatum.isNotEmpty) {
      await prefs.setInt(_kStreak, 0);
      await prefs.remove(_kLastDate);
    }
    return 0;
  }

  static Future<int> lekeres() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kStreak) ?? 0;
  }
}
