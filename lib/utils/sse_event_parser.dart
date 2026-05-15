class SseEventParser {
  String _buffer = '';

  List<String> addChunk(String chunk) {
    if (chunk.isEmpty) return const [];
    _buffer += chunk.replaceAll('\r\n', '\n');
    return _drainCompleteEvents();
  }

  List<String> flush() {
    if (_buffer.isEmpty) return const [];
    final normalized = _buffer.replaceAll('\r\n', '\n').trim();
    _buffer = '';
    if (normalized.isEmpty) return const [];
    return _extractDataLines(normalized);
  }

  List<String> _drainCompleteEvents() {
    final payloads = <String>[];
    while (true) {
      final splitIdx = _buffer.indexOf('\n\n');
      if (splitIdx == -1) break;

      final event = _buffer.substring(0, splitIdx);
      _buffer = _buffer.substring(splitIdx + 2);
      payloads.addAll(_extractDataLines(event));
    }
    return payloads;
  }

  List<String> _extractDataLines(String event) {
    final out = <String>[];
    for (final raw in event.split('\n')) {
      final line = raw.trim();
      if (!line.startsWith('data:')) continue;
      final data = line.substring(5).trim();
      if (data.isNotEmpty) out.add(data);
    }
    return out;
  }
}
