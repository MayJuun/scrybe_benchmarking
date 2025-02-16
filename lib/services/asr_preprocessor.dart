import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:path/path.dart' as p;
import 'package:scrybe_benchmarking/scrybe_benchmarking.dart';

/// This class takes an original [audioPath] and a matching [transcriptPath],
/// splits them into smaller chunks (1-20s) for training & benchmarking in ASR.
/// Each chunk gets its own audio file (.wav) & matching 0-based SRT file.
class ASRPreprocessor {
  final String audioPath;
  final String transcriptPath;
  final String outputPath;

  // Configuration parameters
  final double minSegmentDuration = 1.0; // Recommended min chunk length
  final double maxSegmentDuration = 20.0; // Recommended max chunk length
  final RegExp speakerPattern = RegExp(r'\[.*?\]:|>>|\b[A-Z]+\s*:');
  final RegExp formatPattern = RegExp(r'<[^>]+>');

  ASRPreprocessor({
    required this.audioPath,
    required this.transcriptPath,
    required this.outputPath,
  });

  /// Main pipeline:
  /// 1) Parse transcript into [SubtitleSegment]s
  /// 2) Clean text, remove speaker tags
  /// 3) Merge tiny segments & split overly long segments
  /// 4) Write out audio chunks and offset SRT files
  /// 5) Generate a JSON manifest for training/benchmarking
  Future<void> process({
    required Function(BenchmarkProgress) onProgressUpdate,
  }) async {
    try {
      // Initial progress update
      onProgressUpdate(
        BenchmarkProgress(
          currentModel: 'ASR Preprocessing',
          currentFile: transcriptPath,
          processedFiles: 0,
          totalFiles: 3,
          phase: 'preprocessing',
        ),
      );

      // Step 1: Load transcript
      final rawSegments = await _loadTranscript();

      // Step 2: Clean transcript
      final cleanedSegments = _cleanSegments(rawSegments);

      // Step 3: Merge short or connected segments
      final mergedSegments = _mergeSegments(cleanedSegments);

      // Step 4: Split segments that exceed maxSegmentDuration
      final splitSegments = _optimizeSegmentDurations(mergedSegments);

      // Step 5: Process audio & transcripts in parallel
      await Future.wait([
        _processAudio(splitSegments, onProgressUpdate),
        _writeProcessedTranscripts(splitSegments, onProgressUpdate),
      ]);
    } catch (e, stack) {
      print('Error in ASR preprocessing: $e\n$stack');
      onProgressUpdate(
        BenchmarkProgress(
          currentModel: 'ASR Preprocessing',
          currentFile: transcriptPath,
          processedFiles: 0,
          totalFiles: 1,
          error: e.toString(),
          phase: 'preprocessing',
        ),
      );
      rethrow;
    }
  }

