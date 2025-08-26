import 'dart:io';
import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:path/path.dart' as path;
import 'base_analyzer.dart';

/// Analyzer that finds packages declared in pubspec.yaml that are never used
class UnusedPackageFinder implements BaseAnalyzer {
  @override
  String get name => 'Unused package finder';

  @override
  String get description =>
      'Finds packages declared in pubspec.yaml that are never used';

  @override
  bool canAnalyze(String projectPath) {
    final pubspecFile = File(path.join(projectPath, 'pubspec.yaml'));
    return pubspecFile.existsSync();
  }

  @override
  Future<void> analyze(String projectPath) async {
    print('🔍 Analyzing unused packages in $projectPath\n');

    // Ensure we have an absolute path
    final absoluteProjectPath = path.isAbsolute(projectPath)
        ? projectPath
        : path.absolute(projectPath);

    // Parse pubspec.yaml
    final pubspecFile = File(path.join(absoluteProjectPath, 'pubspec.yaml'));
    if (!pubspecFile.existsSync()) {
      print('❌ pubspec.yaml not found');
      return;
    }

    final declaredPackagesMap = await _parsePubspecDependencies(pubspecFile);
    final regularPackages = declaredPackagesMap['regular'] ?? <String>{};
    final devPackages = declaredPackagesMap['dev'] ?? <String>{};

    if (regularPackages.isEmpty && devPackages.isEmpty) {
      print('ℹ️  No dependencies found in pubspec.yaml');
      return;
    }

    // Find used packages by analyzing Dart files
    final usedPackages = await _findUsedPackages(absoluteProjectPath);

    // Identify unused packages by type
    final unusedRegularPackages = regularPackages
        .where((package) => !usedPackages.contains(package))
        .toList();
    final unusedDevPackages = devPackages
        .where((package) => !usedPackages.contains(package))
        .toList();

    // Generate report
    _generateReport(
      regularPackages,
      devPackages,
      usedPackages,
      unusedRegularPackages,
      unusedDevPackages,
    );
  }

  /// Parse pubspec.yaml to extract declared dependencies by type
  Future<Map<String, Set<String>>> _parsePubspecDependencies(
    File pubspecFile,
  ) async {
    final content = await pubspecFile.readAsString();
    final regularPackages = <String>{};
    final devPackages = <String>{};

    final lines = content.split('\n');
    bool inDependencies = false;
    bool inDevDependencies = false;

    for (final line in lines) {
      final trimmedLine = line.trim();

      if (trimmedLine == 'dependencies:') {
        inDependencies = true;
        inDevDependencies = false;
        continue;
      }

      if (trimmedLine == 'dev_dependencies:') {
        inDependencies = false;
        inDevDependencies = true;
        continue;
      }

      if (trimmedLine.isNotEmpty && (inDependencies || inDevDependencies)) {
        // Check if this line looks like a package dependency
        // It should start with spaces and contain a colon
        if (line.startsWith(' ') && line.contains(':')) {
          // Extract package name from the line
          // Format: "  package_name: version_or_config"
          final colonIndex = line.indexOf(':');
          if (colonIndex > 0) {
            final packageName = line.substring(0, colonIndex).trim();
            if (packageName.isNotEmpty &&
                !_isInternalPackage(packageName) &&
                !_isInvalidPackageName(packageName)) {
              if (inDependencies) {
                regularPackages.add(packageName);
              } else if (inDevDependencies) {
                devPackages.add(packageName);
              }
            }
          }
        }
      }

      // Reset if we hit another top-level key
      // Only reset if we encounter a line that's not indented AND not a comment
      if (trimmedLine.isNotEmpty &&
          !line.startsWith(' ') &&
          !trimmedLine.startsWith('#')) {
        if (trimmedLine != 'dependencies:' &&
            trimmedLine != 'dev_dependencies:') {
          inDependencies = false;
          inDevDependencies = false;
        }
      }
    }

    return {'regular': regularPackages, 'dev': devPackages};
  }

  /// Check if a package name represents an internal package
  bool _isInternalPackage(String packageName) {
    return packageName == 'flutter' ||
        packageName == 'dart' ||
        packageName.startsWith('flutter_') ||
        packageName.startsWith('dart_');
  }

  /// Check if a package name is invalid or not a real package
  bool _isInvalidPackageName(String packageName) {
    // Filter out common false positives from dependency specifications
    return packageName == 'sdk' ||
        packageName == 'git' ||
        packageName == 'url' ||
        packageName == 'ref' ||
        packageName == 'path' ||
        packageName == 'version' ||
        packageName == 'description' ||
        packageName == 'name';
  }

  /// Find packages that are actually used in the project
  Future<Set<String>> _findUsedPackages(String projectPath) async {
    final usedPackages = <String>{};
    final dartFiles = _findDartFiles(projectPath);

    if (dartFiles.isEmpty) {
      return usedPackages;
    }

    // Ensure the project path is properly normalized (no trailing slash)
    final normalizedProjectPath = path.normalize(projectPath);

    // Try using analyzer first
    try {
      final collection = AnalysisContextCollection(
        includedPaths: [normalizedProjectPath],
        resourceProvider: PhysicalResourceProvider.INSTANCE,
      );

      for (final filePath in dartFiles) {
        try {
          final context = collection.contextFor(filePath);
          final result = context.currentSession.getParsedUnit(filePath);

          if (result is ParsedUnitResult) {
            final imports = _extractImports(result);
            usedPackages.addAll(imports);
          }
        } catch (e) {
          // Skip files that can't be parsed by analyzer
          continue;
        }
      }
    } catch (e) {
      // Analyzer failed, fall back to text parsing
      print('   ⚠️  Analyzer failed, falling back to text parsing: $e');
    }

    // If analyzer didn't find any packages, use fallback text parsing
    if (usedPackages.isEmpty) {
      print('   🔍 Using fallback text parsing for package imports...');
      for (final filePath in dartFiles) {
        try {
          final imports = _extractImportsFromText(filePath);
          usedPackages.addAll(imports);
        } catch (e) {
          // Skip files that can't be read
          continue;
        }
      }
    }

    return usedPackages;
  }

