import 'dart:math';

class TranscriptCombiner {
  String combineTranscripts(String chunk1, String chunk2,
      {int minOverlap = 10, double similarityThreshold = 0.7}) {
    double bestScore = 0;
    int bestOverlapLen = 0;

    // Try different overlap lengths
    for (int overlapLen = minOverlap;
        overlapLen <= min(chunk1.length, chunk2.length);
        overlapLen++) {
      // Get suffix of chunk1 and prefix of chunk2
      String suffix = chunk1.substring(chunk1.length - overlapLen);
      String prefix = chunk2.substring(0, overlapLen);

      double score = ratio(suffix, prefix);

      if (score > bestScore) {
        bestScore = score;
        bestOverlapLen = overlapLen;
      }
    }

    // If we found a good match
    if (bestScore >= similarityThreshold) {
      // Join the chunks by overlapping
      return chunk1.substring(0, chunk1.length - bestOverlapLen) + chunk2;
    } else {
      // If no good overlap found, just concatenate with a marker
      return chunk1 + " [...] " + chunk2;
    }
  }

  double ratio(String a, String b) {
    if (a.isEmpty && b.isEmpty) return 1.0;
    if (a.isEmpty || b.isEmpty) return 0.0;

    int matches = 0;
    Map<String, int> charCountA = {};
    Map<String, int> charCountB = {};

    // Count characters in both strings
    for (int i = 0; i < a.length; i++) {
      charCountA[a[i]] = (charCountA[a[i]] ?? 0) + 1;
    }

    for (int i = 0; i < b.length; i++) {
      charCountB[b[i]] = (charCountB[b[i]] ?? 0) + 1;
    }

    // Count matching characters
    for (String char in charCountA.keys) {
      if (charCountB.containsKey(char)) {
        matches += min(charCountA[char]!, charCountB[char]!);
      }
    }

    // Calculate similarity using 2*matches / (len(a) + len(b))
    return (2 * matches) / (a.length + b.length);
  }
}
