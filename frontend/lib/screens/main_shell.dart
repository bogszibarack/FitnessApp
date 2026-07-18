import 'package:flutter/material.dart';

import '../theme/app_tema.dart';
import '../widgets/modern_gomb.dart';
import 'community/community_screen.dart';
import 'home/home_screen.dart';
import 'nutrition/naplo_screen.dart';
import 'settings/settings_screen.dart';
import 'workout/workout_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;
  int _homeVersion = 0;

  void _valtas(int index) {
    Haptika.valasztas();
    setState(() {
      if (index == 0 && _selectedIndex != 0) {
        _homeVersion++;
      }
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Témaváltáskor a füleket újraépítjük (a kulcson keresztül), hogy az
    // AppSzinek-alapú színek minden képernyőn azonnal frissüljenek.
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: TemaVezerlo.mod,
      builder: (context, _, _) {
        // Theme.of függőség: rendszer módban az OS váltását is követi.
        final temaKulcs = Theme.of(context).brightness.name;
        return Scaffold(
          extendBody: true,
          body: IndexedStack(
            key: ValueKey('shell_$temaKulcs'),
            index: _selectedIndex,
            children: [
              HomeScreen(key: ValueKey('home_${_homeVersion}_$temaKulcs')),
              const NaploScreen(),
              const WorkoutScreen(),
              const CommunityScreen(),
              const SettingsScreen(),
            ],
          ),
          bottomNavigationBar: LebegoNavSav(
            selectedIndex: _selectedIndex,
            onValtas: _valtas,
            elemek: const [
              NavSavElem(ikon: Icons.home_outlined, aktivIkon: Icons.home_rounded, cimke: 'Home'),
              NavSavElem(ikon: Icons.menu_book_outlined, aktivIkon: Icons.menu_book_rounded, cimke: 'Napló'),
              NavSavElem(ikon: Icons.fitness_center_outlined, aktivIkon: Icons.fitness_center_rounded, cimke: 'Edzés'),
              NavSavElem(ikon: Icons.people_outline, aktivIkon: Icons.people_rounded, cimke: 'Közösség'),
              NavSavElem(ikon: Icons.person_outline, aktivIkon: Icons.person_rounded, cimke: 'Profil'),
            ],
          ),
        );
      },
    );
  }
}

class NavSavElem {
  const NavSavElem({required this.ikon, required this.aktivIkon, required this.cimke});

  final IconData ikon;
  final IconData aktivIkon;
  final String cimke;
}

/// Lebegő, kapszula alakú alsó navigációs sáv — a kiválasztott elem
/// lekerekített kiemelést kap, a többi csak ikon + felirat.
class LebegoNavSav extends StatelessWidget {
  const LebegoNavSav({
    super.key,
    required this.selectedIndex,
    required this.onValtas,
    required this.elemek,
  });

  final int selectedIndex;
  final ValueChanged<int> onValtas;
  final List<NavSavElem> elemek;

  static const _aktivSzin = Color(0xFF3D2EEB);

  @override
  Widget build(BuildContext context) {
    final alsoBiztonsag = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(14, 0, 14, alsoBiztonsag > 0 ? alsoBiztonsag : 14),
      child: Container(
        height: 72,
        decoration: BoxDecoration(
          color: AppSzinek.kartya,
          borderRadius: BorderRadius.circular(36),
          border: AppSzinek.sotet ? Border.all(color: AppSzinek.szegely) : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: AppSzinek.sotet ? 0.5 : 0.12),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: List.generate(elemek.length, (i) {
            final elem = elemek[i];
            final aktiv = i == selectedIndex;
            return Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onValtas(i),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      width: aktiv ? 46 : 34,
                      height: 32,
                      decoration: BoxDecoration(
                        color: aktiv ? _aktivSzin : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: aktiv
                            ? [
                                BoxShadow(
                                  color: _aktivSzin.withValues(alpha: 0.35),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : null,
                      ),
                      child: Icon(
                        aktiv ? elem.aktivIkon : elem.ikon,
                        size: 22,
                        color: aktiv ? Colors.white : AppSzinek.halvanySzoveg,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      elem.cimke,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: aktiv ? FontWeight.w700 : FontWeight.w500,
                        color: aktiv
                            ? (AppSzinek.sotet ? const Color(0xFF8A7DFF) : _aktivSzin)
                            : AppSzinek.halvanySzoveg,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
