#!/usr/bin/env dart

import 'dart:io';
import 'package:dart_analysis/analysis/unused_file_finder.dart';
import 'package:interact_cli/interact_cli.dart';

void main(List<String> arguments) async {
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
