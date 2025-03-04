import 'dart:math';

class TranscriptCombiner {
  final bool debug;
  final bool useFuzzyMatching;
  final double fuzzyThreshold;

  TranscriptCombiner({
    this.debug = false,
    this.useFuzzyMatching = true,
    this.fuzzyThreshold = 0.8,
  });

  String combine(String textA, String textB) {
    // Handle empty inputs
    if (textA.isEmpty) return textB;
    if (textB.isEmpty) return textA;

    if (debug) {
      print('Combining:');
      print('A: "$textA"');
      print('B: "$textB"');
    }

    // Normalize inputs (lowercase, remove external punctuation)
    textA = normalize(textA);
    textB = normalize(textB);

    // 1. Tokenize inputs
    final List<String> wordsA = _tokenize(textA);
    final List<String> wordsB = _tokenize(textB);

    if (wordsA.isEmpty) return textB;
    if (wordsB.isEmpty) return textA;

    // 2. Try to identify if B is a continuation of A, or vice versa
    final continuationResult = _findBestContinuation(wordsA, wordsB);
    if (continuationResult != null) {
      if (debug) print('Found direct continuation');
      return continuationResult;
    }

    // 3. Try to find the best alignment using overlapping segments
    final segmentResult = _findBestOverlappingSegment(wordsA, wordsB);

    if (segmentResult.overlapSize >= 3) {
      // Good overlap found - merge the segments
      if (debug)
        print('Found segment match with overlap: ${segmentResult.overlapSize}');
      return _mergeWithSegmentOverlap(wordsA, wordsB, segmentResult);
    }

    // 4. Last resort: use LCS (longest common subsequence) approach
    if (debug) print('Using LCS approach');
    return _mergeWithLCS(wordsA, wordsB);
  }

  // Normalize text by lowercasing and removing external punctuation
  static String normalize(String text) {
    // Convert to lowercase
    text = text.toLowerCase();

    // Remove any leading/trailing whitespace
    text = text.trim();

    // Replace multiple spaces with a single space
    text = text.replaceAll(RegExp(r'\s+'), ' ');

    return text;
  }

  // Convert raw text to tokens
  List<String> _tokenize(String text) {
    // Match words including apostrophes and hyphens inside words
    // Only keep letters, numbers, and intra-word punctuation
    final RegExp wordPattern = RegExp(r"[a-z0-9]+([-'][a-z0-9]+)*");
    return wordPattern.allMatches(text).map((m) => m.group(0)!).toList();
  }

  // Check if one text is a continuation of the other
  String? _findBestContinuation(List<String> wordsA, List<String> wordsB) {
    // Minimum words that need to overlap for a continuation
    final minOverlap = min(min(wordsA.length, wordsB.length) ~/ 2, 5);
    if (minOverlap < 2)
      return null; // Not enough words to determine continuation

    // Check if B continues A (A's end matches B's beginning)
    bool isAContinuedByB = true;
    for (int i = 0; i < minOverlap; i++) {
      if (!_wordsMatch(wordsA[wordsA.length - minOverlap + i], wordsB[i])) {
        isAContinuedByB = false;
        break;
      }
    }

    if (isAContinuedByB) {
      // A followed by B (removing B's overlapping beginning)
      return wordsA.sublist(0, wordsA.length - minOverlap).join(' ') +
          ' ' +
          wordsB.join(' ');
    }

    // Check if A continues B (B's end matches A's beginning)
    bool isBContinuedByA = true;
    for (int i = 0; i < minOverlap; i++) {
      if (!_wordsMatch(wordsB[wordsB.length - minOverlap + i], wordsA[i])) {
        isBContinuedByA = false;
        break;
      }
    }

    if (isBContinuedByA) {
      // B followed by A (removing A's overlapping beginning)
      return wordsB.sublist(0, wordsB.length - minOverlap).join(' ') +
          ' ' +
          wordsA.join(' ');
    }

    // Not a continuation
    return null;
  }

  // Find the best overlapping segment between the two transcripts
  _SegmentMatch _findBestOverlappingSegment(
      List<String> wordsA, List<String> wordsB) {
    int bestOverlapSize = 0;
    int bestStartA = 0;
    int bestStartB = 0;

    // Try all possible starting positions in A
    for (int startA = 0; startA < wordsA.length; startA++) {
      // Try all possible starting positions in B
      for (int startB = 0; startB < wordsB.length; startB++) {
        // Count consecutive matching words
        int overlapSize = 0;
        while (startA + overlapSize < wordsA.length &&
            startB + overlapSize < wordsB.length &&
            _wordsMatch(
                wordsA[startA + overlapSize], wordsB[startB + overlapSize])) {
          overlapSize++;
        }

        // Update best match if this is better
        if (overlapSize > bestOverlapSize) {
          bestOverlapSize = overlapSize;
          bestStartA = startA;
          bestStartB = startB;
        }
      }
    }

    return _SegmentMatch(bestOverlapSize, bestStartA, bestStartB);
  }

