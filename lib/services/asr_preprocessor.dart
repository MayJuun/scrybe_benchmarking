import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:path/path.dart' as p;
import 'package:scrybe_benchmarking/scrybe_benchmarking.dart';

class ASRPreprocessor {
  final String audioPath;
  final String transcriptPath;
  final String outputPath;

  // Configuration parameters
  final double minSegmentDuration =
      1.0; // Hugging Face recommends 1-20s segments
  final double maxSegmentDuration = 20.0;
  final RegExp speakerPattern = RegExp(r'\[.*?\]:|>>|\b[A-Z]+\s*:');
  final RegExp formatPattern = RegExp(r'<[^>]+>');

  ASRPreprocessor({
    required this.audioPath,
    required this.transcriptPath,
    required this.outputPath,
  });

  Future<void> process({
    required Function(BenchmarkProgress) onProgressUpdate,
  }) async {
    try {
      // Initial progress update
      onProgressUpdate(BenchmarkProgress(
        currentModel: 'ASR Preprocessing',
        currentFile: transcriptPath,
        processedFiles: 0,
        totalFiles: 3, // Loading, Processing, Writing
        phase: 'preprocessing',
      ));
      // Step 1: Load and clean transcript segments
      final rawSegments = await _loadTranscript();
      final cleanedSegments = _cleanSegments(rawSegments);
      final mergedSegments = _mergeSegments(cleanedSegments);

      // Step 2: Split into optimal duration chunks
      final splitSegments = _optimizeSegmentDurations(mergedSegments);

      // Step 3: Process audio and transcripts in parallel
      await Future.wait([
        _processAudio(splitSegments, onProgressUpdate),
        _writeProcessedTranscripts(splitSegments, onProgressUpdate),
      ]);
    } catch (e, stack) {
      print('Error in ASR preprocessing: $e\n$stack');
      onProgressUpdate(BenchmarkProgress(
        currentModel: 'ASR Preprocessing',
        currentFile: transcriptPath, // Added
        processedFiles: 0, // Added
        totalFiles: 1, // Added
        error: e.toString(),
        phase: 'preprocessing',
      ));
      rethrow;
    }
  }

  Future<List<SubtitleSegment>> _loadTranscript() async {
    final file = File(transcriptPath);
    if (!await file.exists()) {
      throw Exception('Transcript file not found: $transcriptPath');
    }

    if (p.extension(transcriptPath).toLowerCase() == '.srt') {
      return _parseSrtFile(file);
    } else {
      throw Exception('Unsupported transcript format');
    }
  }

  Future<List<SubtitleSegment>> _parseSrtFile(File srtFile) async {
    final lines = await srtFile.readAsLines();
    final segments = <SubtitleSegment>[];

    String? timeLine;
    final textBuffer = <String>[];

    for (var line in lines) {
      line = line.trim();

      if (line.isEmpty) {
        if (timeLine != null && textBuffer.isNotEmpty) {
          final times = timeLine.split('-->');
          final start = SubtitleSegment.parseTimeString(times[0].trim());
          final end = SubtitleSegment.parseTimeString(times[1].trim());

          segments.add(SubtitleSegment(
            start: start,
            end: end,
            text: textBuffer.join('\n'),
          ));
        }
        timeLine = null;
        textBuffer.clear();
      } else if (line.contains('-->')) {
        timeLine = line;
      } else if (!RegExp(r'^\d+$').hasMatch(line)) {
        textBuffer.add(line);
      }
    }

    if (timeLine != null && textBuffer.isNotEmpty) {
      final times = timeLine.split('-->');
      final start = SubtitleSegment.parseTimeString(times[0].trim());
      final end = SubtitleSegment.parseTimeString(times[1].trim());

      segments.add(SubtitleSegment(
        start: start,
        end: end,
        text: textBuffer.join('\n'),
      ));
    }

    return segments;
  }

  List<SubtitleSegment> _cleanSegments(List<SubtitleSegment> segments) {
    return segments
        .map((segment) {
          var text = segment.text;

          // Remove speaker labels and formatting
          text = text.replaceAll(speakerPattern, '');
          text = text.replaceAll(formatPattern, '');

          // Normalize whitespace
          text = text.replaceAll(RegExp(r'\s+'), ' ').trim();

          return SubtitleSegment(
            start: segment.start,
            end: segment.end,
            text: text,
          );
        })
        .where((segment) => segment.text.isNotEmpty)
        .toList();
  }

  List<SubtitleSegment> _mergeSegments(List<SubtitleSegment> segments) {
    if (segments.isEmpty) return [];

    final merged = <SubtitleSegment>[];
    SubtitleSegment current = segments.first;

    for (var i = 1; i < segments.length; i++) {
      final next = segments[i];

      if (_shouldMergeSegments(current, next)) {
        // Merge segments
        current = SubtitleSegment(
          start: current.start,
          end: next.end,
          text: '${current.text} ${next.text}',
        );
      } else {
        merged.add(current);
        current = next;
      }
    }

    merged.add(current);
    return merged;
  }

