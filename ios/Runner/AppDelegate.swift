import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Mapbox public token from ios/Flutter/Secrets.xcconfig (git-ignored)
    // via Info.plist. Without one the map screens show a notice instead of
    // an empty map; Dart asks for it over the channel below.
    let mapboxToken = (Bundle.main.object(forInfoDictionaryKey: "MBXAccessToken") as? String)?
      .trimmingCharacters(in: .whitespaces) ?? ""
    let mapsConfigured = !mapboxToken.isEmpty && !mapboxToken.hasPrefix("$(")
    GeneratedPluginRegistrant.register(with: self)
    if let controller = window?.rootViewController as? FlutterViewController {
      FlutterMethodChannel(name: "swipetrip/maps", binaryMessenger: controller.binaryMessenger)
        .setMethodCallHandler { call, result in
          switch call.method {
          case "isConfigured": result(mapsConfigured)
          case "accessToken": result(mapsConfigured ? mapboxToken : nil)
          default: result(FlutterMethodNotImplemented)
          }
        }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