  // --------------------------------------------------------------------------
  // 1) LOAD TRANSCRIPT
  // --------------------------------------------------------------------------
  Future<List<SubtitleSegment>> _loadTranscript() async {
    final file = File(transcriptPath);
    if (!await file.exists()) {
      throw Exception('Transcript file not found: $transcriptPath');
    }

    if (p.extension(transcriptPath).toLowerCase() == '.srt') {
      return _parseSrtFile(file);
    } else {
      throw Exception('Unsupported transcript format (only .srt supported).');
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

          segments.add(
            SubtitleSegment(
              start: start,
              end: end,
              text: textBuffer.join('\n'),
            ),
          );
        }
        timeLine = null;
        textBuffer.clear();
      } else if (line.contains('-->')) {
        timeLine = line;
      } else if (!RegExp(r'^\d+$').hasMatch(line)) {
        textBuffer.add(line);
      }
    }

    // Handle last segment if file doesn't end with blank line
    if (timeLine != null && textBuffer.isNotEmpty) {
      final times = timeLine.split('-->');
      final start = SubtitleSegment.parseTimeString(times[0].trim());
      final end = SubtitleSegment.parseTimeString(times[1].trim());

      segments.add(
        SubtitleSegment(
          start: start,
          end: end,
          text: textBuffer.join('\n'),
        ),
      );
    }

    return segments;
  }

  // --------------------------------------------------------------------------
  // 2) CLEAN TRANSCRIPT
  // --------------------------------------------------------------------------
  List<SubtitleSegment> _cleanSegments(List<SubtitleSegment> segments) {
    return segments
        .map((segment) {
          var text = segment.text;
          // Remove speaker labels and formatting tags
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

  // --------------------------------------------------------------------------
  // 3) MERGE SHORT/CONNECTED SEGMENTS
  // --------------------------------------------------------------------------
  List<SubtitleSegment> _mergeSegments(List<SubtitleSegment> segments) {
    if (segments.isEmpty) return [];

    final merged = <SubtitleSegment>[];
    SubtitleSegment current = segments.first;

    for (int i = 1; i < segments.length; i++) {
      final next = segments[i];

      if (_shouldMergeSegments(current, next)) {
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
    // Merge if there's less than 0.3s gap
    final timeGap = next.start - current.end;
    if (timeGap < 0.3) return true;

    // Or if the current text does not end with typical punctuation
    if (current.text.endsWith(',') ||
        current.text.endsWith(';') ||
        !RegExp(r'[.!?]$').hasMatch(current.text)) {
      return true;
    }

    // Or if the next text begins with lowercase
    if (next.text.isNotEmpty && next.text[0].toLowerCase() == next.text[0]) {
      return true;
    }

    return false;
  }

  // --------------------------------------------------------------------------
  // 4) SPLIT LONG SEGMENTS
  // --------------------------------------------------------------------------
  List<SubtitleSegment> _optimizeSegmentDurations(
    List<SubtitleSegment> segments,
  ) {
    final optimized = <SubtitleSegment>[];
    SubtitleSegment? current;

    for (final segment in segments) {
      final duration = segment.end - segment.start;

      if (duration < minSegmentDuration) {
        // If short, try to merge with `current`
        if (current != null) {
          current = _mergeSubtitleSegments(current, segment);
        } else {
          current = segment;
        }
      } else if (duration > maxSegmentDuration) {
        // If too long, split into multiple smaller segments
        optimized.addAll(_splitLongSegment(segment));
        current = null;
      } else {
        // If just right, add to optimized, also flush pending `current`
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
      SubtitleSegment first, SubtitleSegment second) {
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

    final words = segment.text.split(' ');
    final wordsPerPart = (words.length / parts).ceil();

    return List.generate(parts, (i) {
      final subStart = segment.start + (i * splitDuration);
      final subEnd = math.min(subStart + splitDuration, segment.end);

      final startWord = i * wordsPerPart;
      final endWord = math.min((i + 1) * wordsPerPart, words.length);
      final chunkText = words.sublist(startWord, endWord).join(' ');

      return SubtitleSegment(
        start: subStart,
        end: subEnd,
        text: chunkText,
      );
    });
  }

  // --------------------------------------------------------------------------
  // 5) PROCESS AUDIO
  // --------------------------------------------------------------------------
  Future<void> _processAudio(
    List<SubtitleSegment> segments,
    Function(BenchmarkProgress) onProgressUpdate,
  ) async {
    final audioConverter = AudioConverter(
      audioPath,
      outputPath,
      maxSegmentDuration.toInt(),
    );

    // Use the "convertWithSegments" approach, which creates one WAV per segment
    await audioConverter.convertWithSegments(
      segments: segments,
      onProgressUpdate: onProgressUpdate,
    );
  }

  // --------------------------------------------------------------------------
  // 6) WRITE CHUNKED TRANSCRIPTS + MANIFEST
  // --------------------------------------------------------------------------
  Future<void> _writeProcessedTranscripts(
    List<SubtitleSegment> segments,
    Function(BenchmarkProgress) onProgressUpdate,
  ) async {
    // 6a) Write JSON manifest
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

    final manifestFile = File(
      p.join(
        outputPath,
        p.basenameWithoutExtension(audioPath),
        'manifest.json',
      ),
    );
    if (!manifestFile.existsSync()) {
      await manifestFile.create(recursive: true);
    }
    await manifestFile.writeAsString(jsonEncode(manifest));

    // 6b) Write one .srt per chunk, offsetting times so each chunk is 0-based
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

      // The chunk's total length
      final chunkDuration = segment.end - segment.start;

      // Offset the times so it starts at 0.0 for this chunk
      final offsetSegment = SubtitleSegment(
        start: 0.0, // ALWAYS 0.0
        end: chunkDuration, // (end - start)
        text: segment.text, // Merged text or single line
      );

      // Write offset SRT
      await outFile.writeAsString(offsetSegment.toSrtString(i + 1));

      onProgressUpdate(
        BenchmarkProgress(
          currentModel: 'Transcript Processing',
          currentFile: 'Writing segment ${i + 1}/${segments.length}',
          processedFiles: i + 1,
          totalFiles: segments.length,
          phase: 'preprocessing',
        ),
      );
    }
  }
}
