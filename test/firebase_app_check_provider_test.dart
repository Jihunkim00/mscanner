import "package:firebase_app_check/firebase_app_check.dart";
import "package:flutter_test/flutter_test.dart";
import "package:mscanner/services/firebase_app_check_service.dart";

void main() {
  test("Android debug selects the debug provider", () {
    expect(
      FirebaseAppCheckService.androidProvider(debug: true),
      isA<AndroidDebugProvider>(),
    );
  });

  test("Android release selects Play Integrity", () {
    expect(
      FirebaseAppCheckService.androidProvider(debug: false),
      isA<AndroidPlayIntegrityProvider>(),
    );
  });

  test("Apple debug selects the debug provider", () {
    expect(
      FirebaseAppCheckService.appleProvider(debug: true),
      isA<AppleDebugProvider>(),
    );
  });

  test("Apple release selects App Attest with Device Check fallback", () {
    expect(
      FirebaseAppCheckService.appleProvider(debug: false),
      isA<AppleAppAttestWithDeviceCheckFallbackProvider>(),
    );
  });
}