  // Merge transcripts when a good segment overlap is found
  String _mergeWithSegmentOverlap(
      List<String> wordsA, List<String> wordsB, _SegmentMatch match) {
    // First check if this is a simple case where B extends A at the end
    if (match.startA + match.overlapSize == wordsA.length &&
        match.startB == 0) {
      final aPrefix = wordsA.sublist(0, match.startA);
      final overlap = _resolveMismatchedWords(
          wordsA.sublist(match.startA), wordsB.sublist(0, match.overlapSize));
      final bSuffix = wordsB.sublist(match.overlapSize);

      final parts = <String>[];
      if (aPrefix.isNotEmpty) parts.add(aPrefix.join(' '));
      if (overlap.isNotEmpty) parts.add(overlap.join(' '));
      if (bSuffix.isNotEmpty) parts.add(bSuffix.join(' '));

      return parts.join(' ');
    }

    // Check if this is a simple case where A extends B at the end
    if (match.startB + match.overlapSize == wordsB.length &&
        match.startA == 0) {
      final bPrefix = wordsB.sublist(0, match.startB);
      final overlap = _resolveMismatchedWords(
          wordsB.sublist(match.startB), wordsA.sublist(0, match.overlapSize));
      final aSuffix = wordsA.sublist(match.overlapSize);

      final parts = <String>[];
      if (bPrefix.isNotEmpty) parts.add(bPrefix.join(' '));
      if (overlap.isNotEmpty) parts.add(overlap.join(' '));
      if (aSuffix.isNotEmpty) parts.add(aSuffix.join(' '));

      return parts.join(' ');
    }

    // More complex case: the overlap is in the middle
    // Need to decide which parts to keep

    // Option 1: Keep A's beginning + overlap + B's ending
    final aBeginning = wordsA.sublist(0, match.startA);
    final overlap = _resolveMismatchedWords(
        wordsA.sublist(match.startA, match.startA + match.overlapSize),
        wordsB.sublist(match.startB, match.startB + match.overlapSize));
    final bEnding = wordsB.sublist(match.startB + match.overlapSize);

    final parts = <String>[];
    if (aBeginning.isNotEmpty) parts.add(aBeginning.join(' '));
    if (overlap.isNotEmpty) parts.add(overlap.join(' '));
    if (bEnding.isNotEmpty) parts.add(bEnding.join(' '));

    return parts.join(' ');
  }

  // Merge using LCS (Longest Common Subsequence) approach
  String _mergeWithLCS(List<String> wordsA, List<String> wordsB) {
    // Build LCS table
    final table = List.generate(
        wordsA.length + 1, (_) => List<int>.filled(wordsB.length + 1, 0));

    // Fill LCS table
    for (int i = 1; i <= wordsA.length; i++) {
      for (int j = 1; j <= wordsB.length; j++) {
        if (_wordsMatch(wordsA[i - 1], wordsB[j - 1])) {
          table[i][j] = table[i - 1][j - 1] + 1;
        } else {
          table[i][j] = max(table[i - 1][j], table[i][j - 1]);
        }
      }
    }

    // Reconstruct merged sequence
    final merged = <String>[];
    int i = wordsA.length;
    int j = wordsB.length;

    while (i > 0 && j > 0) {
      if (_wordsMatch(wordsA[i - 1], wordsB[j - 1])) {
        // Common word - choose the better representation
        if (wordsB[j - 1].length > wordsA[i - 1].length * 1.2) {
          merged.add(wordsB[j - 1]); // B's word is significantly longer
        } else if (wordsA[i - 1].length > wordsB[j - 1].length * 1.2) {
          merged.add(wordsA[i - 1]); // A's word is significantly longer
        } else {
          merged.add(wordsB[j - 1]); // Prefer B (more recent) otherwise
        }
        i--;
        j--;
      } else if (table[i - 1][j] >= table[i][j - 1]) {
        // Word from A only
        merged.add(wordsA[i - 1]);
        i--;
      } else {
        // Word from B only
        merged.add(wordsB[j - 1]);
        j--;
      }
    }

    // Add any remaining words
    while (i > 0) {
      merged.add(wordsA[i - 1]);
      i--;
    }

    while (j > 0) {
      merged.add(wordsB[j - 1]);
      j--;
    }

    // Return merged text (reversed, since we built it backwards)
    return merged.reversed.join(' ');
  }

