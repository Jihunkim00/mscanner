import 'package:flutter/foundation.dart';

void visionScanDebugPrint(String message) {
  debugPrint(message);
}

void visionScanDebugPrintStack({
  required String label,
  required StackTrace stackTrace,
}) {
  debugPrintStack(label: label, stackTrace: stackTrace);
}
