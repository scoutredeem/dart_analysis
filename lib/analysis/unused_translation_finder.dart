import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:interact_cli/interact_cli.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'base_analyzer.dart';
import 'utils.dart';

/// Analyzer that finds and handles unused translation strings in a Flutter project
class UnusedTranslationFinder implements BaseAnalyzer {
  @override
  String get name => 'Unused translation finder';

  @override
  String get description =>
      'Find and optionally delete unused translation strings in your Flutter project';

  @override
  bool canAnalyze(String projectPath) {
    return AnalyzerUtils.isFlutterProject(projectPath) &&
        _hasLocalizationFiles(projectPath);
  }

  bool _hasLocalizationFiles(String projectPath) {
    // Check for l10n.yaml file first (Flutter standard)
    final l10nYamlFile = File(p.join(projectPath, 'l10n.yaml'));
    if (l10nYamlFile.existsSync()) {
      return true;
    }

    // Fallback: Look for common localization file patterns
    final libPath = p.join(projectPath, 'lib');
    if (!Directory(libPath).existsSync()) return false;

    final localizationPatterns = [
      '**/localization/*.arb',
      '**/l10n/*.arb',
      '**/i18n/*.arb',
      '**/app_*.arb',
      '**/localizations.arb',
    ];

    for (final pattern in localizationPatterns) {
      if (_hasFilesMatchingPattern(libPath, pattern)) {
        return true;
      }
    }

    return false;
  }

  bool _hasFilesMatchingPattern(String libPath, String pattern) {
    try {
      final dir = Directory(libPath);
      final entities = dir.listSync(recursive: true);

      for (final entity in entities) {
        if (entity is File && entity.path.endsWith('.arb')) {
          final relativePath = p.relative(entity.path, from: libPath);
          if (_matchesPattern(relativePath, pattern)) {
            return true;
          }
        }
      }
    } catch (e) {
      // Ignore errors
    }
    return false;
  }

  bool _matchesPattern(String path, String pattern) {
    // Simple pattern matching for common cases
    if (pattern == '**/localization/*.arb') {
      return path.contains('localization') && path.endsWith('.arb');
    } else if (pattern == '**/l10n/*.arb') {
      return path.contains('l10n') && path.endsWith('.arb');
    } else if (pattern == '**/i18n/*.arb') {
      return path.contains('i18n') && path.endsWith('.arb');
    } else if (pattern == '**/app_*.arb') {
      return path.contains('app_') && path.endsWith('.arb');
    } else if (pattern == '**/localizations.arb') {
      return path.endsWith('localizations.arb');
    }
    return false;
  }

  @override
  Future<void> analyze(String projectPath) async {
    if (!canAnalyze(projectPath)) {
      print(
        'Error: This project does not appear to be a Flutter project with localization files.',
      );
      exit(1);
    }

    final libPath = p.join(projectPath, 'lib');

    // Find all localization files
    final localizationFiles = findLocalizationFiles(libPath);
    if (localizationFiles.isEmpty) {
      print('No localization files found.');
      return;
    }

    print('Found localization files:');
    for (final file in localizationFiles) {
      print('  ${p.relative(file, from: projectPath)}');
    }

    // Find all translation keys
    final allTranslationKeys = <String>{};
    for (final file in localizationFiles) {
      allTranslationKeys.addAll(extractTranslationKeys(file));
    }

    if (allTranslationKeys.isEmpty) {
      print('No translation keys found in localization files.');
      return;
    }

    print('\nFound ${allTranslationKeys.length} translation keys.');

    // Find all Dart files to analyze for usage
    final allDartFiles = getAllDartFiles(libPath);

    // Find used translation keys
    final usedKeys = findUsedTranslationKeys(allDartFiles, allTranslationKeys);
    final unusedKeys = allTranslationKeys.difference(usedKeys);

    if (unusedKeys.isEmpty) {
      print('No unused translation keys found.');
    } else {
      print('\nUnused translation keys:');
      final sortedUnusedKeys = unusedKeys.toList()..sort();
      for (final key in sortedUnusedKeys) {
        print('  $key');
      }

      final deleteChoice = Confirm(
        prompt: 'Do you want to remove these unused translation keys?',
        defaultValue: false,
      ).interact();

      if (deleteChoice) {
        _removeUnusedTranslationKeys(
          localizationFiles,
          unusedKeys,
          projectPath,
        );
      } else {
        print('No translation keys were removed.');
      }
    }
  }

