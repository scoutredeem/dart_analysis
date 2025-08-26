import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:interact_cli/interact_cli.dart';
import 'base_analyzer.dart';
import 'utils.dart';

/// Analyzer that finds and handles unused Dart files in a project
class UnusedFileFinder implements BaseAnalyzer {
  @override
  String get name => 'Unused file finder';

  @override
  String get description =>
      'Find and optionally delete unused Dart files in your project';

  @override
  bool canAnalyze(String projectPath) {
    final libPath = p.join(projectPath, 'lib');
    return Directory(libPath).existsSync();
  }

  @override
  Future<void> analyze(String projectPath) async {
    final libPath = p.join(projectPath, 'lib');

    if (!canAnalyze(projectPath)) {
      print('Error: lib directory not found in the specified project path.');
      exit(1);
    }

    // Read package name from the TARGET project's pubspec.yaml
    final packageName = getPackageName(projectPath);
    if (packageName == null) {
      print(
        'Error: Could not determine package name from target project pubspec.yaml.',
      );
      exit(1);
    }

    final allDartFiles = getAllDartFiles(libPath);
    final usedFiles = _findUsedFiles(projectPath, libPath, packageName);
    final unusedFiles = allDartFiles.difference(usedFiles);

    _handleUnusedFiles(unusedFiles, projectPath);
  }

  /// Get package name from pubspec.yaml
  String? getPackageName(String projectPath) {
    return AnalyzerUtils.getPackageName(projectPath);
  }

  /// Get all Dart files in the lib directory
  Set<String> getAllDartFiles(String libPath) {
    return Directory(libPath)
        .listSync(recursive: true)
        .where((entity) => entity is File && entity.path.endsWith('.dart'))
        .map((entity) => p.normalize(p.absolute(entity.path)))
        .toSet();
  }

  /// Find all used files by analyzing imports
  Set<String> _findUsedFiles(
    String projectPath,
    String libPath,
    String packageName,
  ) {
    final pubspecFile = File(p.join(projectPath, 'pubspec.yaml'));
    final pubspecContent = pubspecFile.readAsStringSync();

    final allDartFiles = getAllDartFiles(libPath);
    final usedFiles = <String>{};

    // Start analysis from main.dart or other entry points if specified
    final entryPoints = findEntryPoints(allDartFiles, libPath, pubspecContent);
    if (entryPoints.isEmpty) {
      print(
        'Error: No entry point found. Could not determine the main.dart file.',
      );
      exit(1);
    }

    for (final entryPoint in entryPoints) {
      _traverseUsedFiles(
        p.normalize(p.absolute(entryPoint)),
        usedFiles,
        libPath,
        packageName,
      );
    }

    return usedFiles;
  }

  /// Find entry points for analysis
  List<String> findEntryPoints(
    Set<String> allDartFiles,
    String libPath,
    String pubspecContent,
  ) {
    final entryPoints = allDartFiles
        .where((file) => p.basename(file) == 'main.dart')
        .toList();

    if (entryPoints.isEmpty) {
      if (pubspecContent.contains('flutter:')) {
        // Flutter project, assume lib/main.dart is the entry point
        final mainDart = p.join(libPath, 'main.dart');
        if (File(mainDart).existsSync()) {
          entryPoints.add(mainDart);
        }
      }
    }

    return entryPoints;
  }

  /// Traverse and find all used files recursively
  void _traverseUsedFiles(
    String filePath,
    Set<String> usedFiles,
    String libPath,
    String packageName,
  ) {
    filePath = p.normalize(p.absolute(filePath));
    if (!usedFiles.add(filePath)) {
      return;
    }

    final fileContent = File(filePath).readAsStringSync();
    final result = parseString(content: fileContent, throwIfDiagnostics: false);
    final compilationUnit = result.unit;

    for (final directive in compilationUnit.directives) {
      if (directive is ImportDirective) {
        final uri = directive.uri.stringValue;
        if (uri != null && !uri.startsWith('dart:')) {
          final importedFilePath = resolveUri(
            uri,
            filePath,
            libPath,
            packageName,
          );
          if (importedFilePath != null) {
            _traverseUsedFiles(
              importedFilePath,
              usedFiles,
              libPath,
              packageName,
            );
          }
        }
      }
    }
  }

