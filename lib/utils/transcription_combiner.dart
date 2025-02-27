import 'dart:math';
import 'package:fuzzywuzzy/fuzzywuzzy.dart';

class TranscriptionConfig {
  final int ngramSize;
  final double similarityThreshold;
  final int minOverlapWords;
  final bool debug;
  final bool useFuzzyMatching;

  // Scanning parameters
  final int
      maxLookbackNgrams; // Explicit limit on how many ngrams to look back (0 = use smart limit)
  final bool
      scanFullText; // Whether to scan the full text for containment checks
  final bool
      useSmartLimit; // Use a smart limit based on the size of the new text

  const TranscriptionConfig({
    this.ngramSize = 2,
    this.similarityThreshold = 0.75,
    this.minOverlapWords = 2,
    this.debug = true,
    this.useFuzzyMatching = true,
    this.maxLookbackNgrams = 0, // 0 = use smart limit instead of a fixed limit
    this.scanFullText = true, // Enable full text containment checks
    this.useSmartLimit = true, // Enable smart limiting based on new text length
  });
}

class TranscriptionCombiner {
  final TranscriptionConfig config;
  String _previousText = '';

  TranscriptionCombiner({TranscriptionConfig? config})
      : config = config ?? const TranscriptionConfig();

  String combineTranscripts(String existing, String newText) {
    if (config.debug) {
      print('Existing: $existing');
      print('New: $newText');
    }

    // If nothing new or same as last update, return the current transcript.
    if (newText.isEmpty || newText == _previousText) {
      return existing;
    }

    // Clean and normalize texts
    final cleanNew = _cleanText(newText);
    final cleanExisting = _cleanText(existing);

    if (config.debug) {
      print('Clean Existing: $cleanExisting');
      print('Clean New: $cleanNew');
    }

    // If there was no previous transcript, use the new one.
    if (cleanExisting.isEmpty) {
      _updateState(cleanNew);
      return cleanNew;
    }

    // Find the overlap point - where new text matches the end of existing text
    int overlapIndex = _findOverlapPoint(cleanExisting, cleanNew);

    // If we found a good overlap point
    if (overlapIndex > 0) {
      // Only append the non-overlapping part
      final uniqueNewContent = cleanNew.substring(overlapIndex);
      if (uniqueNewContent.trim().isNotEmpty) {
        final combinedText = cleanExisting + uniqueNewContent;
        _updateState(cleanNew);
        if (config.debug) print('Result (appended new content): $combinedText');
        return combinedText;
      } else {
        // No new content to add
        _updateState(cleanNew);
        if (config.debug) print('Result (no new content): $cleanExisting');
        return cleanExisting;
      }
    }

    // Check if the new text already contains the existing transcript
    if (_containsText(cleanNew.toLowerCase(), cleanExisting.toLowerCase())) {
      _updateState(cleanNew);
      if (config.debug) print('Result (new contains existing): $cleanNew');
      return cleanNew;
    }

    // Check if the existing text already contains the new text
    if (config.scanFullText &&
        _containsText(cleanExisting.toLowerCase(), cleanNew.toLowerCase())) {
      _updateState(cleanNew);
      if (config.debug) print('Result (existing contains new): $cleanExisting');
      return cleanExisting;
    }

    // Generate n-grams for both texts for overlap detection.
    final existingNgrams = _generateNgrams(cleanExisting);
    final newNgrams = _generateNgrams(cleanNew);

    // Find the best overlap point - using the ENTIRE text, not just the last few ngrams
    final (int overlapStart, double overlapScore) =
        _findBestOverlap(existingNgrams, newNgrams);

    if (config.debug) {
      print('Best overlap score: $overlapScore at position: $overlapStart');
    }

    // If a good overlap is found, merge the transcripts at the overlap.
    if (overlapScore >= config.similarityThreshold) {
      final result = _mergeAtOverlap(cleanExisting, cleanNew, overlapStart);
      _updateState(cleanNew);
      if (config.debug) print('Result (merged at overlap): $result');
      return result;
    }

    // Otherwise, if the texts differ, append only the non-duplicate portion.
    if (cleanExisting.toLowerCase() != cleanNew.toLowerCase()) {
      // Check for substantial similarity between texts to avoid duplication
      double fullTextSimilarity = config.useFuzzyMatching
          ? ratio(cleanExisting.toLowerCase(), cleanNew.toLowerCase()) / 100.0
          : 0.0;

      if (fullTextSimilarity > 0.8) {
        // If texts are very similar, use the longer one
        String result =
            cleanExisting.length > cleanNew.length ? cleanExisting : cleanNew;
        _updateState(cleanNew);
        if (config.debug) print('Result (using similar text): $result');
        return result;
      }

      // Use a simple concatenation with a space in between.
      final combined = '$cleanExisting $cleanNew';
      _updateState(cleanNew);
      if (config.debug) print('Result (appended): $combined');
      return combined;
    }

    _updateState(cleanNew);
    if (config.debug) print('Result (unchanged): $cleanExisting');
    return cleanExisting;
  }

