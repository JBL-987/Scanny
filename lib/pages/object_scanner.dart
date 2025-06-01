import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'dart:io';
import '../components/scanner_constants.dart';
import '../components/scanner_error_view.dart';
import '../components/scanner_loading_view.dart';
import '../components/scanner_view.dart';
import '../services/gemini_service.dart';

enum ScannerState { initializing, ready, error, processing }

class ObjectScanner extends StatefulWidget {
  final List<CameraDescription> cameras;
  const ObjectScanner({super.key, required this.cameras});

  @override
  _ObjectScannerState createState() => _ObjectScannerState();
}

class _ObjectScannerState extends State<ObjectScanner>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  late CameraController _cameraController;
  ImageLabeler? _imageLabeler;
  bool _isDetecting = false;
  String _detectedObject = "🔍 Find objects around you...";
  bool _isFlashOn = false;
  double _zoomLevel = 1.0;
  double _minZoom = 1.0;
  double _maxZoom = 3.0;
  Timer? _zoomTimer;
  StreamSubscription<dynamic>? _streamSubscription;
  ScannerState _scannerState = ScannerState.initializing;
  String? _errorMessage;
  bool _isDownloadingModel = false;
  final List<String> _labelCache = [];

  // Additional features for capture
  bool _isCapturing = false;
  String? _capturedImagePath;
  List<String> _capturedLabels = [];
  String _geminiDescription = "";
  bool _isLoadingGemini = false;

  late AnimationController _scanAnimationController;
  late AnimationController _pulseAnimationController;
  late AnimationController _captureAnimationController;
  late Animation<double> _scanAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _captureAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeAnimations();
    _initializeScanner();
  }

  void _initializeAnimations() {
    _scanAnimationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    _pulseAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _captureAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _scanAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _scanAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _pulseAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    _captureAnimation = Tween<double>(begin: 1.0, end: 0.8).animate(
      CurvedAnimation(
        parent: _captureAnimationController,
        curve: Curves.elasticOut,
      ),
    );
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
      _handleError('Failed to start camera: $e');
    }
  }

  Future<void> _initializeLabeler() async {
    try {
      setState(() {
        _isDownloadingModel = true;
      });

      final options = ImageLabelerOptions(
        confidenceThreshold: ScannerConstants.confidenceThreshold,
      );
      _imageLabeler = ImageLabeler(options: options);

      setState(() {
        _isDownloadingModel = false;
      });
    } catch (e) {
      setState(() {
        _isDownloadingModel = false;
      });
      _handleError('Error loading model: $e');
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

      // Get actual zoom capabilities
      _minZoom = await _cameraController.getMinZoomLevel();
      _maxZoom = await _cameraController.getMaxZoomLevel();
      _zoomLevel = _minZoom;

      await _cameraController.setFlashMode(FlashMode.off);
      await _cameraController.lockCaptureOrientation(
        DeviceOrientation.portraitUp,
      );

      if (!mounted) return;

      _startImageStream();
    } catch (e) {
      throw Exception('Error starting camera: $e');
    }
  }

  void _startImageStream() {
    try {
      _streamSubscription?.cancel();
      _streamSubscription = _cameraController
          .startImageStream((CameraImage image) async {
            if (_isDetecting ||
                _scannerState != ScannerState.ready ||
                _isCapturing)
              return;

        setState(() {
          _isDetecting = true;
        });

        try {
          await Future.delayed(ScannerConstants.processingDelay);

          final InputImage? inputImage = await _processImageData(image);
          if (inputImage != null && mounted) {
            await _processImage(inputImage);
          }
        } catch (e) {
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
      _handleError('Error starting detection: $e');
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
      final InputImageRotation imageRotation = InputImageRotation.rotation90deg;
      final InputImageFormat inputImageFormat =
      Platform.isAndroid
          ? InputImageFormat.nv21
          : InputImageFormat.bgra8888;

      final InputImageMetadata metadata = InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: imageRotation,
        format: inputImageFormat,
        bytesPerRow: image.planes[0].bytesPerRow,
      );

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

      labels.sort((a, b) => b.confidence.compareTo(a.confidence));
      final filteredLabels =
          labels
              .where(
                (label) =>
                    label.confidence > ScannerConstants.confidenceThreshold,
              )
          .take(ScannerConstants.maxLabelsToShow)
          .map((label) => label.label)
              .toList();
    } catch (e) {
      print('Error processing image: $e');
    }
  }

  // Function to capture photo and labels
  Future<void> _capturePhoto() async {
    if (_isCapturing || !_cameraController.value.isInitialized) return;

    try {
      setState(() {
        _isCapturing = true;
        _scannerState = ScannerState.processing;
      });

      // Capture animation
      await _captureAnimationController.forward();
      await _captureAnimationController.reverse();

      // Take photo
      final XFile photo = await _cameraController.takePicture();

      // Process photo for labeling
      final InputImage inputImage = InputImage.fromFilePath(photo.path);
      final labels = await _imageLabeler!.processImage(inputImage);

      // Filter and sort labels
      labels.sort((a, b) => b.confidence.compareTo(a.confidence));
      final filteredLabels =
          labels
              .where(
                (label) =>
                    label.confidence > ScannerConstants.confidenceThreshold,
              )
              .take(5) // Take top 5 labels
              .map(
                (label) =>
                    "${label.label} (${(label.confidence * 100).toStringAsFixed(1)}%)",
              )
              .toList();

      setState(() {
        _capturedImagePath = photo.path;
        _capturedLabels = filteredLabels;
        _isLoadingGemini = true;
        _geminiDescription = "";
      });

      // Call Gemini API for description
      try {
        final description = await GeminiService.describeImage(photo.path);
        if (mounted) {
          setState(() {
            _geminiDescription = description;
            _isLoadingGemini = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _geminiDescription =
                "🌟 Great photo! There are many interesting things we can learn from this image.";
            _isLoadingGemini = false;
          });
        }
      }

      // Show results
      _showCaptureResult();

      // Delete photo file after some time (optional)
      Timer(const Duration(minutes: 5), () {
        try {
          File(photo.path).delete();
        } catch (e) {
          print('Error deleting photo: $e');
        }
      });
    } catch (e) {
      _handleError('Error taking photo: $e');
    } finally {
      setState(() {
        _isCapturing = false;
        _scannerState = ScannerState.ready;
      });
    }
  }

  void _showCaptureResult() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: ScannerConstants.surfaceVariantColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Container(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Text('📸', style: TextStyle(fontSize: 24)),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            "Your Photo Results",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: ScannerConstants.onSurfaceColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_capturedImagePath != null)
                      Container(
                        height: 200,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: ScannerConstants.primaryColor.withOpacity(
                              0.3,
                            ),
                            width: 2,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(
                            File(_capturedImagePath!),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: ScannerConstants.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: ScannerConstants.primaryColor.withOpacity(0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text('🤖', style: TextStyle(fontSize: 16)),
                              const SizedBox(width: 8),
                              const Text(
                                "Image Story:",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: ScannerConstants.onSurfaceColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _isLoadingGemini
                              ? Row(
                                children: [
                                  const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: ScannerConstants.primaryColor,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    "Creating story...",
                                    style: TextStyle(
                                      color:
                                          ScannerConstants
                                              .onSurfaceVariantColor,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              )
                              : Text(
                                _geminiDescription.isEmpty
                                    ? "🌟 Preparing an interesting story for you..."
                                    : _geminiDescription,
                                style: const TextStyle(
                                  color: ScannerConstants.onSurfaceVariantColor,
                                  fontSize: 14,
                                  height: 1.4,
                                ),
                              ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: TextButton.styleFrom(
                            foregroundColor:
                                ScannerConstants.onSurfaceVariantColor,
                          ),
                          child: Text(
                            "Close",
                            style: TextStyle(
                              fontSize:
                                  MediaQuery.of(context).size.width < 360
                                      ? 14
                                      : 16,
                            ),
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            _capturePhoto();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ScannerConstants.primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                          child: Text(
                            "Take Another",
                            style: TextStyle(
                              fontSize:
                                  MediaQuery.of(context).size.width < 360
                                      ? 14
                                      : 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _updateLabelCache(String label) {
    _labelCache.add(label);
    if (_labelCache.length > ScannerConstants.cacheSize) {
      _labelCache.removeAt(0);
    }
  }

  String? _getMostFrequentLabel() {
    if (_labelCache.isEmpty) return null;

    final Map<String, int> frequency = {};
    for (final label in _labelCache) {
      frequency[label] = (frequency[label] ?? 0) + 1;
    }

    String? mostFrequent;
    int maxCount = 0;

    frequency.forEach((label, count) {
      if (count > maxCount) {
        maxCount = count;
        mostFrequent = label;
      }
    });

    return mostFrequent;
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
          content: Row(
            children: [
              const Text('⚠️', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Expanded(child: Text(error)),
            ],
          ),
          backgroundColor: ScannerConstants.secondaryColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
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
        _handleError('Error zooming: $e');
      }
    });
  }

  Future<void> _zoomIn() async {
    try {
      final newZoom = math.min(_zoomLevel + 0.5, _maxZoom);
      if (newZoom != _zoomLevel) {
        await _cameraController.setZoomLevel(newZoom);
        setState(() => _zoomLevel = newZoom);
      }
    } catch (e) {
      _handleError('Error zooming in: $e');
    }
  }

  Future<void> _zoomOut() async {
    try {
      final newZoom = math.max(_zoomLevel - 0.5, _minZoom);
      if (newZoom != _zoomLevel) {
        await _cameraController.setZoomLevel(newZoom);
        setState(() => _zoomLevel = newZoom);
      }
    } catch (e) {
      _handleError('Error zooming out: $e');
    }
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
        backgroundColor: ScannerConstants.surfaceVariantColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
        title: Row(
          children: [
            const Text('🏠', style: TextStyle(fontSize: 24)),
            const SizedBox(width: 8),
            Flexible(
                      child: const Text(
                        "Return to Home",
                        style: TextStyle(
                          color: ScannerConstants.onSurfaceColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
            ),
          ],
        ),
        content: const Text(
                  "Are you sure you want to return to home?",
                  style: TextStyle(
                    color: ScannerConstants.onSurfaceVariantColor,
                  ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
                    style: TextButton.styleFrom(
                      foregroundColor: ScannerConstants.onSurfaceVariantColor,
                    ),
            child: const Text("No"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: ScannerConstants.primaryColor,
              foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
            ),
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
    _scanAnimationController.dispose();
    _pulseAnimationController.dispose();
    _captureAnimationController.dispose();
    if (_cameraController.value.isInitialized) {
      _cameraController.dispose();
    }
    _imageLabeler?.close();
    _streamSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    switch (_scannerState) {
      case ScannerState.initializing:
        body = ScannerLoadingView(
          isDownloadingModel: _isDownloadingModel,
          pulseAnimation: _pulseAnimation,
        );
        break;
      case ScannerState.error:
        body = ScannerErrorView(
          errorMessage: _errorMessage ?? 'An error occurred',
          onRetry: _initializeScanner,
        );
        break;
      case ScannerState.processing:
        body = Container(
          color: Colors.black,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(
                  color: ScannerConstants.primaryColor,
                ),
                const SizedBox(height: 20),
                const Text(
                  '📸 Processing photo...',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Please wait, creating an interesting story!',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
        );
        break;
      case ScannerState.ready:
        body = Stack(
          children: [
            ScannerView(
              cameraController: _cameraController,
              zoomLevel: _zoomLevel,
              detectedObject: _detectedObject,
              isDetecting: _isDetecting,
              scanAnimation: _scanAnimation,
              pulseAnimation: _pulseAnimation,
              onZoomIn: _zoomIn,
              onZoomOut: _zoomOut,
              onZoomGesture: _handleZoom,
            ),
            // Capture Photo Button
            Positioned(
              bottom: 30,
              left: 0,
              right: 0,
              child: Center(
                child: AnimatedBuilder(
                  animation: _captureAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _captureAnimation.value,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color:
                              _isCapturing
                                  ? ScannerConstants.secondaryColor
                                  : ScannerConstants.primaryColor,
                          border: Border.all(color: Colors.white, width: 4),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: _isCapturing ? null : _capturePhoto,
                            child: Center(
                              child:
                                  _isCapturing
                                      ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 3,
                                        ),
                                      )
                                      : const Text(
                                        '📸',
                                        style: TextStyle(fontSize: 32),
                                      ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        );
        break;
    }

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: ScannerConstants.surfaceColor,
        appBar: AppBar(
          backgroundColor: ScannerConstants.surfaceVariantColor,
          foregroundColor: ScannerConstants.onSurfaceColor,
          elevation: 0,
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('📱', style: TextStyle(fontSize: 24)),
              const SizedBox(width: 8),
              const Text(
                "Scanny",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              const Text('🔍', style: TextStyle(fontSize: 24)),
            ],
          ),
          centerTitle: true,
          actions: [
            Container(
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color:
                    _isFlashOn
                    ? ScannerConstants.tertiaryColor.withOpacity(0.2)
                    : ScannerConstants.primaryColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: IconButton(
                icon: Text(
                  _isFlashOn ? '💡' : '🔦',
                  style: const TextStyle(fontSize: 20),
                ),
                onPressed: _toggleFlash,
                tooltip: 'Toggle Flash',
              ),
            ),
          ],
        ),
        body: body,
      ),
    );
  }
}