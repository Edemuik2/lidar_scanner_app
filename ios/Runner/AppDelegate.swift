import UIKit
import Flutter

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    let controller: FlutterViewController = window?.rootViewController as! FlutterViewController
    let lidarChannel = FlutterMethodChannel(name: "lidar_scanner", binaryMessenger: controller.binaryMessenger)

    lidarChannel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
        switch call.method {
        case "startScan":
            LidarScanner.shared.startScan()
            result(nil)

        case "stopScan":
            LidarScanner.shared.stopScan()
            result(nil)

        case "exportModel":
            LidarScanner.shared.exportModel { url in
                if let fileURL = url {
                    // Экспорт в Files app
                    DispatchQueue.main.async {
                        let activityVC = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
                        controller.present(activityVC, animated: true, completion: nil)
                    }
                    result(nil)
                } else {
                    result(FlutterError(code: "EXPORT_FAILED", message: "Failed to export model", details: nil))
                }
            }

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
