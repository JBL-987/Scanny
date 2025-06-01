import 'package:flutter/material.dart';
import 'scanner_constants.dart';

class ScannerErrorView extends StatelessWidget {
  final String errorMessage;
  final VoidCallback onRetry;

  const ScannerErrorView({
    super.key,
    required this.errorMessage,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ScannerConstants.surfaceColor,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: ScannerConstants.surfaceVariantColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: ScannerConstants.secondaryColor.withOpacity(0.3)),
                  ),
                  child: const Text('⚠️', style: TextStyle(fontSize: 48)),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Oops! Something went wrong',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: ScannerConstants.onSurfaceColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  errorMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: ScannerConstants.onSurfaceVariantColor,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Text('🔄', style: TextStyle(fontSize: 16)),
                  label: const Text('Try Again'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ScannerConstants.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
} 