  /// Find all localization files in the project using l10n.yaml configuration
  Set<String> findLocalizationFiles(String libPath) {
    final files = <String>{};
    final projectPath = p.dirname(libPath);

    try {
      // First try to use l10n.yaml configuration
      final l10nYamlFile = File(p.join(projectPath, 'l10n.yaml'));
      if (l10nYamlFile.existsSync()) {
        final l10nConfig = _parseL10nYaml(l10nYamlFile);
        if (l10nConfig != null) {
          final arbDir = l10nConfig['arb-dir'] as String?;
          if (arbDir != null) {
            final arbDirPath = p.join(projectPath, arbDir);
            if (Directory(arbDirPath).existsSync()) {
              // Find all .arb files in the configured directory
              final arbDirEntity = Directory(arbDirPath);
              for (final entity in arbDirEntity.listSync()) {
                if (entity is File && entity.path.endsWith('.arb')) {
                  files.add(p.normalize(p.absolute(entity.path)));
                }
              }
              return files;
            }
          }
        }
      }

      // Fallback: search for ARB files manually
      final dir = Directory(libPath);
      final entities = dir.listSync(recursive: true);

      for (final entity in entities) {
        if (entity is File && entity.path.endsWith('.arb')) {
          final relativePath = p.relative(entity.path, from: libPath);
          if (_isLocalizationFile(relativePath)) {
            files.add(p.normalize(p.absolute(entity.path)));
          }
        }
      }
    } catch (e) {
      print('Warning: Could not read lib directory: $e');
    }

    return files;
  }

  /// Check if a file is a localization file
  bool _isLocalizationFile(String relativePath) {
    return relativePath.contains('localization') ||
        relativePath.contains('l10n') ||
        relativePath.contains('i18n') ||
        relativePath.contains('app_') ||
        relativePath.endsWith('localizations.arb') ||
        relativePath.endsWith('.arb');
  }

  /// Parse l10n.yaml configuration file
  Map<String, dynamic>? _parseL10nYaml(File l10nYamlFile) {
    try {
      final content = l10nYamlFile.readAsStringSync();

      // Simple YAML parsing for the common l10n.yaml structure
      final config = <String, dynamic>{};

      for (final line in content.split('\n')) {
        final trimmedLine = line.trim();
        if (trimmedLine.isEmpty || trimmedLine.startsWith('#')) continue;

        if (trimmedLine.contains(':')) {
          final parts = trimmedLine.split(':');
          if (parts.length >= 2) {
            final key = parts[0].trim();
            final value = parts.sublist(1).join(':').trim();

            // Handle boolean values
            if (value == 'true') {
              config[key] = true;
            } else if (value == 'false') {
              config[key] = false;
            } else {
              config[key] = value;
            }
          }
        }
      }

      return config;
    } catch (e) {
      print('Warning: Could not parse l10n.yaml: $e');
      return null;
    }
  }

  /// Extract translation keys from an ARB file
  Set<String> extractTranslationKeys(String filePath) {
    final keys = <String>{};

    try {
      final content = File(filePath).readAsStringSync();

      // Parse JSON/ARB content to extract translation keys
      // Look for "keyName": "value" patterns (excluding metadata keys that start with @)
      // Also exclude keys that are just metadata properties like "description", "placeholders", etc.
      final keyPattern = RegExp(r'"([^"@][^"]*)"\s*:\s*"[^"]*"');
      for (final match in keyPattern.allMatches(content)) {
        final key = match.group(1);
        if (key != null && !key.startsWith('@')) {
          // Check if this key is actually a translation key (not a metadata property)
          if (isTranslationKey(content, key)) {
            keys.add(key);
          }
        }
      }
    } catch (e) {
      print('Warning: Could not read file $filePath: $e');
    }

    return keys;
  }

  /// Check if a key is actually a translation key (not a metadata property)
  bool isTranslationKey(String content, String key) {
    // Common metadata properties that should not be considered translation keys
    final metadataProperties = [
      'description',
      'placeholders',
      'context',
      'meaning',
      'example',
      'sourceLocale',
      'isObsolete',
      'requiredResourceAttributes',
    ];

    // If it's a known metadata property, it's not a translation key
    if (metadataProperties.contains(key)) {
      return false;
    }

    // Check if this key appears in a metadata context (inside @keyName blocks)
    // If it does, it's likely a metadata property, not a translation key
    final metadataContextPattern = RegExp(
      '"@[^"]*"\\s*:\\s*\\{[^}]*"$key"\\s*:',
    );
    if (metadataContextPattern.hasMatch(content)) {
      return false;
    }

    return true;
  }

