import "package:firebase_app_check/firebase_app_check.dart";
import "package:flutter/foundation.dart";

/// App Check provider selection for the observation-only PR12 rollout.
class FirebaseAppCheckService {
  static AndroidAppCheckProvider androidProvider({required bool debug}) {
    return debug
        ? const AndroidDebugProvider()
        : const AndroidPlayIntegrityProvider();
  }

  static AppleAppCheckProvider appleProvider({required bool debug}) {
    return debug
        ? const AppleDebugProvider()
        : const AppleAppAttestWithDeviceCheckFallbackProvider();
  }

  static Future<void> activate({bool? debug}) async {
    final useDebugProvider = debug ?? kDebugMode;
    await FirebaseAppCheck.instance.activate(
      providerAndroid: androidProvider(debug: useDebugProvider),
      providerApple: appleProvider(debug: useDebugProvider),
    );
    await FirebaseAppCheck.instance.setTokenAutoRefreshEnabled(true);
  }
}
