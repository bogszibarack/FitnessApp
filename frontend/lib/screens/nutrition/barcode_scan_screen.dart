import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../services/nutrition_service.dart';

/// Kamerás vonalkód-olvasó — Open Food Facts terméket ad vissza (FoodItemModel).
class BarcodeScanScreen extends StatefulWidget {
  const BarcodeScanScreen({super.key});

  @override
  State<BarcodeScanScreen> createState() => _BarcodeScanScreenState();
}

class _BarcodeScanScreenState extends State<BarcodeScanScreen> {
  final _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
      BarcodeFormat.code128,
    ],
  );
  final _service = NutritionService.instance;
  final _keziController = TextEditingController();

  bool _feldolgoz = false;
  String? _hiba;

  @override
  void dispose() {
    _controller.dispose();
    _keziController.dispose();
    super.dispose();
  }

  Future<void> _kodFeldolgozas(String kod) async {
    if (_feldolgoz) return;
    setState(() {
      _feldolgoz = true;
      _hiba = null;
    });

    try {
      final etel = await _service.vonalkodKereses(kod.trim());
      if (!mounted) return;
      Navigator.of(context).pop(etel);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hiba = 'Nincs termék ehhez a vonalkódhoz: $kod';
        _feldolgoz = false;
      });
    }
  }

  void _onDetect(BarcodeCapture capture) {
    if (_feldolgoz) return;
    for (final b in capture.barcodes) {
      final kod = b.rawValue;
      if (kod != null && kod.isNotEmpty) {
        _kodFeldolgozas(kod);
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Vonalkód beolvasása'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => _controller.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch),
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                MobileScanner(controller: _controller, onDetect: _onDetect),
                _kereses(),
                Container(
                  width: 250,
                  height: 160,
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFF34C759), width: 3),
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                if (_hiba != null)
                  Positioned(
                    bottom: 20,
                    left: 20,
                    right: 20,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade700,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(_hiba!, style: const TextStyle(color: Colors.white), textAlign: TextAlign.center),
                    ),
                  ),
              ],
            ),
          ),
          _keziBevitel(),
        ],
      ),
    );
  }

  Widget _kereses() {
    if (!_feldolgoz) return const SizedBox.shrink();
    return Container(
      color: Colors.black54,
      child: const Center(child: CircularProgressIndicator(color: Color(0xFF34C759))),
    );
  }

  Widget _keziBevitel() {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Vagy írd be kézzel a vonalkódot:',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _keziController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'pl. 5997523109912',
                    hintStyle: TextStyle(color: Colors.grey.shade500),
                    filled: true,
                    fillColor: Colors.white10,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _feldolgoz
                    ? null
                    : () {
                        if (_keziController.text.trim().isNotEmpty) {
                          _kodFeldolgozas(_keziController.text);
                        }
                      },
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF34C759)),
                child: const Text('Keresés'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
