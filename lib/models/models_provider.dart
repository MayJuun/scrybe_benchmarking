import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:scrybe_benchmarking/scrybe_benchmarking.dart';

// A provider that loads and manages the models
final modelsProvider = FutureProvider<List<AsrModel>>((ref) async {
  try {
    final models = await loadModels();

    // Optionally log model configs
    for (final model in models) {
      if (model is OfflineRecognizerModel) {
        debugPrint(jsonEncode(model.recognizer.config.toJson()));
      } else if (model is OnlineRecognizerModel) {
        debugPrint(jsonEncode(model.recognizer.config.toJson()));
      }
    }

    return models;
  } catch (e) {
    debugPrint('Error loading models: $e');
    return <AsrModel>[];
  }
});
