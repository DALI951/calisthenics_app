import 'package:calisthenics_app/features/auth/domain/app_user.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('displayLabel', () {
    test('displayName wins over username and email handle', () {
      const user = AppUser(
        id: '1',
        displayName: 'Dali',
        username: 'dali951',
        email: 'dali@example.com',
      );
      expect(user.displayLabel, 'Dali');
    });

    test('falls back to username when no display name', () {
      const user = AppUser(
        id: '1',
        username: 'dali951',
        email: 'dali@example.com',
      );
      expect(user.displayLabel, 'dali951');
    });

    test('falls back to email handle', () {
      const user = AppUser(id: '1', email: 'dali@example.com');
      expect(user.displayLabel, 'dali');
    });

    test('blank display name is skipped', () {
      const user = AppUser(
        id: '1',
        displayName: '   ',
        email: 'dali@example.com',
      );
      expect(user.displayLabel, 'dali');
    });

    test('ultimate fallback', () {
      const user = AppUser(id: '1');
      expect(user.displayLabel, 'Athlete');
    });
  });

  group('initial', () {
    test('uses first character, uppercased', () {
      const user = AppUser(id: '1', displayName: 'ali');
      expect(user.initial, 'A');
    });

    test('always returns a letter, even for fallback labels', () {
      const user = AppUser(id: '1', email: '@');
      // displayLabel falls back to 'Athlete', so initial is 'A'.
      expect(user.displayLabel, 'Athlete');
      expect(user.initial, 'A');
    });
  });

  group('json round-trip', () {
    test('toJson → fromJson preserves identity fields', () {
      const user = AppUser(
        id: 'abc123',
        email: 'dali@example.com',
        displayName: 'Dali',
        username: 'dali951',
        photoUrl: 'https://example.com/a.png',
        emailVerified: true,
      );
      final restored = AppUser.fromJson(user.toJson());
      expect(restored, user);
    });
  });
}