  /// Find all Dart files in the project
  List<String> _findDartFiles(String projectPath) {
    final dartFiles = <String>[];

    // For Flutter/Dart projects, focus on the lib directory
    final libDir = Directory(path.join(projectPath, 'lib'));
    if (libDir.existsSync()) {
      _scanDirectory(libDir, dartFiles);
    }

    // Also check for test files
    final testDir = Directory(path.join(projectPath, 'test'));
    if (testDir.existsSync()) {
      _scanDirectory(testDir, dartFiles);
    }

    // Check for integration test files
    final integrationTestDir = Directory(
      path.join(projectPath, 'integration_test'),
    );
    if (integrationTestDir.existsSync()) {
      _scanDirectory(integrationTestDir, dartFiles);
    }

    return dartFiles;
  }

  /// Recursively scan directory for Dart files
  void _scanDirectory(Directory dir, List<String> dartFiles) {
    try {
      for (final entity in dir.listSync()) {
        if (entity is File && entity.path.endsWith('.dart')) {
          dartFiles.add(entity.path);
        } else if (entity is Directory) {
          final dirName = path.basename(entity.path);
          // Skip common directories that shouldn't contain source code
          if (!dirName.startsWith('.') &&
              dirName != 'build' &&
              dirName != 'node_modules' &&
              dirName != '.dart_tool' &&
              dirName != 'generated') {
            _scanDirectory(entity, dartFiles);
          }
        }
      }
    } catch (e) {
      // Skip directories we can't access
    }
  }

  /// Extract package names from import statements
  Set<String> _extractImports(ParsedUnitResult result) {
    final packages = <String>{};

    for (final directive in result.unit.directives) {
      if (directive is ImportDirective) {
        final uri = directive.uri.stringValue;
        if (uri != null && uri.startsWith('package:')) {
          final packageName = _extractPackageName(uri);
          if (packageName != null) {
            packages.add(packageName);
          }
        }
      }
    }

    return packages;
  }

  /// Extract package name from package URI
  String? _extractPackageName(String uri) {
    // package:package_name/file.dart -> package_name
    final match = RegExp(r'^package:([^/]+)/').firstMatch(uri);
    return match?.group(1);
  }

  /// Extract package imports from text content (fallback method)
  Set<String> _extractImportsFromText(String filePath) {
    final packages = <String>{};

    try {
      final file = File(filePath);
      if (!file.existsSync()) {
        return packages;
      }

      final content = file.readAsStringSync();
      final lines = content.split('\n');

      for (final line in lines) {
        final trimmedLine = line.trim();
        if (trimmedLine.startsWith("import 'package:")) {
          final match = RegExp(
            r"^import\s+\'package:([^/]+)/",
          ).firstMatch(trimmedLine);
          final packageName = match?.group(1);
          if (packageName != null) {
            packages.add(packageName);
          }
        }
      }
    } catch (e) {
      // Skip files that can't be read
    }

    return packages;
  }

  /// Generate and display the analysis report
  void _generateReport(
    Set<String> regularPackages,
    Set<String> devPackages,
    Set<String> usedPackages,
    List<String> unusedRegularPackages,
    List<String> unusedDevPackages,
  ) {
    print('📦 Package Analysis Results\n');

    final totalDeclared = regularPackages.length + devPackages.length;
    final totalUnused = unusedRegularPackages.length + unusedDevPackages.length;

    print('📊 Summary:');
    print('  • Total Declared Packages: $totalDeclared');
    print('    - Regular Dependencies: ${regularPackages.length}');
    print('    - Dev Dependencies: ${devPackages.length}');
    print('  • Used Packages: ${usedPackages.length}');
    print('  • Unused Packages: $totalUnused\n');

    if (totalUnused == 0) {
      print('✅ All declared packages are being used!');
      return;
    }

    // Report unused regular dependencies (affect bundle size)
    if (unusedRegularPackages.isNotEmpty) {
      print('❌ Unused Regular Dependencies (affect bundle size):');
      for (final package in unusedRegularPackages) {
        print('  • $package');
      }
      print('');
    }

    // Report potentially unused dev dependencies
    if (unusedDevPackages.isNotEmpty) {
      print('⚠️  Potentially Unused Dev Dependencies:');
      for (final package in unusedDevPackages) {
        print('  • $package');
      }
      print('');
    }

    print('💡 Recommendations:');
    if (unusedRegularPackages.isNotEmpty) {
      print(
        '  • Consider removing unused regular dependencies to reduce bundle size',
      );
    }
    if (unusedDevPackages.isNotEmpty) {
      print('  • Review dev dependencies for development workflow needs');
    }
    print('  • Check if packages are used in generated code or build scripts');
  }
}
