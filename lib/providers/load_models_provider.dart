import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:scrybe_benchmarking/scrybe_benchmarking.dart';

// A simple immutable state class for the model loading
class LoadModelsState {
  final bool isLoading;
  final List<OfflineModel> models;

  const LoadModelsState({
    this.isLoading = true,
    this.models = const [],
  });

  LoadModelsState copyWith({
    bool? isLoading,
    List<OfflineModel>? models,
  }) {
    return LoadModelsState(
      isLoading: isLoading ?? this.isLoading,
      models: models ?? this.models,
    );
  }
}

// Our Notifier
class LoadModelsNotifier extends Notifier<LoadModelsState> {
  @override
  LoadModelsState build() {
    // Start in loading state
    _initModels();
    return const LoadModelsState();
  }

  Future<void> _initModels() async {
    try {
      final offlineConfigs = await loadOfflineModels();

      state = state.copyWith(
        isLoading: false,
        models: offlineConfigs,
      );
    } catch (e) {
      debugPrint('Error loading models: $e');
      state = state.copyWith(isLoading: false);
    }
  }
}

// The provider
final loadModelsNotifierProvider =
    NotifierProvider<LoadModelsNotifier, LoadModelsState>(
  LoadModelsNotifier.new,
);