  bool _shouldMergeSegments(SubtitleSegment current, SubtitleSegment next) {
    // Merge if:
    // 1. There's less than 0.3s gap between segments
    final timeGap = next.start - current.end;
    if (timeGap < 0.3) return true;

    // 2. Current segment ends with incomplete sentence
    if (current.text.endsWith(',') ||
        current.text.endsWith(';') ||
        !RegExp(r'[.!?]$').hasMatch(current.text)) {
      return true;
    }

    // 3. Next segment starts with lowercase (likely continuation)
    if (next.text.isNotEmpty && next.text[0].toLowerCase() == next.text[0]) {
      return true;
    }

    return false;
  }

  List<SubtitleSegment> _optimizeSegmentDurations(
      List<SubtitleSegment> segments) {
    final optimized = <SubtitleSegment>[];
    SubtitleSegment? current;

    for (final segment in segments) {
      final duration = segment.end - segment.start;

      if (duration < minSegmentDuration) {
        // Too short - try to merge with next segment
        if (current != null) {
          current = _mergeSubtitleSegments(current, segment);
        } else {
          current = segment;
        }
      } else if (duration > maxSegmentDuration) {
        // Too long - split into smaller segments
        optimized.addAll(_splitLongSegment(segment));
        current = null;
      } else {
        // Just right - add directly
        if (current != null) {
          optimized.add(current);
        }
        optimized.add(segment);
        current = null;
      }
    }

    if (current != null) {
      optimized.add(current);
    }

    return optimized;
  }

  SubtitleSegment _mergeSubtitleSegments(
    SubtitleSegment first,
    SubtitleSegment second,
  ) {
    return SubtitleSegment(
      start: first.start,
      end: second.end,
      text: '${first.text} ${second.text}',
    );
  }

  List<SubtitleSegment> _splitLongSegment(SubtitleSegment segment) {
    final duration = segment.end - segment.start;
    final parts = (duration / maxSegmentDuration).ceil();
    final splitDuration = duration / parts;

    return List.generate(parts, (i) {
      final start = segment.start + (i * splitDuration);
      final end = start + splitDuration;
      // For now, we'll split the text evenly - in a real implementation,
      // you might want to split on sentence boundaries
      final words = segment.text.split(' ');
      final wordsPerPart = (words.length / parts).ceil();
      final startWord = i * wordsPerPart;
      final endWord = math.min((i + 1) * wordsPerPart, words.length);

      return SubtitleSegment(
        start: start,
        end: end,
        text: words.sublist(startWord, endWord).join(' '),
      );
    });
  }

  Future<void> _processAudio(
    List<SubtitleSegment> segments,
    Function(BenchmarkProgress) onProgressUpdate,
  ) async {
    final audioConverter = AudioConverter(
      audioPath,
      outputPath,
      maxSegmentDuration.toInt(),
    );

    // Change this to use convertWithSegments instead
    await audioConverter.convertWithSegments(
      segments: segments,
      onProgressUpdate: onProgressUpdate,
    );
  }

  Future<void> _writeProcessedTranscripts(
    List<SubtitleSegment> segments,
    Function(BenchmarkProgress) onProgressUpdate,
  ) async {
    // Create manifest file for training
    final manifest = segments
        .asMap()
        .entries
        .map((entry) => {
              'audio_filepath':
                  '${p.basenameWithoutExtension(audioPath)}_part${entry.key + 1}.wav',
              'text': entry.value.text,
              'duration': entry.value.end - entry.value.start,
            })
        .toList();

    final manifestFile = File(p.join(
        outputPath, p.basenameWithoutExtension(audioPath), 'manifest.json'));
    if (!manifestFile.existsSync()) {
      await manifestFile.create(recursive: true);
    }
    await manifestFile.writeAsString(jsonEncode(manifest));

    // Write individual SRT files for reference
    for (int i = 0; i < segments.length; i++) {
      final segment = segments[i];
      final baseName = p.basenameWithoutExtension(audioPath);
      final srtDir = p.join(outputPath, baseName);

      final outFile = File(
        p.join(srtDir, '${baseName}_part${i + 1}.srt'),
      );
      if (!outFile.existsSync()) {
        await outFile.create(recursive: true);
      }

      await outFile.writeAsString(segment.toSrtString(i + 1));

      onProgressUpdate(BenchmarkProgress(
        currentModel: 'Transcript Processing',
        currentFile: 'Writing segment ${i + 1}/${segments.length}',
        processedFiles: i + 1,
        totalFiles: segments.length,
        phase: 'preprocessing',
      ));
    }
  }
}
