import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/core/config.dart';

void main() {
  group('resetPasswordUrlFor', () {
    test('on web it follows the origin the app is served from', () {
      expect(
        resetPasswordUrlFor(
          isWeb: true,
          base: Uri.parse('http://localhost:5555/some/page?x=1'),
          webUrl: 'https://example.com',
        ),
        Uri.parse('http://localhost:5555/reset-password'),
      );
    });

    test('on native it points at the hosted web app', () {
      expect(
        resetPasswordUrlFor(
          isWeb: false,
          base: Uri.parse('file:///data/app/'),
          webUrl: 'https://example.com',
        ),
        Uri.parse('https://example.com/reset-password'),
      );
    });

    test('a trailing slash on the web url does not double up', () {
      expect(
        resetPasswordUrlFor(
          isWeb: false,
          base: Uri.parse('file:///'),
          webUrl: 'https://example.com/',
        ),
        Uri.parse('https://example.com/reset-password'),
      );
    });

    test('the default web url is the live site', () {
      expect(webBaseUrl, 'https://poolcoachai.kjdybl.easypanel.host');
    });
  });
}
