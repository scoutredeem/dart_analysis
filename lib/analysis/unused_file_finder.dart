import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:interact_cli/interact_cli.dart';

/// Finds and handles unused Dart files in the given project path.
Future<void> findAndHandleUnusedFiles(String projectPath) async {
  final libPath = p.join(projectPath, 'lib');

  if (!Directory(libPath).existsSync()) {
    print('Error: lib directory not found in the specified project path.');
    exit(1);
  }

  // Read package name from the TARGET project's pubspec.yaml
  final pubspecFile = File(p.join(projectPath, 'pubspec.yaml'));
  final pubspecContent = pubspecFile.readAsStringSync();
  final packageNameMatch = RegExp(
    r'^name:\s*(\S+)',
    multiLine: true,
  ).firstMatch(pubspecContent);
  final packageName = packageNameMatch?.group(1);
  if (packageName == null) {
    print(
      'Error: Could not determine package name from target project pubspec.yaml.',
    );
    exit(1);
  }

  final allDartFiles = Directory(libPath)
      .listSync(recursive: true)
      .where((entity) => entity is File && entity.path.endsWith('.dart'))
      .map((entity) => p.normalize(p.absolute(entity.path)))
      .toSet();

  final usedFiles = <String>{};

  // Start analysis from main.dart or other entry points if specified
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

  if (entryPoints.isEmpty) {
    print(
      'Error: No entry point found. Could not determine the main.dart file.',
    );
    exit(1);
  }

  for (final entryPoint in entryPoints) {
    _findUsedFiles(
      p.normalize(p.absolute(entryPoint)),
      usedFiles,
      libPath,
      packageName,
    );
  }

  final unusedFiles = allDartFiles.difference(usedFiles);

  if (unusedFiles.isEmpty) {
    print('No unused files found.');
  } else {
    print('Unused files:');
    final relativeUnused = unusedFiles
        .map((file) => p.relative(file, from: projectPath))
        .toList();
    for (final file in relativeUnused) {
      print(file);
    }
    final deleteChoice = Confirm(
      prompt: 'Do you want to delete these unused files?',
      defaultValue: false,
    ).interact();
    if (deleteChoice) {
      for (final file in unusedFiles) {
        try {
          File(file).deleteSync();
          print('Deleted: ${p.relative(file, from: projectPath)}');
        } catch (e) {
          print(
            'Failed to delete: ${p.relative(file, from: projectPath)} ( [31m$e [0m)',
          );
        }
      }
      print('Unused files deleted.');
    } else {
      print('No files were deleted.');
    }
  }
}

void _findUsedFiles(
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
        final importedFilePath = _resolveUri(
          uri,
          filePath,
          libPath,
          packageName,
        );
        if (importedFilePath != null) {
          _findUsedFiles(importedFilePath, usedFiles, libPath, packageName);
        }
      }
    }
  }
}

String? _resolveUri(
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