  // Helper method to find the exact point where new text starts adding unique content
  int _findOverlapPoint(String existing, String newText) {
    // Start with a reasonable minimum overlap to consider
    int minOverlap = config.minOverlapWords * 5; // Rough character count

    // If either text is too short, use a smaller overlap requirement
    if (existing.length < minOverlap || newText.length < minOverlap) {
      minOverlap = min(existing.length, newText.length) - 1;
      if (minOverlap <= 0) return 0;
    }

    // Try different lengths of overlap, starting with the largest possible
    for (int overlapLen = min(existing.length, newText.length);
        overlapLen >= minOverlap;
        overlapLen--) {
      // Don't check if overlap length is greater than existing text
      if (overlapLen > existing.length) continue;

      String existingSuffix = existing.substring(existing.length - overlapLen);
      String newTextPrefix = newText.substring(0, overlapLen);

      // For an exact match
      if (existingSuffix == newTextPrefix) {
        if (config.debug)
          print('Found exact overlap of $overlapLen characters');
        return overlapLen;
      }

      // For fuzzy matching (to handle small transcription differences)
      if (config.useFuzzyMatching) {
        double similarity =
            ratio(existingSuffix.toLowerCase(), newTextPrefix.toLowerCase()) /
                100.0;
        if (similarity > config.similarityThreshold) {
          if (config.debug)
            print(
                'Found fuzzy overlap of $overlapLen characters (similarity: ${(similarity * 100).toStringAsFixed(1)}%)');
          return overlapLen;
        }
      }
    }

    return 0; // No good overlap found
  }

  List<String> _generateNgrams(String text) {
    final words = text.split(' ');
    if (words.length < config.ngramSize) {
      return [text];
    }

    return List.generate(
      words.length - config.ngramSize + 1,
      (i) => words.sublist(i, i + config.ngramSize).join(' '),
    );
  }

  // Check if text1 contains text2, allowing for some fuzzy matching
  bool _containsText(String text1, String text2) {
    // Direct containment check
    if (text1.contains(text2)) return true;

    // For short text or when fuzzy matching is disabled, rely on direct check
    if (!config.useFuzzyMatching || text2.length < 15) return false;

    // For fuzzy matching with longer texts, use a more sophisticated approach
    final ratio = partialRatio(text1, text2) / 100.0;
    return ratio > 0.9; // High threshold for containment
  }

