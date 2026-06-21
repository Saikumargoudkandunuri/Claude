import 'package:flutter_test/flutter_test.dart';
import 'package:icms/core/permissions/permissions.dart';

void main() {
  group('Permissions (client mirror of backend RBAC)', () {
    test('admin can do everything relevant', () {
      expect(Permissions.can('admin', 'payments:write'), isTrue);
      expect(Permissions.can('admin', 'projects:create'), isTrue);
      expect(Permissions.canControlStage('admin', 'completed'), isTrue);
      expect(Permissions.canUploadDrawings('admin'), isTrue);
    });

    test('designer controls only design stages + drawings', () {
      expect(Permissions.canControlStage('designer', '3d_design'), isTrue);
      expect(Permissions.canControlStage('designer', 'installation'), isFalse);
      expect(Permissions.canUploadDrawings('designer'), isTrue);
      expect(Permissions.canUploadMedia('designer'), isFalse);
      expect(Permissions.can('designer', 'payments:read'), isFalse);
    });

    test('supervisor controls execution stages + media, no payments', () {
      expect(Permissions.canControlStage('supervisor', 'installation'), isTrue);
      expect(Permissions.canControlStage('supervisor', 'drawing'), isFalse);
      expect(Permissions.canUploadMedia('supervisor'), isTrue);
      expect(Permissions.canUploadDrawings('supervisor'), isFalse);
      expect(Permissions.can('supervisor', 'payments:write'), isFalse);
    });

    test('worker is limited to media + own reports', () {
      expect(Permissions.canUploadMedia('worker'), isTrue);
      expect(Permissions.can('worker', 'reports:worker'), isTrue);
      expect(Permissions.canUploadDrawings('worker'), isFalse);
      expect(Permissions.can('worker', 'projects:create'), isFalse);
      expect(Permissions.canControlStage('worker', 'making'), isFalse);
    });
  });
}
