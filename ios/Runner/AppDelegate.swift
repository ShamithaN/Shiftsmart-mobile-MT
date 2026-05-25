import Flutter
import UIKit
import MSAL
import GoogleMaps // 1. Ensure this is imported

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var apnsTokenString: String?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    
    // 2. Initialize Google Maps with your API Key
    GMSServices.provideAPIKey("AIzaSyAN397HAlCveqhw7idZNJHdhSidLl9rIKA")

    GeneratedPluginRegistrant.register(with: self)

    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: "shiftsmart/native_push",
        binaryMessenger: controller.binaryMessenger
      )
      channel.setMethodCallHandler { [weak self] call, result in
        if call.method == "getApnsToken" {
          result(self?.apnsTokenString)
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
    }

    application.registerForRemoteNotifications()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
    apnsTokenString = token
    NSLog("APNS token registered: \(token)")
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    NSLog("APNS registration failed: \(error.localizedDescription)")
    super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
  }

  // 3. Keep your existing MSAL Logic intact
  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey : Any] = [:]
  ) -> Bool {
    return MSALPublicClientApplication.handleMSALResponse(
      url,
      sourceApplication: options[UIApplication.OpenURLOptionsKey.sourceApplication] as? String
    )
  }
}
