// ignore_for_file: unintended_html_in_doc_comment

import 'dart:convert';

import 'package:flutter/services.dart';

class TestFiles {
  final List<String> _testFiles = [];
  final Map<String, String> _referenceTranscripts = {};
  final Map<String, int> _fileDurations = {};
  int currentFileIndex = -1;

  /// A callback that returns a Future<int> for the file duration,
  /// given a wavFile path and sampleRate.
  final Future<int> Function(String wavFile, int sampleRate)? getFileDuration;

  TestFiles({this.getFileDuration});

  /// Load test WAV + SRT transcripts from assets
  Future<void> loadTestFiles({int sampleRate = 16000}) async {
    try {
      final manifest = await rootBundle.loadString('AssetManifest.json');
      final Map<String, dynamic> manifestMap = json.decode(manifest);

      // Filter for `assets/dictation_test/test_files/*.wav`
      _testFiles.addAll(
        manifestMap.keys
            .where((String key) =>
                key.startsWith('assets/dictation_test/test_files/') &&
                key.endsWith('.wav'))
            .toList(),
      );

      // Load transcripts (SRT files) and measure WAV durations
      for (final wavFile in _testFiles) {
        final srtFile = wavFile.replaceAll('.wav', '.srt');
        try {
          final srtContent = await rootBundle.loadString(srtFile);
          _referenceTranscripts[wavFile] = _stripSrt(srtContent);
        } catch (e) {
          // If no SRT file, store empty reference
          _referenceTranscripts[wavFile] = '';
        }

        // Use the provided callback to get the duration.
        if (getFileDuration != null) {
          _fileDurations[wavFile] = await getFileDuration!(wavFile, sampleRate);
        }
      }

      currentFileIndex = 0;
      print('Loaded ${_testFiles.length} test files with '
          '${_referenceTranscripts.length} transcripts');
    } catch (e) {
      print('Error loading test files: $e');
      _testFiles.clear();
      currentFileIndex = -1;
    }
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
  String get currentFile => _testFiles[currentFileIndex];
  String? get currentReferenceTranscript => _referenceTranscripts[currentFile];
  int? get currentFileDuration => _fileDurations[currentFile];
}
