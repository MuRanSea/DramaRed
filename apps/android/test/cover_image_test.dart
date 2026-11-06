import 'package:dramared/widgets/cover_image.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('looksHeic detects extension in signed CDN urls', () {
    expect(
      CoverImage.looksHeic(
        'https://p3-reading-sign.fqnovelpic.com/x~tplv:400:0.heic?x-signature=a',
      ),
      isTrue,
    );
    expect(CoverImage.looksHeic('https://cdn.example/cover.jpg'), isFalse);
    expect(CoverImage.looksHeic(''), isFalse);
  });
}
