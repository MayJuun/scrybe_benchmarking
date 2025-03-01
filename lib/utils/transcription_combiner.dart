// import 'dart:math';

// /// A transcript combiner that focuses on finding and merging overlapping regions
// /// using a suffix-prefix matching approach with special handling for early chunks.
// class TranscriptCombiner {
//   // Track the previous chunk to avoid duplicate processing
//   String _previousChunk = '';

//   // Track how many chunks we've processed (for early replacement logic)
//   int _chunkCount = 0;

//   // Configuration
//   final bool debug;
//   final double similarityThreshold;
//   final int earlyChunksToReplace;

//   TranscriptCombiner({
//     this.debug = false,
//     this.similarityThreshold = 0.7, // Minimum similarity to consider a match
//     this.earlyChunksToReplace =
//         4, // Replace for the first N chunks (approx. first 8-10 seconds)
//   });

//   /// Combines existing transcript with new text by finding where they overlap
//   String combineTranscripts(String existing, String newText) {
//     if (debug) {
//       print('--- combineTranscripts START ---');
//       print('Existing: "$existing"');
//       print('New: "$newText"');
//     }

//     // Clean inputs and handle basic cases
//     newText = _cleanText(newText);

//     // Skip if empty or identical to previous chunk
//     if (newText.isEmpty || newText == _previousChunk) {
//       if (debug) print('No change or empty new text');
//       return existing;
//     }
//     _previousChunk = newText;

//     // If no existing transcript, just return the new text
//     existing = _cleanText(existing);
//     if (existing.isEmpty) {
//       if (debug) print('No existing transcript');
//       _chunkCount++;
//       return newText;
//     }

//     // Special handling for early chunks: during initial transcription build-up,
//     // we prefer to replace with newer versions when they're substantially different
//     if (_chunkCount < earlyChunksToReplace) {
//       if (debug) print('Early chunk detected (chunk #${_chunkCount + 1})');
//       if (_shouldReplaceEarly(existing, newText)) {
//         if (debug) print('Replacing early transcript with newer version');
//         _chunkCount++;
//         return newText;
//       }
//     }

//     // Convert to word arrays for matching
//     final existingWords = existing.split(' ');
//     final newWords = newText.split(' ');

//     // Find the best overlap point
//     final overlapResult = _findBestOverlap(existingWords, newWords);

//     if (debug) {
//       print('Best overlap found:');
//       print('  Similarity: ${overlapResult.similarity}');
//       print('  Existing position: ${overlapResult.existingPos}');
//       print('  Overlap length: ${overlapResult.overlapLength}');
//     }

//     // If we found a good overlap, combine the texts
//     if (overlapResult.similarity >= similarityThreshold) {
//       // 1. Keep existing text up to the overlap point
//       final prefix = existingWords.sublist(0, overlapResult.existingPos);
//       // 2. Use the new text from that point forward (make a copy)
//       final newContent = List<String>.from(newWords);

//       // Enhanced join-point handling: compare a window of 2 words
//       const int windowSize = 2;
//       if (prefix.length >= windowSize && newContent.length >= windowSize) {
//         bool windowMatches = true;
//         for (int i = 0; i < windowSize; i++) {
//           final wordFromPrefix = prefix[prefix.length - windowSize + i]
//               .toLowerCase()
//               .replaceAll(RegExp(r'[,.?!:;]'), '');
//           final wordFromNew =
//               newContent[i].toLowerCase().replaceAll(RegExp(r'[,.?!:;]'), '');
//           if (!_wordsSimilar(wordFromPrefix, wordFromNew)) {
//             windowMatches = false;
//             break;
//           }
//         }
//         if (windowMatches) {
//           if (debug) {
//             print(
//                 'Duplicate window detected at join point: removing first $windowSize words of new text');
//           }
//           newContent.removeRange(0, windowSize);
//         }
//       }

//       final combined = [...prefix, ...newContent].join(' ');
//       if (debug) {
//         print('Combining with overlap. Result: "$combined"');
//       }
//       _chunkCount++;
//       return combined;
//     }

//     // No significant overlap found - check if texts might contain each other
//     if (_isTextContained(newText, existing)) {
//       if (debug) print('New text appears to contain all existing text');
//       _chunkCount++;
//       return newText;
//     }

//     // If all else fails, simply append with a separator
//     if (debug) print('No overlap found - appending with separator');
//     final separator = existing.endsWith('.') ? ' ' : '. ';
//     _chunkCount++;
//     return existing + separator + newText;
//   }

