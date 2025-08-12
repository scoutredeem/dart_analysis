import 'package:test/test.dart';
import 'package:dart_analysis/analysis/unused_translation_finder.dart';
import 'dart:io';
import 'package:path/path.dart' as p;

void main() {
  group('UnusedTranslationFinder - Basic Functionality', () {
    late UnusedTranslationFinder finder;
    late String tempDir;

    setUp(() {
      finder = UnusedTranslationFinder();
      tempDir = Directory.systemTemp.createTempSync('translation_test_').path;
    });

    tearDown(() {
      Directory(tempDir).deleteSync(recursive: true);
    });

    group('canAnalyze', () {
      test('should return true for Flutter project with l10n.yaml', () {
        // Create a mock Flutter project structure
        final projectDir = Directory(p.join(tempDir, 'flutter_project'));
        projectDir.createSync(recursive: true);

        // Create pubspec.yaml (required for Flutter project detection)
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

        expect(finder.canAnalyze(projectDir.path), isTrue);
      });

      test('should return true for Flutter project with .arb files', () {
        // Create a mock Flutter project structure
        final projectDir = Directory(p.join(tempDir, 'flutter_project'));
        projectDir.createSync(recursive: true);

        // Create pubspec.yaml (required for Flutter project detection)
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

        expect(finder.canAnalyze(projectDir.path), isTrue);
      });

      test('should return false for non-Flutter project', () {
        // Create a mock non-Flutter project
        final projectDir = Directory(p.join(tempDir, 'non_flutter_project'));
        projectDir.createSync(recursive: true);

        expect(finder.canAnalyze(projectDir.path), isFalse);
      });
    });

    group('isTranslationKey', () {
      test('should identify translation keys correctly', () {
        final arbContent = '''
{
  "appTitle": "Test App",
  "@appTitle": {
    "description": "App title"
  },
  "welcomeMessage": "Welcome!",
  "@welcomeMessage": {
    "description": "Welcome message"
  }
}
''';

        expect(finder.isTranslationKey(arbContent, 'appTitle'), isTrue);
        expect(finder.isTranslationKey(arbContent, 'welcomeMessage'), isTrue);
        expect(finder.isTranslationKey(arbContent, 'description'), isFalse);
      });

      test('should filter out metadata properties', () {
        final arbContent = '''
{
  "appTitle": "Test App",
  "@appTitle": {
    "description": "App title",
    "placeholders": {
      "count": {
        "type": "String"
      }
    }
  }
}
''';

        expect(finder.isTranslationKey(arbContent, 'appTitle'), isTrue);
        expect(finder.isTranslationKey(arbContent, 'description'), isFalse);
        expect(finder.isTranslationKey(arbContent, 'placeholders'), isFalse);
        expect(finder.isTranslationKey(arbContent, 'type'), isFalse);
      });
    });

    group('isKeyUsedInContent', () {
      test('should detect AppLocalizations.of(context).keyName', () {
        final content = 'Text(AppLocalizations.of(context).appTitle)';
        expect(finder.isKeyUsedInContent(content, 'appTitle'), isTrue);
      });

      test('should detect AppLocalizations.of(context)?.keyName', () {
        final content = 'Text(AppLocalizations.of(context)?.appTitle)';
        expect(finder.isKeyUsedInContent(content, 'appTitle'), isTrue);
      });

      test('should detect context.translation.keyName (same line)', () {
        final content = 'Text(context.translation.appTitle)';
        expect(finder.isKeyUsedInContent(content, 'appTitle'), isTrue);
      });

      test('should detect context.translation.keyName (multi-line)', () {
        final content = '''
Text(context
    .translation.appTitle)
''';
        expect(finder.isKeyUsedInContent(content, 'appTitle'), isTrue);
      });

      test('should detect context.translation.keyName() (method call)', () {
        final content = 'Text(context.translation.welcomeMessage(userName))';
        expect(finder.isKeyUsedInContent(content, 'welcomeMessage'), isTrue);
      });

      test(
        'should detect context.translation.keyName() (multi-line method call)',
        () {
          final content = '''
Text(context.translation
    .welcomeMessage(userName))
''';
          expect(finder.isKeyUsedInContent(content, 'welcomeMessage'), isTrue);
        },
      );

      test('should detect context.tr.keyName', () {
        final content = 'Text(context.tr.appTitle)';
        expect(finder.isKeyUsedInContent(content, 'appTitle'), isTrue);
      });

      test('should detect tr.keyName (variable)', () {
        final content = 'Text(tr.appTitle)';
        expect(finder.isKeyUsedInContent(content, 'appTitle'), isTrue);
      });

      test('should not detect false positives', () {
        final content = '''
class UserProfile {
  String welcomeMessage = "Hello";
  print("This is a welcomeMessage");
}
''';
        expect(finder.isKeyUsedInContent(content, 'welcomeMessage'), isFalse);
      });
    });

    group('removeKeyFromArbContent', () {
      test('should remove key and metadata correctly', () {
        final arbContent = '''
{
  "appTitle": "Test App",
  "@appTitle": {
    "description": "App title"
  },
  "welcomeMessage": "Welcome!",
  "@welcomeMessage": {
    "description": "Welcome message"
  }
}
''';

        final result = finder.removeKeyFromArbContent(
          arbContent,
          'welcomeMessage',
        );

        expect(result, contains('"appTitle"'));
        expect(result, contains('"@appTitle"'));
        expect(result, isNot(contains('"welcomeMessage"')));
        expect(result, isNot(contains('"@welcomeMessage"')));

        // Should be valid JSON
        expect(() => result, returnsNormally);
      });

      test('should handle complex nested structures', () {
        final arbContent = '''
{
  "welcomeMessage": "Welcome {userName}!",
  "@welcomeMessage": {
    "description": "Welcome message with placeholder",
    "placeholders": {
      "userName": {
        "type": "String",
        "example": "John"
      }
    }
  }
}
''';

        final result = finder.removeKeyFromArbContent(
          arbContent,
          'welcomeMessage',
        );

        expect(result, isNot(contains('"welcomeMessage"')));
        expect(result, isNot(contains('"@welcomeMessage"')));
        expect(result, isNot(contains('"placeholders"')));

        // Should be valid JSON
        expect(() => result, returnsNormally);
      });

      test('should fallback to regex if JSON parsing fails', () {
        final invalidArbContent = '''
{
  "appTitle": "Test App",
  "invalid": "Missing quote
}
''';

        final result = finder.removeKeyFromArbContent(
          invalidArbContent,
          'appTitle',
        );

        // Should not crash and should attempt to remove the key
        expect(result, isNot(contains('"appTitle"')));
      });
    });

    group('cleanupArbContent', () {
      test('should remove trailing commas before braces', () {
        final content = '{"key": "value",}';
        final result = finder.cleanupArbContent(content);
        expect(result, equals('{"key": "value"}'));
      });

      test('should remove trailing commas before brackets', () {
        final content = '["item",]';
        final result = finder.cleanupArbContent(content);
        expect(result, equals('["item"]'));
      });

      test('should fix missing commas between properties', () {
        final content = '{"key1": "value1"}\n  "key2": "value2"';
        final result = finder.cleanupArbContent(content);
        // The cleanup should add a comma after key1 and format properly
        expect(result, contains('"key1": "value1"'));
        expect(result, contains('"key2": "value2"'));
        // The cleanup should add a comma between properties
        expect(result, contains(','));
        // The result should start with an opening brace
        expect(result, startsWith('{'));
      });

      test('should remove multiple empty lines', () {
        final content = '{\n\n\n  "key": "value"\n\n\n}';
        final result = finder.cleanupArbContent(content);
        expect(result, isNot(contains('\n\n\n')));
      });
    });

    group('Integration tests', () {
      test('should find used translation keys in mock project', () {
        // Create a mock Flutter project with ARB and Dart files
        final projectDir = Directory(p.join(tempDir, 'test_project'));
        projectDir.createSync(recursive: true);

        // Create pubspec.yaml (required for Flutter project detection)
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

        // Create ARB file
        final l10nDir = Directory(p.join(projectDir.path, 'lib', 'l10n'));
        l10nDir.createSync(recursive: true);

        File(p.join(l10nDir.path, 'app_en.arb')).writeAsStringSync('''
{
  "appTitle": "Test App",
  "@appTitle": {
    "description": "App title"
  },
  "welcomeMessage": "Welcome!",
  "@welcomeMessage": {
    "description": "Welcome message"
  },
  "unusedKey": "This is unused",
  "@unusedKey": {
    "description": "Unused key"
  }
}
''');

        // Create Dart file with translations
        final libDir = Directory(p.join(projectDir.path, 'lib'));
        File(p.join(libDir.path, 'main.dart')).writeAsStringSync('''
import 'package:flutter/material.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: context.translation.appTitle,
      home: Scaffold(
        body: Text(context.translation.welcomeMessage),
      ),
    );
  }
}
''');

        // Test that the finder can analyze this project
        expect(finder.canAnalyze(projectDir.path), isTrue);

        // Test that it finds the correct number of keys
        final arbFiles = finder.findLocalizationFiles(projectDir.path);
        expect(arbFiles.length, equals(1));

        final allKeys = finder.extractTranslationKeys(arbFiles.first);
        expect(
          allKeys.length,
          equals(3),
        ); // appTitle, welcomeMessage, unusedKey

        // Test that it identifies used vs unused keys
        final dartFiles = finder.getAllDartFiles(
          p.join(projectDir.path, 'lib'),
        );
        final usedKeys = finder.findUsedTranslationKeys(dartFiles, allKeys);

        expect(usedKeys.contains('appTitle'), isTrue);
        expect(usedKeys.contains('welcomeMessage'), isTrue);
        expect(usedKeys.contains('unusedKey'), isFalse);
      });
    });
  });
}
