import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mscanner/screens/result/vision_stream_wait_policy.dart';
import 'package:mscanner/screens/result/result_parsing_service.dart';
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

  group('Vision first-response waiting policy', () {
    test('response before the threshold does not show a slow hint', () async {
      var slowHintCount = 0;
      final policy = VisionStreamWaitPolicy(
        firstResponseTimeout: const Duration(milliseconds: 20),
        onFirstResponseSlow: () => slowHintCount += 1,
      )..start();
      addTearDown(policy.dispose);

      await Future<void>.delayed(const Duration(milliseconds: 5));
      policy.markFirstResponse();
      await Future<void>.delayed(const Duration(milliseconds: 25));

      expect(slowHintCount, 0);
      expect(policy.receivedFirstResponse, isTrue);
      expect(policy.completed, isFalse);
    });

    test('slow first response is UX-only and keeps the stream subscribed',
        () async {
      final controller = StreamController<String>();
      var slowHintCount = 0;
      final policy = VisionStreamWaitPolicy(
        firstResponseTimeout: const Duration(milliseconds: 20),
        onFirstResponseSlow: () => slowHintCount += 1,
      )..start();
      addTearDown(policy.dispose);

      var received = '';
      final subscription = controller.stream.listen((value) {
        policy.markFirstResponse();
        received += value;
      }, onDone: () {
        policy.complete();
      });
      addTearDown(subscription.cancel);

      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(slowHintCount, 1);
      expect(policy.completed, isFalse);
      expect(controller.hasListener, isTrue);

      controller.add('{recommended:[]}');
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(received, '{recommended:[]}');
      expect(policy.receivedFirstResponse, isTrue);

      await controller.close();
    });

    test('late response can arrive after the waiting hint and complete',
        () async {
      var slowHintShown = false;
      final policy = VisionStreamWaitPolicy(
        firstResponseTimeout: const Duration(milliseconds: 20),
        onFirstResponseSlow: () => slowHintShown = true,
      )..start();
      addTearDown(policy.dispose);

      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(slowHintShown, isTrue);
      expect(policy.completed, isFalse);

      policy.markFirstResponse();
      policy.complete();
      expect(policy.receivedFirstResponse, isTrue);
      expect(policy.completed, isTrue);
    });

    test('late structured response keeps recommendations and full menu usable',
        () async {
      var slowHintShown = false;
      final policy = VisionStreamWaitPolicy(
        firstResponseTimeout: const Duration(milliseconds: 20),
        onFirstResponseSlow: () => slowHintShown = true,
      )..start();
      addTearDown(policy.dispose);

      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(slowHintShown, isTrue);

      final lateResponse = jsonEncode({
        'isMenu': true,
        'recommended': [
          {'nameOriginal': 'Recommended dish', 'name': 'Recommended dish'},
        ],
        'fullMenu': {
          'items': {
            'main': [
              {'nameOriginal': 'Full menu dish', 'name': 'Full menu dish'},
            ],
          },
        },
      });
      policy.markFirstResponse();

      final parsed = ResultParsingService.parseAiJson(
        responses: [lateResponse],
        imageCount: 4,
      );
      expect(policy.completed, isFalse);
      expect(ResultParsingService.getRecommendedItems(parsed.aiJson),
          hasLength(1));
      expect(ResultParsingService.hasUsableFullMenu(parsed.aiJson), isTrue);

      policy.complete();
      expect(policy.completed, isTrue);
    });

    test('actual stream error remains terminal', () async {
      final controller = StreamController<String>();
      var terminalFailure = false;
      final policy = VisionStreamWaitPolicy(
        firstResponseTimeout: const Duration(milliseconds: 20),
        onFirstResponseSlow: () {},
      )..start();
      addTearDown(policy.dispose);

      final subscription = controller.stream.listen(
        (_) {},
        onError: (Object error, StackTrace stackTrace) {
          terminalFailure = true;
          policy.complete();
        },
      );
      addTearDown(subscription.cancel);

      controller.addError(StateError('stream failed'));
      await Future<void>.delayed(const Duration(milliseconds: 5));

      expect(terminalFailure, isTrue);
      expect(policy.completed, isTrue);
    });

    test('empty stream completion remains terminal', () async {
      final controller = StreamController<String>();
      var terminalFailure = false;
      final policy = VisionStreamWaitPolicy(
        firstResponseTimeout: const Duration(milliseconds: 20),
        onFirstResponseSlow: () {},
      )..start();
      addTearDown(policy.dispose);

      final subscription = controller.stream.listen(
        (_) {},
        onDone: () {
          terminalFailure = true;
          policy.complete();
        },
      );
      addTearDown(subscription.cancel);

      await controller.close();

      expect(terminalFailure, isTrue);
      expect(policy.completed, isTrue);
    });

    test('active empty responses are waiting, not parse failure', () {
      expect(
        VisionStreamWaitPolicy.shouldWaitForFirstResponse(
          hasResponseStream: true,
          streamDone: false,
          responses: const <String>[],
        ),
        isTrue,
      );
      expect(
        VisionStreamWaitPolicy.shouldWaitForFirstResponse(
          hasResponseStream: true,
          streamDone: true,
          responses: const <String>[],
        ),
        isFalse,
      );
    });
  });
}
