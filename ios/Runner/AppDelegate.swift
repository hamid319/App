import Flutter
import GoogleMaps
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Maps SDK key from ios/Flutter/Secrets.xcconfig (git-ignored) via
    // Info.plist. Without a key the map screens show a notice instead
    // of crashing; Dart asks over the channel below.
    let mapsKey = (Bundle.main.object(forInfoDictionaryKey: "GMSApiKey") as? String)?
      .trimmingCharacters(in: .whitespaces) ?? ""
    let mapsConfigured = !mapsKey.isEmpty && !mapsKey.hasPrefix("$(")
    if mapsConfigured {
      GMSServices.provideAPIKey(mapsKey)
    }
    GeneratedPluginRegistrant.register(with: self)
    if let controller = window?.rootViewController as? FlutterViewController {
      FlutterMethodChannel(name: "swipetrip/maps", binaryMessenger: controller.binaryMessenger)
        .setMethodCallHandler { call, result in
          result(call.method == "isConfigured" ? mapsConfigured : FlutterMethodNotImplemented)
        }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
