import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/nutrition_models.dart';
import '../../services/recept_service.dart';
import 'recipe_detail_screen.dart';

/// Receptek böngészése — keresés, kategória, kalória szűrő.
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
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hiba = '$e';
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
      await _felfedezes();
      return;
    }
    setState(() {
      _betolt = true;
      _aktivKategoria = null;
      _aktivTartomany = null;
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
        _hiba = '$e';
        _betolt = false;
      });
    }
  }

  Future<void> _felfedezes() async {
    setState(() => _betolt = true);
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
        _hiba = '$e';
        _betolt = false;
      });
    }
  }

  Future<void> _kategoriaValasztas(String id) async {
    setState(() {
      _betolt = true;
      _aktivKategoria = id;
      _aktivTartomany = null;
      _keresoController.clear();
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
        _hiba = '$e';
        _betolt = false;
      });
    }
  }

  Future<void> _kaloriaValasztas(KaloriaTartomanyModel t) async {
    setState(() {
      _betolt = true;
      _aktivTartomany = t;
      _aktivKategoria = null;
      _keresoController.clear();
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
        _hiba = '$e';
        _betolt = false;
      });
    }
  }

  Future<void> _receptMegnyitas(ReceptListaElemModel recept) async {
    final friss = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => RecipeDetailScreen(receptId: recept.id, etkezesTipus: widget.etkezesTipus),
      ),
    );
    if (friss == true && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Receptek', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _keresoController,
              decoration: InputDecoration(
                hintText: 'Recept keresése...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                isDense: true,
              ),
              onChanged: _onKereses,
              onSubmitted: _kereses,
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: _kategoriak.map((k) {
                final aktiv = _aktivKategoria == k.id;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(k.nev, style: const TextStyle(fontSize: 12)),
                    selected: aktiv,
                    onSelected: (_) => _kategoriaValasztas(k.id),
                    selectedColor: const Color(0xFF34C759).withValues(alpha: 0.2),
                    checkmarkColor: const Color(0xFF34C759),
                  ),
                );
              }).toList(),
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: _tartomanyok.map((t) {
                final aktiv = _aktivTartomany?.nev == t.nev;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(t.nev, style: const TextStyle(fontSize: 11)),
                    selected: aktiv,
                    onSelected: (_) => _kaloriaValasztas(t),
                    selectedColor: Colors.orange.shade100,
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(child: _lista()),
        ],
      ),
    );
  }

  Widget _lista() {
    if (_betolt) return const Center(child: CircularProgressIndicator());
    if (_hiba != null) {
      return Center(child: Padding(padding: const EdgeInsets.all(20), child: Text(_hiba!, textAlign: TextAlign.center)));
    }
    if (_receptek.isEmpty) return const Center(child: Text('Nincs recept'));

    return LayoutBuilder(
      builder: (context, constraints) {
        final oszlop = constraints.maxWidth > 700 ? 3 : (constraints.maxWidth > 450 ? 2 : 1);
        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: oszlop,
            childAspectRatio: 0.78,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: _receptek.length,
          itemBuilder: (context, i) => _receptKartya(_receptek[i]),
        );
      },
    );
  }

  Widget _receptKartya(ReceptListaElemModel r) {
    return InkWell(
      onTap: () => _receptMegnyitas(r),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
                child: r.kepUrl.isNotEmpty
                    ? Image.network(r.kepUrl, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => ColoredBox(color: Colors.grey.shade200, child: const Icon(Icons.restaurant)))
                    : ColoredBox(color: Colors.grey.shade200, child: const Icon(Icons.restaurant, size: 40)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.nev, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text('${r.becsultKaloria} kcal · ${r.kategoria}', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
