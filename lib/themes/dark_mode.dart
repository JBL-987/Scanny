import 'package:flutter/material.dart';

ThemeData darkTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.dark(
    surface: const Color.fromARGB(255, 0, 0, 0),
    primary: const Color.fromARGB(255, 1, 45, 82),
    secondary: const Color.fromARGB(255, 8, 47, 66),
    tertiary: const Color.fromARGB(255, 28, 81, 105),
    outline: const Color.fromARGB(255, 0, 0, 0),
  ),
  textTheme: const TextTheme(
    headlineSmall: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
  ),
);
