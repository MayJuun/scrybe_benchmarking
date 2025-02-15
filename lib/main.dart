import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'models/asr_model.dart';
import 'models/punctuation_model.dart';
import 'screens/benchmark_screen.dart';

final asrModels = [
  // 1) Offline Moonshine model
  AsrModel(
    name: 'sherpa-onnx-moonshine-base-en-int8',
    encoder: 'encode.int8.onnx',
    decoder: '',
    preprocessor: 'preprocess.onnx',
    uncachedDecoder: 'uncached_decode.int8.onnx',
    cachedDecoder: 'cached_decode.int8.onnx',
    joiner: '',
    tokens: 'tokens.txt',
    modelType: SherpaModelType.moonshine,
  ),

  // 2) Offline Nemo transducer
  AsrModel(
    name: 'sherpa-onnx-nemo-fast-conformer-transducer-en-24500',
    encoder: 'encoder.onnx',
    decoder: 'decoder.onnx',
    preprocessor: '',
    uncachedDecoder: '',
    cachedDecoder: '',
    joiner: 'joiner.onnx',
    tokens: 'tokens.txt',
    modelType: SherpaModelType.nemoTransducer,
  ),

  // 3) Streaming Zipformer transducer (v2)
  AsrModel(
    name: 'sherpa-onnx-streaming-zipformer-en-2023-06-26-mobile',
    encoder: 'encoder-epoch-99-avg-1-chunk-16-left-128.onnx',
    decoder: 'decoder-epoch-99-avg-1-chunk-16-left-128.onnx',
    preprocessor: '',
    uncachedDecoder: '',
    cachedDecoder: '',
    joiner: 'joiner-epoch-99-avg-1-chunk-16-left-128.int8.onnx',
    tokens: 'tokens.txt',
    modelType: SherpaModelType.zipformer2,
  ),

  // 4) Streaming Zipformer v2 (INT8)
  AsrModel(
    name: 'sherpa-onnx-streaming-zipformer-en-2023-06-26-mobile.int8',
    encoder: 'encoder-epoch-99-avg-1-chunk-16-left-128.int8.onnx',
    decoder: 'decoder-epoch-99-avg-1-chunk-16-left-128.onnx',
    preprocessor: '',
    uncachedDecoder: '',
    cachedDecoder: '',
    joiner: 'joiner-epoch-99-avg-1-chunk-16-left-128.int8.onnx',
    tokens: 'tokens.txt',
    modelType: SherpaModelType.zipformer2,
  ),

  // 5..10) Offline Whisper models
  AsrModel(
    name: 'sherpa-onnx-whisper-medium.en',
    encoder: 'medium.en-encoder.onnx',
    decoder: 'medium.en-decoder.onnx',
    preprocessor: '',
    uncachedDecoder: '',
    cachedDecoder: '',
    joiner: '',
    tokens: 'medium.en-tokens.txt',
    modelType: SherpaModelType.whisper,
  ),
  AsrModel(
    name: 'sherpa-onnx-whisper-medium.en.int8',
    encoder: 'medium.en-encoder.int8.onnx',
    decoder: 'medium.en-decoder.int8.onnx',
    preprocessor: '',
    uncachedDecoder: '',
    cachedDecoder: '',
    joiner: '',
    tokens: 'medium.en-tokens.txt',
    modelType: SherpaModelType.whisper,
  ),
  AsrModel(
    name: 'sherpa-onnx-whisper-small.en',
    encoder: 'small.en-encoder.onnx',
    decoder: 'small.en-decoder.onnx',
    preprocessor: '',
    uncachedDecoder: '',
    cachedDecoder: '',
    joiner: '',
    tokens: 'small.en-tokens.txt',
    modelType: SherpaModelType.whisper,
  ),
  AsrModel(
    name: 'sherpa-onnx-whisper-small.en.int8',
    encoder: 'small.en-encoder.int8.onnx',
    decoder: 'small.en-decoder.int8.onnx',
    preprocessor: '',
    uncachedDecoder: '',
    cachedDecoder: '',
    joiner: '',
    tokens: 'small.en-tokens.txt',
    modelType: SherpaModelType.whisper,
  ),
  AsrModel(
    name: 'sherpa-onnx-whisper-tiny.en',
    encoder: 'tiny.en-encoder.onnx',
    decoder: 'tiny.en-decoder.onnx',
    preprocessor: '',
    uncachedDecoder: '',
    cachedDecoder: '',
    joiner: '',
    tokens: 'tiny.en-tokens.txt',
    modelType: SherpaModelType.whisper,
  ),
  AsrModel(
    name: 'sherpa-onnx-whisper-tiny.en.int8',
    encoder: 'tiny.en-encoder.int8.onnx',
    decoder: 'tiny.en-decoder.int8.onnx',
    preprocessor: '',
    uncachedDecoder: '',
    cachedDecoder: '',
    joiner: '',
    tokens: 'tiny.en-tokens.txt',
    modelType: SherpaModelType.whisper,
  ),

  // 11) Offline Zipformer transducer
  AsrModel(
    name: 'sherpa-onnx-zipformer-small-en-2023-06-26',
    encoder: 'encoder-epoch-99-avg-1.onnx',
    decoder: 'decoder-epoch-99-avg-1.onnx',
    preprocessor: '',
    uncachedDecoder: '',
    cachedDecoder: '',
    joiner: 'joiner-epoch-99-avg-1.onnx',
    tokens: 'tokens.txt',
    modelType: SherpaModelType.transducer,
  ),

  // 12) Offline Zipformer transducer (INT8)
  AsrModel(
    name: 'sherpa-onnx-zipformer-small-en-2023-06-26.int8',
    encoder: 'encoder-epoch-99-avg-1.int8.onnx',
    decoder: 'decoder-epoch-99-avg-1.int8.onnx',
    preprocessor: '',
    uncachedDecoder: '',
    cachedDecoder: '',
    joiner: 'joiner-epoch-99-avg-1.int8.onnx',
    tokens: 'tokens.txt',
    modelType: SherpaModelType.transducer,
  ),

  // 13) Nemo CTC offline
  AsrModel(
    name: 'sherpa-onnx-nemo-ctc-en-conformer-large',
    encoder: 'model.int8.onnx',
    decoder: '',
    preprocessor: '',
    uncachedDecoder: '',
    cachedDecoder: '',
    joiner: '',
    tokens: 'tokens.txt',
    modelType: SherpaModelType.nemoCtcOffline,
  ),

  // 14) Nemo CTC offline
  AsrModel(
    name: 'sherpa-onnx-nemo-ctc-en-conformer-small',
    encoder: 'model.int8.onnx',
    decoder: '',
    preprocessor: '',
    uncachedDecoder: '',
    cachedDecoder: '',
    joiner: '',
    tokens: 'tokens.txt',
    modelType: SherpaModelType.nemoCtcOffline,
  ),

  // 15) (Commented out) Nemo streaming fast-conformer => Nemo CTC online?
  // AsrModel(
  //   name: 'sherpa-onnx-nemo-streaming-fast-conformer-ctc-en-80ms',
  //   encoder: 'model.onnx',
  //   tokens: 'tokens.txt',
  //   ...
  //   modelType: SherpaModelType.nemoCtcOnline, // if we want streaming
  // ),

  // 16) Streaming Zipformer2 CTC
  AsrModel(
    name: 'sherpa-onnx-streaming-zipformer-ctc-small-2024-03-18',
    encoder: 'ctc-epoch-30-avg-3-chunk-16-left-128.onnx',
    decoder: '',
    preprocessor: '',
    uncachedDecoder: '',
    cachedDecoder: '',
    joiner: '',
    tokens: 'tokens.txt',
    modelType: SherpaModelType.zipformer2Ctc,
  ),

  // 17) Streaming Zipformer v2 transducer
  AsrModel(
    name: 'sherpa-onnx-streaming-zipformer-en-2023-06-26',
    encoder: 'encoder-epoch-99-avg-1-chunk-16-left-128.onnx',
    decoder: 'decoder-epoch-99-avg-1-chunk-16-left-128.onnx',
    preprocessor: '',
    uncachedDecoder: '',
    cachedDecoder: '',
    joiner: 'joiner-epoch-99-avg-1-chunk-16-left-128.onnx',
    tokens: 'tokens.txt',
    modelType: SherpaModelType.zipformer2,
  ),

  // 18) Streaming Zipformer v2 transducer (INT8)
  AsrModel(
    name: 'sherpa-onnx-streaming-zipformer-en-2023-06-26.int8',
    encoder: 'encoder-epoch-99-avg-1-chunk-16-left-128.int8.onnx',
    decoder: 'decoder-epoch-99-avg-1-chunk-16-left-128.int8.onnx',
    preprocessor: '',
    uncachedDecoder: '',
    cachedDecoder: '',
    joiner: 'joiner-epoch-99-avg-1-chunk-16-left-128.int8.onnx',
    tokens: 'tokens.txt',
    modelType: SherpaModelType.zipformer2,
  ),

  // 19) Offline zipformer (large)
  AsrModel(
    name: 'sherpa-onnx-zipformer-large-en-2023-06-26',
    encoder: 'encoder-epoch-99-avg-1.onnx',
    decoder: 'decoder-epoch-99-avg-1.onnx',
    preprocessor: '',
    uncachedDecoder: '',
    cachedDecoder: '',
    joiner: 'joiner-epoch-99-avg-1.onnx',
    tokens: 'tokens.txt',
    modelType: SherpaModelType.transducer,
  ),

  // 20) Offline zipformer (large) INT8
  AsrModel(
    name: 'sherpa-onnx-zipformer-large-en-2023-06-26.int8',
    encoder: 'encoder-epoch-99-avg-1.int8.onnx',
    decoder: 'decoder-epoch-99-avg-1.int8.onnx',
    preprocessor: '',
    uncachedDecoder: '',
    cachedDecoder: '',
    joiner: 'joiner-epoch-99-avg-1.int8.onnx',
    tokens: 'tokens.txt',
    modelType: SherpaModelType.transducer,
  ),
];

// Define punctuation models
final punctuationModels = <PunctuationModel>[
  // PunctuationModel(
  //   name: 'sherpa-onnx-online-punct-en-2024-08-06',
  //   model: 'model.onnx',
  //   vocab: 'bpe.vocab',
  // ),
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
