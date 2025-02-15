import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;

enum PunctuationType {
  online,
  offline,
}

class PunctuationService {
  sherpa_onnx.OnlinePunctuation? _onlinePunctuation;
  sherpa_onnx.OfflinePunctuation? _offlinePunctuation;
  final PunctuationType type;

  PunctuationService({required this.type});

  Future<void> initialize({required String modelDir}) async {
    switch (type) {
      case PunctuationType.online:
        await _initializeOnline(modelDir);
        break;
      case PunctuationType.offline:
        await _initializeOffline(modelDir);
        break;
    }
  }

  Future<void> _initializeOnline(String modelDir) async {
    

    final modelPath = p.join(modelDir, 'model.onnx');
    final vocabPath = p.join(modelDir, 'bpe.vocab');

    // Check if files exist
    final modelExists = await File(modelPath).exists();
    final vocabExists = await File(vocabPath).exists();

    
    

    if (!modelExists || !vocabExists) {
      throw Exception('Missing required files for punctuation model');
    }

    final config = sherpa_onnx.OnlinePunctuationModelConfig(
      cnnBiLstm: modelPath,
      bpeVocab: vocabPath,
    );

    final puncConfig = sherpa_onnx.OnlinePunctuationConfig(model: config);
    _onlinePunctuation = sherpa_onnx.OnlinePunctuation(config: puncConfig);

    if (_onlinePunctuation?.ptr == null) {
      throw Exception('Failed to create OnlinePunctuation');
    }

  }

  Future<void> _initializeOffline(String modelDir) async {
    

    final ctTransformerPath = p.join(modelDir, 'model.onnx');

    // Check if files exist
    final ctTransformerExists = await File(ctTransformerPath).exists();


    if (!ctTransformerExists) {
      throw Exception('Missing required files for punctuation model');
    }

    final modelConfig = sherpa_onnx.OfflinePunctuationModelConfig(
      ctTransformer: ctTransformerPath,
      numThreads: 1,
      provider: 'cpu',
      debug: false,
    );

    final config = sherpa_onnx.OfflinePunctuationConfig(model: modelConfig);
    _offlinePunctuation = sherpa_onnx.OfflinePunctuation(config: config);

    if (_offlinePunctuation?.ptr == null) {
      throw Exception('Failed to create OfflinePunctuation');
    }
  }

  String addPunctuation(String text) {
    final normalizedText = text.toLowerCase().trim();
    

    switch (type) {
      case PunctuationType.online:
        
        if (_onlinePunctuation == null) {
          throw StateError('Online punctuation not initialized');
        }
        // Add more debug info
        
        try {
          final result = _onlinePunctuation!.addPunct(normalizedText);
          
          
          if (result.isEmpty) {
            // If empty, return the original text to avoid losing content
            print('Empty punctuation result, returning original text');
            return normalizedText;
          }
          return result;
        } catch (e) {
          print('Error in addPunct: $e');
          // Return original text on error
          return normalizedText;
        }

      case PunctuationType.offline:
        
        if (_offlinePunctuation == null) {
          throw StateError('Online punctuation not initialized');
        }
        // Add more debug info
        
        try {
          final result = _offlinePunctuation!.addPunct(normalizedText);
          
          
          if (result.isEmpty) {
            // If empty, return the original text to avoid losing content
            
            return normalizedText;
          }
          return result;
        } catch (e) {
          print('Error in addPunct: $e');
          // Return original text on error
          return normalizedText;
        }
    }
  }

  void dispose() {
    _onlinePunctuation?.free();
    _offlinePunctuation?.free();
    _onlinePunctuation = null;
    _offlinePunctuation = null;
  }
}