  // Choose the best word for each position in an overlapping segment
  List<String> _resolveMismatchedWords(
      List<String> segmentA, List<String> segmentB) {
    final result = <String>[];
    final minLen = min(segmentA.length, segmentB.length);

    for (int i = 0; i < minLen; i++) {
      // If words match exactly, just take either
      if (segmentA[i] == segmentB[i]) {
        result.add(segmentA[i]);
        continue;
      }

      // Words don't match exactly but might be fuzzy matches
      if (_wordsMatch(segmentA[i], segmentB[i])) {
        // Choose the better version (generally prefer longer words)
        if (segmentB[i].length > segmentA[i].length * 1.2) {
          result.add(segmentB[i]); // B's word is significantly longer
        } else if (segmentA[i].length > segmentB[i].length * 1.2) {
          result.add(segmentA[i]); // A's word is significantly longer
        } else {
          // Similar length, prefer B as it's more recent
          result.add(segmentB[i]);
        }
      } else {
        // Not matches - include both words
        result.add(segmentA[i]);
        result.add(segmentB[i]);
      }
    }

    // Add any remaining words from the longer segment
    if (segmentA.length > minLen) {
      result.addAll(segmentA.sublist(minLen));
    } else if (segmentB.length > minLen) {
      result.addAll(segmentB.sublist(minLen));
    }

    return result;
  }

  // Determine if two words should be considered a match
  bool _wordsMatch(String wordA, String wordB) {
    // Exact match
    if (wordA == wordB) return true;

    // Skip fuzzy matching if disabled
    if (!useFuzzyMatching) return false;

    // Avoid matching very short words or words of very different lengths
    if (wordA.length < 3 || wordB.length < 3) {
      // For very short words, only match exactly or if just 1 character different
      return _editDistance(wordA, wordB) <= 1;
    }

    // Check length ratio - very different lengths unlikely to be matches
    final lengthRatio =
        min(wordA.length, wordB.length) / max(wordA.length, wordB.length);
    if (lengthRatio < 0.7) return false;

    // For longer words, first check if they share the same first few characters
    final prefixLength = min(3, min(wordA.length, wordB.length));
    final samePrefix =
        wordA.substring(0, prefixLength) == wordB.substring(0, prefixLength);

    // Calculate similarity
    double similarity = _calculateSimilarity(wordA, wordB);

    // Boost similarity if they share the same prefix
    if (samePrefix) {
      similarity += 0.1;
    }

    // Words with similar letters are more likely to be matches
    return similarity >= fuzzyThreshold;
  }

  // Calculate similarity between strings (1.0 = identical, 0.0 = completely different)
  double _calculateSimilarity(String a, String b) {
    if (a == b) return 1.0;

    final distance = _editDistance(a, b);
    final maxLength = max(a.length, b.length);

    return 1.0 - (distance / maxLength);
  }

  // Calculate edit distance (Levenshtein distance) between two strings
  int _editDistance(String s1, String s2) {
    if (s1 == s2) return 0;
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;

    // Use Wagner-Fischer algorithm with two rows to save space
    final v0 = List<int>.filled(s2.length + 1, 0);
    final v1 = List<int>.filled(s2.length + 1, 0);

    // Initialize first row
    for (int j = 0; j <= s2.length; j++) {
      v0[j] = j;
    }

    for (int i = 0; i < s1.length; i++) {
      v1[0] = i + 1;

      for (int j = 0; j < s2.length; j++) {
        // Calculate cost - 0 if the same, 1 if different
        final cost = s1[i] == s2[j] ? 0 : 1;

        // Take the minimum of:
        // 1. Delete from s1: v1[j] + 1
        // 2. Insert into s1: v0[j+1] + 1
        // 3. Substitute: v0[j] + cost
        v1[j + 1] = min(min(v1[j] + 1, v0[j + 1] + 1), v0[j] + cost);
      }

      // Swap the arrays for next iteration
      for (int j = 0; j <= s2.length; j++) {
        v0[j] = v1[j];
      }
    }

    return v1[s2.length];
  }
}

// Result of finding a segment match
class _SegmentMatch {
  final int overlapSize;
  final int startA;
  final int startB;

  _SegmentMatch(this.overlapSize, this.startA, this.startB);
}
