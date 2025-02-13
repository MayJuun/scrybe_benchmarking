import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as p;
import '../models/subtitle_segment.dart';
import '../models/benchmark_progress.dart';

class TranscriptProcessor {
  final String inputPath;
  final String outputPath;
  final double chunkSize;

  TranscriptProcessor({
    required this.inputPath,
    required this.outputPath,
    this.chunkSize = 30.0,
  });

  Future<void> processTranscript({
    required double totalDuration,
    required Function(BenchmarkProgress) onProgressUpdate,
  }) async {
    final inputFile = File(inputPath);
    if (!await inputFile.exists()) {
      throw Exception('Input file does not exist: $inputPath');
    }

    final ext = p.extension(inputPath).toLowerCase();
    List<SubtitleSegment> segments;

    try {
      // Parse based on file type
      if (ext == '.srt') {
        segments = await _parseSrtFile(inputFile);
      } else if (ext == '.json') {
        segments = await _parseJsonTranscript(inputFile);
      } else {
        throw Exception('Unsupported transcript format: $ext');
      }

      // Chunk the segments
      final chunkedSegments = _chunkTranscript(segments, chunkSize, totalDuration);

      // Write out the chunks
      await _writeChunkedTranscripts(chunkedSegments, onProgressUpdate);

    } catch (e, stack) {
      print('Error processing transcript: $e\n$stack');
      onProgressUpdate(BenchmarkProgress(
        currentModel: 'Transcript Processing',
        currentFile: inputPath,
        processedFiles: 0,
        totalFiles: 1,
        error: e.toString(),
      ));
      rethrow;
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
          final start = _parseTimeString(times[0].trim());
          final end = _parseTimeString(times[1].trim());
          
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
    
    // Handle last segment if file doesn't end with empty line
    if (timeLine != null && textBuffer.isNotEmpty) {
      final times = timeLine.split('-->');
      final start = _parseTimeString(times[0].trim());
      final end = _parseTimeString(times[1].trim());
      
      segments.add(SubtitleSegment(
        start: start,
        end: end,
        text: textBuffer.join('\n'),
      ));
    }
    
    return segments;
  }

  Future<List<SubtitleSegment>> _parseJsonTranscript(File jsonFile) async {
    final content = await jsonFile.readAsString();
    final data = jsonDecode(content) as Map<String, dynamic>;
    
    if (!data.containsKey('segments')) {
      throw Exception('Invalid JSON transcript format: missing segments');
    }
    
    final jsonSegments = data['segments'] as List;
    return jsonSegments.map((seg) {
      final map = seg as Map<String, dynamic>;
      return SubtitleSegment(
        start: (map['start'] as num).toDouble(),
        end: (map['end'] as num).toDouble(),
        text: map['text'] as String,
        speakerId: map['speakerId'] as String?,
        confidence: map['confidence'] != null ? (map['confidence'] as num).toDouble() : null,
      );
    }).toList();
  }

  List<List<SubtitleSegment>> _chunkTranscript(
    List<SubtitleSegment> allSegments,
    double chunkSize,
    double totalDuration,
  ) {
    final chunks = <List<SubtitleSegment>>[];
    double startTime = 0.0;
    
    while (startTime < totalDuration) {
      final endTime = (startTime + chunkSize <= totalDuration)
          ? startTime + chunkSize
          : totalDuration;
      
      final chunkSegments = allSegments
          .where((seg) => seg.overlapsWithWindow(startTime, endTime))
          .map((seg) => seg.clipToTimeWindow(startTime, endTime))
          .toList();
      
      chunks.add(chunkSegments);
      startTime += chunkSize;
    }
    
    return chunks;
  }

  Future<void> _writeChunkedTranscripts(
    List<List<SubtitleSegment>> chunks,
    Function(BenchmarkProgress) onProgressUpdate,
  ) async {
    final baseName = p.basenameWithoutExtension(inputPath);
    final outputDir = Directory(p.join(outputPath, baseName));
    await outputDir.create(recursive: true);
    
    for (int i = 0; i < chunks.length; i++) {
      final chunk = chunks[i];
      final chunkIndex = i + 1;
      
      // Update progress
      onProgressUpdate(BenchmarkProgress(
        currentModel: 'Transcript Processing',
        currentFile: 'Writing chunk $chunkIndex/${chunks.length}',
        processedFiles: i,
        totalFiles: chunks.length,
      ));
      
      final outFile = File(p.join(outputDir.path, '${baseName}_part$chunkIndex.srt'));
      final buffer = StringBuffer();
      
      for (int j = 0; j < chunk.length; j++) {
        buffer.write(chunk[j].toSrtString(j + 1));
        if (j < chunk.length - 1) buffer.writeln();
      }
      
      await outFile.writeAsString(buffer.toString());
    }
  }

  double _parseTimeString(String timeStr) {
    final parts = timeStr.split(':');
    final secondsParts = parts[2].split(',');
    
    final hours = int.parse(parts[0]);
    final minutes = int.parse(parts[1]);
    final seconds = int.parse(secondsParts[0]);
    final milliseconds = int.parse(secondsParts[1]);
    
    return hours * 3600 + minutes * 60 + seconds + milliseconds / 1000;
  }
}