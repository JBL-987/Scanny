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

enum ScannerState { initializing, ready, error, scanning }

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
  String _detectedObject = "🔍 Scanning...";
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

  // Animation controllers
  late AnimationController _scanAnimationController;
  late AnimationController _pulseAnimationController;
  late Animation<double> _scanAnimation;
  late Animation<double> _pulseAnimation;

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

    _scanAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scanAnimationController,
      curve: Curves.easeInOut,
    ));

    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _pulseAnimationController,
      curve: Curves.easeInOut,
    ));
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
      final filteredLabels = labels
          .where((label) => label.confidence > ScannerConstants.confidenceThreshold)
          .take(ScannerConstants.maxLabelsToShow)
          .map((label) => label.label)
          .toList();

      if (filteredLabels.isNotEmpty) {
        _updateLabelCache(filteredLabels.first);
        final mostFrequentLabel = _getMostFrequentLabel();

        setState(() {
          _detectedObject = "🎯 ${mostFrequentLabel ?? "No objects detected"}";
        });
      } else {
        setState(() {
          _detectedObject = "🔍 Looking for objects...";
        });
      }
    } catch (e) {
      print('Error processing image: $e');
    }
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
      builder: (context) => AlertDialog(
        backgroundColor: ScannerConstants.surfaceVariantColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Text('🏠', style: TextStyle(fontSize: 24)),
            const SizedBox(width: 8),
            Flexible(
                child: const Text(
                  "Back to Home",
                  style: TextStyle(color: ScannerConstants.onSurfaceColor),
                  overflow: TextOverflow.ellipsis,
                )
            ),
          ],
        ),
        content: const Text(
          "Are you sure you want to go back?",
          style: TextStyle(color: ScannerConstants.onSurfaceVariantColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(foregroundColor: ScannerConstants.onSurfaceVariantColor),
            child: const Text("No"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: ScannerConstants.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
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
      case ScannerState.ready:
      case ScannerState.scanning:
        body = ScannerView(
          cameraController: _cameraController,
          zoomLevel: _zoomLevel,
          detectedObject: _detectedObject,
          isDetecting: _isDetecting,
          scanAnimation: _scanAnimation,
          pulseAnimation: _pulseAnimation,
          onZoomIn: _zoomIn,
          onZoomOut: _zoomOut,
          onZoomGesture: _handleZoom,
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
                color: _isFlashOn
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