  // Returns a record (tuple) containing the best overlap position and score.
  (int, double) _findBestOverlap(
      List<String> existingNgrams, List<String> newNgrams) {
    var bestScore = 0.0;
    var bestPosition = -1;

    // Determine how far back to look in the existing text
    int startIdx;

    if (config.maxLookbackNgrams > 0) {
      // Case 1: Explicit fixed limit is specified
      startIdx = max(0, existingNgrams.length - config.maxLookbackNgrams);
    } else if (config.useSmartLimit) {
      // Case 2: Smart limit based on new text length plus a buffer
      // Rationale: An overlap shouldn't be longer than the new text itself
      final newTextLength = newNgrams.length;
      final bufferSize = 5; // Small buffer to catch partial overlaps
      final smartLimit = newTextLength + bufferSize;
      startIdx = max(0, existingNgrams.length - smartLimit);

      if (config.debug) {
        print('Using smart limit: looking back ${existingNgrams.length - startIdx} ngrams ' +
            '(new text length: $newTextLength ngrams + buffer: $bufferSize)');
      }
    } else {
      // Case 3: No limiting - check the entire text
      startIdx = 0;
    }

    // Look through all ngrams in the existing text (or a limited window)
    for (var i = startIdx; i < existingNgrams.length; i++) {
      // Check all ngrams in the new text (or a reasonable limit)
      final maxNewCheck =
          min(newNgrams.length, 50); // Limit how many new ngrams we check
      for (var j = 0; j < maxNewCheck; j++) {
        final score = _calculateSimilarity(existingNgrams[i], newNgrams[j]);
        if (score > bestScore) {
          bestScore = score;
          bestPosition = i;
        }
      }
    }

    // For longer texts, also try to find longer matching sequences
    // This helps catch multi-word overlaps that might be missed by individual ngrams
    if (existingNgrams.length > 10 && newNgrams.length > 10) {
      // Try different window sizes for matching
      for (var windowSize = 3; windowSize <= 8; windowSize++) {
        for (var i = max(0, existingNgrams.length - 30);
            i < existingNgrams.length - windowSize + 1;
            i++) {
          for (var j = 0; j < min(20, newNgrams.length - windowSize + 1); j++) {
            // Compare sequences of ngrams
            var sequenceScore = 0.0;
            for (var k = 0; k < windowSize; k++) {
              sequenceScore +=
                  _calculateSimilarity(existingNgrams[i + k], newNgrams[j + k]);
            }
            sequenceScore /= windowSize; // Average score

            if (sequenceScore > bestScore) {
              bestScore = sequenceScore;
              bestPosition = i;
            }
          }
        }
      }
    }

    return (bestPosition, bestScore);
  }

  // Updated similarity calculation using fuzzywuzzy.
  double _calculateSimilarity(String ngram1, String ngram2) {
    if (!config.useFuzzyMatching) {
      // Fallback: use original exact word-by-word matching.
      if (ngram1 == ngram2) return 1.0;
      ngram1 = ngram1.toLowerCase();
      ngram2 = ngram2.toLowerCase();

      final words1 = ngram1.split(' ');
      final words2 = ngram2.split(' ');

      var matchingWords = 0;
      for (var i = 0; i < words1.length; i++) {
        if (i < words2.length && words1[i] == words2[i]) {
          matchingWords++;
        }
      }

      return matchingWords / config.ngramSize;
    } else {
      // Use fuzzywuzzy's ratio to get a percentage similarity.
      final score = ratio(ngram1.toLowerCase(), ngram2.toLowerCase());
      return score / 100.0;
    }
  }

  String _mergeAtOverlap(String existing, String newText, int overlapPosition) {
    final existingWords = existing.split(' ');

    // Take existing text up to the overlap point
    final prefix = existingWords.take(overlapPosition).join(' ');

    // Return prefix + new text
    return prefix.isEmpty ? newText : '$prefix $newText';
  }

  String _cleanText(String text) {
    return text
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'[.!?]+\s*'), '. ')
        .replaceAll(RegExp(r'\|\s*'), ' ')
        .trim();
  }

  void _updateState(String newText) {
    _previousText = newText;
  }

  // Detects if a new text is likely a truncated version of old text
  bool isPossiblyTruncatedFrom(String oldText, String newText) {
    if (oldText.isEmpty || newText.isEmpty) return false;

    // Check if newText might be a truncated version of oldText
    // by comparing overlapping suffixes and prefixes
    int minLength = min(oldText.length, newText.length);
    int checkLength = min(minLength, 30); // Check up to 30 chars

    String oldSuffix = oldText.substring(oldText.length - checkLength);
    String newPrefix = newText.substring(0, min(checkLength, newText.length));

    // Use fuzzy matching to find if there's significant overlap
    double suffixPrefixScore = config.useFuzzyMatching
        ? ratio(oldSuffix.toLowerCase(), newPrefix.toLowerCase()) / 100.0
        : 0.0;

    return suffixPrefixScore > 0.7; // 70% similarity threshold
  }
}
