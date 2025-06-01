import 'package:flutter/material.dart';
import 'scanner_constants.dart';

class ScannerLoadingView extends StatelessWidget {
  final bool isDownloadingModel;
  final Animation<double> pulseAnimation;

  const ScannerLoadingView({
    super.key,
    required this.isDownloadingModel,
    required this.pulseAnimation,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ScannerConstants.surfaceColor,
      child: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: pulseAnimation.value,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: ScannerConstants.surfaceVariantColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: ScannerConstants.primaryColor.withOpacity(0.3)),
                        boxShadow: [
                          BoxShadow(
                            color: ScannerConstants.primaryColor.withOpacity(0.2),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Text('📷', style: TextStyle(fontSize: 48)),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              const CircularProgressIndicator(
                color: ScannerConstants.primaryColor,
                strokeWidth: 3,
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Text(
                  isDownloadingModel
                      ? '📥 Downloading AI model...\nThis may take a moment'
                      : '🚀 Initializing smart scanner...',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: ScannerConstants.onSurfaceColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 