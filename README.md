# BuStop
## About this app 
BuStop is a map-based app created for the Engineer Guild Hackathon on November 9, 2024. <br>
Developed by Ayu and lienoise over a 7-day period, it focuses on providing an efficient bus schedule interface and map integration. <br>
BuStop also promotes local tourism through features like QR codes and an interactive puzzle, making travel both informative and engaging.


## API key setup

Real API keys are not included in the source files. Each developer must create
local configuration files. Do not put these files in `assets/` or commit them.
Use separate keys for Android Maps SDK, iOS Maps SDK, and Geocoding API.

### 1. Location search (Dart)

From the repository root:

```sh
cp config/api_keys.example.json config/api_keys.json
```

Set `GOOGLE_GEOCODING_API_KEY` in `config/api_keys.json`, then launch with:

```sh
flutter pub get
flutter run --dart-define-from-file=config/api_keys.json
```

Pass the same `--dart-define-from-file` option to `flutter build apk` or
`flutter build ios` when building. An empty value disables location search
with a user-facing message; it does not configure the native map SDKs.

### 2. Android map display

```sh
cp android/maps.properties.example android/maps.properties
```

Replace the placeholder with an Android Maps SDK key. Gradle reads this file
and injects the value into the manifest. Missing configuration fails the build
with a setup message. Restrict this key to the actual application ID and
signing certificate SHA-1, and to Maps SDK for Android.

### 3. iOS map display

```sh
cp ios/Flutter/Secrets.xcconfig.example ios/Flutter/Secrets.xcconfig
```

Replace the placeholder with an iOS Maps SDK key. Debug, Release, and Profile
use this configuration through the existing Flutter xcconfig files.
`Info.plist` passes the value to `AppDelegate`. Missing configuration stops
startup with a setup message. Restrict this key to the actual bundle ID and
to Maps SDK for iOS.

### Existing keys and deployment

Keys previously committed remain in Git history. Review their usage and
restrictions in Google Cloud Console. Delete unused keys; for active keys,
migrate consumers to appropriately restricted replacement keys before retiring
the old keys. Removing a value from source does not revoke it.

Local files and Dart defines keep keys out of Git, but do not make keys secret
inside a distributed app. This prototype still calls the Geocoding web service
directly from Dart. For production, use an authenticated, rate-limited backend
proxy with a server-restricted key, or follow Google's supported secure mobile
web-service approach. Never ship an unrestricted server key in the app.

See [Google Maps Platform security guidance](https://developers.google.com/maps/api-security-best-practices).
