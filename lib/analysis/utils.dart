import 'dart:io';
import 'package:path/path.dart' as p;

/// Common utilities for analyzers
class AnalyzerUtils {
  /// Get package name from pubspec.yaml
  static String? getPackageName(String projectPath) {
    final pubspecFile = File(p.join(projectPath, 'pubspec.yaml'));
    if (!pubspecFile.existsSync()) return null;

    final pubspecContent = pubspecFile.readAsStringSync();
    final packageNameMatch = RegExp(
      r'^name:\s*(\S+)',
      multiLine: true,
    ).firstMatch(pubspecContent);

    return packageNameMatch?.group(1);
  }

  /// Check if project is a Flutter project
  static bool isFlutterProject(String projectPath) {
    final pubspecFile = File(p.join(projectPath, 'pubspec.yaml'));
    if (!pubspecFile.existsSync()) return false;

    final pubspecContent = pubspecFile.readAsStringSync();
    return pubspecContent.contains('flutter:');
  }

  /// Get all files recursively from a directory with error handling
  static Set<String> getAllFilesRecursively(
    Directory dir, {
    List<String>? extensions,
  }) {
    final files = <String>{};

    try {
      for (final entity in dir.listSync(recursive: true)) {
        if (entity is File) {
          if (extensions == null ||
              extensions.any((ext) => entity.path.endsWith(ext))) {
            files.add(p.normalize(p.absolute(entity.path)));
          }
        }
      }
    } catch (e) {
      // Ignore permission errors or other issues
      print('Warning: Could not read directory ${dir.path}: $e');
    }

    return files;
  }

  /// Get files by extension from a directory
  static Set<String> getFilesByExtension(Directory dir, String extension) {
    return getAllFilesRecursively(dir, extensions: [extension]);
  }

  /// Safely delete a file with error handling
  static bool deleteFile(String filePath, String projectPath) {
    try {
      File(filePath).deleteSync();
      print('Deleted: ${p.relative(filePath, from: projectPath)}');
      return true;
    } catch (e) {
      print(
        'Failed to delete: ${p.relative(filePath, from: projectPath)} ( [31m$e [0m)',
      );
      return false;
    }
  }

  /// Format file paths for display (relative to project)
  static List<String> formatFilePaths(Set<String> files, String projectPath) {
    return files.map((file) => p.relative(file, from: projectPath)).toList()
      ..sort(); // Sort for consistent output
  }

  /// Check if a file exists and is readable
  static bool isFileReadable(String filePath) {
    try {
      final file = File(filePath);
      return file.existsSync();
    } catch (e) {
      return false;
    }
  }

  /// Get common asset directories
  static List<String> getCommonAssetDirectories() {
    return [
      'assets',
      'images',
      'icons',
      'fonts',
      'audio',
      'video',
      'data',
      'resources',
      'static',
    ];
  }

  /// Get common image extensions
  static List<String> getCommonImageExtensions() {
    return [
      '.png',
      '.jpg',
      '.jpeg',
      '.gif',
      '.svg',
      '.webp',
      '.bmp',
      '.tiff',
      '.ico',
    ];
  }

  /// Get common font extensions
  static List<String> getCommonFontExtensions() {
    return ['.ttf', '.otf', '.woff', '.woff2', '.eot'];
  }
}
