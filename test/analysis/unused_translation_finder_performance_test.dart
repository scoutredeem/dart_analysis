import 'package:test/test.dart';
import 'package:dart_analysis/analysis/unused_translation_finder.dart';
import 'dart:io';
import 'package:path/path.dart' as p;

void main() {
  group('UnusedTranslationFinder - Performance & Scalability', () {
    late UnusedTranslationFinder finder;
    late String tempDir;

    setUp(() {
      finder = UnusedTranslationFinder();
      tempDir = Directory.systemTemp.createTempSync('translation_test_').path;
    });

    tearDown(() {
      Directory(tempDir).deleteSync(recursive: true);
    });

    group('Performance & Scalability', () {
      test('should handle large ARB files efficiently', () {
        // Create a mock Flutter project
        final projectDir = Directory(p.join(tempDir, 'test_project'));
        projectDir.createSync(recursive: true);

        // Create pubspec.yaml
        File(p.join(projectDir.path, 'pubspec.yaml')).writeAsStringSync('''
name: test_app
description: A test Flutter app
version: 1.0.0+1

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter

flutter:
  uses-material-design: true
''');

        // Create l10n.yaml
        File(p.join(projectDir.path, 'l10n.yaml')).writeAsStringSync('''
arb-dir: lib/l10n
template-arb-file: app_en.arb
output-localization-file: app_localizations.dart
''');

        // Create lib directory with large ARB file
        final libDir = Directory(p.join(projectDir.path, 'lib'));
        libDir.createSync();

        final l10nDir = Directory(p.join(libDir.path, 'l10n'));
        l10nDir.createSync();

        // Create a large ARB file with many keys
        final buffer = StringBuffer();
        buffer.writeln('{');

        for (int i = 0; i < 1000; i++) {
          if (i > 0) buffer.writeln(',');
          buffer.writeln('  "key$i": "Value $i",');
          buffer.writeln('  "@key$i": {');
          buffer.writeln('    "description": "Description for key $i"');
          buffer.writeln('  }');
        }

        buffer.writeln('}');

        File(
          p.join(l10nDir.path, 'app_en.arb'),
        ).writeAsStringSync(buffer.toString());

        // Should be able to analyze the project efficiently
        expect(finder.canAnalyze(projectDir.path), isTrue);

        // Should extract all translation keys
        final arbFiles = finder.findLocalizationFiles(projectDir.path);
        expect(arbFiles.length, equals(1));

        final allKeys = finder.extractTranslationKeys(arbFiles.first);
        expect(allKeys.length, equals(1000));
        expect(allKeys.contains('key0'), isTrue);
        expect(allKeys.contains('key999'), isTrue);
      });

      test('should handle large Dart files efficiently', () {
        // Create a mock Flutter project
        final projectDir = Directory(p.join(tempDir, 'test_project'));
        projectDir.createSync(recursive: true);

        // Create pubspec.yaml
        File(p.join(projectDir.path, 'pubspec.yaml')).writeAsStringSync('''
name: test_app
description: A test Flutter app
version: 1.0.0+1

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter

flutter:
  uses-material-design: true
''');

        // Create l10n.yaml
        File(p.join(projectDir.path, 'l10n.yaml')).writeAsStringSync('''
arb-dir: lib/l10n
template-arb-file: app_en.arb
output-localization-file: app_localizations.dart
''');

        // Create lib directory
        final libDir = Directory(p.join(projectDir.path, 'lib'));
        libDir.createSync();

        final l10nDir = Directory(p.join(libDir.path, 'l10n'));
        l10nDir.createSync();

        // Create a simple ARB file
        File(p.join(l10nDir.path, 'app_en.arb')).writeAsStringSync('''
{
  "appTitle": "Test App",
  "welcomeMessage": "Welcome!"
}
''');

        // Create a large Dart file with many translation usages
        final buffer = StringBuffer();
        buffer.writeln('import \'package:flutter/material.dart\';');
        buffer.writeln('');
        buffer.writeln('class LargeWidget extends StatelessWidget {');
        buffer.writeln('  @override');
        buffer.writeln('  Widget build(BuildContext context) {');
        buffer.writeln('    return Column(');
        buffer.writeln('      children: [');

        for (int i = 0; i < 1000; i++) {
          buffer.writeln('        Text(context.translation.appTitle),');
          buffer.writeln('        Text(context.translation.welcomeMessage),');
        }

        buffer.writeln('      ],');
        buffer.writeln('    );');
        buffer.writeln('  }');
        buffer.writeln('}');

        File(
          p.join(libDir.path, 'large_widget.dart'),
        ).writeAsStringSync(buffer.toString());

        // Should be able to analyze the project efficiently
        expect(finder.canAnalyze(projectDir.path), isTrue);

        // Should find used translation keys efficiently
        final arbFiles = finder.findLocalizationFiles(projectDir.path);
        final allKeys = finder.extractTranslationKeys(arbFiles.first);
        final dartFiles = finder.getAllDartFiles(libDir.path);
        final usedKeys = finder.findUsedTranslationKeys(dartFiles, allKeys);

        expect(usedKeys.contains('appTitle'), isTrue);
        expect(usedKeys.contains('welcomeMessage'), isTrue);
      });

      test('should handle multiple ARB files efficiently', () {
        // Create a mock Flutter project
        final projectDir = Directory(p.join(tempDir, 'test_project'));
        projectDir.createSync(recursive: true);

        // Create pubspec.yaml
        File(p.join(projectDir.path, 'pubspec.yaml')).writeAsStringSync('''
name: test_app
description: A test Flutter app
version: 1.0.0+1

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter

flutter:
  uses-material-design: true
''');

        // Create l10n.yaml
        File(p.join(projectDir.path, 'l10n.yaml')).writeAsStringSync('''
arb-dir: lib/l10n
template-arb-file: app_en.arb
output-localization-file: app_localizations.dart
''');

        // Create lib directory with multiple ARB files
        final libDir = Directory(p.join(projectDir.path, 'lib'));
        libDir.createSync();

        final l10nDir = Directory(p.join(libDir.path, 'l10n'));
        l10nDir.createSync();

        // Create multiple ARB files with different languages
        for (int i = 0; i < 10; i++) {
          final languageCode = String.fromCharCodes([
            97 + (i % 26), // 'a' to 'z'
          ]);

          final buffer = StringBuffer();
          buffer.writeln('{');

          for (int j = 0; j < 100; j++) {
            if (j > 0) buffer.writeln(',');
            buffer.writeln('  "key$j": "Value $j in $languageCode",');
            buffer.writeln('  "@key$j": {');
            buffer.writeln(
              '    "description": "Description for key $j in $languageCode"',
            );
            buffer.writeln('  }');
          }

          buffer.writeln('}');

          File(
            p.join(l10nDir.path, 'app_$languageCode.arb'),
          ).writeAsStringSync(buffer.toString());
        }

        // Should be able to analyze the project efficiently
        expect(finder.canAnalyze(projectDir.path), isTrue);

        // Should find all localization files
        final arbFiles = finder.findLocalizationFiles(projectDir.path);
        expect(arbFiles.length, equals(10));

        // Should extract keys from all files efficiently
        final allKeys = <String>{};
        for (final file in arbFiles) {
          allKeys.addAll(finder.extractTranslationKeys(file));
        }
        expect(allKeys.length, equals(100)); // 100 unique keys across all files
      });

      test('should handle complex translation key patterns efficiently', () {
        // Create a mock Flutter project
        final projectDir = Directory(p.join(tempDir, 'test_project'));
        projectDir.createSync(recursive: true);

        // Create pubspec.yaml
        File(p.join(projectDir.path, 'pubspec.yaml')).writeAsStringSync('''
name: test_app
description: A test Flutter app
version: 1.0.0+1

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter

flutter:
  uses-material-design: true
''');

        // Create l10n.yaml
        File(p.join(projectDir.path, 'l10n.yaml')).writeAsStringSync('''
arb-dir: lib/l10n
template-arb-file: app_en.arb
output-localization-file: app_localizations.dart
''');

        // Create lib directory
        final libDir = Directory(p.join(projectDir.path, 'lib'));
        libDir.createSync();

        final l10nDir = Directory(p.join(libDir.path, 'l10n'));
        l10nDir.createSync();

        // Create ARB file with complex keys
        File(p.join(l10nDir.path, 'app_en.arb')).writeAsStringSync('''
{
  "appTitle": "Test App",
  "welcomeMessage": "Welcome!",
  "errorMessage": "An error occurred",
  "successMessage": "Operation successful"
}
''');

        // Create Dart files with complex translation usage patterns
        for (int i = 0; i < 100; i++) {
          final buffer = StringBuffer();
          buffer.writeln('import \'package:flutter/material.dart\';');
          buffer.writeln('');
          buffer.writeln('class Widget$i extends StatelessWidget {');
          buffer.writeln('  @override');
          buffer.writeln('  Widget build(BuildContext context) {');
          buffer.writeln('    return Column(');
          buffer.writeln('      children: [');
          buffer.writeln('        Text(context.translation.appTitle),');
          buffer.writeln('        Text(context.translation.welcomeMessage),');
          buffer.writeln(
            '        if (i % 2 == 0) Text(context.translation.errorMessage),',
          );
          buffer.writeln(
            '        if (i % 3 == 0) Text(context.translation.successMessage),',
          );
          buffer.writeln('      ],');
          buffer.writeln('    );');
          buffer.writeln('  }');
          buffer.writeln('}');

          File(
            p.join(libDir.path, 'widget_$i.dart'),
          ).writeAsStringSync(buffer.toString());
        }

        // Should be able to analyze the project efficiently
        expect(finder.canAnalyze(projectDir.path), isTrue);

        // Should find used translation keys efficiently
        final arbFiles = finder.findLocalizationFiles(projectDir.path);
        final allKeys = finder.extractTranslationKeys(arbFiles.first);
        final dartFiles = finder.getAllDartFiles(libDir.path);
        final usedKeys = finder.findUsedTranslationKeys(dartFiles, allKeys);

        expect(usedKeys.contains('appTitle'), isTrue);
        expect(usedKeys.contains('welcomeMessage'), isTrue);
        expect(usedKeys.contains('errorMessage'), isTrue);
        expect(usedKeys.contains('successMessage'), isTrue);
      });
    });
  });
}
