import Flutter
import UIKit
import GoogleMaps // Google Maps SDK를 가져옵니다.

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Google Maps API 키를 제공합니다.
    GMSServices.provideAPIKey("AIzaSyCGCqVRwu3jafx3Opia4eVFEDV4n5WYbNo")

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
