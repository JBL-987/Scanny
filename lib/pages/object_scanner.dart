import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'dart:io';

enum ScannerState { initializing, ready, error, scanning }

class ObjectScanner extends StatefulWidget {
  final List<CameraDescription> cameras;
  const ObjectScanner({Key? key, required this.cameras}) : super(key: key);

  @override
  _ObjectScannerState createState() => _ObjectScannerState();
}

class _ObjectScannerState extends State<ObjectScanner>
    with WidgetsBindingObserver {
  late CameraController _cameraController;
  ImageLabeler? _imageLabeler;
  bool _isDetecting = false;
  String _detectedObject = "Scanning...";
  bool _isFlashOn = false;
  double _zoomLevel = 1.0;
  final double _minZoom = 1.0;
  final double _maxZoom = 3.0;
  Timer? _zoomTimer;
  StreamSubscription<dynamic>? _streamSubscription;
  ScannerState _scannerState = ScannerState.initializing;
  String? _errorMessage;
  bool _isDownloadingModel = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeScanner();
  }

  Future<void> _initializeScanner() async {
    try {
      await _initializeLabeler();
      await _initializeCamera();

      if (mounted) {
        setState(() {
          _scannerState = ScannerState.ready;
        });
      }
    } catch (e) {
      _handleError('Failed to initialize scanner: $e');
    }
  }

