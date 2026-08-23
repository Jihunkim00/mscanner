import 'dart:async';

/// Keeps the first-response timeout as a non-terminal UX signal.
///
/// The underlying callable/stream owns the real timeout. This policy only
/// reports that the first response is taking longer than expected; it never
/// completes or cancels the stream itself.
class VisionStreamWaitPolicy {
  VisionStreamWaitPolicy({
    required this.onFirstResponseSlow,
    this.firstResponseTimeout = const Duration(seconds: 20),
  });

  final void Function() onFirstResponseSlow;
  final Duration firstResponseTimeout;

  Timer? _firstResponseTimer;
  bool _completed = false;
  bool _receivedFirstResponse = false;
  bool _reportedSlowResponse = false;

  bool get completed => _completed;
  bool get receivedFirstResponse => _receivedFirstResponse;
  bool get reportedSlowResponse => _reportedSlowResponse;

  static bool shouldWaitForFirstResponse({
    required bool hasResponseStream,
    required bool streamDone,
    required Iterable<String> responses,
  }) {
    return hasResponseStream &&
        !streamDone &&
        responses.every((response) => response.trim().isEmpty);
  }

  void start() {
    _firstResponseTimer?.cancel();
    _completed = false;
    _receivedFirstResponse = false;
    _reportedSlowResponse = false;
    _firstResponseTimer = Timer(firstResponseTimeout, () {
      if (_completed || _receivedFirstResponse || _reportedSlowResponse) return;

      _reportedSlowResponse = true;
      onFirstResponseSlow();
    });
  }

  void markFirstResponse() {
    if (_completed) return;
    _receivedFirstResponse = true;
    _firstResponseTimer?.cancel();
  }

  void complete() {
    _completed = true;
    _firstResponseTimer?.cancel();
    _firstResponseTimer = null;
  }

  void dispose() {
    complete();
  }
}
