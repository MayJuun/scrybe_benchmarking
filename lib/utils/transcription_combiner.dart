import 'dart:math';

class TranscriptCombiner {
  /// Maximum number of words to consider in the overlap region.
  final int maxOverlapWords;

  /// Similarity threshold [0..1]; higher means stricter overlap matching.
  final double similarityThreshold;

  TranscriptCombiner({
    this.maxOverlapWords = 5,
    this.similarityThreshold = 0.7,
  });

  /// Main entry point to combine two transcript chunks with a word-level overlap.
  String combineTranscripts(String chunk1, String chunk2) {
    // NORMALIZE BOTH CHUNKS FIRST
    final normalized1 = normalize(chunk1);
    final normalized2 = normalize(chunk2);

    // We'll use the normalized chunks for everything from now on

    // Split into words for overlap detection
    final words1 =
        normalized1.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final words2 =
        normalized2.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

    // Edge cases
    if (words1.isEmpty) return normalized2; // no overlap needed
    if (words2.isEmpty) return normalized1;

    double bestScore = 0.0;
    int bestOverlap = 0;

    // Try overlap sizes from 1 up to maxOverlapWords
    // but no more than the actual number of words in each chunk
    final overlapLimit =
        min(maxOverlapWords, min(words1.length, words2.length));

    for (int overlapSize = 1; overlapSize <= overlapLimit; overlapSize++) {
      // Suffix of chunk1
      final suffix = words1.sublist(words1.length - overlapSize);
      // Prefix of chunk2
      final prefix = words2.sublist(0, overlapSize);

      // Calculate a similarity score (e.g., Jaccard or simple word overlap ratio)
      final score = _jaccardSimilarity(suffix, prefix);

      if (score > bestScore) {
        bestScore = score;
        bestOverlap = overlapSize;
      }
    }

    // Decide if our best overlap is good enough
    if (bestScore >= similarityThreshold && bestOverlap > 0) {
      // We have a decent match, so merge without duplicating the overlap words
      final merged =
          _mergeWithWordOverlap(normalized1, normalized2, bestOverlap);
      return merged;
    } else {
      // No decent match, just join with a separator
      return normalized1 + ' ' + normalized2;
    }
  }

  /// Merge the two original strings by removing the overlapping words
  /// from the start of chunk2.
  String _mergeWithWordOverlap(String chunk1, String chunk2, int overlapWords) {
    // A simple approach:
    //  1) Convert chunk2 to words
    //  2) Skip overlapWords from the front
    //  3) Append to chunk1

    // Count how many words we've seen, then note the index in chunk2's original text.
    final chunk2TrimIndex = _findWordBoundaryIndex(chunk2, overlapWords);

    // Merge
    return chunk1.trim() + ' ' + chunk2.substring(chunk2TrimIndex).trim();
  }

  /// Find the character index in [text] after skipping [wordCount] "real words".
  /// This method preserves original spacing/punctuation in chunk2 after the overlap.
  int _findWordBoundaryIndex(String text, int wordCount) {
    // Basic idea: parse through text word by word, keep track of char indices
    // until we've passed 'wordCount' words, then return that char index.
    final regex = RegExp(r'\S+'); // matches consecutive non-whitespace
    final matches = regex.allMatches(text);

    int wordsSeen = 0;
    for (final match in matches) {
      wordsSeen++;
      if (wordsSeen == wordCount) {
        // return the character index right after this match
        return match.end;
      }
    }
    // If text has fewer than wordCount words, return entire length (i.e., no leftover).
    return text.length;
  }

  /// A simple Jaccard similarity for word arrays: intersection / union.
  double _jaccardSimilarity(List<String> a, List<String> b) {
    if (a.isEmpty && b.isEmpty) return 1.0;
    if (a.isEmpty || b.isEmpty) return 0.0;

    final setA = a.toSet();
    final setB = b.toSet();
    final intersection = setA.intersection(setB).length;
    final union = setA.union(setB).length;
    return intersection / union;
  }

  /// Normalize text: lowercase, preserve in-word punctuation (hyphens & apostrophes), and strip other non-word characters.
  /// This is tailored for medical dictation where compound terms and contractions are important.
  static String normalize(String text) {
    // Convert to lowercase
    final lower = text.toLowerCase();

    // Create a pattern that keeps alphanumeric chars, spaces, hyphens, and apostrophes
    // but removes all other punctuation
    final keepInWordPunctuation = lower.replaceAll(RegExp(r"[^\w\s\'-]+"), '');

    // Remove any non-word characters (except hyphens, apostrophes, and spaces)
    // This will catch any special characters that aren't already handled
    final wordsOnly =
        keepInWordPunctuation.replaceAll(RegExp(r"[^\w\s\'-]"), '');

    // Collapse multiple spaces
    return wordsOnly.replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}
