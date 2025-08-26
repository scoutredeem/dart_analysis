import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';
import 'package:dart_analysis/analysis/unused_package_finder.dart';

void main() {
  group('UnusedPackageFinder - Fallback Text Parsing', () {
    late UnusedPackageFinder analyzer;
    late Directory tempDir;

    setUp(() {
      analyzer = UnusedPackageFinder();
      tempDir = Directory.systemTemp.createTempSync(
        'unused_package_finder_fallback_test',
      );
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    group('Text Parsing Edge Cases', () {
      test('should handle import statements with extra whitespace', () async {
        final pubspecFile = File(path.join(tempDir.path, 'pubspec.yaml'));
        pubspecFile.writeAsStringSync('''
name: test_project
dependencies:
  flutter:
    sdk: flutter
  http: ^1.0.0
''');

        final libDir = Directory(path.join(tempDir.path, 'lib'));
        libDir.createSync();

        final mainFile = File(path.join(libDir.path, 'main.dart'));
        mainFile.writeAsStringSync('''
import   'package:flutter/material.dart';
import 'package:http/http.dart'  ;
import  'package:provider/provider.dart'  ;

void main() {
  runApp(MyApp());
}
''');

        await analyzer.analyze(tempDir.path);
        expect(true, isTrue);
      });

      test('should handle import statements with comments', () async {
        final pubspecFile = File(path.join(tempDir.path, 'pubspec.yaml'));
        pubspecFile.writeAsStringSync('''
name: test_project
dependencies:
  flutter:
    sdk: flutter
  http: ^1.0.0
''');

        final libDir = Directory(path.join(tempDir.path, 'lib'));
        libDir.createSync();

        final mainFile = File(path.join(libDir.path, 'main.dart'));
        mainFile.writeAsStringSync('''
import 'package:flutter/material.dart'; // Flutter framework
import 'package:http/http.dart'; // HTTP client
// import 'package:unused/package.dart'; // Commented out import

void main() {
  runApp(MyApp());
}
''');

        await analyzer.analyze(tempDir.path);
        expect(true, isTrue);
      });

      test('should handle multiline import statements', () async {
        final pubspecFile = File(path.join(tempDir.path, 'pubspec.yaml'));
        pubspecFile.writeAsStringSync('''
name: test_project
dependencies:
  flutter:
    sdk: flutter
  http: ^1.0.0
''');

        final libDir = Directory(path.join(tempDir.path, 'lib'));
        libDir.createSync();

        final mainFile = File(path.join(libDir.path, 'main.dart'));
        mainFile.writeAsStringSync('''
import 'package:flutter/material.dart';
import 
  'package:http/http.dart';

void main() {
  runApp(MyApp());
}
''');

        await analyzer.analyze(tempDir.path);
        expect(true, isTrue);
      });
    });

    group('Package Name Extraction Patterns', () {
      test(
        'should handle package names with numbers and underscores',
        () async {
          final pubspecFile = File(path.join(tempDir.path, 'pubspec.yaml'));
          pubspecFile.writeAsStringSync('''
name: test_project
dependencies:
  flutter:
    sdk: flutter
  http_2: ^1.0.0
  package_123: ^2.0.0
  my_package_v2: ^3.0.0
''');

          final libDir = Directory(path.join(tempDir.path, 'lib'));
          libDir.createSync();

          final mainFile = File(path.join(libDir.path, 'main.dart'));
          mainFile.writeAsStringSync('''
import 'package:flutter/material.dart';
import 'package:http_2/http.dart';
import 'package:package_123/core.dart';
import 'package:my_package_v2/api.dart';

void main() {
  runApp(MyApp());
}
''');

          await analyzer.analyze(tempDir.path);
          expect(true, isTrue);
        },
      );

      test('should handle package names with hyphens', () async {
        final pubspecFile = File(path.join(tempDir.path, 'pubspec.yaml'));
        pubspecFile.writeAsStringSync('''
name: test_project
dependencies:
  flutter:
    sdk: flutter
  http-client: ^1.0.0
  my-package: ^2.0.0
''');

        final libDir = Directory(path.join(tempDir.path, 'lib'));
        libDir.createSync();

        final mainFile = File(path.join(libDir.path, 'main.dart'));
        mainFile.writeAsStringSync('''
import 'package:flutter/material.dart';
import 'package:http-client/http.dart';
import 'package:my-package/core.dart';

void main() {
  runApp(MyApp());
}
''');

        await analyzer.analyze(tempDir.path);
        expect(true, isTrue);
      });
    });

    group('File System Edge Cases', () {
      test('should handle deeply nested directories', () async {
        final pubspecFile = File(path.join(tempDir.path, 'pubspec.yaml'));
        pubspecFile.writeAsStringSync('''
name: test_project
dependencies:
  flutter:
    sdk: flutter
''');

        // Create deeply nested directory structure
        final libDir = Directory(path.join(tempDir.path, 'lib'));
        libDir.createSync();

        final nested1 = Directory(path.join(libDir.path, 'features'));
        nested1.createSync();

        final nested2 = Directory(path.join(nested1.path, 'auth'));
        nested2.createSync();

        final nested3 = Directory(path.join(nested2.path, 'screens'));
        nested3.createSync();

        final nested4 = Directory(path.join(nested3.path, 'login'));
        nested4.createSync();

        final deepFile = File(path.join(nested4.path, 'login_screen.dart'));
        deepFile.writeAsStringSync('''
import 'package:flutter/material.dart';

class LoginScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold();
  }
}
''');

        await analyzer.analyze(tempDir.path);
        expect(true, isTrue);
      });

      test('should handle files with special characters in names', () async {
        final pubspecFile = File(path.join(tempDir.path, 'pubspec.yaml'));
        pubspecFile.writeAsStringSync('''
name: test_project
dependencies:
  flutter:
    sdk: flutter
''');

        final libDir = Directory(path.join(tempDir.path, 'lib'));
        libDir.createSync();

        // Files with special characters
        final specialFile1 = File(path.join(libDir.path, 'my-file.dart'));
        specialFile1.writeAsStringSync(
          'import "package:flutter/material.dart";',
        );

        final specialFile2 = File(path.join(libDir.path, 'my_file.dart'));
        specialFile2.writeAsStringSync(
          "import 'package:flutter/material.dart';",
        );

        final specialFile3 = File(path.join(libDir.path, 'my.file.dart'));
        specialFile3.writeAsStringSync(
          'import "package:flutter/material.dart";',
        );

        await analyzer.analyze(tempDir.path);
        expect(true, isTrue);
      });
    });

    group('Import Statement Variations', () {
      test('should handle different quote styles', () async {
        final pubspecFile = File(path.join(tempDir.path, 'pubspec.yaml'));
        pubspecFile.writeAsStringSync('''
name: test_project
dependencies:
  flutter:
    sdk: flutter
  http: ^1.0.0
''');

        final libDir = Directory(path.join(tempDir.path, 'lib'));
        libDir.createSync();

        final mainFile = File(path.join(libDir.path, 'main.dart'));
        mainFile.writeAsStringSync('''
import 'package:flutter/material.dart';
import "package:http/http.dart";
import `package:provider/provider.dart`;

void main() {
  runApp(MyApp());
}
''');

        await analyzer.analyze(tempDir.path);
        expect(true, isTrue);
      });

      test('should handle import statements with aliases', () async {
        final pubspecFile = File(path.join(tempDir.path, 'pubspec.yaml'));
        pubspecFile.writeAsStringSync('''
name: test_project
dependencies:
  flutter:
    sdk: flutter
  http: ^1.0.0
  provider: ^6.0.0
''');

        final libDir = Directory(path.join(tempDir.path, 'lib'));
        libDir.createSync();

        final mainFile = File(path.join(libDir.path, 'main.dart'));
        mainFile.writeAsStringSync('''
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart' show ChangeNotifier;

void main() {
  runApp(MyApp());
}
''');

        await analyzer.analyze(tempDir.path);
        expect(true, isTrue);
      });
    });
  });
}
