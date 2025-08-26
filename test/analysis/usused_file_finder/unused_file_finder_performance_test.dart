import 'package:test/test.dart';
import 'package:dart_analysis/analysis/unused_file_finder.dart';
import 'dart:io';
import 'package:path/path.dart' as p;

void main() {
  group('UnusedFileFinder - Performance & Scalability', () {
    late UnusedFileFinder finder;
    late String tempDir;

    setUp(() {
      finder = UnusedFileFinder();
      tempDir = Directory.systemTemp.createTempSync('unused_file_test_').path;
    });

    tearDown(() {
      Directory(tempDir).deleteSync(recursive: true);
    });

    group('Performance & Scalability', () {
      test('should handle large number of files efficiently', () {
        // Create a mock project with many files
        final projectDir = Directory(p.join(tempDir, 'test_project'));
        projectDir.createSync(recursive: true);

        final libDir = Directory(p.join(projectDir.path, 'lib'));
        libDir.createSync();

        // Create many Dart files
        for (int i = 0; i < 100; i++) {
          File(p.join(libDir.path, 'file_$i.dart')).writeAsStringSync('''
class File$i {
  void doSomething() {}
}
''');
        }

        // Create main.dart that imports a few files
        File(p.join(libDir.path, 'main.dart')).writeAsStringSync('''
import 'file_0.dart';
import 'file_50.dart';

void main() {
  File0().doSomething();
  File50().doSomething();
}
''');

        // Should handle large number of files without performance issues
        final allDartFiles = finder.getAllDartFiles(libDir.path);
        expect(allDartFiles.length, equals(101)); // 100 files + main.dart

        // Test that entry points are found
        final entryPoints = finder.findEntryPoints(
          allDartFiles,
          libDir.path,
          '',
        );
        expect(entryPoints.length, equals(1));
        expect(entryPoints.first.endsWith('main.dart'), isTrue);
      });

      test('should handle complex import chains efficiently', () {
        // Create a mock project with complex import chains
        final projectDir = Directory(p.join(tempDir, 'test_project'));
        projectDir.createSync(recursive: true);

        final libDir = Directory(p.join(projectDir.path, 'lib'));
        libDir.createSync();

        // Create a chain of files that import each other
        for (int i = 0; i < 20; i++) {
          final nextFile = i < 19 ? 'chain_${i + 1}.dart' : '';
          final importStatement = nextFile.isNotEmpty
              ? "import '$nextFile';"
              : '';

          File(p.join(libDir.path, 'chain_$i.dart')).writeAsStringSync('''
$importStatement

class Chain$i {
  void doSomething() {
    ${nextFile.isNotEmpty ? 'Chain${i + 1}().doSomething();' : ''}
  }
}
''');
        }

        // Create main.dart that starts the chain
        File(p.join(libDir.path, 'main.dart')).writeAsStringSync('''
import 'chain_0.dart';

void main() {
  Chain0().doSomething();
}
''');

        // Should handle complex import chains efficiently
        final allDartFiles = finder.getAllDartFiles(libDir.path);
        expect(allDartFiles.length, equals(21)); // 20 chain files + main.dart

        // Test that entry points are found
        final entryPoints = finder.findEntryPoints(
          allDartFiles,
          libDir.path,
          '',
        );
        expect(entryPoints.length, equals(1));
        expect(entryPoints.first.endsWith('main.dart'), isTrue);
      });

      test('should handle deep directory nesting efficiently', () {
        // Create a mock project with deeply nested directories
        final projectDir = Directory(p.join(tempDir, 'test_project'));
        projectDir.createSync(recursive: true);

        final libDir = Directory(p.join(projectDir.path, 'lib'));
        libDir.createSync();

        // Create deeply nested directory structure with files
        var currentDir = libDir;
        for (int i = 0; i < 15; i++) {
          currentDir = Directory(p.join(currentDir.path, 'level_$i'));
          currentDir.createSync();

          // Create a Dart file at each level
          File(p.join(currentDir.path, 'file_level_$i.dart')).writeAsStringSync(
            '''
class FileLevel$i {
  void doSomething() {}
}
''',
          );
        }

        // Create main.dart that imports files from different levels
        File(p.join(libDir.path, 'main.dart')).writeAsStringSync('''
import 'level_0/file_level_0.dart';
import 'level_0/level_1/level_2/file_level_2.dart';
import 'level_0/level_1/level_2/level_3/level_4/level_5/level_6/level_7/level_8/level_9/level_10/level_11/level_12/level_13/level_14/file_level_14.dart';

void main() {
  FileLevel0().doSomething();
  FileLevel2().doSomething();
  FileLevel14().doSomething();
}
''');

        // Should handle deep nesting efficiently
        final allDartFiles = finder.getAllDartFiles(libDir.path);
        expect(allDartFiles.length, equals(16)); // 15 level files + main.dart

        // Test that entry points are found
        final entryPoints = finder.findEntryPoints(
          allDartFiles,
          libDir.path,
          '',
        );
        expect(entryPoints.length, equals(1));
        expect(entryPoints.first.endsWith('main.dart'), isTrue);
      });

      test('should handle mixed file types efficiently', () {
        // Create a mock project with mixed file types
        final projectDir = Directory(p.join(tempDir, 'test_project'));
        projectDir.createSync(recursive: true);

        final libDir = Directory(p.join(projectDir.path, 'lib'));
        libDir.createSync();

        // Create many Dart files
        for (int i = 0; i < 50; i++) {
          File(p.join(libDir.path, 'dart_file_$i.dart')).writeAsStringSync('''
class DartFile$i {
  void doSomething() {}
}
''');
        }

        // Create many non-Dart files (should be ignored)
        for (int i = 0; i < 100; i++) {
          File(
            p.join(libDir.path, 'text_file_$i.txt'),
          ).writeAsStringSync('Text content $i');
          File(
            p.join(libDir.path, 'json_file_$i.json'),
          ).writeAsStringSync('{"key": "value$i"}');
          File(
            p.join(libDir.path, 'yaml_file_$i.yaml'),
          ).writeAsStringSync('key: value$i');
        }

        // Create main.dart
        File(p.join(libDir.path, 'main.dart')).writeAsStringSync('''
import 'dart_file_0.dart';
import 'dart_file_25.dart';

void main() {
  DartFile0().doSomething();
  DartFile25().doSomething();
}
''');

        // Should only find Dart files efficiently
        final allDartFiles = finder.getAllDartFiles(libDir.path);
        expect(allDartFiles.length, equals(51)); // 50 dart files + main.dart

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
