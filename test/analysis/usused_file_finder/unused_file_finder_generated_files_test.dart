import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:dart_analysis/analysis/unused_file_finder.dart';

void main() {
  group('UnusedFileFinder - Generated Files Handling', () {
    late UnusedFileFinder finder;
    late String tempDir;

    setUp(() {
      finder = UnusedFileFinder();
      tempDir = Directory.systemTemp.createTempSync('unused_file_finder_test_').path;
    });

    tearDown(() {
      if (Directory(tempDir).existsSync()) {
        Directory(tempDir).deleteSync(recursive: true);
      }
    });

    group('findParentFile', () {
      test('should find parent file for .g.dart with single quotes', () {
        // Create the parent file first
        _createFile(tempDir, 'parent.dart', 'class Parent {}');
        
        final generatedFile = _createGeneratedFile(
          tempDir,
          'test.g.dart',
          "part of 'parent.dart';",
        );

        final parentFile = finder.findParentFile(generatedFile.path);
        expect(parentFile, isNotNull);
        expect(p.basename(parentFile!), equals('parent.dart'));
        expect(p.dirname(parentFile), equals(p.dirname(generatedFile.path)));
      });

      test('should find parent file for .g.dart with double quotes', () {
        // Create the parent file first
        _createFile(tempDir, 'parent.dart', 'class Parent {}');
        
        final generatedFile = _createGeneratedFile(
          tempDir,
          'test.g.dart',
          'part of "parent.dart";',
        );

        final parentFile = finder.findParentFile(generatedFile.path);
        expect(parentFile, isNotNull);
        expect(p.basename(parentFile!), equals('parent.dart'));
      });

      test('should find parent file with complex path', () {
        // Create the directory structure and parent file
        final libSrcDir = Directory(p.join(tempDir, 'lib', 'src'));
        libSrcDir.createSync(recursive: true);
        _createFile(libSrcDir.path, 'parent.dart', 'class Parent {}');
        
        final generatedFile = _createGeneratedFile(
          tempDir,
          'test.g.dart',
          "part of 'lib/src/parent.dart';",
        );

        final parentFile = finder.findParentFile(generatedFile.path);
        expect(parentFile, isNotNull);
        expect(p.basename(parentFile!), equals('parent.dart'));
      });

      test('should return null for file without part of directive', () {
        final generatedFile = _createGeneratedFile(
          tempDir,
          'test.g.dart',
          '// This is not a part file\nclass Test {}',
        );

        final parentFile = finder.findParentFile(generatedFile.path);
        expect(parentFile, isNull);
      });

      test('should return null for file with malformed part of directive', () {
        final generatedFile = _createGeneratedFile(
          tempDir,
          'test.g.dart',
          "part of 'incomplete",
        );

        final parentFile = finder.findParentFile(generatedFile.path);
        expect(parentFile, isNull);
      });

      test('should return null for non-existent file', () {
        final nonExistentFile = p.join(tempDir, 'non_existent.g.dart');
        final parentFile = finder.findParentFile(nonExistentFile);
        expect(parentFile, isNull);
      });

      test('should handle file with multiple part of directives (use first)', () {
        // Create the parent files first
        _createFile(tempDir, 'first.dart', 'class First {}');
        _createFile(tempDir, 'second.dart', 'class Second {}');
        
        final generatedFile = _createGeneratedFile(
          tempDir,
          'test.g.dart',
          "part of 'first.dart';\npart of 'second.dart';",
        );

        final parentFile = finder.findParentFile(generatedFile.path);
        expect(parentFile, isNotNull);
        expect(p.basename(parentFile!), equals('first.dart'));
      });

    });

    group('filterGeneratedFiles', () {
      test('should filter out .g.dart files whose parents are not unused', () {
        final unusedFiles = <String>{
          p.join(tempDir, 'file1.dart'),
          p.join(tempDir, 'file2.dart'),
          p.join(tempDir, 'env.g.dart'), // This should be filtered out
          p.join(tempDir, 'unused_parent.dart'),
          p.join(tempDir, 'unused_parent.g.dart'), // This should stay
        };

        // Create the actual files
        _createGeneratedFile(tempDir, 'env.g.dart', "part of 'env.dart';");
        _createGeneratedFile(tempDir, 'unused_parent.g.dart', "part of 'unused_parent.dart';");
        _createFile(tempDir, 'file1.dart', 'class File1 {}');
        _createFile(tempDir, 'file2.dart', 'class File2 {}');
        _createFile(tempDir, 'unused_parent.dart', 'class UnusedParent {}');
        // Note: env.dart is NOT created, so it won't be in unusedFiles

        final filteredFiles = finder.filterGeneratedFiles(unusedFiles);

        // Should contain all non-generated files
        expect(filteredFiles.contains(p.join(tempDir, 'file1.dart')), isTrue);
        expect(filteredFiles.contains(p.join(tempDir, 'file2.dart')), isTrue);
        expect(filteredFiles.contains(p.join(tempDir, 'unused_parent.dart')), isTrue);

        // Should contain .g.dart file whose parent is also unused
        expect(filteredFiles.contains(p.join(tempDir, 'unused_parent.g.dart')), isTrue);

        // Should NOT contain .g.dart file whose parent is not unused
        expect(filteredFiles.contains(p.join(tempDir, 'env.g.dart')), isFalse);

        // Total count should be 4 (5 original - 1 filtered out)
        expect(filteredFiles.length, equals(4));
      });

      test('should keep .g.dart files whose parents are also unused', () {
        final unusedFiles = <String>{
          p.join(tempDir, 'parent.dart'),
          p.join(tempDir, 'parent.g.dart'),
        };

        // Create both files
        _createFile(tempDir, 'parent.dart', 'class Parent {}');
        _createGeneratedFile(tempDir, 'parent.g.dart', "part of 'parent.dart';");

        final filteredFiles = finder.filterGeneratedFiles(unusedFiles);

        // Both files should be kept since parent is also unused
        expect(filteredFiles.contains(p.join(tempDir, 'parent.dart')), isTrue);
        expect(filteredFiles.contains(p.join(tempDir, 'parent.g.dart')), isTrue);
        expect(filteredFiles.length, equals(2));
      });

      test('should handle files that are not .g.dart files', () {
        final unusedFiles = <String>{
          p.join(tempDir, 'regular.dart'),
          p.join(tempDir, 'another.dart'),
          p.join(tempDir, 'not_generated.dart'),
        };

        // Create regular files
        _createFile(tempDir, 'regular.dart', 'class Regular {}');
        _createFile(tempDir, 'another.dart', 'class Another {}');
        _createFile(tempDir, 'not_generated.dart', 'class NotGenerated {}');

        final filteredFiles = finder.filterGeneratedFiles(unusedFiles);

        // All regular files should be kept
        expect(filteredFiles.length, equals(3));
        expect(filteredFiles.contains(p.join(tempDir, 'regular.dart')), isTrue);
        expect(filteredFiles.contains(p.join(tempDir, 'another.dart')), isTrue);
        expect(filteredFiles.contains(p.join(tempDir, 'not_generated.dart')), isTrue);
      });

      test('should handle empty unused files set', () {
        final unusedFiles = <String>{};
        final filteredFiles = finder.filterGeneratedFiles(unusedFiles);
        expect(filteredFiles, isEmpty);
      });

      test('should handle .g.dart files with non-existent parent files', () {
        final unusedFiles = <String>{
          p.join(tempDir, 'orphaned.g.dart'),
        };

        // Create .g.dart file with non-existent parent
        _createGeneratedFile(tempDir, 'orphaned.g.dart', "part of 'non_existent.dart';");

        final filteredFiles = finder.filterGeneratedFiles(unusedFiles);

        // Should be filtered out since parent doesn't exist
        expect(filteredFiles.contains(p.join(tempDir, 'orphaned.g.dart')), isFalse);
        expect(filteredFiles, isEmpty);
      });
    });

    group('Integration tests', () {
      test('should handle real-world scenario with env.g.dart and env.dart', () {
        // Simulate the bioy-client scenario
        final unusedFiles = <String>{
          p.join(tempDir, 'some_unused_file.dart'),
          p.join(tempDir, 'env.g.dart'), // This should be filtered out
          p.join(tempDir, 'another_unused.dart'),
        };

        // Create the files
        _createFile(tempDir, 'some_unused_file.dart', 'class SomeUnused {}');
        _createGeneratedFile(tempDir, 'env.g.dart', "part of 'env.dart';");
        _createFile(tempDir, 'another_unused.dart', 'class AnotherUnused {}');
        // Note: env.dart is NOT created, so it won't be in unusedFiles

        final filteredFiles = finder.filterGeneratedFiles(unusedFiles);

        // env.g.dart should be filtered out since env.dart is not unused
        expect(filteredFiles.contains(p.join(tempDir, 'env.g.dart')), isFalse);
        
        // Other files should remain
        expect(filteredFiles.contains(p.join(tempDir, 'some_unused_file.dart')), isTrue);
        expect(filteredFiles.contains(p.join(tempDir, 'another_unused.dart')), isTrue);
        
        // Total should be 2 (3 original - 1 filtered out)
        expect(filteredFiles.length, equals(2));
      });
    });
  });
}

/// Helper function to create a generated file with specific content
File _createGeneratedFile(String dir, String filename, String content) {
  final file = File(p.join(dir, filename));
  file.writeAsStringSync(content);
  return file;
}

/// Helper function to create a regular file with specific content
File _createFile(String dir, String filename, String content) {
  final file = File(p.join(dir, filename));
  file.writeAsStringSync(content);
  return file;
}
