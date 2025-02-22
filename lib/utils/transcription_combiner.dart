import 'dart:math';

class TranscriptionConfig {
  final int ngramSize;
  final double similarityThreshold;
  final int minOverlapWords;
  final bool debug;

  const TranscriptionConfig({
    this.ngramSize = 3,
    this.similarityThreshold = 0.85,
    this.minOverlapWords = 3,
    this.debug = false,
  });
}

class TranscriptionCombiner {
  final TranscriptionConfig config;
  String _previousText = '';

  TranscriptionCombiner({TranscriptionConfig? config})
      : config = config ?? const TranscriptionConfig();

  String combineTranscripts(String existing, String newText) {
    if (newText.isEmpty || newText == _previousText) {
      return existing;
    }

    // Clean and normalize texts
    final cleanNew = _cleanText(newText);
    final cleanExisting = _cleanText(existing);

    if (cleanExisting.isEmpty) {
      _updateState(cleanNew);
      return cleanNew;
    }

    // Generate n-grams for both texts
    final existingNgrams = _generateNgrams(cleanExisting);
    final newNgrams = _generateNgrams(cleanNew);

    // Find the best overlap point
    final (overlapStart, overlapScore) = _findBestOverlap(existingNgrams, newNgrams);

    if (config.debug) {
      print('Best overlap score: $overlapScore at position: $overlapStart');
      print('Existing n-grams: $existingNgrams');
      print('New n-grams: $newNgrams');
    }

    // If we found a good overlap point
    if (overlapScore >= config.similarityThreshold) {
      final result = _mergeAtOverlap(cleanExisting, cleanNew, overlapStart);
      _updateState(cleanNew);
      return result;
    }

    // Check if this is a progressive update
    if (_isProgressiveUpdate(cleanExisting, cleanNew)) {
      _updateState(cleanNew);
      return cleanNew;
    }

    _updateState(cleanNew);
    return cleanExisting;
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

  (int, double) _findBestOverlap(List<String> existingNgrams, List<String> newNgrams) {
    var bestScore = 0.0;
    var bestPosition = -1;

    // Only look at the last portion of existing text for potential overlaps
    final startIdx = max(0, existingNgrams.length - 20);
    
    for (var i = startIdx; i < existingNgrams.length; i++) {
      for (var j = 0; j < min(newNgrams.length, 20); j++) {
        final score = _calculateSimilarity(existingNgrams[i], newNgrams[j]);
        if (score > bestScore) {
          bestScore = score;
          bestPosition = i;
        }
      }
    }

    return (bestPosition, bestScore);
  }

  double _calculateSimilarity(String ngram1, String ngram2) {
    if (ngram1 == ngram2) return 1.0;
    
    // Convert to lowercase for comparison
    ngram1 = ngram1.toLowerCase();
    ngram2 = ngram2.toLowerCase();
    
    // Calculate word-level similarity
    final words1 = ngram1.split(' ');
    final words2 = ngram2.split(' ');
    
    var matchingWords = 0;
    for (var i = 0; i < words1.length; i++) {
      if (i < words2.length && words1[i] == words2[i]) {
        matchingWords++;
      }
    }
    
    return matchingWords / config.ngramSize;
  }

  String _mergeAtOverlap(String existing, String newText, int overlapPosition) {
    final existingWords = existing.split(' ');
    final newWords = newText.split(' ');
    
    // Take existing text up to overlap point
    final prefix = existingWords.take(overlapPosition).join(' ');
    
    // Find where overlap ends in new text
    final overlapNgram = existingWords
        .skip(overlapPosition)
        .take(config.ngramSize)
        .join(' ');
    
    var newTextStart = 0;
    for (var i = 0; i < newWords.length - config.ngramSize + 1; i++) {
      final currentNgram = newWords.skip(i).take(config.ngramSize).join(' ');
      if (_calculateSimilarity(overlapNgram, currentNgram) >= config.similarityThreshold) {
        newTextStart = i + config.ngramSize;
        break;
      }
    }
    
    // Combine the non-overlapping parts
    final suffix = newWords.skip(newTextStart).join(' ');
    return suffix.isEmpty ? existing : '$prefix $overlapNgram $suffix'.trim();
  }

  bool _isProgressiveUpdate(String existing, String newText) {
    if (newText.length <= existing.length) return false;
    
    // Check if new text starts with most of existing text
    final existingNgrams = _generateNgrams(existing);
    final newStartNgrams = _generateNgrams(
      newText.substring(0, min(newText.length, existing.length))
    );
    
    var matchCount = 0;
    final minNgrams = min(existingNgrams.length, newStartNgrams.length);
    
    for (var i = 0; i < minNgrams; i++) {
      if (_calculateSimilarity(existingNgrams[i], newStartNgrams[i]) >= config.similarityThreshold) {
        matchCount++;
      }
    }
    
    return matchCount / minNgrams >= config.similarityThreshold;
  }

  void _updateState(String newText) {
    _previousText = newText;
  }

  String _cleanText(String text) {
    return text
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'[.!?]+\s*'), '. ')
        .replaceAll(RegExp(r'\|\s*'), ' ')
        .trim();
  }
}