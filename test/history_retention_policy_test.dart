import 'package:flutter_test/flutter_test.dart';
import 'package:mscanner/services/history_retention_service.dart';

void main() {
  const policy = HistoryRetentionPolicy();

  test('free history retains the newest 20 entries', () {
    final entries = List<int>.generate(21, (index) => index);
    final deleted = policy.documentsToDelete(
      newestFirst: entries,
      isPremium: false,
    );

    expect(deleted, [20]);
  });

  test('free history deletes every entry beyond the newest 20', () {
    final entries = List<int>.generate(25, (index) => index);
    final deleted = policy.documentsToDelete(
      newestFirst: entries,
      isPremium: false,
    );

    expect(deleted, [20, 21, 22, 23, 24]);
  });

  test('premium history has no retention cap', () {
    final entries = List<int>.generate(120, (index) => index);
    expect(
      policy.documentsToDelete(newestFirst: entries, isPremium: true),
      isEmpty,
    );
  });
}
