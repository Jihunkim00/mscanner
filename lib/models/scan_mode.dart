enum ScanMode {
  single,
  multi,
}

extension ScanModeX on ScanMode {
  String get wireName {
    switch (this) {
      case ScanMode.single:
        return 'single';
      case ScanMode.multi:
        return 'multi';
    }
  }
}