  /// Get all Dart files in the lib directory
  Set<String> getAllDartFiles(String libPath) {
    return AnalyzerUtils.getAllFilesRecursively(
      Directory(libPath),
      extensions: ['.dart'],
    );
  }

  /// Find which translation keys are actually used in the code
  Set<String> findUsedTranslationKeys(
    Set<String> dartFiles,
    Set<String> allKeys,
  ) {
    final usedKeys = <String>{};

    for (final filePath in dartFiles) {
      try {
        final content = File(filePath).readAsStringSync();

        // Use comprehensive regex-based detection for reliability
        for (final key in allKeys) {
          if (isKeyUsedInContent(content, key)) {
            usedKeys.add(key);
          }
        }
      } catch (e) {
        // Ignore files that can't be read
        print('Warning: Could not read file $filePath: $e');
      }
    }

    return usedKeys;
  }

  /// Extract all identifiers from the AST
  void _extractIdentifiers(AstNode node, Set<String> identifiers) {
    if (node is Identifier) {
      identifiers.add(node.name);
    }

    for (final child in node.childEntities) {
      if (child is AstNode) {
        _extractIdentifiers(child, identifiers);
      }
    }
  }

  /// Check if a key usage looks like a translation key usage
  bool _isTranslationKeyUsage(String content, String key) {
    // Look for the key in context that suggests translation usage
    final patterns = [
      RegExp('AppLocalizations\\.of\\([^)]+\\)\\.$key\\b'),
      RegExp('AppLocalizations\\.of\\([^)]+\\)\\?\\.$key\\b'),
      RegExp('context\\.translation\\.$key\\b'),
      RegExp('context\\.tr\\.$key\\b'),
      RegExp('\\btr\\.$key\\b'),
    ];

    for (final pattern in patterns) {
      if (pattern.hasMatch(content)) {
        return true;
      }
    }

    return false;
  }

  /// Check if a translation key is used in the given content
  bool isKeyUsedInContent(String content, String key) {
    // Look for various usage patterns
    final patterns = [
      // AppLocalizations.of(context).keyName
      RegExp('AppLocalizations\\.of\\([^)]+\\)\\.$key\\b'),
      // AppLocalizations.of(context)?.keyName (nullable access)
      RegExp('AppLocalizations\\.of\\([^)]+\\)\\?\\.$key\\b'),
      // context.translation.keyName (extension method - property access)
      RegExp('context\\s*\\.\\s*translation\\s*\\.\\s*$key\\b', dotAll: true),
      // context.translation.keyName() (extension method - method call)
      RegExp(
        'context\\.translation\\s*\\.\\s*$key\\s*\\([^)]*\\)',
        dotAll: true,
      ),
      // context.localizations.keyName
      RegExp('context\\.localizations\\.$key\\b'),
      // localizations.keyName
      RegExp('localizations\\.$key\\b'),
      // l10n.keyName
      RegExp('l10n\\.$key\\b'),
      // S.of(context).keyName
      RegExp('S\\.of\\([^)]+\\)\\.$key\\b'),
      // S.current.keyName
      RegExp('S\\.current\\.$key\\b'),
      // context.tr.keyName (extension method)
      RegExp('context\\.tr\\.$key\\b'),
      // tr.keyName (when tr is a variable)
      RegExp('\\btr\\.$key\\b'),
    ];

    for (final pattern in patterns) {
      if (pattern.hasMatch(content)) {
        return true;
      }
    }

    return false;
  }

