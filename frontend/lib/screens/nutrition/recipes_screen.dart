import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/nutrition_models.dart';
import '../../services/recept_service.dart';
import '../../widgets/recipe_filter_widgets.dart';
import 'recipe_detail_screen.dart';

/// Receptek böngészése — Yazio-stílusú színes szűrők + makró bontás.
class RecipesScreen extends StatefulWidget {
  const RecipesScreen({super.key, required this.etkezesTipus});

  final String etkezesTipus;

  @override
  State<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends State<RecipesScreen> {
  final _service = ReceptService.instance;
  final _keresoController = TextEditingController();

  List<ReceptKategoriaModel> _kategoriak = [];
  List<KaloriaTartomanyModel> _tartomanyok = [];
  List<ReceptListaElemModel> _receptek = [];
  String? _aktivKategoria;
  KaloriaTartomanyModel? _aktivTartomany;
  bool _betolt = true;
  String? _hiba;
  Timer? _debounce;
  bool _keresesMod = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _keresoController.dispose();
    super.dispose();
  }

  String _hibaUzenet(Object e) {
    final szoveg = e.toString();
    if (szoveg.contains('429') || szoveg.contains('Too Many Requests')) {
      return 'Túl sok kérés érkezett a recept szolgáltatáshoz.\nVárj pár másodpercet, majd próbáld újra.';
    }
    if (szoveg.contains('Connection') || szoveg.contains('SocketException')) {
      return 'Nem sikerült csatlakozni a szerverhez.\nEllenőrizd, hogy fut-e a backend.';
    }
    return 'Hiba történt a receptek betöltésekor.\nPróbáld újra később.';
  }

  Future<void> _init() async {
    try {
      final eredmeny = await Future.wait([
        _service.kategoriak(),
        _service.kaloriaTartomanyok(),
        _service.felfedezes(darab: 12),
      ]);
      if (!mounted) return;
      setState(() {
        _kategoriak = eredmeny[0] as List<ReceptKategoriaModel>;
        _tartomanyok = eredmeny[1] as List<KaloriaTartomanyModel>;
        _receptek = eredmeny[2] as List<ReceptListaElemModel>;
        _betolt = false;
        _hiba = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hiba = _hibaUzenet(e);
        _betolt = false;
      });
    }
  }

