// ignore_for_file: avoid_print

import 'dart:io';

import 'package:scrybe_benchmarking/scrybe_benchmarking.dart';

class ASRPreprocessor {
  ASRPreprocessor({required this.audioPath, required this.transcriptPath}) {
    var tempPath =
        audioPath.replaceAll('/raw/', '/curated/').replaceAll('.wav', '');
    if (!Directory(tempPath).existsSync()) {
      Directory(tempPath).createSync(recursive: true);
    }
    outputPath = tempPath;
  }

  final String audioPath;
  final String transcriptPath;
  late final String outputPath;

  String twoDigits(int value) => value.toString().padLeft(2, '0');
  String threeDigits(int value) => value.toString().padLeft(3, '0');

  /// Main entry point.
  // ignore: unintended_html_in_doc_comment
  /// Usage: dart split_srt_audio.dart <input_srt> <input_wav> <output_prefix>
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

      // Verify input files exist
      if (!await File(transcriptPath).exists()) {
        print('Error: SRT file not found: $transcriptPath');
        exit(1);
      }
      if (!await File(audioPath).exists()) {
        print('Error: WAV file not found: $audioPath');
        exit(1);
      }

      // Verify ffmpeg is installed
      try {
        final result = await Process.run('ffmpeg', ['-version']);
        if (result.exitCode != 0) {
          print('Error: ffmpeg is not installed or not accessible');
          exit(1);
        }
      } catch (e) {
        print('Error: ffmpeg is required but not found');
        exit(1);
      }

      print('Parsing SRT file...');
      final subtitles = await parseSrtFile();
      if (subtitles.isEmpty) {
        print('Error: No subtitles found in file');
        exit(1);
      }

      print('Creating chunks...');
      final chunks = createSmartSubtitleChunks(subtitles);

      print('Splitting audio and writing subtitles...');
      await splitAudioAndWriteSubtitles(chunks);

      print('Done! Created ${chunks.length} segments.');
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

  /// Parses an SRT file into a list of [Subtitle] objects.
  Future<List<Subtitle>> parseSrtFile() async {
    final lines = await File(transcriptPath).readAsLines();
    final subtitles = <Subtitle>[];

    int? currentIndex;
    double? currentStart;
    double? currentEnd;
    final textBuffer = <String>[];

    for (var line in lines) {
      line = line.trim();

      if (line.isEmpty) {
        if (currentIndex != null &&
            currentStart != null &&
            currentEnd != null) {
          subtitles.add(
            Subtitle(
              index: currentIndex,
              startSeconds: currentStart,
              endSeconds: currentEnd,
              textLines: List.from(textBuffer),
            ),
          );
        }
        currentIndex = null;
        currentStart = null;
        currentEnd = null;
        textBuffer.clear();
        continue;
      }

      if (RegExp(r'^\d+$').hasMatch(line)) {
        currentIndex = int.parse(line);
        continue;
      }

      if (line.contains('-->')) {
        final times = line.split('-->');
        if (times.length == 2) {
          try {
            currentStart = parseSrtTime(times[0].trim());
            currentEnd = parseSrtTime(times[1].trim());
          } catch (e) {
            print('Warning: Failed to parse timestamp: $line');
            continue;
          }
        }
        continue;
      }

      textBuffer.add(line);
    }

    // Handle final subtitle if file doesn't end with blank line
    if (currentIndex != null && currentStart != null && currentEnd != null) {
      subtitles.add(
        Subtitle(
          index: currentIndex,
          startSeconds: currentStart,
          endSeconds: currentEnd,
          textLines: List.from(textBuffer),
        ),
      );
    }

    return subtitles;
  }

  /// Creates chunks of subtitles with improved splitting logic.
  /// Aims for ~30 second chunks but will adjust based on sentence boundaries
  /// and natural speech patterns.
  List<List<Subtitle>> createSmartSubtitleChunks(List<Subtitle> subtitles) {
    const targetDuration = 3.0;
    const minDuration = 1.0;
    const maxDuration = 5.0;

    final chunks = <List<Subtitle>>[];
    var currentChunk = <Subtitle>[];
    double chunkStart =
        subtitles.isNotEmpty ? subtitles.first.startSeconds : 0.0;

    for (var i = 0; i < subtitles.length; i++) {
      final sub = subtitles[i];
      final nextSub = i < subtitles.length - 1 ? subtitles[i + 1] : null;

      currentChunk.add(sub);
      final chunkDuration = sub.endSeconds - chunkStart;

      // Conditions for ending the current chunk:
      bool shouldEndChunk = false;

      // 1. Chunk is near target duration and current subtitle ends a sentence
      if (chunkDuration >= targetDuration * 0.8 && sub.endsWithSentence) {
        shouldEndChunk = true;
      }

      // 2. Chunk has reached maximum duration
      if (chunkDuration >= maxDuration) {
        shouldEndChunk = true;
      }

      // 3. Natural break in speech (gap between subtitles)
      if (nextSub != null && nextSub.startSeconds - sub.endSeconds > 2.0) {
        shouldEndChunk = true;
      }

      if (shouldEndChunk &&
          currentChunk.isNotEmpty &&
          (sub.endSeconds - chunkStart) >= minDuration) {
        chunks.add(List.from(currentChunk));
        currentChunk.clear();
        if (nextSub != null) {
          chunkStart = nextSub.startSeconds;
        }
      }
    }

    // Add any remaining subtitles as the final chunk
    if (currentChunk.isNotEmpty) {
      chunks.add(currentChunk);
    }

    return chunks;
  }

