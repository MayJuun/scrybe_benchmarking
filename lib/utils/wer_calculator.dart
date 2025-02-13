class WerCalculator {
  /// Compute Word Error Rate (case-insensitive)
  /// Returns a value between 0.0 and 1.0, where 0.0 is perfect
  static double computeWer(String reference, String hypothesis) {
    final refWords = reference.toLowerCase().split(RegExp(r'\s+'));
    final hypWords = hypothesis.toLowerCase().split(RegExp(r'\s+'));

    final m = refWords.length;
    final n = hypWords.length;
    final dp = List.generate(m + 1, (_) => List.filled(n + 1, 0));

    for (int i = 0; i <= m; i++) {
      dp[i][0] = i;
    }
    for (int j = 0; j <= n; j++) {
      dp[0][j] = j;
    }

    for (int i = 1; i <= m; i++) {
      for (int j = 1; j <= n; j++) {
        if (refWords[i - 1] == hypWords[j - 1]) {
          dp[i][j] = dp[i - 1][j - 1];
        } else {
          dp[i][j] = 1 +
              _min3(
                dp[i - 1][j], // deletion
                dp[i][j - 1], // insertion
                dp[i - 1][j - 1], // substitution
              );
        }
      }
    }

    final editDistance = dp[m][n];
    if (m == 0) return 0.0;
    return editDistance / m;
  }

  /// Get detailed error statistics
  static WerStats getDetailedStats(String reference, String hypothesis) {
    final refWords = reference.toLowerCase().split(RegExp(r'\s+'));
    final hypWords = hypothesis.toLowerCase().split(RegExp(r'\s+'));

    int substitutions = 0;
    int deletions = 0;
    int insertions = 0;

    final m = refWords.length;
    final n = hypWords.length;
    final dp = List.generate(m + 1, (_) => List.filled(n + 1, 0));
    final ops = List.generate(m + 1, (_) => List<Operation>.filled(n + 1, Operation.none));

    // Initialize first row and column
    for (int i = 0; i <= m; i++) {
      dp[i][0] = i;
      if (i > 0) ops[i][0] = Operation.deletion;
    }
    for (int j = 0; j <= n; j++) {
      dp[0][j] = j;
      if (j > 0) ops[0][j] = Operation.insertion;
    }

    // Fill the matrices
    for (int i = 1; i <= m; i++) {
      for (int j = 1; j <= n; j++) {
        if (refWords[i - 1] == hypWords[j - 1]) {
          dp[i][j] = dp[i - 1][j - 1];
          ops[i][j] = Operation.none;
        } else {
          final delCost = dp[i - 1][j] + 1;
          final insCost = dp[i][j - 1] + 1;
          final subCost = dp[i - 1][j - 1] + 1;

          if (delCost <= insCost && delCost <= subCost) {
            dp[i][j] = delCost;
            ops[i][j] = Operation.deletion;
          } else if (insCost <= delCost && insCost <= subCost) {
            dp[i][j] = insCost;
            ops[i][j] = Operation.insertion;
          } else {
            dp[i][j] = subCost;
            ops[i][j] = Operation.substitution;
          }
        }
      }
    }

    // Backtrack to count operations
    int i = m, j = n;
    while (i > 0 || j > 0) {
      switch (ops[i][j]) {
        case Operation.none:
          i--;
          j--;
          break;
        case Operation.substitution:
          substitutions++;
          i--;
          j--;
          break;
        case Operation.deletion:
          deletions++;
          i--;
          break;
        case Operation.insertion:
          insertions++;
          j--;
          break;
      }
    }

    return WerStats(
      wer: m > 0 ? dp[m][n] / m : 0.0,
      substitutions: substitutions,
      deletions: deletions,
      insertions: insertions,
      referenceLength: m,
      hypothesisLength: n,
    );
  }

  static int _min3(int a, int b, int c) => a < b ? (a < c ? a : c) : (b < c ? b : c);
}

enum Operation {
  none,
  substitution,
  deletion,
  insertion,
}

class WerStats {
  final double wer;
  final int substitutions;
  final int deletions;
  final int insertions;
  final int referenceLength;
  final int hypothesisLength;

  WerStats({
    required this.wer,
    required this.substitutions,
    required this.deletions,
    required this.insertions,
    required this.referenceLength,
    required this.hypothesisLength,
  });

  @override
  String toString() {
    return '''
WER: ${(wer * 100).toStringAsFixed(2)}%
Substitutions: $substitutions
Deletions: $deletions
Insertions: $insertions
Reference Length: $referenceLength
Hypothesis Length: $hypothesisLength
''';
  }
}