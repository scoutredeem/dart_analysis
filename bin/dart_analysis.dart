#!/usr/bin/env dart

import 'dart:io';
import 'package:dart_analysis/analysis/unused_file_finder.dart';
import 'package:interact_cli/interact_cli.dart';
import 'package:path/path.dart' as p;

void main(List<String> arguments) async {
  // Version flag support (check anywhere in arguments)
  if (arguments.any((arg) => arg == '-v' || arg == '--version')) {
    final pubspecFile = File(
      p.join(p.dirname(Platform.script.toFilePath()), '..', 'pubspec.yaml'),
    );
    if (pubspecFile.existsSync()) {
      final pubspecContent = pubspecFile.readAsStringSync();
      final versionMatch = RegExp(
        r'^version:\s*(\S+)',
        multiLine: true,
      ).firstMatch(pubspecContent);
      final version = versionMatch != null ? versionMatch.group(1) : 'unknown';
      print('dart_analysis version $version');
    } else {
      print('dart_analysis version unknown');
    }
    exit(0);
  }

  if (arguments.isEmpty) {
    print('Usage: dart run bin/dart_analysis.dart <path_to_project>');
    exit(1);
  }

  print('Dart Analysis Tool');
  final options = [
    'Unused file finder',
    // Add more options here in the future
  ];
  final selected = Select(
    prompt: 'Select an analysis option:',
    options: options,
    initialIndex: 0,
  ).interact();

  final projectPath = arguments.first;

  switch (selected) {
    case 0:
      await findAndHandleUnusedFiles(projectPath);
      break;
    // Add more cases for future options
    default:
      print('Invalid choice or feature not implemented yet.');
      exit(1);
  }
}
