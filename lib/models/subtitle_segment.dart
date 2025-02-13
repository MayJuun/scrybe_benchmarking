class SubtitleSegment {
  final double start;
  final double end;
  final String text;
  final String? speakerId;
  final double? confidence;

  SubtitleSegment({
    required this.start,
    required this.end,
    required this.text,
    this.speakerId,
    this.confidence,
  });

  Duration get duration => Duration(milliseconds: ((end - start) * 1000).round());

  SubtitleSegment copyWith({
    double? start,
    double? end,
    String? text,
    String? speakerId,
    double? confidence,
  }) {
    return SubtitleSegment(
      start: start ?? this.start,
      end: end ?? this.end,
      text: text ?? this.text,
      speakerId: speakerId ?? this.speakerId,
      confidence: confidence ?? this.confidence,
    );
  }

  /// Create a SubtitleSegment with clipped start/end times
  SubtitleSegment clipToTimeWindow(double windowStart, double windowEnd) {
    return copyWith(
      start: start < windowStart ? windowStart : start,
      end: end > windowEnd ? windowEnd : end,
    );
  }

  /// Check if this segment overlaps with a time window
  bool overlapsWithWindow(double windowStart, double windowEnd) {
    return end >= windowStart && start < windowEnd;
  }

  /// Convert to SRT format string with given index
  String toSrtString(int index) {
    final startStr = _formatSrtTimestamp(start);
    final endStr = _formatSrtTimestamp(end);
    
    return '''
$index
$startStr --> $endStr
$text
''';
  }

  static String _formatSrtTimestamp(double seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = (seconds % 60).floor();
    final millis = ((seconds - seconds.floor()) * 1000).round();
    
    return '${_pad(hours)}:${_pad(minutes)}:${_pad(secs)},${_pad(millis, 3)}';
  }

  static String _pad(int n, [int width = 2]) => n.toString().padLeft(width, '0');

  @override
  String toString() => 'SubtitleSegment(${start.toStringAsFixed(3)}-${end.toStringAsFixed(3)}: "$text")';

  /// Create from JSON map (for JSON transcript format)
  factory SubtitleSegment.fromJson(Map<String, dynamic> json) {
    return SubtitleSegment(
      start: (json['start'] as num).toDouble(),
      end: (json['end'] as num).toDouble(),
      text: json['text'] as String,
      speakerId: json['speakerId'] as String?,
      confidence: json['confidence'] != null ? (json['confidence'] as num).toDouble() : null,
    );
  }

  /// Convert to JSON map
  Map<String, dynamic> toJson() {
    return {
      'start': start,
      'end': end,
      'text': text,
      if (speakerId != null) 'speakerId': speakerId,
      if (confidence != null) 'confidence': confidence,
    };
  }

  /// Parse an SRT time string ("HH:MM:SS,mmm") to seconds
  static double parseTimeString(String timeStr) {
    final parts = timeStr.split(':');
    final secondsParts = parts[2].split(',');
    
    final hours = int.parse(parts[0]);
    final minutes = int.parse(parts[1]);
    final seconds = int.parse(secondsParts[0]);
    final milliseconds = int.parse(secondsParts[1]);

    return hours * 3600 + minutes * 60 + seconds + milliseconds / 1000;
  }
}