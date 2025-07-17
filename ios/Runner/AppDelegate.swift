import UIKit
import Flutter
import Photos

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
    let photoLocationChannel = FlutterMethodChannel(name: "io.flutter.flutter.app/photo_location",
                                              binaryMessenger: controller.binaryMessenger)

    photoLocationChannel.setMethodCallHandler({
      [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      guard call.method == "updatePhotoLocation" else {
        result(FlutterMethodNotImplemented)
        return
      }

      guard let args = call.arguments as? [String: Any],
            let localId = args["localId"] as? String,
            let latitude = args["latitude"] as? Double,
            let longitude = args["longitude"] as? Double else {
        result(false)
        return
      }

      self?.updatePhotoLocation(localId: localId, latitude: latitude, longitude: longitude, result: result)
    })

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func updatePhotoLocation(localId: String, latitude: Double, longitude: Double, result: @escaping FlutterResult) {
    let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [localId], options: nil)
    guard let asset = fetchResult.firstObject else {
      result(false)
      return
    }

    PHPhotoLibrary.shared().performChanges({
      let request = PHAssetChangeRequest(for: asset)
      request.location = CLLocation(latitude: latitude, longitude: longitude)
    }, completionHandler: { success, error in
      DispatchQueue.main.async {
        result(success)
      }
    })
  }
}