  void _onKereses(String szoveg) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () => _kereses(szoveg));
  }

  Future<void> _kereses(String szoveg) async {
    if (szoveg.trim().isEmpty) {
      setState(() {
        _keresesMod = false;
        _aktivKategoria = null;
        _aktivTartomany = null;
      });
      await _felfedezes();
      return;
    }
    setState(() {
      _betolt = true;
      _keresesMod = true;
      _aktivKategoria = null;
      _aktivTartomany = null;
      _hiba = null;
    });
    try {
      final lista = await _service.kereses(szoveg);
      if (!mounted) return;
      setState(() {
        _receptek = lista;
        _betolt = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hiba = _hibaUzenet(e);
        _betolt = false;
      });
    }
  }

  Future<void> _felfedezes() async {
    setState(() {
      _betolt = true;
      _hiba = null;
    });
    try {
      final lista = await _service.felfedezes(darab: 12);
      if (!mounted) return;
      setState(() {
        _receptek = lista;
        _betolt = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hiba = _hibaUzenet(e);
        _betolt = false;
      });
    }
  }

  Future<void> _kategoriaValasztas(String id) async {
    setState(() {
      _betolt = true;
      _aktivKategoria = id;
      _aktivTartomany = null;
      _keresesMod = false;
      _keresoController.clear();
      _hiba = null;
    });
    try {
      final lista = await _service.kategoriaSzerint(id);
      if (!mounted) return;
      setState(() {
        _receptek = lista;
        _betolt = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hiba = _hibaUzenet(e);
        _betolt = false;
      });
    }
  }

  Future<void> _kaloriaValasztas(KaloriaTartomanyModel t) async {
    setState(() {
      _betolt = true;
      _aktivTartomany = t;
      _aktivKategoria = null;
      _keresesMod = false;
      _keresoController.clear();
      _hiba = null;
    });
    try {
      final lista = await _service.kaloriaSzerint(t.min, t.max);
      if (!mounted) return;
      setState(() {
        _receptek = lista;
        _betolt = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hiba = _hibaUzenet(e);
        _betolt = false;
      });
    }
  }

  void _szuroTorlese() {
    _keresoController.clear();
    setState(() {
      _aktivKategoria = null;
      _aktivTartomany = null;
      _keresesMod = false;
    });
    _felfedezes();
  }

  Future<void> _receptMegnyitas(ReceptListaElemModel recept) async {
    final friss = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => RecipeDetailScreen(receptId: recept.id, etkezesTipus: widget.etkezesTipus),
      ),
    );
    if (friss == true && mounted) Navigator.of(context).pop(true);
  }

  String get _eredmenyCim {
    if (_keresesMod) return 'Keresési eredmények';
    if (_aktivKategoria != null) {
      return _kategoriak.firstWhere((k) => k.id == _aktivKategoria, orElse: () => ReceptKategoriaModel(id: '', nev: 'Szűrt')).nev;
    }
    if (_aktivTartomany != null) return _aktivTartomany!.nev;
    return 'Ajánlott receptek';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: const Text('Receptek', style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1A2E),
        elevation: 0,
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _fejlec()),
          if (!_keresesMod) ...[
            const SliverToBoxAdapter(child: ReceptSzekcioCim(cim: 'Népszerű kategóriák')),
            SliverToBoxAdapter(child: _kategoriaSav()),
            const SliverToBoxAdapter(child: ReceptSzekcioCim(cim: 'Receptek kalória szerint')),
            SliverToBoxAdapter(child: _kaloriaRacs()),
          ],
          SliverToBoxAdapter(
            child: ReceptSzekcioCim(
              cim: _eredmenyCim,
              ujraGomb: (_aktivKategoria != null || _aktivTartomany != null) ? _szuroTorlese : null,
            ),
          ),
          _listaSliver(),
        ],
      ),
    );
  }

  Widget _fejlec() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: TextField(
        controller: _keresoController,
        decoration: InputDecoration(
          hintText: 'Recept keresése...',
          prefixIcon: const Icon(Icons.search, color: Color(0xFF34C759)),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF34C759), width: 1.5),
          ),
          isDense: true,
        ),
        onChanged: _onKereses,
        onSubmitted: _kereses,
      ),
    );
  }

  Widget _kategoriaSav() {
    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _kategoriak.length,
        itemBuilder: (context, i) => ReceptKategoriaKartya(
          kategoria: _kategoriak[i],
          aktiv: _aktivKategoria == _kategoriak[i].id,
          onTap: () => _kategoriaValasztas(_kategoriak[i].id),
        ),
      ),
    );
  }

  Widget _kaloriaRacs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 1.55,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemCount: _tartomanyok.length,
        itemBuilder: (context, i) => KaloriaTartomanyKartya(
          tartomany: _tartomanyok[i],
          aktiv: _aktivTartomany?.nev == _tartomanyok[i].nev,
          index: i,
          onTap: () => _kaloriaValasztas(_tartomanyok[i]),
        ),
      ),
    );
  }

  Widget _listaSliver() {
    if (_betolt) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: CircularProgressIndicator(color: Color(0xFF34C759))),
      );
    }
    if (_hiba != null) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud_off_outlined, size: 48, color: Colors.grey.shade400),
                const SizedBox(height: 12),
                Text(_hiba!, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade700, height: 1.4)),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _init,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Újrapróbálás'),
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF34C759)),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (_receptek.isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: Text('Nincs recept ebben a szűrőben')),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
      sliver: SliverLayoutBuilder(
        builder: (context, constraints) {
          final szelesseg = constraints.crossAxisExtent;
          final oszlop = szelesseg > 700 ? 3 : (szelesseg > 420 ? 2 : 1);
          return SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: oszlop,
              childAspectRatio: oszlop == 1 ? 0.92 : 0.78,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, i) => _receptKartya(_receptek[i]),
              childCount: _receptek.length,
            ),
          );
        },
      ),
    );
  }

  // Kártya szín + ikon a recept neve alapján (determinisztikus)
  static const _szinek = [
    [Color(0xFF2ECC71), Color(0xFF27AE60)],
    [Color(0xFF3498DB), Color(0xFF2980B9)],
    [Color(0xFFE67E22), Color(0xFFD35400)],
    [Color(0xFF9B59B6), Color(0xFF8E44AD)],
    [Color(0xFFE74C3C), Color(0xFFC0392B)],
    [Color(0xFF1ABC9C), Color(0xFF16A085)],
    [Color(0xFFF39C12), Color(0xFFD68910)],
    [Color(0xFF2C3E50), Color(0xFF34495E)],
  ];

  static const _ikonok = [
    Icons.restaurant_menu,
    Icons.local_dining,
    Icons.set_meal,
    Icons.rice_bowl,
    Icons.outdoor_grill,
    Icons.emoji_food_beverage,
    Icons.soup_kitchen,
    Icons.bakery_dining,
  ];

  Widget _receptKartya(ReceptListaElemModel r) {
    final idx = r.nev.hashCode.abs() % _szinek.length;
    final szinpair = _szinek[idx];
    final kcal = r.becsultKaloria;
    final vanKep = r.kepUrl.isNotEmpty;

    return InkWell(
      onTap: () => _receptMegnyitas(r),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.07), blurRadius: 10, offset: const Offset(0, 3)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Kép vagy gradiens fejléc
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: SizedBox(
                height: 90,
                child: vanKep
                    ? Image.network(
                        r.kepUrl,
                        fit: BoxFit.cover,
                        loadingBuilder: (_, child, progress) =>
                            progress == null ? child : _gradiensHatter(szinpair, kcal),
                        errorBuilder: (_, __, ___) => _gradiensHatter(szinpair, kcal),
                      )
                    : _gradiensHatter(szinpair, kcal),
              ),
            ),
            // Recept neve + makrók
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        r.nev,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, height: 1.25),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _makroPill('F', r.becsultFeherje.toStringAsFixed(0), const Color(0xFF3498DB)),
                        const SizedBox(width: 4),
                        _makroPill('Sz', r.becsultSzenhidrat.toStringAsFixed(0), const Color(0xFFE67E22)),
                        const SizedBox(width: 4),
                        _makroPill('Zs', r.becsultZsir.toStringAsFixed(0), const Color(0xFF9B59B6)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _gradiensHatter(List<Color> szinek, int kcal) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: szinek, begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: Align(
        alignment: Alignment.bottomLeft,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              const Icon(Icons.local_fire_department, size: 13, color: Colors.white70),
              const SizedBox(width: 2),
              Text('$kcal kcal', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _makroPill(String cimke, String ertek, Color szin) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: szin.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$cimke $ertek g',
        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: szin),
      ),
    );
  }
}
