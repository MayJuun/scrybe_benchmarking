import 'package:flutter/material.dart';
import 'screens/benchmark_screen.dart';
import 'models/asr_model.dart';
import 'models/punctuation_model.dart';

// Define your ASR models
final asrModels = [
  AsrModel(
    name: 'sherpa-onnx-streaming-zipformer-en-2023-06-26-mobile',
    encoder: 'encoder-epoch-99-avg-1-chunk-16-left-128.int8.onnx',
    decoder: 'decoder-epoch-99-avg-1-chunk-16-left-128.onnx',
    joiner: 'joiner-epoch-99-avg-1-chunk-16-left-128.int8.onnx',
    tokens: 'tokens.txt',
    modelType: 'zipformer2',
  ),
  // Add more models as needed
];

// Define your punctuation models if any
final punctuationModels = [
  PunctuationModel(
    name: 'sherpa-onnx-online-punct-en-2024-08-06',
    model: 'model.onnx',
    vocab: 'bpe.vocab',
  ),
  // Add more punctuation models as needed
];

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sherpa Onnx Benchmark',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        // Customize card themes
        cardTheme: CardTheme(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        // Customize button themes
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        cardTheme: CardTheme(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
      themeMode: ThemeMode.system, // Respect system theme settings
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BenchmarkScreen(
      asrModels: asrModels,
      punctuationModels: punctuationModels,
    );
  }
}

// Optional: Add this if you want a loading screen while initializing
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    // Add any initialization logic here
    // For example:
    // - Check for required directories
    // - Verify model files exist
    // - Initialize any services

    // After initialization, navigate to the main screen
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const HomePage(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}