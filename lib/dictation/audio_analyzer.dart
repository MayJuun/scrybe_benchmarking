import 'dart:math' show ln10, log, max, min, sqrt;

class AudioAnalyzer {
  AudioAnalyzer({
    int historySize = 5,
    double silenceThresholdDb = -60.0,
    int samplesPerFrame = 480,
  })  : _rmsHistory = [],
        _historySize = historySize,
        _silenceThresholdDb = silenceThresholdDb,
        _samplesPerFrame = samplesPerFrame;

  final List<double> _rmsHistory;
  final int _historySize;
  final double _silenceThresholdDb;
  final int _samplesPerFrame;

  double _log10(double x) => log(x) / ln10;

  bool isSilent(List<int> audioData) {
    if (audioData.length < _samplesPerFrame) {
      // chunk too small, skip
      return false;
    }

    // DC offset
    double sum = 0;
    int count = 0;
    for (int i = 0; i < audioData.length - 1; i += 2) {
      int sample = (audioData[i + 1] << 8) | audioData[i];
      if (sample > 32767) sample -= 65536;
      sum += sample;
      count++;
    }
    double dcOffset = sum / count;

    double sumSquares = 0;
    int maxSample = -32768;
    int minSample = 32767;

    for (int i = 0; i < audioData.length - 1; i += 2) {
      int sample = (audioData[i + 1] << 8) | audioData[i];
      if (sample > 32767) sample -= 65536;
      double centeredSample = sample - dcOffset;
      sumSquares += centeredSample * centeredSample;
      maxSample = max(maxSample, sample);
      minSample = min(minSample, sample);
    }

    double rms = sqrt(sumSquares / count);
    double db = 20 * _log10(rms.clamp(1, double.infinity) / 32768);

    _rmsHistory.add(db);
    if (_rmsHistory.length > _historySize) {
      _rmsHistory.removeAt(0);
    }

    bool silent = _rmsHistory.every((d) => d < _silenceThresholdDb);
    return silent;
  }

  void reset() {
    _rmsHistory.clear();
  }
}
