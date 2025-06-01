import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:math' as math;
import 'scanner_constants.dart';

class ScannerView extends StatelessWidget {
  final CameraController cameraController;
  final double zoomLevel;
  final String detectedObject;
  final bool isDetecting;
  final Animation<double> scanAnimation;
  final Animation<double> pulseAnimation;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final Function(double) onZoomGesture;

  const ScannerView({
    super.key,
    required this.cameraController,
    required this.zoomLevel,
    required this.detectedObject,
    required this.isDetecting,
    required this.scanAnimation,
    required this.pulseAnimation,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onZoomGesture,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenSize = _ScreenSize.from(constraints);

        return GestureDetector(
          onVerticalDragUpdate: (details) {
            final sensitivity = screenSize.isSmall ? 120.0 : 100.0;
            onZoomGesture(-details.delta.dy / sensitivity);
          },
          child: Container(
            color: ScannerConstants.surfaceColor,
            child: SafeArea(
              child: Column(
                children: [
                  _buildCameraSection(screenSize),
                  _buildInfoSection(screenSize),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCameraSection(_ScreenSize screenSize) {
    return Expanded(
      flex: screenSize.cameraFlex,
      child: Container(
        margin: EdgeInsets.all(screenSize.margin),
        decoration: _buildCameraContainerDecoration(),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Camera preview that fills the container
              SizedBox.expand(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: cameraController.value.previewSize?.width ?? 1,
                    height: cameraController.value.previewSize?.height ?? 1,
                    child: CameraPreview(cameraController),
                  ),
                ),
              ),
              _buildZoomIndicator(screenSize),
              _buildScanningFrame(screenSize),
              Positioned(
                bottom: 20,
                child: _buildZoomControls(screenSize),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoSection(_ScreenSize screenSize) {
    return Expanded(
      flex: screenSize.infoFlex,
      child: Container(
        width: double.infinity,
        margin: EdgeInsets.fromLTRB(
          screenSize.margin,
          0,
          screenSize.margin,
          screenSize.margin,
        ),
        padding: EdgeInsets.all(screenSize.padding),
        decoration: _buildInfoContainerDecoration(),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildDetectionResult(screenSize),
            SizedBox(height: screenSize.spacing),
          ],
        ),
      ),
    );
  }

  Widget _buildScanningFrame(_ScreenSize screenSize) {
    return AnimatedBuilder(
      animation: scanAnimation,
      builder: (context, child) {
        return Container(
          width: screenSize.frameSize,
          height: screenSize.frameSize,
          decoration: BoxDecoration(
            border: Border.all(
              color: ScannerConstants.primaryColor,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
        );
      },
    );
  }

  Widget _buildZoomControls(_ScreenSize screenSize) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      decoration: BoxDecoration(
        color: ScannerConstants.surfaceVariantColor.withOpacity(0.8),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildZoomButton(Icons.remove, onZoomOut),
          SizedBox(width: 20),
          Text(
            '${zoomLevel.toStringAsFixed(1)}x',
            style: TextStyle(
              color: ScannerConstants.onSurfaceColor,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          SizedBox(width: 20),
          _buildZoomButton(Icons.add, onZoomIn),
        ],
      ),
    );
  }

  BoxDecoration _buildCameraContainerDecoration() {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: ScannerConstants.primaryColor.withOpacity(0.3),
        width: 2,
      ),
      boxShadow: [
        BoxShadow(
          color: ScannerConstants.primaryColor.withOpacity(0.1),
          blurRadius: 20,
          spreadRadius: 2,
        ),
      ],
    );
  }

  BoxDecoration _buildInfoContainerDecoration() {
    return BoxDecoration(
      color: ScannerConstants.surfaceVariantColor,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: ScannerConstants.primaryColor.withOpacity(0.2)),
      boxShadow: [
        BoxShadow(
          color: ScannerConstants.primaryColor.withOpacity(0.1),
          blurRadius: 10,
          spreadRadius: 1,
        ),
      ],
    );
  }

  Widget _buildZoomIndicator(_ScreenSize screenSize) {
    return Positioned(
      top: 12,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: ScannerConstants.surfaceVariantColor.withOpacity(0.9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: ScannerConstants.primaryColor.withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🔍', style: TextStyle(fontSize: 14)),
            const SizedBox(width: 4),
            Text(
              '${zoomLevel.toStringAsFixed(1)}x',
              style: TextStyle(
                color: ScannerConstants.onSurfaceColor,
                fontWeight: FontWeight.bold,
                fontSize: screenSize.zoomIndicatorFontSize,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildZoomButton(IconData icon, VoidCallback onPressed) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: ScannerConstants.surfaceVariantColor.withOpacity(0.9),
            shape: BoxShape.circle,
            border: Border.all(
              color: ScannerConstants.primaryColor.withOpacity(0.3),
            ),
            boxShadow: [
              BoxShadow(
                color: ScannerConstants.primaryColor.withOpacity(0.2),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Icon(icon, color: ScannerConstants.onSurfaceColor, size: 24),
        ),
      ),
    );
  }

  Widget _buildDetectionResult(_ScreenSize screenSize) {
    return AnimatedBuilder(
      animation: pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: isDetecting ? pulseAnimation.value : 1.0,
          child: Text(
            detectedObject.isEmpty ? 'Scanning...' : detectedObject,
            style: TextStyle(
              fontSize: screenSize.detectionFontSize,
              color: ScannerConstants.tertiaryColor,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        );
      },
    );
  }
}

class _ScreenSize {
  final double width;
  final double height;
  final bool isSmall;

  _ScreenSize._({
    required this.width,
    required this.height,
    required this.isSmall,
  });

  factory _ScreenSize.from(BoxConstraints constraints) {
    return _ScreenSize._(
      width: constraints.maxWidth,
      height: constraints.maxHeight,
      isSmall: constraints.maxHeight < 700,
    );
  }

  int get cameraFlex => isSmall ? 3 : 4;
  int get infoFlex => isSmall ? 2 : 1;
  double get frameSize => math.min(width * 0.75, height * 0.4);
  double get margin => math.min(16, width * 0.04);
  double get padding => math.min(20, width * 0.05);
  double get spacing => math.min(12, height * 0.015);
  double get zoomIndicatorFontSize => isSmall ? 12 : 14;
  double get detectionFontSize => math.min(isSmall ? 16 : 20, width * 0.05);
  double get hintFontSize => math.min(isSmall ? 11 : 13, width * 0.03);
  double get hintIconSize => math.min(16, width * 0.04);
  double get hintPaddingH => math.min(16, width * 0.04);
  double get hintPaddingV => math.min(8, height * 0.01);
  double get hintSpacing => math.min(8, width * 0.02);
}