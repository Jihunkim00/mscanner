import 'package:flutter_test/flutter_test.dart';
import 'package:mscanner/l10n/gen_l10n/app_localizations_en.dart';
import 'package:mscanner/services/history_retention_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const policy = HistoryRetentionPolicy();

  test('free history under the limit does not trigger a notice', () {
    final entries = List<int>.generate(20, (index) => index);
    final deleted = policy.documentsToDelete(
      newestFirst: entries,
      isPremium: false,
    );

    expect(deleted, isEmpty);
    expect(
      HistoryRetentionResult(deletedCount: deleted.length).oldestHistoryRemoved,
      isFalse,
    );
  });

  test('free 21st history entry removes the oldest and triggers a notice', () {
    final entries = List<int>.generate(21, (index) => index);
    final deleted = policy.documentsToDelete(
      newestFirst: entries,
      isPremium: false,
    );

    expect(deleted, [20]);
    expect(
      HistoryRetentionResult(deletedCount: deleted.length).oldestHistoryRemoved,
      isTrue,
    );
  });

  test('guest history follows the same 20-entry retention policy', () {
    final entries = List<int>.generate(21, (index) => index);
    expect(
      policy.documentsToDelete(newestFirst: entries, isPremium: false),
      [20],
    );
  });

  test('premium history has no retention cap or notice', () {
    final entries = List<int>.generate(120, (index) => index);
    expect(
      policy.documentsToDelete(newestFirst: entries, isPremium: true),
      isEmpty,
    );
    expect(
      const HistoryRetentionResult.none().oldestHistoryRemoved,
      isFalse,
    );
  });

  test('limit notice is shown at most once per local day', () async {
    SharedPreferences.setMockInitialValues({});
    final service = HistoryLimitNoticeService();
    final day = DateTime(2026, 9, 5, 12);

    expect(await service.claimForToday(now: day), isTrue);
    expect(await service.claimForToday(now: day), isFalse);
    expect(
      await service.claimForToday(now: day.add(const Duration(days: 1))),
      isTrue,
    );
  });

  test('localized limit notice uses the retention policy limit', () {
    final message = AppLocalizationsEn().historyLimitReachedMessage(
      HistoryRetentionPolicy.freeHistoryLimit,
    );

    expect(message, contains('20'));
  });
}
