import 'package:test/test.dart';
import 'package:dart_analysis/analysis/unused_file_finder.dart';
import 'dart:io';
import 'package:path/path.dart' as p;

void main() {
  group('UnusedFileFinder - Edge Cases & Error Handling', () {
    late UnusedFileFinder finder;
    late String tempDir;

    setUp(() {
      finder = UnusedFileFinder();
      tempDir = Directory.systemTemp.createTempSync('unused_file_test_').path;
    });

    tearDown(() {
      Directory(tempDir).deleteSync(recursive: true);
    });

    group('Edge Cases & Error Handling', () {
      test('should handle malformed pubspec.yaml gracefully', () {
        // Create a mock project with invalid pubspec.yaml
        final projectDir = Directory(p.join(tempDir, 'test_project'));
        projectDir.createSync(recursive: true);

        // Create malformed pubspec.yaml
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
  # Missing closing quote
  assets: "assets/
''');

        final libDir = Directory(p.join(projectDir.path, 'lib'));
        libDir.createSync();

        // Should still be able to analyze the project
        expect(finder.canAnalyze(projectDir.path), isTrue);

        // Package name extraction should still work even with malformed YAML
        final packageName = finder.getPackageName(projectDir.path);
        expect(packageName, equals('test_app'));
      });

      test('should handle deep nested directory structures', () {
        // Create a mock project with deeply nested directories
        final projectDir = Directory(p.join(tempDir, 'test_project'));
        projectDir.createSync(recursive: true);

        final libDir = Directory(p.join(projectDir.path, 'lib'));
        libDir.createSync();

        // Create deeply nested directory structure
        var currentDir = libDir;
        for (int i = 0; i < 10; i++) {
          currentDir = Directory(p.join(currentDir.path, 'level_$i'));
          currentDir.createSync();
        }

        // Create a Dart file at the deepest level
        File(p.join(currentDir.path, 'deep_file.dart')).writeAsStringSync('''
class DeepFile {
  void doSomething() {}
}
''');

        // Create main.dart that imports the deep file
        File(p.join(libDir.path, 'main.dart')).writeAsStringSync('''
import 'level_0/level_1/level_2/level_3/level_4/level_5/level_6/level_7/level_8/level_9/deep_file.dart';

void main() {
  DeepFile().doSomething();
}
''');

        // Should find all Dart files including the deeply nested one
        final allDartFiles = finder.getAllDartFiles(libDir.path);
        expect(allDartFiles.length, equals(2)); // main.dart + deep_file.dart
        expect(allDartFiles.any((f) => f.endsWith('deep_file.dart')), isTrue);
      });

      test('should handle files with special characters in names', () {
        // Create a mock project structure
        final projectDir = Directory(p.join(tempDir, 'test_project'));
        projectDir.createSync(recursive: true);

        final libDir = Directory(p.join(projectDir.path, 'lib'));
        libDir.createSync();

        // Create files with special characters
        File(p.join(libDir.path, 'file-with-dashes.dart')).writeAsStringSync('''
class FileWithDashes {}
''');

        File(
          p.join(libDir.path, 'file_with_underscores.dart'),
        ).writeAsStringSync('''
class FileWithUnderscores {}
''');

        File(p.join(libDir.path, 'file.with.dots.dart')).writeAsStringSync('''
class FileWithDots {}
''');

        File(p.join(libDir.path, 'file (with spaces).dart')).writeAsStringSync(
          '''
class FileWithSpaces {}
''',
        );

        // Should find all Dart files regardless of naming conventions
        final allDartFiles = finder.getAllDartFiles(libDir.path);
        expect(allDartFiles.length, equals(4));
        expect(
          allDartFiles.any((f) => f.endsWith('file-with-dashes.dart')),
          isTrue,
        );
        expect(
          allDartFiles.any((f) => f.endsWith('file_with_underscores.dart')),
          isTrue,
        );
        expect(
          allDartFiles.any((f) => f.endsWith('file.with.dots.dart')),
          isTrue,
        );
        expect(
          allDartFiles.any((f) => f.endsWith('file (with spaces).dart')),
          isTrue,
        );
      });
    });

    group('Import Resolution Edge Cases', () {
      test('should handle export statements correctly', () {
        // Create a mock project structure
        final projectDir = Directory(p.join(tempDir, 'test_project'));
        projectDir.createSync(recursive: true);

        final libDir = Directory(p.join(projectDir.path, 'lib'));
        libDir.createSync();

        // Create a library file
        File(p.join(libDir.path, 'library.dart')).writeAsStringSync('''
library my_library;

export 'src/helper.dart';
export 'src/utils.dart';
''');

        // Create the exported files
        final srcDir = Directory(p.join(libDir.path, 'src'));
        srcDir.createSync();

        File(p.join(srcDir.path, 'helper.dart')).writeAsStringSync('''
class Helper {}
''');

        File(p.join(srcDir.path, 'utils.dart')).writeAsStringSync('''
class Utils {}
''');

        // Create main.dart that imports the library
        File(p.join(libDir.path, 'main.dart')).writeAsStringSync('''
import 'library.dart';

void main() {
  Helper();
  Utils();
}
''');

        // Should find all files including exported ones
        final allDartFiles = finder.getAllDartFiles(libDir.path);
        expect(
          allDartFiles.length,
          equals(4),
        ); // main.dart, library.dart, helper.dart, utils.dart

        // Test that entry points are found
        final entryPoints = finder.findEntryPoints(
          allDartFiles,
          libDir.path,
          '',
        );
        expect(entryPoints.length, equals(1));
        expect(entryPoints.first.endsWith('main.dart'), isTrue);
      });

      test('should handle conditional imports', () {
        // Create a mock project structure
        final projectDir = Directory(p.join(tempDir, 'test_project'));
        projectDir.createSync(recursive: true);

        final libDir = Directory(p.join(projectDir.path, 'lib'));
        libDir.createSync();

        // Create conditional import files
        File(p.join(libDir.path, 'conditional.dart')).writeAsStringSync('''
import 'dart:io' if (dart.library.html) 'dart:html' as io;

void conditionalImport() {
  io.File('test.txt');
}
''');

        // Create main.dart
        File(p.join(libDir.path, 'main.dart')).writeAsStringSync('''
import 'conditional.dart';

void main() {
  conditionalImport();
}
''');

        // Should handle conditional imports gracefully
        final allDartFiles = finder.getAllDartFiles(libDir.path);
        expect(allDartFiles.length, equals(2));

        // Test that entry points are found
        final entryPoints = finder.findEntryPoints(
          allDartFiles,
          libDir.path,
          '',
        );
        expect(entryPoints.length, equals(1));
        expect(entryPoints.first.endsWith('main.dart'), isTrue);
      });

      test('should handle part/part of directives', () {
        // Create a mock project structure
        final projectDir = Directory(p.join(tempDir, 'test_project'));
        projectDir.createSync(recursive: true);

        final libDir = Directory(p.join(projectDir.path, 'lib'));
        libDir.createSync();

        // Create main library file
        File(p.join(libDir.path, 'main_library.dart')).writeAsStringSync('''
library main_library;

part 'part_file.dart';

class MainClass {
  void doSomething() {
    PartClass().doSomething();
  }
}
''');

        // Create part file
        File(p.join(libDir.path, 'part_file.dart')).writeAsStringSync('''
part of main_library;

class PartClass {
  void doSomething() {}
}
''');

        // Create main.dart
        File(p.join(libDir.path, 'main.dart')).writeAsStringSync('''
import 'main_library.dart';

void main() {
  MainClass().doSomething();
}
''');

        // Should find all files including part files
        final allDartFiles = finder.getAllDartFiles(libDir.path);
        expect(
          allDartFiles.length,
          equals(3),
        ); // main.dart, main_library.dart, part_file.dart

        // Test that entry points are found
        final entryPoints = finder.findEntryPoints(
          allDartFiles,
          libDir.path,
          '',
        );
        expect(entryPoints.length, equals(1));
        expect(entryPoints.first.endsWith('main.dart'), isTrue);
      });
    });
  });
}
