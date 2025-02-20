import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart';
import 'package:scrybe_benchmarking/scrybe_benchmarking.dart'; 

// A simple immutable state class for the model loading
class ModelState {
  final bool isLoading;
  final List<OnlineRecognizerConfig> onlineConfigs;
  final List<OfflineRecognizerConfig> offlineConfigs;

  const ModelState({
    this.isLoading = true,
    this.onlineConfigs = const [],
    this.offlineConfigs = const [],
  });

  ModelState copyWith({
    bool? isLoading,
    List<OnlineRecognizerConfig>? onlineConfigs,
    List<OfflineRecognizerConfig>? offlineConfigs,
  }) {
    return ModelState(
      isLoading: isLoading ?? this.isLoading,
      onlineConfigs: onlineConfigs ?? this.onlineConfigs,
      offlineConfigs: offlineConfigs ?? this.offlineConfigs,
    );
  }
}

// Our Notifier
class ModelNotifier extends Notifier<ModelState> {
  @override
  ModelState build() {
    // Start in loading state
    _initModels();
    return const ModelState(); 
  }

  Future<void> _initModels() async {
    try {
      final onlineConfigs = await loadOnlineConfigs();
      final offlineConfigs = await loadOfflineConfigs();

      state = state.copyWith(
        isLoading: false,
        onlineConfigs: onlineConfigs,
        offlineConfigs: offlineConfigs,
      );
    } catch (e) {
      debugPrint('Error loading models: $e');
      state = state.copyWith(isLoading: false);
    }
  }
}

// The provider
final modelNotifierProvider = NotifierProvider<ModelNotifier, ModelState>(
  ModelNotifier.new,
);
