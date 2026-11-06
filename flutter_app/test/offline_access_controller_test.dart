import 'package:curio/features/offline/offline_access_controller.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeKnownDevices implements KnownDeviceStore {
  String? accountId;

  @override
  Future<void> clear() async => accountId = null;
  @override
  Future<void> enroll(String value) async => accountId = value;
  @override
  Future<String?> enrolledAccountId() async => accountId;
}

class _FakeDeviceUnlock implements DeviceUnlock {
  _FakeDeviceUnlock(this.allowed);
  bool allowed;
  int calls = 0;

  @override
  Future<bool> unlock() async {
    calls++;
    return allowed;
  }
}

void main() {
  late _FakeKnownDevices store;
  late _FakeDeviceUnlock device;
  late OfflineAccessController controller;

  setUp(() {
    store = _FakeKnownDevices();
    device = _FakeDeviceUnlock(true);
    controller = OfflineAccessController(
      knownDevices: store,
      deviceUnlock: device,
    );
  });

  test('known device unlocks only same restored expired-session account',
      () async {
    await controller.recordOnlineLogin('user-a');
    final decision = await controller.unlockOffline(
      restoredSessionUserId: 'user-a',
      sessionExpired: true,
    );
    expect(decision?.accountId, 'user-a');
    expect(decision?.offlineOnly, isTrue);
    expect(device.calls, 1);
  });

  test('different user cannot reuse previous account enrollment', () async {
    await controller.recordOnlineLogin('user-a');
    final result = await controller.unlockOffline(
      restoredSessionUserId: 'user-b',
      sessionExpired: true,
    );
    expect(result, isNull);
    expect(device.calls, 0);
  });

  test('no session identity cannot unlock offline', () async {
    await controller.recordOnlineLogin('user-a');
    expect(
      await controller.unlockOffline(
        restoredSessionUserId: null,
        sessionExpired: true,
      ),
      isNull,
    );
    expect(device.calls, 0);
  });

  test('only expired sessions use the separate offline unlock path', () async {
    await controller.recordOnlineLogin('user-a');
    expect(
      await controller.unlockOffline(
        restoredSessionUserId: 'user-a',
        sessionExpired: false,
      ),
      isNull,
    );
    expect(device.calls, 0);
  });

  test('device unlock refusal fails closed', () async {
    await controller.recordOnlineLogin('user-a');
    device.allowed = false;
    expect(
      await controller.unlockOffline(
        restoredSessionUserId: 'user-a',
        sessionExpired: true,
      ),
      isNull,
    );
  });

  test('account must have previously logged in online on this device',
      () async {
    expect(
      await controller.unlockOffline(
        restoredSessionUserId: 'user-a',
        sessionExpired: true,
      ),
      isNull,
    );
    expect(device.calls, 0);
    await controller.recordOnlineLogin('user-a');
    await controller.forgetDevice();
    expect(store.accountId, isNull);
    expect(
      await controller.unlockOffline(
        restoredSessionUserId: 'user-a',
        sessionExpired: true,
      ),
      isNull,
    );
  });

  test('cannot enroll empty account identity', () async {
    await expectLater(controller.recordOnlineLogin('   '),
        throwsArgumentError);
  });
}
