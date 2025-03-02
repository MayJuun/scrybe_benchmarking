class TranscriptCombiner {
  // Keep track of the last content we added
  String _lastAddedContent = '';

  String combineTranscripts(String existing, String newText) {
    // Clean up inputs
    newText = newText.trim();
    existing = existing.trim();

    // Basic case - empty inputs
    if (newText.isEmpty) return existing;
    if (existing.isEmpty) return newText;

    // Skip if the new content is identical or very similar to what we just added
    if (newText == _lastAddedContent ||
        existing.contains(newText) ||
        _isMostlyDuplicate(newText, existing)) {
      return existing;
    }

    // Remember what we added
    _lastAddedContent = newText;

    // Try to find the last few words of existing in the beginning of newText
    final existingWords = existing.split(' ');
    final newWords = newText.split(' ');

    // Only look for overlap if we have enough words to work with
    if (existingWords.length >= 3 && newWords.length >= 3) {
      // Try different overlap sizes from 5 down to 3
      for (int overlap = 5; overlap >= 3; overlap--) {
        if (existingWords.length < overlap) continue;

        // Get last [overlap] words from existing text
        final existingEnd =
            existingWords.sublist(existingWords.length - overlap);
        // Get first [overlap] words from new text
        final newStart = newWords.sublist(0, overlap);

        // Compare them (just doing simple comparison for now)
        if (_wordsAreEqual(existingEnd, newStart)) {
          // We found an overlap! Join them
          final result = [
            ...existingWords.sublist(0, existingWords.length - overlap),
            ...newWords
          ];
          return result.join(' ');
        }
      }
    }

    // If we didn't find an overlap, just append with a space
    return existing + ' ' + newText;
  }

  // Simple word list comparison
  bool _wordsAreEqual(List<String> list1, List<String> list2) {
    if (list1.length != list2.length) return false;
    for (int i = 0; i < list1.length; i++) {
      // Ignore punctuation and capitalization for comparison
      final word1 = list1[i].toLowerCase().replaceAll(RegExp(r'[,.!?]'), '');
      final word2 = list2[i].toLowerCase().replaceAll(RegExp(r'[,.!?]'), '');
      if (word1 != word2) return false;
    }
    return true;
  }

  // Check if most of the text is already in the existing content
  bool _isMostlyDuplicate(String newText, String existing) {
    final newWords = newText.split(' ');
    final existingWords = existing.split(' ');

    // Get the last 50 words or so from existing
    final recentWords = existingWords.length > 50
        ? existingWords.sublist(existingWords.length - 50)
        : existingWords;

    int matchingWords = 0;
    for (final word in newWords) {
      final cleaned = word.toLowerCase().replaceAll(RegExp(r'[,.!?]'), '');
      if (recentWords.any((w) =>
          w.toLowerCase().replaceAll(RegExp(r'[,.!?]'), '') == cleaned)) {
        matchingWords++;
      }
    }

    // If more than 70% of words are in the recent text, consider it a duplicate
    return matchingWords / newWords.length > 0.7;
  }
}