  /// For each chunk, runs ffmpeg to split the audio and writes matching SRT.
  Future<void> splitAudioAndWriteSubtitles(
    List<List<Subtitle>> chunks,
  ) async {
    for (var i = 0; i < chunks.length; i++) {
      final chunk = chunks[i];
      final chunkStart = chunk.first.startSeconds;
      final chunkEnd = chunk.last.endSeconds;
      final chunkDuration = chunkEnd - chunkStart;

      final paddedIndex = (i + 1).toString().padLeft(3, '0');
      final chunkWavPath = '$outputPath/$paddedIndex.wav';
      final chunkSrtPath = '$outputPath/$paddedIndex.srt';

      // Split audio with ffmpeg
      final result = await Process.run('ffmpeg', [
        '-y',
        '-i', audioPath,
        '-ss', chunkStart.toStringAsFixed(3),
        '-t', chunkDuration.toStringAsFixed(3),
        '-ac', '1', // Convert to mono
        '-ar', '16000', // Set sample rate to 16kHz
        chunkWavPath,
      ]);

      if (result.exitCode != 0) {
        print('Warning: FFmpeg error on chunk $paddedIndex: ${result.stderr}');
        continue;
      }

      // Write the corresponding SRT file
      final srtContent = buildChunkSrt(chunk, i + 1, chunkStart);
      await File(chunkSrtPath).writeAsString(srtContent);

      // Print progress
      print(
          'Created segment $paddedIndex (${chunkDuration.toStringAsFixed(1)}s)');
    }
  }

  /// Builds an SRT string for a chunk of subtitles.
  String buildChunkSrt(
      List<Subtitle> chunk, int chunkIndex, double chunkStartOffset) {
    final buffer = StringBuffer();
    for (var i = 0; i < chunk.length; i++) {
      final sub = chunk[i];
      final localStart = sub.startSeconds - chunkStartOffset;
      final localEnd = sub.endSeconds - chunkStartOffset;

      buffer.writeln(i + 1);
      buffer.writeln(
          '${formatSrtTime(localStart)} --> ${formatSrtTime(localEnd)}');
      for (final line in sub.textLines) {
        buffer.writeln(line);
      }
      buffer.writeln();
    }
    return buffer.toString();
  }

  /// Parses an SRT timestamp into seconds.
  double parseSrtTime(String srtTime) {
    final parts = srtTime.split(',');
    final timePart = parts[0];
    final msPart = parts.length > 1 ? parts[1] : '0';

    final hms = timePart.split(':');
    final hours = int.parse(hms[0]);
    final minutes = int.parse(hms[1]);
    final seconds = int.parse(hms[2]);
    final milliseconds = int.parse(msPart);

    return hours * 3600 + minutes * 60 + seconds + (milliseconds / 1000.0);
  }

  /// Formats seconds to SRT timestamp.
  String formatSrtTime(double seconds) {
    final totalMs = (seconds * 1000).round();
    final hrs = totalMs ~/ 3600000;
    final remainderAfterHours = totalMs % 3600000;
    final mins = remainderAfterHours ~/ 60000;
    final remainderAfterMinutes = remainderAfterHours % 60000;
    final secs = remainderAfterMinutes ~/ 1000;
    final ms = remainderAfterMinutes % 1000;

    return '${twoDigits(hrs)}:${twoDigits(mins)}:${twoDigits(secs)},${threeDigits(ms)}';
  }
}

/// A simple class to hold subtitle data.
class Subtitle {
  int index;
  double startSeconds;
  double endSeconds;
  List<String> textLines;

  Subtitle({
    required this.index,
    required this.startSeconds,
    required this.endSeconds,
    required this.textLines,
  });

  /// Calculate duration of this subtitle
  double get duration => endSeconds - startSeconds;

  /// Check if this subtitle ends with sentence-ending punctuation
  bool get endsWithSentence {
    if (textLines.isEmpty) return false;
    final lastLine = textLines.last.trim();
    return lastLine.endsWith('.') ||
        lastLine.endsWith('!') ||
        lastLine.endsWith('?');
  }
}
