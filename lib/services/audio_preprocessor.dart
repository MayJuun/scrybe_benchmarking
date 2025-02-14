import 'dart:math' as math;
import 'dart:typed_data';
import 'package:fftea/fftea.dart';

class AudioPreprocessor {
  // Cache FFT objects for better performance
  static final Map<int, FFT> _fftCache = {};

  static Float32List preprocessAudio(Float32List samples) {
    // Parameters for mel spectrogram extraction
    const int sampleRate = 16000;
    const int nFft = 512;
    const int hopLength = 160; // 10ms at 16kHz
    const int nMels = 80;
    const double fMin = 0.0;
    const double fMax = 8000.0;

    // Step 1: Compute STFT
    final stft = computeSTFT(samples, nFft, hopLength);

    // Step 2: Convert to mel spectrogram
    final melSpec = stftToMelSpectrogram(
      stft,
      sampleRate,
      nMels,
      fMin,
      fMax,
      nFft,
    );

    // Step 3: Convert to log scale and normalize
    for (var i = 0; i < melSpec.length; i++) {
      melSpec[i] = math.log(math.max(melSpec[i], 1e-10));
    }

    return melSpec;
  }

  static Float32List computeSTFT(Float32List samples, int nFft, int hopLength) {
    final window = List<double>.generate(
      nFft,
      (i) => 0.54 - 0.46 * math.cos(2 * math.pi * i / (nFft - 1)),
    );

    final numFrames = ((samples.length - nFft) / hopLength).floor() + 1;

    // Get or create FFT object FIRST
    final fft = _fftCache.putIfAbsent(nFft, () => FFT(nFft));

    // NOW we can use it to calculate spectrum length
    final spectrumLength = fft.realFft(Float64List(nFft)).length;
    final result = Float32List(numFrames * spectrumLength * 2);
    print(
        'computeSTFT: Spectrum length=$spectrumLength, total size=${result.length}');

    // Compute STFT frame by frame
    for (var i = 0; i < numFrames; i++) {
      final startIdx = i * hopLength;
      final frame = Float64List(nFft);

      // Apply window function
      for (var j = 0; j < nFft; j++) {
        if (startIdx + j < samples.length) {
          frame[j] = samples[startIdx + j] * window[j];
        }
      }

      // Compute FFT using fftea
      final spectrum = fft.realFft(frame);

      // Store results
      for (var j = 0; j < spectrum.length; j++) {
        result[i * spectrum.length * 2 + j * 2] =
            spectrum[j].x.toDouble(); // Real part
        result[i * spectrum.length * 2 + j * 2 + 1] =
            spectrum[j].y.toDouble(); // Imaginary part
      }
    }

    return result;
  }

  static Float32List stftToMelSpectrogram(
    Float32List stft,
    int sampleRate,
    int nMels,
    double fMin,
    double fMax,
    int nFft,
  ) {
    // Create mel filterbank matrix
    final melBasis = createMelFilterbank(
      sampleRate,
      nMels,
      fMin,
      fMax,
      nFft ~/ 2 + 1,
    );

    // Apply mel filterbank
    final powerSpec = Float32List(stft.length ~/ 2);
    for (var i = 0; i < powerSpec.length; i++) {
      final real = stft[i * 2];
      final imag = stft[i * 2 + 1];
      powerSpec[i] = real * real + imag * imag;
    }

    // Matrix multiplication with mel filterbank
    final melSpec = Float32List(nMels * (powerSpec.length ~/ (nFft ~/ 2 + 1)));
    applyMelFilterbank(powerSpec, melBasis, melSpec);

    return melSpec;
  }

  static List<Float32List> createMelFilterbank(
    int sampleRate,
    int nMels,
    double fMin,
    double fMax,
    int nFft,
  ) {
    // Convert frequencies to mel scale
    final melMin = _hzToMel(fMin);
    final melMax = _hzToMel(fMax);

    // Create equally spaced points in mel scale
    final melPoints = List<double>.generate(
      nMels + 2,
      (i) => melMin + (melMax - melMin) * i / (nMels + 1),
    );

    // Convert back to Hz
    final fPoints = melPoints.map(_melToHz).toList();

    // Convert to FFT bin numbers
    final bins = fPoints
        .map((f) => ((f * (nFft - 1) / sampleRate).round()).clamp(0, nFft - 1))
        .toList();

    // Create the filterbank
    final filterbank = List<Float32List>.generate(
      nMels,
      (i) => Float32List(nFft),
    );

    for (var i = 0; i < nMels; i++) {
      for (var j = bins[i]; j < bins[i + 2]; j++) {
        if (j < bins[i + 1]) {
          filterbank[i][j] = (j - bins[i]) / (bins[i + 1] - bins[i]);
        } else {
          filterbank[i][j] = (bins[i + 2] - j) / (bins[i + 2] - bins[i + 1]);
        }
      }
    }

    return filterbank;
  }

  static void applyMelFilterbank(
    Float32List powerSpec,
    List<Float32List> melBasis,
    Float32List melSpec,
  ) {
    final nMels = melBasis.length;
    final nFrames = powerSpec.length ~/ melBasis[0].length;

    for (var frame = 0; frame < nFrames; frame++) {
      for (var mel = 0; mel < nMels; mel++) {
        var sum = 0.0;
        for (var bin = 0; bin < melBasis[0].length; bin++) {
          sum +=
              powerSpec[frame * melBasis[0].length + bin] * melBasis[mel][bin];
        }
        melSpec[frame * nMels + mel] = sum;
      }
    }
  }

  static double _hzToMel(double hz) {
    return 2595 * (math.log(1 + hz / 700) / math.ln10);
  }

  static double _melToHz(double mel) {
    return 700 * (math.exp(mel / 2595 * math.ln10) - 1);
  }
}
