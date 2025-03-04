import 'dart:math';

class TranscriptCombiner {
  final bool debug;
  final bool useFuzzyMatching;
  final double fuzzyThreshold; // e.g. 0.8 => 80% similarity needed

  TranscriptCombiner({
    this.debug = false,
    this.useFuzzyMatching = false,
    this.fuzzyThreshold = 0.8,
  });

  String combine(String textA, String textB) {
    // 1) Normalize
    final normA = normalize(textA);
    final normB = normalize(textB);

    // 2) Tokenize
    final wordsA =
        normA.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final wordsB =
        normB.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

    if (wordsA.isEmpty) return normB;
    if (wordsB.isEmpty) return normA;

    // 3) Build LCS table
    // dp[i][j] will store the length of the best alignment for wordsA up to i, wordsB up to j
    final dp = List.generate(
        wordsA.length + 1, (_) => List<int>.filled(wordsB.length + 1, 0));

    // We'll also store "direction" so we can reconstruct
    final dir = List.generate(
        wordsA.length + 1, (_) => List<String>.filled(wordsB.length + 1, ''));

    for (int i = 1; i <= wordsA.length; i++) {
      for (int j = 1; j <= wordsB.length; j++) {
        // Check if these words match
        if (_wordsMatch(wordsA[i - 1], wordsB[j - 1])) {
          dp[i][j] = dp[i - 1][j - 1] + 1;
          dir[i][j] = 'diag'; // match came from diagonal
        } else {
          // No match => we take whichever is longer: skip from A or skip from B
          if (dp[i - 1][j] > dp[i][j - 1]) {
            dp[i][j] = dp[i - 1][j];
            dir[i][j] = 'up';
          } else {
            dp[i][j] = dp[i][j - 1];
            dir[i][j] = 'left';
          }
        }
      }
    }

    // 4) Reconstruct the merged sequence
    // We'll walk backwards from dp[wordsA.length][wordsB.length]
    final merged = <String>[];
    int i = wordsA.length;
    int j = wordsB.length;

    while (i > 0 || j > 0) {
      if (i > 0 && j > 0 && dir[i][j] == 'diag') {
        // They matched => output that word once
        merged.add(wordsA[i - 1]);
        i--;
        j--;
      } else if (i > 0 && (j == 0 || dir[i][j] == 'up')) {
        // This word in A wasn't matched => keep it
        merged.add(wordsA[i - 1]);
        i--;
      } else if (j > 0 && (i == 0 || dir[i][j] == 'left')) {
        // This word in B wasn't matched => keep it
        merged.add(wordsB[j - 1]);
        j--;
      }
    }

    // The merged list is in reverse order, so reverse it
    final result = merged.reversed.join(' ').trim();

    if (debug) {
      // print('--- LCS COMBINE DEBUG ---');
      // print('A: $normA');
      // print('B: $normB');
      // print('Combined: $result');
    }

    return result;
  }

  /// Basic word normalization:
  ///   - Lowercase
  ///   - Keep letters/digits plus internal ' or -
  static String normalize(String text) {
    text = text.toLowerCase();
    final wordRegex = RegExp(r"[a-z0-9]+(?:[\'-][a-z0-9]+)*");
    final matches = wordRegex.allMatches(text);
    return matches.map((m) => m.group(0)!).join(' ').trim();
  }

  /// Decide if two words match:
  ///  1) if useFuzzyMatching == false, they must match exactly
  ///  2) if fuzzy, check a simple character-based similarity ratio
  bool _wordsMatch(String w1, String w2) {
    if (!useFuzzyMatching) return w1 == w2;

    if (w1 == w2) return true;

    // simple ratio = # of matching chars / max length
    final ratioVal = _charSimilarity(w1, w2);
    return ratioVal >= fuzzyThreshold;
  }

  double _charSimilarity(String a, String b) {
    int same = 0;
    final length = min(a.length, b.length);
    for (int i = 0; i < length; i++) {
      if (a[i] == b[i]) same++;
    }
    final maxLen = max(a.length, b.length);
    return same / maxLen;
  }
}