  /// Remove unused translation keys from ARB files and regenerate Dart files
  void _removeUnusedTranslationKeys(
    Set<String> localizationFiles,
    Set<String> unusedKeys,
    String projectPath,
  ) {
    int removedCount = 0;

    for (final filePath in localizationFiles) {
      try {
        final content = File(filePath).readAsStringSync();
        final originalContent = content;

        // Remove unused keys from the ARB content
        var modifiedContent = content;
        for (final key in unusedKeys) {
          modifiedContent = removeKeyFromArbContent(modifiedContent, key);
        }

        // Only write if content changed
        if (modifiedContent != originalContent) {
          File(filePath).writeAsStringSync(modifiedContent);
          print('Updated ARB file: ${p.relative(filePath, from: projectPath)}');
          removedCount++;
        }
      } catch (e) {
        print(
          'Failed to update: ${p.relative(filePath, from: projectPath)} - $e',
        );
      }
    }

    if (removedCount > 0) {
      print('\nRegenerating localization files...');
      _regenerateLocalizationFiles(projectPath);
    }

    print('Translation files updated: $removedCount');
  }

  /// Remove a specific key from ARB content
  String removeKeyFromArbContent(String content, String key) {
    try {
      // Parse the content as JSON to handle complex structures properly
      final Map<String, dynamic> jsonData = json.decode(content);

      // Remove the key and its metadata
      jsonData.remove(key);
      jsonData.remove('@$key');

      // Convert back to JSON with proper formatting
      final encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(jsonData);
    } catch (e) {
      // Fallback to regex-based approach if JSON parsing fails
      print('Warning: JSON parsing failed, falling back to regex: $e');
      return _removeKeyFromArbContentRegex(content, key);
    }
  }

  /// Fallback regex-based removal method
  String _removeKeyFromArbContentRegex(String content, String key) {
    // First, find and remove the key-value pair
    final keyPattern = RegExp('\\s*"$key"\\s*:\\s*"[^"]*",?\\s*');
    var result = content.replaceAll(keyPattern, '');

    // Then remove the metadata block if it exists
    result = _removeMetadataBlock(result, key);

    // Clean up the JSON structure
    result = cleanupArbContent(result);

    return result;
  }

  /// Remove the metadata block for a specific key
  String _removeMetadataBlock(String content, String key) {
    final metadataPattern = RegExp(
      '\\s*"@$key"\\s*:\\s*\\{[^}]*\\},?\\s*',
      dotAll: true,
    );
    return content.replaceAll(metadataPattern, '');
  }

  /// Clean up ARB content after removing keys
  String cleanupArbContent(String content) {
    // Remove multiple consecutive empty lines
    content = content.replaceAll(RegExp(r'\n\s*\n\s*\n'), '\n\n');

    // Remove trailing commas before closing braces
    content = content.replaceAll(RegExp(r',\s*}'), '}');
    content = content.replaceAll(RegExp(r',\s*]'), ']');

    // Fix missing commas between properties
    content = content.replaceAll(RegExp(r'}\s*\n\s*"'), '},\n  "');
    content = content.replaceAll(RegExp(r'"\s*\n\s*"'), '",\n  "');

    // Remove empty lines between properties
    content = content.replaceAll(RegExp(r'\n\s*\n'), '\n');

    // Clean up any double commas
    content = content.replaceAll(RegExp(r',\s*,+'), ',');

    return content;
  }

  /// Regenerate localization files using Flutter's localization generation
  void _regenerateLocalizationFiles(String projectPath) {
    try {
      print('Regenerating localization files...');

      // Change to the project directory
      final originalDir = Directory.current.path;
      Directory.current = projectPath;

      // First run flutter pub get to ensure dependencies are up to date
      print('Running flutter pub get...');
      var result = Process.runSync('flutter', ['pub', 'get']);

      if (result.exitCode != 0) {
        print(
          'Warning: flutter pub get failed with exit code ${result.exitCode}',
        );
        if (result.stderr.isNotEmpty) {
          print('Error: ${result.stderr}');
        }
        return;
      }

      // Then run flutter gen-l10n to regenerate localization files
      print('Running flutter gen-l10n...');
      result = Process.runSync('flutter', ['gen-l10n']);

      if (result.exitCode == 0) {
        print('Successfully regenerated localization files.');
      } else {
        print(
          'Warning: flutter gen-l10n failed with exit code ${result.exitCode}',
        );
        if (result.stderr.isNotEmpty) {
          print('Error: ${result.stderr}');
        }
        print(
          'Please run "flutter gen-l10n" manually in the project directory.',
        );
      }

      // Restore original directory
      Directory.current = originalDir;
    } catch (e) {
      print('Error regenerating localization files: $e');
      print(
        'Please run "flutter gen-l10n" manually in the project directory to regenerate localization files.',
      );
    }
  }
}
