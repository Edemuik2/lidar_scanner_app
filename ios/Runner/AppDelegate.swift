import UIKit
import Flutter

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  private var lidarScanner: LidarScanner?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    let controller = window?.rootViewController as! FlutterViewController
    let channel = FlutterMethodChannel(name: "lidar_scanner_channel",
                                       binaryMessenger: controller.binaryMessenger)

    if #available(iOS 13.4, *) {
      lidarScanner = LidarScanner(viewController: controller)
    }

    channel.setMethodCallHandler { [weak self] call, result in
      guard let scanner = self?.lidarScanner else {
        result(FlutterError(code: "UNSUPPORTED_VERSION",
                            message: "LiDAR scanning requires iOS 13.4 or newer.",
                            details: nil))
        return
      }

      switch call.method {
        case "startScan":
          scanner.startScan(result: result)
        case "stopScan":
          scanner.stopScan(result: result)
        case "exportModel":
          scanner.exportModel(result: result)
        case "viewModelInAR":
          scanner.viewModelInAR(result: result)
        default:
          result(FlutterMethodNotImplemented)
      }
    }

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
