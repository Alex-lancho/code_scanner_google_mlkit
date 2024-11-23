/*import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:permission_handler/permission_handler.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({Key? key}) : super(key: key);

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen>
    with SingleTickerProviderStateMixin {
  bool _isPermissionGranted = false;
  CameraController? _cameraController;
  final _barcodeScanner = BarcodeScanner();
  final List<String> _scannedCodes = [];
  bool _isScanningEnabled = true;
  bool _isProcessingImage = false;
  late Future<void> _initializeControllerFuture;
  late AnimationController _animationController;
  bool _showScanningLine = false;

  @override
  void initState() {
    super.initState();
    _initializeControllerFuture = _requestCameraPermission();

    // Configurar animación para la línea de escaneo
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500), // Escaneo rápido
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
      await _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    _cameraController = CameraController(
      cameras.first,
      ResolutionPreset.high,
      enableAudio: false,
    );

    await _cameraController!.initialize();
    await _cameraController!.startImageStream((image) {
      if (_isProcessingImage || !_isScanningEnabled) return;
      _isProcessingImage = true;
      _processCameraImage(image).then((_) => _isProcessingImage = false);
    });

    setState(() {});
  }

  Future<void> _processCameraImage(CameraImage image) async {
    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    final inputImage = InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: InputImageRotation.rotation0deg,
        format: InputImageFormat.nv21,
        bytesPerRow: image.planes[0].bytesPerRow,
      ),
    );

    await _scanBarcodes(inputImage);
  }

  Future<void> _scanBarcodes(InputImage inputImage) async {
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
            _showScanningLine = true; // Mostrar la línea de escaneo
          });

          _animationController.forward(from: 0).then((_) {
            setState(() {
              _showScanningLine = false; // Ocultar la línea después del escaneo
            });
          });

          // Pausar el escaneo temporalmente
          setState(() {
            _isScanningEnabled = false;
          });
          Future.delayed(const Duration(milliseconds: 500), () {
            setState(() {
              _isScanningEnabled = true;
            });
          });
        }
      }
    } catch (error) {
      debugPrint('Error al escanear: $error');
    }
  }

  Widget _buildScannerOverlay() {
    return Stack(
      children: [
        // Línea de escaneo visible solo al detectar un código
        if (_showScanningLine)
          Center(
            child: AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(
                    _animationController.value * 300 -
                        150, // Mueve de izquierda a derecha
                    0,
                  ),
                  child: Container(
                    width: 2,
                    height: 300,
                    color: Colors.green,
                  ),
                );
              },
            ),
          ),
        // Borde del cuadro
        Center(
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.green, width: 3),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Escáner de Códigos'),
        backgroundColor: Colors.blueAccent,
      ),
      body: FutureBuilder(
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
                  Text(
                    'Se requiere permiso de cámara',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
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
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
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
              height: 120, // Altura máxima para 3 elementos
              child: ListView.builder(
                itemCount: _scannedCodes.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    title: Text(_scannedCodes[index]),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
*/