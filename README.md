# Dart Analysis Tool

A command-line tool to analyze Dart/Flutter projects and find unused files and translation strings.

## Features

### 🔍 Unused File Finder

- Finds unused Dart files in your project by analyzing import statements
- Traces dependencies from entry points (main.dart)
- Supports both Dart and Flutter projects
- Optionally deletes unused files

### 🌐 Unused Translation Finder

- Finds unused translation strings in Flutter projects
- Detects various usage patterns including:
  - `AppLocalizations.of(context).keyName`
  - `context.tr.keyName` (extension methods)
  - `S.of(context).keyName`
  - And more...
- Automatically removes unused translation keys
- Supports multiple localization file patterns

### 📦 Unused Package Finder

- Finds packages declared in pubspec.yaml that are never used
- Analyzes all Dart files for import statements
- Identifies both regular and dev dependencies
- Provides recommendations for package cleanup
- Helps reduce bundle size and dependency bloat

## Architecture

The tool is built with a composable architecture:

- **BaseAnalyzer**: Abstract interface for all analyzers
- **AnalyzerRegistry**: Manages available analyzers
- **AnalyzerUtils**: Common utilities shared across analyzers
- **Individual Analyzers**: Specialized analyzers for different tasks

This makes it easy to add new analysis features in the future.

## Installation

```bash
git clone <repository>
cd dart_analysis
dart pub get
```

## Usage

### Basic Usage

```bash
# Analyze a project
dart run bin/dart_analysis.dart /path/to/your/project

# Show help
dart run bin/dart_analysis.dart --help

# Show version
dart run bin/dart_analysis.dart --version
```

### Examples

```bash
# Analyze current directory
dart run bin/dart_analysis.dart .

# Analyze a Flutter project
dart run bin/dart_analysis.dart /path/to/flutter/app

# Analyze a Dart package
dart run bin/dart_analysis.dart /path/to/dart/package
```

## How It Works

### Unused File Finder

1. Scans the `lib/` directory for all Dart files
2. Identifies entry points (main.dart files)
3. Recursively traces all import statements
4. Reports files that are never imported

### Unused Translation Finder

1. Detects Flutter projects with localization files
2. Scans localization files for translation keys
3. Analyzes all Dart files for usage patterns
4. Identifies unused translation keys
5. Optionally removes them from localization files

### Unused Package Finder

1. Parses pubspec.yaml to extract declared dependencies
2. Scans all Dart files for package import statements
3. Identifies packages that are declared but never imported
4. Provides detailed analysis report with recommendations
5. Helps optimize project dependencies and reduce bundle size

## Supported Localization Patterns

The translation finder recognizes these file patterns:

- `**/localization/*.dart`
- `**/l10n/*.dart`
- `**/i18n/*.dart`
- `**/app_localizations_*.dart`
- `**/localizations.dart`

## Usage Patterns Detected

The tool detects translation key usage in these patterns:

- `AppLocalizations.of(context).keyName`
- `context.tr.keyName`
- `context.localizations.keyName`
- `localizations.keyName`
- `l10n.keyName`
- `S.of(context).keyName`
- `S.current.keyName`

## Development

### Adding New Analyzers

1. Create a new class implementing `BaseAnalyzer`
2. Add it to `AnalyzerRegistry._analyzers`
3. The tool will automatically detect and offer it

### Running Tests

```bash
dart test
```

### Project Structure

```
lib/
├── analysis/
│   ├── base_analyzer.dart      # Abstract analyzer interface
│   ├── analyzer_registry.dart  # Analyzer management
│   ├── unused_file_finder.dart # Unused file detection
│   ├── unused_translation_finder.dart # Translation analysis
│   ├── unused_package_finder.dart # Package dependency analysis
│   └── utils.dart              # Common utilities
├── analysis.dart               # Barrel export file
└── bin/
    └── dart_analysis.dart     # Main CLI entry point
```

## Requirements

- Dart SDK ^3.8.1
- Flutter (for Flutter project analysis)

## Dependencies

- `analyzer`: For Dart code analysis
- `interact_cli`: For interactive command-line interface
- `path`: For path manipulation utilities

## Contributing

1. Fork the repository
2. Create a feature branch
3. Implement your changes
4. Add tests
5. Submit a pull request

## License

This project is open source and available under the [MIT License](LICENSE).
