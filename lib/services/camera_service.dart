import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'dart:async';

class CameraService {
  CameraController? cameraController;
  late Future<void> controllerFuture;
  final BarcodeScanner _barcodeScanner = BarcodeScanner();
  final List<String> scannedCodes = [];
  bool _isProcessingImage = false;

  CameraService() {
    controllerFuture = Completer<void>().future;
  }

  Future<void> initializeCamera() async {
    final completer = Completer<void>();
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw Exception('No se encontraron cámaras disponibles.');
      }

      cameraController = CameraController(
        cameras.first,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await cameraController!.initialize();
      completer.complete();
      controllerFuture = completer.future;
      _startImageStream();
    } catch (e) {
      completer.completeError('Error al inicializar la cámara: $e');
      controllerFuture = completer.future;
    }
  }

  void _startImageStream() {
    cameraController!.startImageStream((image) async {
      if (_isProcessingImage) return;
      _isProcessingImage = true;

      final inputImage = _convertCameraImageToInputImage(image);
      await _processBarcodes(inputImage);

      _isProcessingImage = false;
    });
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
    final barcodes = await _barcodeScanner.processImage(inputImage);
    for (final barcode in barcodes) {
      if (barcode.rawValue != null &&
          !scannedCodes.contains(barcode.rawValue)) {
        scannedCodes.insert(0, barcode.rawValue!);
        if (scannedCodes.length > 10) {
          scannedCodes.removeLast();
        }
      }
    }
  }

  void dispose() {
    cameraController?.dispose();
    _barcodeScanner.close();
  }
}
