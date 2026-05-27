# Alto Jam Key Helper

Android app for alto saxophone players who want to quickly find the correct written key when jamming with concert-pitch musicians. Optionally displays key + scale notes on **Brilliant Labs Frame** smart glasses over BLE.

---

## Features

- 12 large, high-contrast concert-key buttons (3-column grid)
- Each button shows the **concert key** (orange) and the **alto sax written key** (cyan)
- Tap a button to see the full major scale and major pentatonic notes
- Auto-sends key info to Frame glasses when connected
- Works completely without Frame connected
- Copy-to-clipboard fallback for any musician

---

## Project structure

```
lib/
  main.dart                   App entry point, theme, provider setup
  models/
    jam_key.dart              JamKey data class
  data/
    key_data.dart             All 12 concert→alto mappings, scales, pentatonics
  services/
    frame_service.dart        BLE connection + Frame display via frame_ble 3.0.0
  screens/
    home_screen.dart          Main screen (key grid, connection bar)
  widgets/
    key_button.dart           Individual key button widget
    selected_key_card.dart    Bottom card for selected key info

test/
  key_data_test.dart          Unit tests (no hardware required)

android/app/src/main/
  AndroidManifest.xml         BLE permissions (replaces flutter-generated file)
```

---

## Setup

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) ≥ 3.3.0
- Android Studio or VS Code with Flutter extension
- An Android device or emulator running API 21+ (Android 5.0+)
- (Optional) Brilliant Labs Frame glasses for BLE testing

### 1. Create the Flutter project scaffold

Run this **once** to generate the boilerplate (build.gradle, Kotlin activity, etc.):

```bash
cd alto_jam_key_helper
flutter create . --org com.example --project-name alto_jam_key_helper
```

> The `flutter create .` command will generate files but **will not overwrite** the
> source files already in `lib/`, `test/`, and `android/app/src/main/AndroidManifest.xml`
> if they exist. Confirm that the manifest was not overwritten — if it was, restore it
> from the repository.

### 2. Set minSdkVersion to 21

Open `android/app/build.gradle` and change:

```gradle
android {
    defaultConfig {
        minSdkVersion 21    // ← change from flutter.minSdkVersion to 21
        targetSdkVersion 34
        ...
    }
}
```

### 3. Get dependencies

```bash
flutter pub get
```

### 4. Run on a connected Android device

```bash
flutter run
```

---

## Running tests

No hardware required:

```bash
flutter test
```

---

## Frame glasses integration

### Packages used

| Package | Version | Role |
|---------|---------|------|
| `frame_ble` | ^3.0.0 | BLE scan, connect, send Lua strings to Frame |
| `frame_msg` | ^2.0.0 | (available for future sprite/image display) |
| `flutter_blue_plus` | ^1.35.3 | BT adapter state check; transitive dep of frame_ble |

### What was verified at build time vs. what needs hardware testing

All Frame-specific code is in `lib/services/frame_service.dart`.  
Lines marked `// TODO(hardware):` must be verified on a real Frame device:

| Item | Expected API | Needs verification |
|------|-------------|-------------------|
| `BrilliantBluetooth.scan()` | Returns `Stream<BrilliantScannedDevice>` | ✅ Check actual return type |
| `BrilliantBluetooth.connect(scanned)` | Returns `Future<BrilliantDevice>` | ✅ Check timeout behaviour |
| `BrilliantDevice.sendString(lua, awaitResponse: false)` | Sends Lua to Frame eval | ✅ Check method signature |
| `BrilliantDevice.connectionState` | `Stream<BrilliantConnectionState>` for out-of-range detection | ✅ Verify stream exists and enable `_monitorConnectionState()` |
| Frame display line height | `lineHeight = 68` (3 lines in 400 px) | ✅ Adjust on real glasses |

### Frame display format

Each key tap sends a 3-line Lua display command:

```
Concert C -> Alto A
A B C# D E F# G#
Pent: A B C# E F#
```

Lua template used:
```lua
frame.display.text('Concert C -> Alto A',1,1);
frame.display.text('A B C# D E F# G#',1,69);
frame.display.text('Pent: A B C# E F#',1,137);
frame.display.show()
```

### Android runtime permissions

On Android 12+ (API 31+) the user will be prompted for **Bluetooth** permissions
(`BLUETOOTH_SCAN`, `BLUETOOTH_CONNECT`) the first time they tap **Connect Frame**.

Currently the permission request is delegated to `flutter_blue_plus` internals via
the BLE scan call. If you need an explicit pre-scan permission dialog, add the
`permission_handler` package and call it before `frameService.connect()`.

### Connecting to Frame

1. Make sure Frame is worn and charged.
2. Tap **Connect Frame** in the app.
3. The app scans for 12 seconds and connects to the first Frame found.
4. Tap any key button — the notes display immediately on the phone and on the glasses.

---

## Extending the app

### Adding minor / pentatonic / blues scales

Add new `JamKey` entries in `lib/data/key_data.dart` with `scaleType: 'minor'` etc.
The UI and Frame service need no changes for new entries.

### Enharmonic display for G# / Ab

Concert B → Alto G# major contains `Fx` (F double-sharp).
A future enharmonic toggle in `JamKey` could switch to the Ab major spelling
(`Ab Bb C Db Eb F G Ab`) for simpler reading. Hook it to a settings toggle.

### Practice mode / scale highlighting

A future overlay could highlight which scale degrees are being played.
Structure is already clean: extend `JamKey` with additional note lists.

---

## Notes on Brilliant Labs Frame

- Frame display: **640 × 400 pixels**, variable-width font, no word-wrap.
- Text Lua API: `frame.display.text(string, x, y)` — x: 1–640, y: 1–400.
- Display is flushed to hardware on `frame.display.show()`.
- The `frame_ble` package (CitizenOneX) is the actively maintained BLE stack
  as of May 2026. If the API changes in a future major version, only
  `FrameService._buildFrameLua()`, `connect()`, `sendText()`, and
  `_monitorConnectionState()` need updating.
