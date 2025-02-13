class DurationFormatter {
  /// Format seconds into "HH:MM:SS,mmm" format used in SRT files
  static String formatSrtTimestamp(double seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = (seconds % 60).floor();
    final milliseconds = ((seconds - seconds.floor()) * 1000).round();

    return '${_twoDigits(hours)}:${_twoDigits(minutes)}:${_twoDigits(secs)},${_threeDigits(milliseconds)}';
  }

  /// Format Duration into "HH:MM:SS,mmm" format used in SRT files
  static String formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    final milliseconds = duration.inMilliseconds.remainder(1000);

    return '${_twoDigits(hours)}:${_twoDigits(minutes)}:${_twoDigits(seconds)},${_threeDigits(milliseconds)}';
  }

  /// Format seconds into human readable format (e.g., "2h 30m 45s")
  static String formatHumanReadable(double seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = (seconds % 60).floor();

    final parts = <String>[];
    if (hours > 0) parts.add('${hours}h');
    if (minutes > 0) parts.add('${minutes}m');
    if (secs > 0 || parts.isEmpty) parts.add('${secs}s');

    return parts.join(' ');
  }

  /// Parse SRT timestamp format ("HH:MM:SS,mmm") into seconds
  static double parseFromSrtTimestamp(String timestamp) {
    final parts = timestamp.split(':');
    final secondsParts = parts[2].split(',');
    
    final hours = int.parse(parts[0]);
    final minutes = int.parse(parts[1]);
    final seconds = int.parse(secondsParts[0]);
    final milliseconds = int.parse(secondsParts[1]);

    return hours * 3600 + minutes * 60 + seconds + milliseconds / 1000;
  }

  static String _twoDigits(int n) => n.toString().padLeft(2, '0');
  static String _threeDigits(int n) => n.toString().padLeft(3, '0');
}