Future<void> _initializeLabeler() async {
    try {
      setState(() {
        _isDownloadingModel = true;
      });

      final options = ImageLabelerOptions(confidenceThreshold: 0.3);
      _imageLabeler = ImageLabeler(options: options);

      setState(() {
        _isDownloadingModel = false;
      });
    } catch (e) {
      setState(() {
        _isDownloadingModel = false;
      });
      _handleError('Error initializing image labeler: $e');
    }
  }

  Future<void> _initializeCamera() async {
    try {
      _cameraController = CameraController(
        widget.cameras[0],
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup:
            Platform.isAndroid
                ? ImageFormatGroup.nv21
                : ImageFormatGroup.bgra8888,
      );

      await _cameraController.initialize();
      await _cameraController.setFlashMode(FlashMode.off);
      await _cameraController.lockCaptureOrientation(
        DeviceOrientation.portraitUp,
      );

      if (!mounted) return;

      _startImageStream();
    } catch (e) {
      throw Exception('Error initializing camera: $e');
    }
  }

  void _startImageStream() {
    try {
      _streamSubscription?.cancel();
      _streamSubscription = _cameraController
          .startImageStream((CameraImage image) async {
            if (_isDetecting || _scannerState != ScannerState.ready) return;

            setState(() {
              _isDetecting = true;
            });

            try {
              final InputImage? inputImage = await _processImageData(image);
              if (inputImage != null && mounted) {
                await _processImage(inputImage);
              }
            } catch (e) {
              // Hanya log error tanpa mengubah state untuk menghindari crash
              print('Error in stream: $e');
            } finally {
              if (mounted) {
                setState(() {
                  _isDetecting = false;
                });
              }
            }
          })
          .asStream()
          .listen(
            null,
            onError: (error) {
              print('Stream error: $error');
              _restartImageStream();
            },
            cancelOnError: false,
          );
    } catch (e) {
      _handleError('Error starting image stream: $e');
    }
  }

  void _restartImageStream() async {
    await Future.delayed(const Duration(seconds: 1));
    if (mounted && _scannerState != ScannerState.error) {
      _startImageStream();
    }
  }

  Future<InputImage?> _processImageData(CameraImage image) async {
    try {
      final WriteBuffer allBytes = WriteBuffer();
      for (final Plane plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final bytes = allBytes.done().buffer.asUint8List();

      // Get the image rotation
      final InputImageRotation imageRotation = InputImageRotation.rotation90deg;

      // Get the image format
      final InputImageFormat inputImageFormat =
          Platform.isAndroid
              ? InputImageFormat.nv21
              : InputImageFormat.bgra8888;

      // Get image dimensions
      final InputImageMetadata metadata = InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: imageRotation,
        format: inputImageFormat,
        bytesPerRow: image.planes[0].bytesPerRow,
      );

      // Create InputImage
      final inputImage = InputImage.fromBytes(bytes: bytes, metadata: metadata);

      return inputImage;
    } catch (e) {
      print('Error processing image data: $e');
      return null;
    }
  }

  Future<void> _processImage(InputImage inputImage) async {
    if (_imageLabeler == null || !mounted) return;

    try {
      final labels = await _imageLabeler!.processImage(inputImage);
      if (!mounted) return;

      // Debug: print all detected labels and their confidence
      for (final label in labels) {
        print('Label: ${label.label}, Confidence: ${label.confidence}');
      }

      final detectedLabels =
          labels.where((label) => label.confidence > 0.3).map((label) {
            final confidence = (label.confidence) * 100;
            return '${label.label} (${confidence.toStringAsFixed(0)}%)';
          }).toList();

      setState(() {
        _detectedObject =
            detectedLabels.isNotEmpty
                ? detectedLabels.join(", ")
                : "No objects detected";
      });
    } catch (e) {
      print('Error processing image: $e');
    }
  }

  void _handleError(String error) {
    print(error);
    if (mounted) {
      setState(() {
        _errorMessage = error;
        _scannerState = ScannerState.error;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _toggleFlash() async {
    try {
      setState(() => _isFlashOn = !_isFlashOn);
      await _cameraController.setFlashMode(
        _isFlashOn ? FlashMode.torch : FlashMode.off,
      );
    } catch (e) {
      _handleError('Error toggling flash: $e');
    }
  }

  void _handleZoom(double delta) {
    if (_zoomTimer?.isActive ?? false) return;

    _zoomTimer = Timer(const Duration(milliseconds: 50), () async {
      try {
        final newZoom = (_zoomLevel + delta).clamp(_minZoom, _maxZoom);
        if (newZoom != _zoomLevel) {
          await _cameraController.setZoomLevel(newZoom);
          setState(() => _zoomLevel = newZoom);
        }
      } catch (e) {
        _handleError('Error handling zoom: $e');
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_cameraController.value.isInitialized) return;

    try {
      if (state == AppLifecycleState.inactive ||
          state == AppLifecycleState.paused) {
        _streamSubscription?.cancel();
        _cameraController.dispose();
      } else if (state == AppLifecycleState.resumed) {
        _initializeCamera().then((_) {
          if (mounted && _scannerState == ScannerState.ready) {
            _startImageStream();
          }
        });
      }
    } catch (e) {
      _handleError('Error changing app lifecycle state: $e');
    }
  }
  
  Future<bool> _onWillPop() async {
    return await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text("Back to Home"),
                content: const Text("Are you sure you want to go back?"),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text("No"),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text("Yes"),
                  ),
                ],
              ),
        ) ??
        false;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _zoomTimer?.cancel();
    if (_cameraController.value.isInitialized) {
      _cameraController.dispose();
    }
    _imageLabeler?.close();
    _streamSubscription?.cancel();
    super.dispose();
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            _errorMessage ?? 'An error occurred',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _initializeScanner,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Colors.green),
          const SizedBox(height: 16),
          Text(
            _isDownloadingModel
                ? 'Downloading model... This may take a moment'
                : 'Initializing scanner...',
          ),
        ],
      ),
    );
  }

  Widget _buildScannerView() {
    return GestureDetector(
      onVerticalDragUpdate: (details) {
        _handleZoom(-details.delta.dy / 100);
      },
      child: Column(
        children: [
          Expanded(
            flex: 4,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CameraPreview(_cameraController),
                Positioned(
                  top: 20,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_zoomLevel.toStringAsFixed(1)}x',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.blue.withOpacity(0.5),
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  width: MediaQuery.of(context).size.width * 0.8,
                  height: MediaQuery.of(context).size.width * 0.8,
                ),
              ],
            ),
          ),
          Expanded(
            flex: 1,
            child: Container(
              width: double.infinity,
              color: Colors.black,
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _detectedObject,
                    style: const TextStyle(
                      fontSize: 20,
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Swipe up/down to zoom',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    switch (_scannerState) {
      case ScannerState.initializing:
        body = _buildLoadingView();
        break;
      case ScannerState.error:
        body = _buildErrorView();
        break;
      case ScannerState.ready:
      case ScannerState.scanning:
        body = _buildScannerView();
        break;
    }

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Object Scanner"),
          centerTitle: true,
          actions: [
            IconButton(
              icon: Icon(_isFlashOn ? Icons.flash_on : Icons.flash_off),
              onPressed: _toggleFlash,
              tooltip: 'Toggle Flash',
            ),
          ],
        ),
        body: body,
      ),
    );
  }
}
