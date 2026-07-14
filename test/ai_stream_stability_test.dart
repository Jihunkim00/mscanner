import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mscanner/utils/async_request_gate.dart';
import 'package:mscanner/utils/sse_event_parser.dart';

void main() {
  group('SSE parser robustness', () {
    test('handles CRLF separated SSE events', () {
      final parser = SseEventParser();
      final out = parser.addChunk(
        'data: {"choices":[{"delta":{"content":"RECO"}}]}\r\n\r\n',
      );

      expect(out, hasLength(1));
      expect(out.first, contains('RECO'));
    });

    test('handles fragmented chunks and flush', () {
      final parser = SseEventParser();
      expect(parser.addChunk('data: part1'), isEmpty);
      final out = parser.addChunk('\n\ndata: [DONE]\n\n');
      expect(out, hasLength(2));
      expect(out.last, '[DONE]');
      expect(parser.flush(), isEmpty);
    });

    test('empty response event is detectable', () {
      final parser = SseEventParser();
      final out = parser.addChunk('data: [DONE]\n\n');
      expect(out, ['[DONE]']);
    });
  });

  group('Stream lifecycle guards', () {
    test('stalled stream triggers timeout', () async {
      final controller = StreamController<String>();
      addTearDown(controller.close);

      final timed = controller.stream.timeout(const Duration(milliseconds: 20));
      expectLater(timed.drain(), throwsA(isA<TimeoutException>()));
    });

    test('stream error is surfaced', () async {
      final controller = StreamController<String>();
      addTearDown(controller.close);

      Future.microtask(() => controller.addError(Exception('boom')));
      expectLater(controller.stream.drain(), throwsException);
    });

    test('request gate resets loading state and prevents duplicate race',
        () async {
      final gate = AsyncRequestGate();
      var executions = 0;

      final first = gate.run(() async {
        executions += 1;
        expect(gate.inFlight, isTrue);
        await Future<void>.delayed(const Duration(milliseconds: 25));
        throw StateError('fail once');
      });

      final second = gate.run(() async {
        executions += 1;
        return 2;
      });

      await expectLater(first, throwsA(isA<StateError>()));
      expect(second, completion(isNull));
      expect(gate.inFlight, isFalse);
      expect(executions, 1);
    });
  });
}
