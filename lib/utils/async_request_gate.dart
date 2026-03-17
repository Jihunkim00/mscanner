class AsyncRequestGate {
  bool _inFlight = false;

  bool get inFlight => _inFlight;

  Future<T?> run<T>(Future<T> Function() operation) async {
    if (_inFlight) return null;
    _inFlight = true;
    try {
      return await operation();
    } finally {
      _inFlight = false;
    }
  }
}