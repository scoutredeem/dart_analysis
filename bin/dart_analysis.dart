#!/usr/bin/env dart

import 'dart:io';
import 'package:dart_analysis/analysis.dart';
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

  // Help flag support
  if (arguments.any((arg) => arg == '-h' || arg == '--help')) {
    print('Dart Analysis Tool');
    print('');
    print('Usage: dart_analysis <path_to_project>');
    print('');
    print('Options:');
    print('  -h, --help     Show this help message');
    print('  -v, --version  Show version information');
    print('');
    print('Examples:');
    print('  dart_analysis /path/to/flutter/project');
    print('  dart_analysis .');
    exit(0);
  }

  if (arguments.isEmpty) {
    print('Usage: dart_analysis <path_to_project>');
    print('Use --help for more information');
    exit(1);
  }

  final projectPath = arguments.first;

  // Check if project path exists
  if (!Directory(projectPath).existsSync()) {
    print('Error: Project path does not exist: $projectPath');
    exit(1);
  }

  print('Dart Analysis Tool');
  print('Analyzing project: ${p.basename(projectPath)}');

  // Get available analyzers and check which ones can run
  final options = AnalyzerRegistry.getOptions();
  final descriptions = AnalyzerRegistry.getDescriptions();
  final canAnalyzeResults = AnalyzerRegistry.getCanAnalyzeResults(projectPath);

  // Filter options to only show analyzers that can run on this project
  final availableOptions = <String>[];
  final availableDescriptions = <String>[];
  final availableIndices = <int>[];

  for (int i = 0; i < options.length; i++) {
    if (canAnalyzeResults[i]) {
      availableOptions.add(options[i]);
      availableDescriptions.add(descriptions[i]);
      availableIndices.add(i);
    }
  }

  if (availableOptions.isEmpty) {
    print('No analyzers available for this project type.');
    print('Make sure this is a valid Dart/Flutter project.');
    exit(1);
  }

  // Show available options with descriptions
  print('\nAvailable analysis options:');
  for (int i = 0; i < availableOptions.length; i++) {
    print('${i + 1}. ${availableOptions[i]} - ${availableDescriptions[i]}');
  }

  final selected = Select(
    prompt: 'Select an analysis option:',
    options: availableOptions,
    initialIndex: 0,
  ).interact();

  // Get the actual analyzer index from the registry
  final analyzerIndex = availableIndices[selected];
  final analyzer = AnalyzerRegistry.getAnalyzer(analyzerIndex);

  if (analyzer == null) {
    print('Error: Selected analyzer not found.');
    exit(1);
  }

  print('\nRunning: ${analyzer.name}');
  print('Description: ${analyzer.description}');

  try {
    await analyzer.analyze(projectPath);
  } catch (e) {
    print('Error during analysis: $e');
    exit(1);
  }
}
