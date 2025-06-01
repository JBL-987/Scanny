import 'package:flutter/material.dart';

class ScannerConstants {
  static const Color surfaceColor = Color.fromRGBO(255, 253, 245, 1);
  static const Color primaryColor = Color.fromRGBO(255, 193, 7, 1);
  static const Color secondaryColor = Color.fromRGBO(255, 152, 0, 1);
  static const Color tertiaryColor = Color.fromRGBO(76, 175, 80, 1);
  static const Color surfaceVariantColor = Color.fromRGBO(255, 248, 225, 1);
  static const Color onSurfaceColor = Color.fromRGBO(66, 66, 66, 1);
  static const Color onSurfaceVariantColor = Color.fromRGBO(117, 117, 117, 1);
  static const int maxLabelsToShow = 1;
  static const double confidenceThreshold = 0.65;
  static const Duration processingDelay = Duration(milliseconds: 300);
  static const int cacheSize = 3;
} 