import 'package:flutter/material.dart';

ThemeData lightTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.light(
    surface: Colors.white,
    primary: const Color.fromRGBO(33, 150, 243, 1),
    secondary: Colors.lightBlue,
    tertiary: Colors.lightBlueAccent,
    outline: Colors.grey.shade300,
  ),
  textTheme: const TextTheme(
    headlineSmall: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
  ),
);
