import 'package:flutter/material.dart';
import 'package:scrybe_benchmarking/scrybe_benchmarking.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  ColorScheme colorFromSeed(Brightness brightness) =>
      ColorScheme.fromSeed(seedColor: Colors.blue, brightness: brightness);

  RoundedRectangleBorder roundedRectangleBorder(double border) =>
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(border));

  FilledButtonThemeData filledButtonThemeData() => FilledButtonThemeData(
      style: FilledButton.styleFrom(shape: roundedRectangleBorder(8)));

  CardTheme cardTheme() =>
      CardTheme(elevation: 0, shape: roundedRectangleBorder(12));

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ASR Benchmark',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: colorFromSeed(Brightness.light),
        useMaterial3: true,
        cardTheme: cardTheme(),
        filledButtonTheme: filledButtonThemeData(),
      ),
      darkTheme: ThemeData(
        colorScheme: colorFromSeed(Brightness.dark),
        cardTheme: cardTheme(),
        filledButtonTheme: filledButtonThemeData(),
      ),
      themeMode: ThemeMode.system,
      home: const SplashScreen(),
    );
  }
}
