import 'package:flutter/material.dart';

ThemeData lightTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.light(
    surface: const Color.fromRGBO(255, 253, 245, 1),
    primary: const Color.fromRGBO(255, 193, 7, 1),
    secondary: const Color.fromRGBO(255, 152, 0, 1),
    tertiary: const Color.fromRGBO(76, 175, 80, 1),
    outline: const Color.fromRGBO(255, 224, 130, 1),
    onPrimary: Colors.white,
    onSecondary: Colors.white,
    onSurface: const Color.fromRGBO(66, 66, 66, 1),
    surfaceVariant: const Color.fromRGBO(255, 248, 225, 1), 
  ),
  textTheme: const TextTheme(
    headlineSmall: TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.bold,
      color: Color.fromRGBO(66, 66, 66, 1),
    ),
    titleLarge: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: Color.fromRGBO(66, 66, 66, 1),
    ),
    bodyLarge: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w500,
      color: Color.fromRGBO(66, 66, 66, 1),
    ),
    bodyMedium: TextStyle(
      fontSize: 14,
      color: Color.fromRGBO(117, 117, 117, 1),
    ),
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: Color.fromRGBO(255, 248, 225, 1),
    foregroundColor: Color.fromRGBO(66, 66, 66, 1),
    elevation: 0,
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: const Color.fromRGBO(255, 193, 7, 1),
      foregroundColor: Colors.white,
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
    ),
  ),
);
