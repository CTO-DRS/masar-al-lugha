// Shared test double for the notification API seam (v5.12 F2.5).
//
// Records schedule/cancel calls so tests can assert against orchestrator
// behaviour without ever touching the real plugin (which needs a platform
// channel that widget tests do not provide).
import 'package:masar_al_lugha/services/notifications.dart';

class FakeNotificationApi implements NotificationApi {
  bool initCalled = false;
  bool permissionToGrant = true;
  int permissionRequests = 0;

  final List<({int id, int hour, int minute, String title, String body})>
      scheduled = [];
  final List<int> cancelled = [];

  @override
  Future<bool> init() async {
    initCalled = true;
    return true;
  }

  @override
  Future<bool> requestPermission() async {
    permissionRequests += 1;
    return permissionToGrant;
  }

  @override
  Future<void> scheduleDaily({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    scheduled.add((
      id: id,
      hour: hour,
      minute: minute,
      title: title,
      body: body,
    ));
  }

  @override
  Future<void> cancelDaily(int id) async {
    cancelled.add(id);
  }
}
