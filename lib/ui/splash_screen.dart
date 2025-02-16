import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:scrybe_benchmarking/scrybe_benchmarking.dart';

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
