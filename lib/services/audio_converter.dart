import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:scrybe_benchmarking/scrybe_benchmarking.dart';

class AudioConverter {
  AudioConverter(this.rawFile, this.outputBasePath, [this.chunkSize = 30]);

  final String rawFile;
  final String outputBasePath;
  final int chunkSize;

  Future<ConversionResult> convertWithSegments({
    required List<SubtitleSegment> segments,
    Function(BenchmarkProgress)? onProgressUpdate,
  }) async {
    try {
      final duration = await _getAudioDuration(rawFile);
      if (duration == null) {
        final error =
            'Unable to get duration for $rawFile. Make sure ffprobe is installed.';
        _updateProgress(onProgressUpdate,
            currentFile: rawFile,
            processedFiles: 0,
            totalFiles: segments.length,
            error: error);
        return ConversionResult(success: false, error: error);
      }

      final baseName = p.basenameWithoutExtension(rawFile);
      final chunksDir = p.join(outputBasePath, baseName);
      await Directory(chunksDir).create(recursive: true);

      int processedSegments = 0;
      for (int i = 0; i < segments.length; i++) {
        final segment = segments[i];
        final outFile = p.join(chunksDir, '${baseName}_part${i + 1}.wav');

        final ffmpegArgs = [
          '-y',
          '-i',
          rawFile,
          '-ss',
          '${segment.start}',
          '-t',
          '${segment.end - segment.start}',
          '-acodec',
          'pcm_s16le',
          '-ar',
          '16000',
          '-ac',
          '1',
          '-filter:a',
          'volume=0.9',
          outFile,
        ];

        _updateProgress(
          onProgressUpdate,
          currentFile: 'Converting segment ${i + 1}/${segments.length}',
          processedFiles: processedSegments,
          totalFiles: segments.length,
        );

        final result = await Process.run('ffmpeg', ffmpegArgs);

        if (result.exitCode != 0) {
          print('Error processing segment: ${result.stderr}');
          continue;
        }

        processedSegments++;
        _updateProgress(
          onProgressUpdate,
          currentFile:
              'Processed segment $processedSegments/${segments.length}',
          processedFiles: processedSegments,
          totalFiles: segments.length,
        );
      }

      return ConversionResult(
        success: true,
        duration: duration,
        outputDirectory: chunksDir,
        numChunks: processedSegments,
      );
    } catch (e, stack) {
      print('Error during segment conversion: $e\n$stack');
      _updateProgress(onProgressUpdate,
          currentFile: 'Error',
          processedFiles: 0,
          totalFiles: segments.length,
          error: e.toString());
      return ConversionResult(success: false, error: e.toString());
    }
  }

  Future<ConversionResult> convert({
    Function(BenchmarkProgress)? onProgressUpdate,
  }) async {
    try {
      // 1) Get the total audio duration using ffprobe
      final duration = await _getAudioDuration(rawFile);
      if (duration == null) {
        final error =
            'Unable to get duration for $rawFile. Make sure ffprobe is installed.';
        _updateProgress(onProgressUpdate, error: error);
        return ConversionResult(success: false, error: error);
      }

      _updateProgress(
        onProgressUpdate,
        currentFile: rawFile,
        additionalInfo: {'duration': duration},
      );

      print('Processing $rawFile (duration: $duration seconds)');

      // Create chunks directory inside the mirrored directory structure
      final baseName = p.basenameWithoutExtension(rawFile);
      final chunksDir = p.join(outputBasePath, baseName);
      await Directory(chunksDir).create(recursive: true);

      // Calculate total chunks for progress tracking
      final totalChunks = (duration / chunkSize).ceil();
      int processedChunks = 0;

      // 2) Loop over audio in increments of `chunkSize` seconds
      double start = 0.0;
      int index = 1;
      while (start < duration) {
        final end = start + chunkSize;
        final actualChunkDuration =
            (end <= duration) ? chunkSize : (duration - start);
        if (actualChunkDuration <= 0) break;

        final outFile = p.join(chunksDir, '${baseName}_part$index.wav');

        // Updated ffmpeg arguments to output 16kHz mono WAV
        final ffmpegArgs = [
          '-y', // overwrite
          '-i', rawFile,
          '-ss', '$start',
          '-t', '$actualChunkDuration',
          '-acodec', 'pcm_s16le', // 16-bit PCM encoding
          '-ar', '16000', // 16kHz sample rate
          '-ac', '1', // mono channel
          '-filter:a',
          'volume=0.9', // Optional: prevent clipping during resampling
          outFile,
        ];

        _updateProgress(
          onProgressUpdate,
          currentFile: 'Converting chunk $index/$totalChunks',
          processedFiles: processedChunks,
          totalFiles: totalChunks,
        );

        final result = await Process.run('ffmpeg', ffmpegArgs);

        if (result.exitCode != 0) {
          print('Error splitting file: ${result.stderr}');
          // Continue with next chunk instead of failing completely
          continue;
        }

        start += chunkSize;
        index++;
        processedChunks++;

        _updateProgress(
          onProgressUpdate,
          currentFile: 'Processed chunk $processedChunks/$totalChunks',
          processedFiles: processedChunks,
          totalFiles: totalChunks,
        );
      }

      print('Done! Chunks are in folder: $chunksDir');
      return ConversionResult(
        success: true,
        duration: duration,
        outputDirectory: chunksDir,
        numChunks: processedChunks,
      );
    } catch (e, stack) {
      print('Error during conversion: $e\n$stack');
      _updateProgress(onProgressUpdate, error: e.toString());
      return ConversionResult(success: false, error: e.toString());
    }
  }

  void _updateProgress(
    Function(BenchmarkProgress)? onProgressUpdate, {
    String currentFile = '',
    int? processedFiles,
    int? totalFiles,
    String? error,
    Map<String, dynamic>? additionalInfo,
  }) {
    if (onProgressUpdate != null) {
      // Fixed by providing all required parameters
      onProgressUpdate(BenchmarkProgress(
        currentModel: p.basename(rawFile),
        currentFile: currentFile, // This was already provided
        processedFiles: processedFiles ?? 0, // Default if null
        totalFiles: totalFiles ?? 0, // Default if null
        error: error,
        phase: 'converting',
        additionalInfo: additionalInfo,
      ));
    }
  }

  /// Helper function to get total audio duration in seconds (float)
  /// Returns null if parsing fails or ffprobe is not installed.
  Future<double?> _getAudioDuration(String rawFile) async {
    final result = await Process.run('ffprobe', [
      '-v',
      'error',
      '-show_entries',
      'format=duration',
      '-of',
      'default=noprint_wrappers=1:nokey=1',
      rawFile,
    ]);

    if (result.exitCode != 0) {
      stderr.writeln('ffprobe error: ${result.stderr}');
      return null;
    }

    final output = result.stdout.toString().trim();
    if (output.isEmpty) return null;

    return double.tryParse(output);
  }
}

class ConversionResult {
  final bool success;
  final String? error;
  final double? duration;
  final String? outputDirectory;
  final int? numChunks;

  ConversionResult({
    required this.success,
    this.error,
    this.duration,
    this.outputDirectory,
    this.numChunks,
  });

  bool get hasError => error != null;
}
