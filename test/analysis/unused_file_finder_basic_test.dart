import 'package:test/test.dart';
import 'package:dart_analysis/analysis/unused_file_finder.dart';
import 'dart:io';
import 'package:path/path.dart' as p;

void main() {
  group('UnusedFileFinder - Basic Functionality', () {
    late UnusedFileFinder finder;
    late String tempDir;

    setUp(() {
      finder = UnusedFileFinder();
      tempDir = Directory.systemTemp.createTempSync('unused_file_test_').path;
    });

    tearDown(() {
      Directory(tempDir).deleteSync(recursive: true);
    });

    group('canAnalyze', () {
      test('should return true for project with lib directory', () {
        // Create a mock project structure
        final projectDir = Directory(p.join(tempDir, 'test_project'));
        projectDir.createSync(recursive: true);

        // Create lib directory
        final libDir = Directory(p.join(projectDir.path, 'lib'));
        libDir.createSync();

        expect(finder.canAnalyze(projectDir.path), isTrue);
      });

      test('should return false for project without lib directory', () {
        // Create a mock project structure without lib
        final projectDir = Directory(p.join(tempDir, 'test_project'));
        projectDir.createSync(recursive: true);

        expect(finder.canAnalyze(projectDir.path), isFalse);
      });
    });

    group('getPackageName', () {
      test('should extract package name from pubspec.yaml', () {
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

        final packageName = finder.getPackageName(projectDir.path);
        expect(packageName, equals('test_app'));
      });

      test('should return null for project without pubspec.yaml', () {
        // Create a mock project structure without pubspec.yaml
        final projectDir = Directory(p.join(tempDir, 'test_project'));
        projectDir.createSync(recursive: true);

        final packageName = finder.getPackageName(projectDir.path);
        expect(packageName, isNull);
      });
    });

    group('getAllDartFiles', () {
      test('should find all Dart files in lib directory', () {
        // Create a mock project structure
        final projectDir = Directory(p.join(tempDir, 'test_project'));
        projectDir.createSync(recursive: true);

        final libDir = Directory(p.join(projectDir.path, 'lib'));
        libDir.createSync();

        // Create some Dart files
        File(
          p.join(libDir.path, 'main.dart'),
        ).writeAsStringSync('void main() {}');
        File(
          p.join(libDir.path, 'utils.dart'),
        ).writeAsStringSync('class Utils {}');

        // Create a subdirectory with more Dart files
        final srcDir = Directory(p.join(libDir.path, 'src'));
        srcDir.createSync();
        File(
          p.join(srcDir.path, 'helper.dart'),
        ).writeAsStringSync('class Helper {}');

        // Create a non-Dart file (should be ignored)
        File(p.join(libDir.path, 'config.txt')).writeAsStringSync('config');

        final dartFiles = finder.getAllDartFiles(libDir.path);

        expect(dartFiles.length, equals(3));
        expect(dartFiles.any((f) => f.endsWith('main.dart')), isTrue);
        expect(dartFiles.any((f) => f.endsWith('utils.dart')), isTrue);
        expect(dartFiles.any((f) => f.endsWith('helper.dart')), isTrue);
        expect(dartFiles.any((f) => f.endsWith('config.txt')), isFalse);
      });

      test('should throw exception for non-existent lib directory', () {
        final libPath = p.join(tempDir, 'non_existent_lib');
        // The method should throw an exception for non-existent directories
        expect(
          () => finder.getAllDartFiles(libPath),
          throwsA(isA<PathNotFoundException>()),
        );
      });

      test('should return empty list for empty lib directory', () {
        // Create a mock project structure
        final projectDir = Directory(p.join(tempDir, 'test_project'));
        projectDir.createSync(recursive: true);

        final libDir = Directory(p.join(projectDir.path, 'lib'));
        libDir.createSync();

        final dartFiles = finder.getAllDartFiles(libDir.path);
        expect(dartFiles, isEmpty);
      });
    });

    group('findEntryPoints', () {
      test('should find main.dart as entry point', () {
        // Create a mock project structure
        final projectDir = Directory(p.join(tempDir, 'test_project'));
        projectDir.createSync(recursive: true);

        final libDir = Directory(p.join(projectDir.path, 'lib'));
        libDir.createSync();

        // Create main.dart
        File(
          p.join(libDir.path, 'main.dart'),
        ).writeAsStringSync('void main() {}');

        // Create other Dart files
        File(
          p.join(libDir.path, 'utils.dart'),
        ).writeAsStringSync('class Utils {}');

        final allDartFiles = finder.getAllDartFiles(libDir.path);
        final entryPoints = finder.findEntryPoints(
          allDartFiles,
          libDir.path,
          '',
        );

        expect(entryPoints.length, equals(1));
        expect(entryPoints.first.endsWith('main.dart'), isTrue);
      });

      test(
        'should find main.dart in Flutter project even if not in allDartFiles',
        () {
          // Create a mock Flutter project structure
          final projectDir = Directory(p.join(tempDir, 'test_project'));
          projectDir.createSync(recursive: true);

          final libDir = Directory(p.join(projectDir.path, 'lib'));
          libDir.createSync();

          // Create main.dart
          File(
            p.join(libDir.path, 'main.dart'),
          ).writeAsStringSync('void main() {}');

          // Create other Dart files
          File(
            p.join(libDir.path, 'utils.dart'),
          ).writeAsStringSync('class Utils {}');

          final allDartFiles = finder.getAllDartFiles(libDir.path);
          final pubspecContent = 'flutter:\n  uses-material-design: true';
          final entryPoints = finder.findEntryPoints(
            allDartFiles,
            libDir.path,
            pubspecContent,
          );

          expect(entryPoints.length, equals(1));
          expect(entryPoints.first.endsWith('main.dart'), isTrue);
        },
      );

      test('should return empty list when no main.dart found', () {
        // Create a mock project structure without main.dart
        final projectDir = Directory(p.join(tempDir, 'test_project'));
        projectDir.createSync(recursive: true);

        final libDir = Directory(p.join(projectDir.path, 'lib'));
        libDir.createSync();

        // Create other Dart files but no main.dart
        File(
          p.join(libDir.path, 'utils.dart'),
        ).writeAsStringSync('class Utils {}');

        final allDartFiles = finder.getAllDartFiles(libDir.path);
        final entryPoints = finder.findEntryPoints(
          allDartFiles,
          libDir.path,
          '',
        );

        expect(entryPoints, isEmpty);
      });
    });

    group('resolveUri', () {
      test('should resolve package imports correctly', () {
        // Create a mock project structure
        final projectDir = Directory(p.join(tempDir, 'test_project'));
        projectDir.createSync(recursive: true);

        final libDir = Directory(p.join(projectDir.path, 'lib'));
        libDir.createSync();

        // Create a Dart file
        File(
          p.join(libDir.path, 'utils.dart'),
        ).writeAsStringSync('class Utils {}');

        final fromFile = p.join(libDir.path, 'main.dart');
        final packageName = 'test_project';

        final resolvedPath = finder.resolveUri(
          'package:test_project/utils.dart',
          fromFile,
          libDir.path,
          packageName,
        );

        expect(resolvedPath, isNotNull);
        expect(resolvedPath!.endsWith('utils.dart'), isTrue);
      });

      test('should resolve relative imports correctly', () {
        // Create a mock project structure
        final projectDir = Directory(p.join(tempDir, 'test_project'));
        projectDir.createSync(recursive: true);

        final libDir = Directory(p.join(projectDir.path, 'lib'));
        libDir.createSync();

        // Create a subdirectory with a Dart file
        final srcDir = Directory(p.join(libDir.path, 'src'));
        srcDir.createSync();
        File(
          p.join(srcDir.path, 'helper.dart'),
        ).writeAsStringSync('class Helper {}');

        final fromFile = p.join(libDir.path, 'main.dart');

        final resolvedPath = finder.resolveUri(
          'src/helper.dart',
          fromFile,
          libDir.path,
          'test_project',
        );

        expect(resolvedPath, isNotNull);
        expect(resolvedPath!.endsWith('helper.dart'), isTrue);
      });

      test('should return null for non-existent package imports', () {
        final fromFile = p.join(tempDir, 'main.dart');

        final resolvedPath = finder.resolveUri(
          'package:nonexistent/file.dart',
          fromFile,
          tempDir,
          'test_project',
        );

        expect(resolvedPath, isNull);
      });

      test('should return null for non-existent relative imports', () {
        final fromFile = p.join(tempDir, 'main.dart');

        final resolvedPath = finder.resolveUri(
          'nonexistent.dart',
          fromFile,
          tempDir,
          'test_project',
        );

        expect(resolvedPath, isNull);
      });

      test('should return null for dart: imports', () {
        final fromFile = p.join(tempDir, 'main.dart');

        final resolvedPath = finder.resolveUri(
          'dart:io',
          fromFile,
          tempDir,
          'test_project',
        );

        expect(resolvedPath, isNull);
      });
    });

    group('Integration tests', () {
      test('should find used and unused files in simple project', () {
        // Create a mock Flutter project structure
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

        final libDir = Directory(p.join(projectDir.path, 'lib'));
        libDir.createSync();

        // Create main.dart that imports utils.dart
        File(p.join(libDir.path, 'main.dart')).writeAsStringSync('''
import 'package:test_app/utils.dart';

void main() {
  Utils.doSomething();
}
''');

        // Create utils.dart that imports helper.dart
        File(p.join(libDir.path, 'utils.dart')).writeAsStringSync('''
import 'src/helper.dart';

class Utils {
  static void doSomething() {
    Helper.help();
  }
}
''');

        // Create helper.dart
        final srcDir = Directory(p.join(libDir.path, 'src'));
        srcDir.createSync();
        File(p.join(srcDir.path, 'helper.dart')).writeAsStringSync('''
class Helper {
  static void help() {
    print('Helping!');
  }
}
''');

        // Create unused.dart (should be detected as unused)
        File(p.join(libDir.path, 'unused.dart')).writeAsStringSync('''
class UnusedClass {
  void doNothing() {}
}
''');

        // Test that the finder can analyze this project
        expect(finder.canAnalyze(projectDir.path), isTrue);

        // Test that it finds the correct number of files
        final allDartFiles = finder.getAllDartFiles(libDir.path);
        expect(
          allDartFiles.length,
          equals(4),
        ); // main.dart, utils.dart, helper.dart, unused.dart

        // Test that it finds entry points
        final entryPoints = finder.findEntryPoints(
          allDartFiles,
          libDir.path,
          'flutter:',
        );
        expect(entryPoints.length, equals(1));
        expect(entryPoints.first.endsWith('main.dart'), isTrue);

        // Test package name extraction
        final packageName = finder.getPackageName(projectDir.path);
        expect(packageName, equals('test_app'));
      });
    });
  });
}
