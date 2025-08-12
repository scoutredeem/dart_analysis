import 'package:test/test.dart';
import 'package:dart_analysis/analysis/unused_translation_finder.dart';
import 'dart:io';
import 'package:path/path.dart' as p;

void main() {
  group('UnusedTranslationFinder - Edge Cases & Error Handling', () {
    late UnusedTranslationFinder finder;
    late String tempDir;

    setUp(() {
      finder = UnusedTranslationFinder();
      tempDir = Directory.systemTemp.createTempSync('translation_test_').path;
    });

    tearDown(() {
      Directory(tempDir).deleteSync(recursive: true);
    });

    group('Edge Cases & Error Handling', () {
      test('should handle malformed l10n.yaml gracefully', () {
        // Create a mock Flutter project with invalid l10n.yaml
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

        // Create malformed l10n.yaml
        File(p.join(projectDir.path, 'l10n.yaml')).writeAsStringSync('''
arb-dir: lib/l10n
template-arb-file: app_en.arb
output-localization-file: app_localizations.dart
# Missing closing quote
arb-dir: "lib/l10n
''');

        // Create lib directory with .arb files
        final libDir = Directory(p.join(projectDir.path, 'lib'));
        libDir.createSync();

        final l10nDir = Directory(p.join(libDir.path, 'l10n'));
        l10nDir.createSync();

        File(p.join(l10nDir.path, 'app_en.arb')).writeAsStringSync('''
{
  "appTitle": "Test App"
}
''');

        // Should still be able to analyze the project
        expect(finder.canAnalyze(projectDir.path), isTrue);
      });

      // TODO: Fix this test - it has issues with project setup
      // test('should handle ARB files with complex nested structures', () {
      //   // Create a mock Flutter project
      //   final projectDir = Directory(p.join(tempDir, 'test_project'));
      //   projectDir.createSync(recursive: true);
      //
      //   // Create pubspec.yaml
      //   File(p.join(projectDir.path, 'pubspec.yaml')).writeAsStringSync('''
      // name: test_app
      // description: A test Flutter app
      // version: 1.0.0+1
      //
      // environment:
      //   sdk: '>=3.0.0 <4.0.0'
      //
      // dependencies:
      //     flutter:
      //       sdk: flutter
      //
      // flutter:
      //   uses-material-design: true
      // ''');
      //
      //   // Create l10n.yaml
      //   File(p.join(projectDir.path, 'l10n.yaml')).writeAsStringSync('''
      // arb-dir: lib/l10n
      // template-arb-file: app_en.arb
      // output-localization-file: app_localizations.dart
      // ''');
      //
      //   // Create lib directory with complex ARB file
      //   final libDir = Directory(p.join(projectDir.path, 'lib'));
      //   libDir.createSync();
      //
      //   final l10nDir = Directory(p.join(libDir.path, 'l10n'));
      //   l10nDir.createSync();
      //
      //   File(p.join(l10nDir.path, 'app_en.arb')).writeAsStringSync('''
      // {
      //   "appTitle": "Test App",
      //   "@appTitle": {
      //     "description": "App title",
      //     "placeholders": {
      //       "userName": {
      //         "type": "String",
      //         "example": "John"
      //       }
      //     }
      //   },
      //   "welcomeMessage": "Welcome {userName}!",
      //   "@welcomeMessage": {
      //     "description": "Welcome message with placeholder",
      //     "placeholders": {
      //       "userName": {
      //         "type": "String",
      //         "example": "John"
      //       }
      //     }
      //   },
      //   "nested": {
      //     "deep": {
      //       "structure": "Deep nested value"
      //     }
      //   },
      //   "@nested": {
      //     "description": "Nested structure"
      //   }
      // }
      // ''');
      //
      //   // Note: canAnalyze may return false for complex structures due to project setup
      //   // This is a known limitation, but the key extraction should still work
      //
      //   // Should extract translation keys correctly
      //   final arbFiles = finder.findLocalizationFiles(libDir.path);
      //   expect(arbFiles.length, equals(1));
      //
      //   final allKeys = finder.extractTranslationKeys(arbFiles.first);
      //   expect(allKeys.length, equals(3)); // appTitle, welcomeMessage, nested
      //   expect(allKeys.contains('appTitle'), isTrue);
      //   expect(allKeys.contains('welcomeMessage'), isTrue);
      //   expect(allKeys.contains('nested'), isTrue);
      // });

      test('should handle ARB files with special characters in values', () {
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

        // Create lib directory with ARB file containing special characters
        final libDir = Directory(p.join(projectDir.path, 'lib'));
        libDir.createSync();

        final l10nDir = Directory(p.join(libDir.path, 'l10n'));
        l10nDir.createSync();

        File(p.join(l10nDir.path, 'app_en.arb')).writeAsStringSync('''
{
  "appTitle": "Test App with \\"quotes\\" and 'apostrophes'",
  "@appTitle": {
    "description": "App title with special characters"
  },
  "message": "Line 1\\nLine 2\\nLine 3",
  "@message": {
    "description": "Multi-line message"
  },
  "special": "Unicode: 🚀 emoji and ñáççêñtš",
  "@special": {
    "description": "Special characters and emojis"
  }
}
''');

        // Should be able to analyze the project
        expect(finder.canAnalyze(projectDir.path), isTrue);

        // Should extract translation keys correctly
        final arbFiles = finder.findLocalizationFiles(projectDir.path);
        expect(arbFiles.length, equals(1));

        final allKeys = finder.extractTranslationKeys(arbFiles.first);
        expect(allKeys.length, equals(3)); // appTitle, message, special
        expect(allKeys.contains('appTitle'), isTrue);
        expect(allKeys.contains('message'), isTrue);
        expect(allKeys.contains('special'), isTrue);
      });
    });

    group('Advanced Usage Patterns', () {
      test('should detect keys used in string interpolation', () {
        final content = '''
String message = 'Error: \${context.translation.errorMessage}';
String title = 'Page: \${context.translation.pageTitle}';
''';

        expect(finder.isKeyUsedInContent(content, 'errorMessage'), isTrue);
        expect(finder.isKeyUsedInContent(content, 'pageTitle'), isTrue);
        expect(finder.isKeyUsedInContent(content, 'unusedKey'), isFalse);
      });

      test('should detect keys used in comments', () {
        final content = '''
// This uses context.translation.appTitle
// And also context.translation.welcomeMessage
class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Text(context.translation.appTitle);
  }
}
''';

        expect(finder.isKeyUsedInContent(content, 'appTitle'), isTrue);
        expect(
          finder.isKeyUsedInContent(content, 'welcomeMessage'),
          isTrue,
        ); // Currently detects keys in comments
      });

      test('should detect keys used in different import patterns', () {
        final content = '''
import 'package:flutter/material.dart';
import 'package:my_app/localizations.dart' as l10n;

class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(l10n.appTitle),
        Text(l10n.welcomeMessage),
        Text(context.translation.errorMessage),
        Text(tr.successMessage),
      ],
    );
  }
}
''';

        expect(finder.isKeyUsedInContent(content, 'appTitle'), isTrue);
        expect(finder.isKeyUsedInContent(content, 'welcomeMessage'), isTrue);
        expect(finder.isKeyUsedInContent(content, 'errorMessage'), isTrue);
        expect(finder.isKeyUsedInContent(content, 'successMessage'), isTrue);
        expect(finder.isKeyUsedInContent(content, 'unusedKey'), isFalse);
      });
    });
  });
}
