import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({Key? key}) : super(key: key);

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen>
    with SingleTickerProviderStateMixin {
  bool _isPermissionGranted = false;
  CameraController? _cameraController;
  final BarcodeScanner _barcodeScanner = BarcodeScanner();
  final List<String> _scannedCodes = [];
  bool _isScanningEnabled = true;
  bool _isProcessingImage = false;
  bool _showScanningLine = false;
  bool _isFlashOn = false;
  late Future<void> _initializeControllerFuture;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _initializeControllerFuture = _requestCameraPermission();
    _loadScannedCodes();

    // Animación de la línea de escaneo
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _barcodeScanner.close();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _requestCameraPermission() async {
    final status = await Permission.camera.request();
    setState(() {
      _isPermissionGranted = status == PermissionStatus.granted;
    });

    if (_isPermissionGranted) {
      _initializeControllerFuture = _initializeCamera();
    } else {
      throw Exception('Permiso de cámara denegado.');
    }
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      throw Exception('No se encontraron cámaras disponibles.');
    }

    _cameraController = CameraController(
      cameras.first,
      ResolutionPreset.high,
      enableAudio: false,
    );

    await _cameraController!.initialize();
    _cameraController!.startImageStream((image) async {
      if (!_isProcessingImage && _isScanningEnabled) {
        _isProcessingImage = true;
        final inputImage = _convertCameraImageToInputImage(image);
        await _processBarcodes(inputImage);
        _isProcessingImage = false;
      }
    });

    setState(() {});
  }

  InputImage _convertCameraImageToInputImage(CameraImage image) {
    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: InputImageRotation.rotation0deg,
        format: InputImageFormat.nv21,
        bytesPerRow: image.planes[0].bytesPerRow,
      ),
    );
  }

  Future<void> _processBarcodes(InputImage inputImage) async {
    try {
      final barcodes = await _barcodeScanner.processImage(inputImage);

      for (final barcode in barcodes) {
        if (barcode.rawValue != null &&
            !_scannedCodes.contains(barcode.rawValue)) {
          setState(() {
            _scannedCodes.insert(0, barcode.rawValue!);
            if (_scannedCodes.length > 10) {
              _scannedCodes.removeLast();
            }
            _showScanningLine = true; // Mostrar la línea al detectar un código
          });

          // Guardar el historial de códigos
          await _saveScannedCodes();

          // Vibración
          HapticFeedback.lightImpact();

          // Cambiar el color del cuadro
          _animationController.repeat(reverse: true);

          // Pausa para evitar lecturas repetidas
          _isScanningEnabled = false;
          await Future.delayed(const Duration(milliseconds: 1500));
          _showScanningLine = false; // Ocultar la línea después de la pausa
          _animationController.stop();
          setState(() {
            _isScanningEnabled = true;
          });
        }
      }
    } catch (e) {
      debugPrint('Error al procesar códigos de barras: $e');
    }
  }

  Future<void> _saveScannedCodes() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('scannedCodes', _scannedCodes);
  }

  Future<void> _loadScannedCodes() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _scannedCodes.addAll(prefs.getStringList('scannedCodes') ?? []);
    });
  }

  Widget _buildScannerOverlay() {
    return Stack(
      children: [
        Center(
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              border: Border.all(
                color: _showScanningLine ? Colors.blue : Colors.green,
                width: 3,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        if (_showScanningLine)
          Positioned(
            top: MediaQuery.of(context).size.height * 0.5 - 150,
            left: MediaQuery.of(context).size.width * 0.5 - 150,
            child: AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, _animationController.value * 300),
                  child: Container(
                    width: 300,
                    height: 4,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.green.withOpacity(0.1),
                          Colors.green,
                          Colors.green.withOpacity(0.1),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildScannedList() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Códigos Escaneados',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          if (_scannedCodes.isEmpty)
            const Text('No hay códigos escaneados aún.')
          else
            SizedBox(
              height: 120,
              child: ListView.builder(
                itemCount: _scannedCodes.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    title: Text(_scannedCodes[index]),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () async {
                        setState(() {
                          _scannedCodes.removeAt(index);
                        });
                        await _saveScannedCodes();
                      },
                    ),
                  );
                },
              ),
            ),
          ElevatedButton(
            onPressed: () async {
              setState(() {
                _scannedCodes.clear();
              });
              await _saveScannedCodes();
            },
            child: const Text('Limpiar Historial'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Escáner de Códigos'),
        backgroundColor: Colors.blueAccent,
        actions: [
          IconButton(
            icon: Icon(_isFlashOn ? Icons.flash_on : Icons.flash_off),
            onPressed: () {
              setState(() {
                _isFlashOn = !_isFlashOn;
                _cameraController?.setFlashMode(
                    _isFlashOn ? FlashMode.torch : FlashMode.off);
              });
            },
          ),
        ],
      ),
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (!_isPermissionGranted) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.camera_alt_outlined,
                      size: 100, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('Se requiere permiso de cámara.'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _requestCameraPermission,
                    child: const Text('Conceder permiso'),
                  ),
                ],
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.done) {
            return Stack(
              children: [
                if (_cameraController?.value.isInitialized ?? false)
                  CameraPreview(_cameraController!),
                _buildScannerOverlay(),
                Positioned(
                  bottom: 20,
                  left: 20,
                  right: 20,
                  child: _buildScannedList(),
                ),
              ],
            );
          } else if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }
}
