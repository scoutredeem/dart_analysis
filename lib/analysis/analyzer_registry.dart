import 'base_analyzer.dart';
import 'unused_file_finder.dart';
import 'unused_translation_finder.dart';

/// Registry for all available analyzers
class AnalyzerRegistry {
  static final List<BaseAnalyzer> _analyzers = [
    UnusedFileFinder(),
    UnusedTranslationFinder(),
  ];

  /// Get all available analyzers
  static List<BaseAnalyzer> get analyzers => List.unmodifiable(_analyzers);

  /// Get analyzer by index
  static BaseAnalyzer? getAnalyzer(int index) {
    if (index >= 0 && index < _analyzers.length) {
      return _analyzers[index];
    }
    return null;
  }

  /// Get analyzer by name
  static BaseAnalyzer? getAnalyzerByName(String name) {
    try {
      return _analyzers.firstWhere((analyzer) => analyzer.name == name);
    } catch (e) {
      return null;
    }
  }

  /// Get available options for the CLI
  static List<String> getOptions() {
    return _analyzers.map((analyzer) => analyzer.name).toList();
  }

  /// Get analyzer descriptions for the CLI
  static List<String> getDescriptions() {
    return _analyzers.map((analyzer) => analyzer.description).toList();
  }

  /// Check if an analyzer can run on the given project
  static List<bool> getCanAnalyzeResults(String projectPath) {
    return _analyzers
        .map((analyzer) => analyzer.canAnalyze(projectPath))
        .toList();
  }
}
