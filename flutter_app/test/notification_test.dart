import 'package:flutter_test/flutter_test.dart';
import 'package:vaktet/src/logic/cities.dart';
import 'package:vaktet/src/logic/day.dart';
import 'package:vaktet/src/state/notification_service.dart';

void main() {
  test('buildSchedule generates upcoming enabled prayers with unique IDs and early reminder offsets', () {
    final city = cityById('prishtina');
    final nowUtc = DateTime.utc(2026, 6, 15, 0, 1).millisecondsSinceEpoch;
    final enabled = {for (final p in NotifyPrayer.values) p: p.byDefault};

    final exact = NotificationService.buildSchedule(
      city: city,
      enabled: enabled,
      beforeMin: 0,
      nowUtcMs: nowUtc,
      days: 7,
    );
    // 5 default prayers (Imsaku, Dreka, Ikindia, Akshami, Jacia) * 7 days = 35 alarms
    expect(exact.length, 35);
    final ids = exact.map((e) => e['id'] as int).toSet();
    expect(ids.length, 35);
    expect(exact.every((e) => (e['triggerAtMs'] as int) > nowUtc), isTrue);
    expect(exact.any((e) => (e['title'] as String).startsWith('Lindja e diellit')), isFalse);

    final early = NotificationService.buildSchedule(
      city: city,
      enabled: enabled,
      beforeMin: 15,
      nowUtcMs: nowUtc,
      days: 7,
    );
    expect(early.length, 35);
    expect((exact.first['triggerAtMs'] as int) - (early.first['triggerAtMs'] as int), 15 * msPerMinute);
    expect((early.first['title'] as String), contains('pas 15 min'));
  });
}
