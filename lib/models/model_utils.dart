// Copy the asset file from src to dst
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

Future<String> copyAssetFile(String? modelName, String file) async {
  final Directory directory = await getApplicationDocumentsDirectory();
  final target = modelName == null
      ? p.join(directory.path, file)
      : p.join(directory.path, modelName, file);
  bool exists = await File(target).exists();
  if (!exists) {
    await File(target).create(recursive: true);
  }
  final data = modelName == null
      ? await rootBundle.load(p.join('assets', 'models', file))
      : await rootBundle.load(p.join('assets', 'models', modelName, file));
  if (!exists || File(target).lengthSync() != data.lengthInBytes) {
    final List<int> bytes =
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    await File(target).writeAsBytes(bytes);
  }

  return target;
}
