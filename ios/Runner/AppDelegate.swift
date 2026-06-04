import Flutter
import UIKit
import MSAL
import GoogleMaps // 1. Ensure this is imported

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var apnsTokenString: String?

  private func googleMapsApiKey() -> String {
    if let key = Bundle.main.object(forInfoDictionaryKey: "GOOGLE_MAPS_API_KEY") as? String,
       !key.isEmpty {
      return key
    }

    if let key = ProcessInfo.processInfo.environment["GOOGLE_MAPS_API_KEY"],
       !key.isEmpty {
      return key
    }

    let assetPaths = [
      Bundle.main.path(forResource: ".env", ofType: nil, inDirectory: "flutter_assets"),
      Bundle.main.path(forResource: ".env", ofType: nil, inDirectory: "Frameworks/App.framework/flutter_assets")
    ].compactMap { $0 }

    for path in assetPaths {
      guard let contents = try? String(contentsOfFile: path, encoding: .utf8) else {
        continue
      }

      for line in contents.components(separatedBy: .newlines) {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("GOOGLE_MAPS_API_KEY=") {
          return String(trimmed.dropFirst("GOOGLE_MAPS_API_KEY=".count))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        }
      }
    }

    return "AIzaSyDUmFaCazbVnAWE2mcRtZLMzqeidR16LkQ"
  }

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    
    // 2. Initialize Google Maps with the same key used by Dart/Places.
    GMSServices.provideAPIKey(googleMapsApiKey())

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
