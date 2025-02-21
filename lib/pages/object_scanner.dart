import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';

class ObjectScanner extends StatefulWidget {
  const ObjectScanner({Key? key}) : super(key: key);

  @override
  State<ObjectScanner> createState() => _ObjectScannerState();
}

class _ObjectScannerState extends State<ObjectScanner> {
  late CameraController _cameraController;
  late ObjectDetector _objectDetector;
  bool _isDetecting = false;
  String detectedLabel = "Arahkan kamera ke objek";

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _initializeObjectDetector();
  }

  void _initializeCamera() async {
    final cameras = await availableCameras();
    _cameraController = CameraController(cameras[0], ResolutionPreset.medium);
    await _cameraController.initialize();
    if (!mounted) return;
    setState(() {});
  }

  void _initializeObjectDetector() {
    final options = ObjectDetectorOptions(
      mode: DetectionMode.single,
      classifyObjects: true,
      multipleObjects: true,
    );
    _objectDetector = ObjectDetector(options: options);
  }

  Future<void> _captureAndDetect() async {
    if (_isDetecting) return;
    setState(() => _isDetecting = true);

    final imageFile = await _cameraController.takePicture();
    final inputImage = InputImage.fromFilePath(imageFile.path);

    final objects = await _objectDetector.processImage(inputImage);

    if (objects.isNotEmpty) {
      setState(() {
        detectedLabel =
            objects.first.labels.isNotEmpty
                ? objects.first.labels.first.text
                : "Tidak ada label";
      });
    } else {
      setState(() {
        detectedLabel = "Tidak ada objek terdeteksi";
      });
    }

    setState(() => _isDetecting = false);
  }

  @override
  void dispose() {
    _cameraController.dispose();
    _objectDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Object Scanner")),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child:
                _cameraController.value.isInitialized
                    ? CameraPreview(_cameraController)
                    : const Center(child: CircularProgressIndicator()),
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(detectedLabel, style: const TextStyle(fontSize: 20)),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: _captureAndDetect,
                  child: const Text("Scan Object"),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
