import 'dart:io';

/// Base interface for all analyzers in the dart_analysis tool
abstract class BaseAnalyzer {
  /// The name of this analyzer
  String get name;

  /// A description of what this analyzer does
  String get description;

  /// Run the analysis on the given project path
  Future<void> analyze(String projectPath);

  /// Check if this analyzer can run on the given project
  bool canAnalyze(String projectPath);
}