  /// Resolve import URIs to file paths
  String? resolveUri(
    String uri,
    String fromFile,
    String libPath,
    String packageName,
  ) {
    if (uri.startsWith('package:')) {
      // Example: package:my_package/src/foo.dart
      final match = RegExp(r'^package:([^/]+)/(.*)').firstMatch(uri);
      if (match != null && match.group(1) == packageName) {
        final relativePath = match.group(2)!;
        final absolutePath = p.normalize(
          p.absolute(p.join(libPath, relativePath)),
        );
        if (File(absolutePath).existsSync()) {
          return absolutePath;
        }
      }
      return null;
    } else {
      final fromDir = p.dirname(fromFile);
      final absolutePath = p.normalize(p.absolute(p.join(fromDir, uri)));
      if (File(absolutePath).existsSync()) {
        return absolutePath;
      }
    }
    return null;
  }

  /// Handle the unused files (show results and optionally delete)
  void _handleUnusedFiles(Set<String> unusedFiles, String projectPath) {
    // Filter out .g.dart files whose parent files are not unused
    final filteredUnusedFiles = filterGeneratedFiles(unusedFiles);

    if (filteredUnusedFiles.isEmpty) {
      print('No unused files found.');
    } else {
      print('Unused files:');
      final relativeUnused = AnalyzerUtils.formatFilePaths(
        filteredUnusedFiles,
        projectPath,
      );
      for (final file in relativeUnused) {
        print(file);
      }

      final deleteChoice = Confirm(
        prompt: 'Do you want to delete these unused files?',
        defaultValue: false,
      ).interact();

      if (deleteChoice) {
        _deleteUnusedFiles(filteredUnusedFiles, projectPath);
      } else {
        print('No files were deleted.');
      }
    }
  }

  /// Filter out .g.dart files whose parent files are not unused
  Set<String> filterGeneratedFiles(Set<String> unusedFiles) {
    final filteredFiles = <String>{};

    for (final file in unusedFiles) {
      if (file.endsWith('.g.dart')) {
        // For .g.dart files, check if their parent file is also unused
        final parentFile = findParentFile(file);
        if (parentFile != null && unusedFiles.contains(parentFile)) {
          // Only include .g.dart file if its parent is also unused
          filteredFiles.add(file);
        }
        // If parent is not unused, skip this .g.dart file
      } else {
        // Non-generated files are included as-is
        filteredFiles.add(file);
      }
    }

    return filteredFiles;
  }

  /// Find the parent file for a generated .g.dart file
  String? findParentFile(String generatedFilePath) {
    try {
      final file = File(generatedFilePath);
      if (!file.existsSync()) return null;

      final content = file.readAsStringSync();

      // Look for 'part of' directive to find the parent file
      if (content.contains('part of')) {
        final lines = content.split('\n');

        for (final line in lines) {
          if (line.trim().startsWith('part of')) {
            // Extract the filename from the part of directive
            final trimmedLine = line.trim();

            // Try single quotes first
            var startQuote = trimmedLine.indexOf("'");
            var endQuote = trimmedLine.lastIndexOf("'");

            // If no single quotes, try double quotes
            if (startQuote == -1) {
              startQuote = trimmedLine.indexOf('"');
              endQuote = trimmedLine.lastIndexOf('"');
            }

            if (startQuote != -1 && endQuote != -1 && startQuote < endQuote) {
              final parentFileName = trimmedLine.substring(
                startQuote + 1,
                endQuote,
              );

              if (parentFileName.isNotEmpty) {
                // Resolve the parent file path relative to the generated file's directory
                final generatedDir = p.dirname(generatedFilePath);
                final parentPath = p.join(generatedDir, parentFileName);
                final absoluteParentPath = p.normalize(p.absolute(parentPath));

                // Check if the parent file exists
                if (File(absoluteParentPath).existsSync()) {
                  return absoluteParentPath;
                }
              }
            }
            break;
          }
        }
      }
    } catch (e) {
      // If there's any error reading or parsing the file, return null
      print('Warning: Could not parse generated file $generatedFilePath: $e');
    }

    return null;
  }

  /// Delete the unused files
  void _deleteUnusedFiles(Set<String> unusedFiles, String projectPath) {
    int deletedCount = 0;
    for (final file in unusedFiles) {
      if (AnalyzerUtils.deleteFile(file, projectPath)) {
        deletedCount++;
      }
    }
    print('Unused files deleted: $deletedCount');
  }
}

/// Legacy function for backward compatibility
@Deprecated('Use UnusedFileFinder().analyze() instead')
Future<void> findAndHandleUnusedFiles(String projectPath) async {
  final finder = UnusedFileFinder();
  await finder.analyze(projectPath);
}
