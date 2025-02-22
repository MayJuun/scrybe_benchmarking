class TranscriptionConfig {
  final double timestampThreshold;
  final int minOverlapWords;
  final bool useSentenceBoundaries;
  final bool debug;
  final int minWordLength; // New: ignore very short words in overlap detection

  const TranscriptionConfig({
    this.timestampThreshold = 1.0,
    this.minOverlapWords = 3,
    this.useSentenceBoundaries = true,
    this.debug = false,
    this.minWordLength = 2, // Ignore single-letter words by default
  });
}

class TranscriptionCombiner {
  final TranscriptionConfig config;
  String? _previousText; // Track the previous result for better deduplication

  TranscriptionCombiner({TranscriptionConfig? config})
      : config = config ?? const TranscriptionConfig();

  String combineTranscripts(String existing, TranscriptionResult newResult) {
    if (config.debug) {
      print('\nCombining transcripts:');
      print('Existing: "$existing"');
      print('New result: "${newResult.text}"');
    }

    if (existing.isEmpty) {
      _previousText = newResult.text;
      return newResult.text;
    }

    // If the new result is empty or identical to previous, return existing
    if (newResult.text.isEmpty || newResult.text == _previousText) {
      return existing;
    }

    // Clean up text
    final cleanExisting = _cleanText(existing);
    final cleanNew = _cleanText(newResult.text);

    // Store this result for next comparison
    _previousText = cleanNew;

    // Find the longest common substring between existing and new text
    final lcs = _longestCommonSubstring(cleanExisting, cleanNew);

    if (lcs.length > 20) {
      // If we found a substantial common part
      final newStart = cleanNew.indexOf(lcs) + lcs.length;
      if (newStart < cleanNew.length) {
        // Only add the part after the common substring
        return '$cleanExisting ${cleanNew.substring(newStart)}';
      }
      return cleanExisting;
    }

    // If texts are very different, look for sentence boundaries
    if (config.useSentenceBoundaries) {
      final sentences = cleanExisting.split(RegExp(r'[.!?] ')).toList();
      if (sentences.isNotEmpty) {
        final lastSentence = sentences.last;
        if (cleanNew.contains(lastSentence)) {
          // If new text contains the last sentence, start from there
          final newPart = cleanNew
              .substring(cleanNew.indexOf(lastSentence) + lastSentence.length);
          if (newPart.isNotEmpty) {
            return cleanExisting + newPart;
          }
        }
      }
    }

    // If the new text is completely different and seems to be a continuation
    if (!cleanNew.contains(cleanExisting.split(' ').last) &&
        !cleanExisting.contains(cleanNew)) {
      return '$cleanExisting $cleanNew';
    }

    return cleanExisting;
  }

  String _cleanText(String text) {
    return text
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'[.!?]+\s*'), '. ')
        .replaceAll(RegExp(r'\|\s*'), ' ') // Remove any separators
        .trim();
  }

  String _longestCommonSubstring(String s1, String s2) {
    if (s1.isEmpty || s2.isEmpty) return '';

    var longest = '';
    var table = List.generate(s1.length, (i) => List.filled(s2.length, 0));

    for (var i = 0; i < s1.length; i++) {
      for (var j = 0; j < s2.length; j++) {
        if (s1[i] == s2[j]) {
          table[i][j] = (i == 0 || j == 0) ? 1 : table[i - 1][j - 1] + 1;
          if (table[i][j] > longest.length) {
            longest = s1.substring(i - table[i][j] + 1, i + 1);
          }
        }
      }
    }

    return longest;
  }
}

extension IterableExtension<T> on Iterable<T> {
  Iterable<T> takeLast(int n) {
    if (length <= n) return this;
    return skip(length - n);
  }
}

class TokenInfo {
  final String text;
  final double? timestamp; // Optional since not all models provide timestamps
  final int position; // Position in sequence

  TokenInfo({
    required this.text,
    this.timestamp,
    required this.position,
  });

  @override
  String toString() =>
      'TokenInfo(text: $text, timestamp: $timestamp, position: $position)';
}

class TranscriptionResult {
  final String text;
  final List<TokenInfo> tokens;
  final bool hasTimestamps;

  TranscriptionResult({
    required this.text,
    required this.tokens,
    required this.hasTimestamps,
  });

  TranscriptionResult.empty()
      : text = '',
        tokens = [],
        hasTimestamps = false;

  // Create a simple text-only result
  factory TranscriptionResult.text(String text) {
    return TranscriptionResult(
      text: text,
      tokens: [TokenInfo(text: text, position: 0)],
      hasTimestamps: false,
    );
  }

  // Factory to create from model result
  factory TranscriptionResult.fromJson(Map<String, dynamic> json) {
    try {
      final List<dynamic> tokenTexts = json['tokens'] as List;
      final List<dynamic> timestamps = json['timestamps'] as List? ?? [];
      final bool hasTimestamps = timestamps.isNotEmpty;

      // Validate token and timestamp counts match
      if (hasTimestamps && tokenTexts.length != timestamps.length) {
        print(
            'Warning: Token count (${tokenTexts.length}) doesn\'t match timestamp count (${timestamps.length})');
        return TranscriptionResult.text(json['text'] as String);
      }

      final tokens = List<TokenInfo>.generate(
        tokenTexts.length,
        (i) => TokenInfo(
          text: tokenTexts[i] as String,
          timestamp: hasTimestamps ? (timestamps[i] as num).toDouble() : null,
          position: i,
        ),
      );

      return TranscriptionResult(
        text: json['text'] as String,
        tokens: tokens,
        hasTimestamps: hasTimestamps,
      );
    } catch (e) {
      print('Error parsing transcription result: $e');
      return TranscriptionResult.text(json['text'] as String);
    }
  }

  void debugPrint() {
    print('TranscriptionResult:');
    print('Text: $text');
    print('Has timestamps: $hasTimestamps');
    print('Tokens:');
    for (var token in tokens) {
      print('  ${token.toString()}');
    }
  }
}
