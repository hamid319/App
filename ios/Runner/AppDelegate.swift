import Flutter
import UIKit
import Vision

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
    // Local notifications (check-in reminders), also while the app is open.
    UNUserNotificationCenter.current().delegate = self
    if let controller = window?.rootViewController as? FlutterViewController {
      FlutterMethodChannel(name: "swipetrip/maps", binaryMessenger: controller.binaryMessenger)
        .setMethodCallHandler { call, result in
          switch call.method {
          case "isConfigured": result(mapsConfigured)
          case "accessToken": result(mapsConfigured ? mapboxToken : nil)
          default: result(FlutterMethodNotImplemented)
          }
        }
      // Receipt scan: text recognition on the device, the photo stays here.
      FlutterMethodChannel(name: "tripfam/text_recognition", binaryMessenger: controller.binaryMessenger)
        .setMethodCallHandler { call, result in
          guard call.method == "recognize",
                let args = call.arguments as? [String: Any],
                let path = args["path"] as? String else {
            result(FlutterMethodNotImplemented)
            return
          }
          ReceiptTextRecognizer.recognize(path: path, result: result)
        }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

/// Reads the text in a photo with Apple Vision, entirely on the device.
/// Returns one entry per recognised line with its box in 0..1, y downwards.
enum ReceiptTextRecognizer {
  static func recognize(path: String, result: @escaping FlutterResult) {
    guard let image = UIImage(contentsOfFile: path), let cgImage = image.cgImage else {
      result(FlutterError(code: "unreadable", message: "Could not open the photo", details: nil))
      return
    }
    let request = VNRecognizeTextRequest { request, error in
      if let error = error {
        DispatchQueue.main.async {
          result(FlutterError(code: "vision", message: error.localizedDescription, details: nil))
        }
        return
      }
      let observations = request.results as? [VNRecognizedTextObservation] ?? []
      let lines: [[String: Any]] = observations.compactMap { observation in
        guard let text = observation.topCandidates(1).first?.string else { return nil }
        let box = observation.boundingBox // 0..1, origin bottom left
        return [
          "text": text,
          "left": Double(box.minX),
          "top": Double(1 - box.maxY),
          "right": Double(box.maxX),
          "bottom": Double(1 - box.minY),
        ]
      }
      DispatchQueue.main.async { result(lines) }
    }
    request.recognitionLevel = .accurate
    // Prices and article codes must stay as printed.
    request.usesLanguageCorrection = false
    if #available(iOS 16.0, *) {
      request.automaticallyDetectsLanguage = true
    }
    let handler = VNImageRequestHandler(
      cgImage: cgImage, orientation: CGImagePropertyOrientation(image.imageOrientation), options: [:])
    DispatchQueue.global(qos: .userInitiated).async {
      do {
        try handler.perform([request])
      } catch {
        DispatchQueue.main.async {
          result(FlutterError(code: "vision", message: error.localizedDescription, details: nil))
        }
      }
    }
  }
}

extension CGImagePropertyOrientation {
  init(_ orientation: UIImage.Orientation) {
    switch orientation {
    case .up: self = .up
    case .down: self = .down
    case .left: self = .left
    case .right: self = .right
    case .upMirrored: self = .upMirrored
    case .downMirrored: self = .downMirrored
    case .leftMirrored: self = .leftMirrored
    case .rightMirrored: self = .rightMirrored
    @unknown default: self = .up
    }
  }
}
