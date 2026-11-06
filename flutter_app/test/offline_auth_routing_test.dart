import 'package:curio/core/router.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('restored valid session opens home automatically', () {
    expect(authRedirect(
      hasSession: true, sessionExpired: false, route: '/login',
    ), '/home');
    expect(authRedirect(
      hasSession: true, sessionExpired: false, route: '/offline',
    ), '/home');
    expect(authRedirect(
      hasSession: true, sessionExpired: false, route: '/items',
    ), isNull);
  });

  test('expired session is restricted to offline unlock or online sign in',
      () {
    for (final route in [
      '/home', '/items', '/households', '/capture/photo',
    ]) {
      expect(authRedirect(
        hasSession: true, sessionExpired: true, route: route,
      ), '/offline');
    }
    expect(authRedirect(
      hasSession: true, sessionExpired: true, route: '/offline',
    ), isNull);
    expect(authRedirect(
      hasSession: true, sessionExpired: true, route: '/login',
    ), isNull);
  });

  test('signed-out device never uses remembered marker as cloud login', () {
    for (final route in [
      '/home', '/offline', '/items', '/capture/photo',
    ]) {
      expect(authRedirect(
        hasSession: false, sessionExpired: true, route: route,
      ), '/login');
    }
    expect(authRedirect(
      hasSession: false, sessionExpired: true, route: '/login',
    ), isNull);
  });
}
