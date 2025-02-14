import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'models/asr_model.dart';
import 'models/punctuation_model.dart';
import 'screens/benchmark_screen.dart';

// Define ASR models
final asrModels = [
  // Zipformer streaming model
  AsrModel(
    name: 'sherpa-onnx-streaming-zipformer-en-2023-06-26-mobile',
    encoder: 'encoder-epoch-99-avg-1-chunk-16-left-128.int8.onnx',
    decoder: 'decoder-epoch-99-avg-1-chunk-16-left-128.onnx',
    joiner: 'joiner-epoch-99-avg-1-chunk-16-left-128.int8.onnx',
    tokens: 'tokens.txt',
    modelType: 'zipformer2',
  ),
  // Whisper tiny.en model - float32
  WhisperModel(
    name: 'sherpa-onnx-whisper-tiny.en',
    encoder: 'tiny.en-encoder.onnx',
    decoder: 'tiny.en-decoder.onnx',
    joiner: '',
    tokens: 'tiny.en-tokens.txt',
  ),
  // Whisper tiny.en model - int8 quantized
  WhisperModel(
    name: 'sherpa-onnx-whisper-tiny.en.int8',
    encoder: 'tiny.en-encoder.int8.onnx',
    decoder: 'tiny.en-decoder.int8.onnx',
    joiner: '',
    tokens: 'tiny.en-tokens.txt',
  ),
];

// Define punctuation models
final punctuationModels = [
  PunctuationModel(
    name: 'sherpa-onnx-online-punct-en-2024-08-06',
    model: 'model.onnx',
    vocab: 'bpe.vocab',
  ),
];

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ASR Benchmark',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
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
      themeMode: ThemeMode.system,
      home: const SplashScreen(),
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

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String? _error;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      // Validate required directories
      await _validateDirectories();

      // Validate model files
      await _validateModelFiles();

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomePage()),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _validateDirectories() async {
    final requiredDirs = [
      p.join(Directory.current.path, 'assets'),
      p.join(Directory.current.path, 'assets', 'models'),
      p.join(Directory.current.path, 'assets', 'raw'),
      p.join(Directory.current.path, 'assets', 'curated'),
      p.join(Directory.current.path, 'assets', 'derived'),
    ];

    for (final dir in requiredDirs) {
      final directory = Directory(dir);
      if (!await directory.exists()) {
        try {
          await directory.create(recursive: true);
        } catch (e) {
          throw Exception('Failed to create directory: $dir\nError: $e');
        }
      }
    }
  }

  Future<void> _validateModelFiles() async {
    final modelDir =
        Directory(p.join(Directory.current.path, 'assets', 'models'));

    // Validate ASR model files
    for (final model in asrModels) {
      final files = [
        p.join(modelDir.path, model.name, model.encoder),
        p.join(modelDir.path, model.name, model.decoder),
        p.join(modelDir.path, model.name, model.tokens),
      ];

      // Add joiner for non-Whisper models
      if (model is! WhisperModel) {
        files.add(p.join(modelDir.path, model.name, model.joiner));
      }

      for (final file in files) {
        if (!await File(file).exists()) {
          throw Exception('Model file not found: $file');
        }
      }
    }

    // Validate punctuation model files
    for (final model in punctuationModels) {
      final files = [
        p.join(modelDir.path, model.name, model.model),
        p.join(modelDir.path, model.name, model.vocab),
      ];

      for (final file in files) {
        if (!await File(file).exists()) {
          throw Exception('Punctuation file not found: $file');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.red,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  'Initialization Error',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Initializing...'),
          ],
        ),
      ),
    );
  }
}