//   /// Determine if we should replace the early transcript with the new version
//   bool _shouldReplaceEarly(String existing, String newText) {
//     if (newText.length > existing.length * 1.3) {
//       if (debug) print('New text is significantly longer than existing');
//       return true;
//     }
//     final existingProblemScore = _countTranscriptionProblems(existing);
//     final newProblemScore = _countTranscriptionProblems(newText);
//     if (newProblemScore < existingProblemScore) {
//       if (debug) print('New text has fewer transcription problems');
//       return true;
//     }
//     final similarity = _textSimilarity(existing, newText);
//     if (similarity > 0.7 && newProblemScore < existingProblemScore) {
//       if (debug) print('Texts are similar but new is cleaner');
//       return true;
//     }
//     return false;
//   }

//   /// Count patterns that might indicate transcription problems
//   int _countTranscriptionProblems(String text) {
//     int score = 0;
//     final repeatedPattern = RegExp(r'(\w+)(-\1)+');
//     score += repeatedPattern.allMatches(text).length * 3;
//     final shortWordSequence = RegExp(r'\b\w{1,2}\b \b\w{1,2}\b \b\w{1,2}\b');
//     score += shortWordSequence.allMatches(text).length;
//     final unusualPunctuation = RegExp(r'\.{2,}|,{2,}|\s{2,}');
//     score += unusualPunctuation.allMatches(text).length;
//     return score;
//   }

//   /// Find the best suffix-prefix overlap between two word lists
//   _OverlapResult _findBestOverlap(
//       List<String> existingWords, List<String> newWords) {
//     _OverlapResult bestOverlap = _OverlapResult();
//     final maxOverlapToCheck = min(existingWords.length, newWords.length);
//     for (int overlapLen = maxOverlapToCheck; overlapLen >= 3; overlapLen--) {
//       if (existingWords.length < overlapLen) continue;
//       final existingStartPos = existingWords.length - overlapLen;
//       final existingSuffix = existingWords.sublist(existingStartPos);
//       final newPrefix = newWords.sublist(0, overlapLen);
//       final similarity = _calculateSimilarity(existingSuffix, newPrefix);
//       if (similarity > bestOverlap.similarity) {
//         bestOverlap = _OverlapResult(
//           existingPos: existingStartPos,
//           overlapLength: overlapLen,
//           similarity: similarity,
//         );
//         if (similarity > 0.9) break;
//       }
//     }
//     return bestOverlap;
//   }

//   /// Calculate similarity between two word lists
//   double _calculateSimilarity(List<String> words1, List<String> words2) {
//     if (words1.length != words2.length) return 0.0;
//     int matches = 0;
//     for (int i = 0; i < words1.length; i++) {
//       if (_wordsSimilar(words1[i], words2[i])) {
//         matches++;
//       }
//     }
//     return matches / words1.length;
//   }

//   /// Calculate simple text similarity ratio
//   double _textSimilarity(String text1, String text2) {
//     final words1 = text1.split(' ');
//     final words2 = text2.split(' ');
//     final minLen = min(words1.length, words2.length);
//     final maxLen = max(words1.length, words2.length);
//     int matches = 0;
//     for (int i = 0; i < minLen; i++) {
//       if (_wordsSimilar(words1[i], words2[i])) {
//         matches++;
//       }
//     }
//     return matches / maxLen;
//   }

//   /// Check if two words are similar (exact or close match)
//   bool _wordsSimilar(String word1, String word2) {
//     word1 = word1.toLowerCase().replaceAll(RegExp(r'[,.?!:;]'), '');
//     word2 = word2.toLowerCase().replaceAll(RegExp(r'[,.?!:;]'), '');
//     if (word1 == word2) return true;
//     if (word1.length < 4 || word2.length < 4) return false;
//     int sameChars = 0;
//     final len = min(word1.length, word2.length);
//     for (int i = 0; i < len; i++) {
//       if (word1[i] == word2[i]) {
//         sameChars++;
//       }
//     }
//     final maxLen = max(word1.length, word2.length);
//     return sameChars / maxLen > 0.7;
//   }

//   /// Check if text1 approximately contains text2
//   bool _isTextContained(String text1, String text2) {
//     if (text1.contains(text2)) return true;
//     final words1 = text1.split(' ');
//     final words2 = text2.split(' ');
//     if (words2.length > words1.length) return false;
//     for (int i = 0; i <= words1.length - words2.length; i++) {
//       final window = words1.sublist(i, i + words2.length);
//       final similarity = _calculateSimilarity(window, words2);
//       if (similarity > 0.8) {
//         return true;
//       }
//     }
//     return false;
//   }

//   /// Clean and normalize text for consistent matching
//   String _cleanText(String text) {
//     if (text.isEmpty) return '';
//     return text.replaceAll(RegExp(r'\s+'), ' ').trim();
//   }
// }

// /// Helper class to store overlap information
// class _OverlapResult {
//   final int existingPos;
//   final int overlapLength;
//   final double similarity;

//   _OverlapResult({
//     this.existingPos = 0,
//     this.overlapLength = 0,
//     this.similarity = 0.0,
//   });
// }
