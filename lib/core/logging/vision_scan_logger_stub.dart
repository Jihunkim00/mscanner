void visionScanDebugPrint(String message) {
  // ignore: avoid_print
  print(message);
}

void visionScanDebugPrintStack({
  required String label,
  required StackTrace stackTrace,
}) {
  // ignore: avoid_print
  print(label);
  // ignore: avoid_print
  print(stackTrace);
}
