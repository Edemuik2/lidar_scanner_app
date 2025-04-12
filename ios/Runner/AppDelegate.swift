import UIKit
import Flutter

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    let controller = window?.rootViewController as! FlutterViewController
    let channel = FlutterMethodChannel(name: "lidar_scanner_channel",
                                       binaryMessenger: controller.binaryMessenger)

    let scanner = LidarScanner(viewController: controller)

    channel.setMethodCallHandler { call, result in
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
