// ignore_for_file: unintended_html_in_doc_comment

import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

class AudioTestFiles {
  AudioTestFiles({
    this.getFileDuration,
    this.fileExtension = '.wav',
  });

  final List<String> _testFiles = [];
  final Map<String, String> _referenceTranscripts = {};
  final Map<String, int> _fileDurations = {};
  int currentFileIndex = -1;

  /// File extension to look for (e.g., '.wav')
  final String fileExtension;

  /// A callback that returns a Future<int> for the file duration,
  /// given a wavFile path and sampleRate.
  final Future<int> Function(String wavFile, int sampleRate)? getFileDuration;

  /// Load test audio files + reference transcripts from assets
  Future<void> loadDictationFiles(
      {required String rootDir, int sampleRate = 16000}) async {
    try {
      final manifest = await rootBundle.loadString('AssetManifest.json');
      final Map<String, dynamic> manifestMap = json.decode(manifest);

      // Filter for files in the specified directory with the specified extension
      _testFiles.addAll(
        manifestMap.keys
            .where((String key) =>
                key.startsWith(rootDir) && key.endsWith(fileExtension))
            .toList(),
      );
      await _afterFilesLoad(sampleRate);
    } catch (e) {
      print('Error loading test files: $e');
      _testFiles.clear();
      currentFileIndex = -1;
    }
  }

  Future<void> loadTranscriptionFiles({int sampleRate = 16000}) async {
    final curatedDir =
        Directory(p.join(Directory.current.path, 'assets', 'curated'));

    print(!await curatedDir.exists());

    _testFiles.addAll(!await curatedDir.exists()
        ? []
        : curatedDir
            .listSync(recursive: true)
            .map((e) => e.path)
            .toList()
            .where((p) => p.endsWith('.wav'))
            .toList());
    await _afterFilesLoad(sampleRate);
  }

  Future<void> _afterFilesLoad(int sampleRate) async {
    // Load transcripts (SRT files) and measure audio durations
    for (final audioFile in _testFiles) {
      final srtFile = audioFile.replaceAll(fileExtension, '.srt');
      try {
        final srtContent = await rootBundle.loadString(srtFile);
        _referenceTranscripts[audioFile] = _stripSrt(srtContent);
      } catch (e) {
        // If no SRT file, store empty reference
        _referenceTranscripts[audioFile] = '';
      }

      // Use the provided callback to get the duration.
      if (getFileDuration != null) {
        _fileDurations[audioFile] =
            await getFileDuration!(audioFile, sampleRate);
      }
    }

    currentFileIndex = _testFiles.isEmpty ? -1 : 0;
    print('Loaded ${_testFiles.length} test files with '
        '${_referenceTranscripts.length} transcripts');
  }

  /// Convert SRT text to a simple raw transcript.
  String _stripSrt(String text) {
    final lines = text.split('\n');
    final sb = StringBuffer();
    for (final l in lines) {
      final trimmed = l.trim();
      if (trimmed.isEmpty) continue;
      // Skip lines that are just numbers or contain `-->`
      if (RegExp(r'^\d+$').hasMatch(trimmed)) continue;
      if (trimmed.contains('-->')) continue;
      sb.write('$trimmed ');
    }
    return sb.toString().trim();
  }

  bool get isEmpty => _testFiles.isEmpty;
  int get length => _testFiles.length;
  String get currentFile =>
      _testFiles.isEmpty ? '' : _testFiles[currentFileIndex];
  String? get currentReferenceTranscript => _referenceTranscripts[currentFile];
  int? get currentFileDuration => _fileDurations[currentFile];

  // Access all files as a list
  List<String> get allFiles => List.unmodifiable(_testFiles);

  // Get reference transcript for any file
  String? getReferenceTranscript(String filePath) =>
      _referenceTranscripts[filePath];

  // Get duration for any file
  int? getFileDurationMs(String filePath) => _fileDurations[filePath];
}

// Provider for preloaded test files (ready to use)
final dictationFilesProvider = FutureProvider<AudioTestFiles>((ref) async {
  final testFiles = AudioTestFiles();
  await testFiles.loadDictationFiles(
      rootDir: 'assets/dictation_test/test_files/');
  return testFiles;
});

final transcriptionFilesProvider = FutureProvider<AudioTestFiles>((ref) async {
  final testFiles = AudioTestFiles();
  await testFiles.loadTranscriptionFiles();
  print('all files loaded');
  return testFiles;
});
