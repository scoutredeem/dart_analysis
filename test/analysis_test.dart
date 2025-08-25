import 'package:test/test.dart';
import 'package:dart_analysis/analysis.dart';

void main() {
  group('Analyzer Architecture Tests', () {
    test('AnalyzerRegistry should have analyzers', () {
      expect(AnalyzerRegistry.analyzers, isNotEmpty);
      expect(AnalyzerRegistry.analyzers.length, equals(3));
    });

    test('UnusedFileFinder should implement BaseAnalyzer', () {
      final finder = UnusedFileFinder();
      expect(finder, isA<BaseAnalyzer>());
      expect(finder.name, equals('Unused file finder'));
      expect(finder.description, isNotEmpty);
    });

    test('UnusedTranslationFinder should implement BaseAnalyzer', () {
      final finder = UnusedTranslationFinder();
      expect(finder, isA<BaseAnalyzer>());
      expect(finder.name, equals('Unused translation finder'));
      expect(finder.description, isNotEmpty);
    });

    test('UnusedPackageFinder should implement BaseAnalyzer', () {
      final finder = UnusedPackageFinder();
      expect(finder, isA<BaseAnalyzer>());
      expect(finder.name, equals('Unused package finder'));
      expect(finder.description, isNotEmpty);
    });

    test('AnalyzerRegistry should get analyzer by index', () {
      final analyzer = AnalyzerRegistry.getAnalyzer(0);
      expect(analyzer, isNotNull);
      expect(analyzer!.name, equals('Unused file finder'));
    });

    test('AnalyzerRegistry should get analyzer by name', () {
      final analyzer = AnalyzerRegistry.getAnalyzerByName(
        'Unused translation finder',
      );
      expect(analyzer, isNotNull);
      expect(analyzer!.name, equals('Unused translation finder'));
    });

    test('AnalyzerRegistry should get options', () {
      final options = AnalyzerRegistry.getOptions();
      expect(options, contains('Unused file finder'));
      expect(options, contains('Unused translation finder'));
      expect(options, contains('Unused package finder'));
    });

    test('AnalyzerUtils should have common asset directories', () {
      final dirs = AnalyzerUtils.getCommonAssetDirectories();
      expect(dirs, contains('assets'));
      expect(dirs, contains('images'));
      expect(dirs, contains('fonts'));
    });

    test('AnalyzerUtils should have common image extensions', () {
      final exts = AnalyzerUtils.getCommonImageExtensions();
      expect(exts, contains('.png'));
      expect(exts, contains('.jpg'));
      expect(exts, contains('.svg'));
    });
  });
}
