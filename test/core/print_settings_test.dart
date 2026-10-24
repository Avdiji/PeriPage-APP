import 'package:flutter_test/flutter_test.dart';
import 'package:peripage_app/core/printing/domain/print_settings.dart';

void main() {
  group('page spec', () {
    List<int> parse(String spec, [int pages = 10]) => PrintSettings.parsePageSpec(spec, pages);

    test('single page and lists are 1-based', () {
      expect(parse('2'), [1]);
      expect(parse('1, 3 5'), [0, 2, 4]);
    });

    test('ranges, open ends and duplicates', () {
      expect(parse('2-4'), [1, 2, 3]);
      expect(parse('8-'), [7, 8, 9]);
      expect(parse('-2'), [0, 1]);
      expect(parse('1-3, 2'), [0, 1, 2]);
    });

    test('out of range and garbage are ignored', () {
      expect(parse('0, 11, abc'), isEmpty);
      expect(parse('9-20'), [8, 9]);
      expect(parse(''), isEmpty);
    });
  });

  test('legacy range selections are migrated', () {
    final settings = PrintSettings.fromJson({'pages': 'range', 'rangeStart': 1, 'rangeEnd': 3});
    expect(settings.pages, PageSelection.custom);
    expect(settings.pageIndices(10), [1, 2, 3]);
  });
}
