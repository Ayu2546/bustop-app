import Flutter
import UIKit
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    guard let mapsApiKey = Bundle.main.object(forInfoDictionaryKey: "GoogleMapsAPIKey") as? String,
          !mapsApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
          !mapsApiKey.contains("$("),
          mapsApiKey != "YOUR_IOS_MAPS_API_KEY" else {
      fatalError("Set GOOGLE_MAPS_API_KEY in ios/Flutter/Secrets.xcconfig. See README.md.")
    }
    GMSServices.provideAPIKey(mapsApiKey)
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
