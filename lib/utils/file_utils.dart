import 'dart:io';
import 'package:path/path.dart' as p;

class FileUtils {
  static Future<bool> validateDirectory(String path) async {
    final dir = Directory(path);
    if (!await dir.exists()) {
      return false;
    }
    return true;
  }

  static Future<void> ensureDirectoryExists(String path) async {
    final dir = Directory(path);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
  }

  static List<File> findFilesByExtension(Directory directory, String extension, {bool recursive = true}) {
    return directory
        .listSync(recursive: recursive)
        .whereType<File>()
        .where((file) => p.extension(file.path).toLowerCase() == extension.toLowerCase())
        .toList();
  }

  static Future<Map<String, List<File>>> groupMatchingFiles(Directory directory, List<String> extensions) async {
    final Map<String, List<File>> groups = {};
    
    for (final ext in extensions) {
      groups[ext] = findFilesByExtension(directory, ext);
    }

    return groups;
  }

  static String getRelativePath(String fullPath, String basePath) {
    return p.relative(fullPath, from: basePath);
  }

  static Future<bool> isDirectoryEmpty(String path) async {
    final dir = Directory(path);
    if (!await dir.exists()) {
      return true;
    }
    return await dir.list().isEmpty;
  }

  static String sanitizeFilename(String filename) {
    // Remove or replace characters that might be problematic in filenames
    return filename
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), '_');
  }

  static Future<void> copyDirectory(String source, String destination) async {
    final sourceDir = Directory(source);
    final destDir = Directory(destination);

    if (!await sourceDir.exists()) {
      throw Exception('Source directory does not exist: $source');
    }

    if (!await destDir.exists()) {
      await destDir.create(recursive: true);
    }

    await for (final entity in sourceDir.list(recursive: false)) {
      if (entity is Directory) {
        final newDestDir = Directory(p.join(destination, p.basename(entity.path)));
        await copyDirectory(entity.path, newDestDir.path);
      } else if (entity is File) {
        final newDestFile = File(p.join(destination, p.basename(entity.path)));
        await entity.copy(newDestFile.path);
      }
    }
  }

  static Future<void> cleanDirectory(String path, {bool deleteDirectory = false}) async {
    final directory = Directory(path);
    if (await directory.exists()) {
      await for (final entity in directory.list(recursive: true)) {
        await entity.delete(recursive: true);
      }
      if (deleteDirectory) {
        await directory.delete(recursive: true);
      }
    }
  }

  static bool isSubdirectoryOf(String parent, String child) {
    final parentDir = Directory(parent);
    final childDir = Directory(child);
    
    final parentPath = parentDir.absolute.path;
    final childPath = childDir.absolute.path;
    
    return childPath.startsWith(parentPath) && childPath != parentPath;
  }
}