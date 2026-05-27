import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:frame_ble/frame_ble.dart';

/// Connection lifecycle for the Brilliant Labs Frame glasses.
enum FrameConnectionStatus { disconnected, connecting, connected }

/// Manages BLE connection and display output to Brilliant Labs Frame glasses.
///
/// Uses frame_ble 3.0.0 (CitizenOneX) for BLE transport.
/// The app runs fully without Frame connected — all sends are no-ops when
/// [isConnected] is false, and no errors are thrown.
///
/// SCAN STRATEGY NOTE
/// ------------------
/// frame_ble's BrilliantBluetooth.scan() uses a withServices UUID filter.
/// On Android, withServices only matches the *primary* advertisement packet.
/// Brilliant Labs Frame advertises its service UUIDs in the *scan response*
/// packet only, so the UUID filter silently misses the device.
///
/// We therefore bypass BrilliantBluetooth.scan() and drive FlutterBluePlus
/// directly with withNames: ['Frame'], then hand the found device straight to
/// BrilliantBluetooth.connect().
class FrameService extends ChangeNotifier {
  FrameConnectionStatus _status = FrameConnectionStatus.disconnected;
  BrilliantDevice? _device;
  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<BrilliantDevice>? _connStateSub;
  Timer? _scanTimer;
  String? _lastError;
  bool _lastSendFailed = false;
  bool _connecting = false; // guard against double-connect from scan stream

  FrameConnectionStatus get status => _status;
  bool get isConnected => _status == FrameConnectionStatus.connected;
  String? get lastError => _lastError;
  bool get lastSendFailed => _lastSendFailed;

  String get statusLabel => switch (_status) {
        FrameConnectionStatus.disconnected => 'Frame: Disconnected',
        FrameConnectionStatus.connecting => 'Frame: Scanning…',
        FrameConnectionStatus.connected => 'Frame: Connected',
      };

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Scans for a nearby Frame device (by name "Frame") and connects.
  ///
  /// Requests Android runtime BT permissions first, then gates on adapter
  /// state. Shows [lastError] and returns to disconnected on any failure.
  Future<void> connect() async {
    if (_status != FrameConnectionStatus.disconnected) return;
    _clearError();
    _connecting = false;
    _setStatus(FrameConnectionStatus.connecting);

    // 1 ── Request Android runtime permissions (BLUETOOTH_SCAN / BLUETOOTH_CONNECT).
    try {
      await BrilliantBluetooth.requestPermission();
    } catch (e) {
      _fail('BT permission denied – allow in Settings → Apps → Alto Jam');
      return;
    }

    // 2 ── Gate on BT adapter being on.
    final adapterState = await FlutterBluePlus.adapterState.first;
    if (adapterState != BluetoothAdapterState.on) {
      _fail('Bluetooth is off – enable it and try again');
      return;
    }

    // 3 ── Scan by device name "Frame".
    //      withNames matches the advertisement name field, which Frame
    //      includes in the primary advertisement packet (unlike service UUIDs
    //      which are in the scan response only on Android).
    try {
      _scanSub = FlutterBluePlus.onScanResults.listen(
        (results) async {
          if (_connecting) return; // already connecting to first found device
          final frames = results
              .where((r) => r.device.advName == 'Frame')
              .toList()
            ..sort((a, b) => b.rssi.compareTo(a.rssi)); // nearest first

          if (frames.isEmpty) return;
          _connecting = true;

          await _scanSub?.cancel();
          _scanSub = null;
          _scanTimer?.cancel();
          _scanTimer = null;
          await FlutterBluePlus.stopScan();

          try {
            final scanned = BrilliantScannedDevice(
              device: frames.first.device,
              rssi: frames.first.rssi,
            );
            _device = await BrilliantBluetooth.connect(scanned);
            _monitorConnectionState();
            _setStatus(FrameConnectionStatus.connected);
          } catch (e) {
            _connecting = false;
            _fail('Connection failed – move Frame closer and retry');
          }
        },
        onError: (Object e) {
          _fail('Scan error – check Location Services and retry');
        },
        onDone: () {
          if (_status == FrameConnectionStatus.connecting) {
            _fail('Frame not found – off charger? Within 1 m?');
          }
        },
      );

      await FlutterBluePlus.startScan(
        withNames: ['Frame'],
        timeout: const Duration(seconds: 10),
        continuousUpdates: false,
        removeIfGone: null,
      );

      // Auto-cancel safety net after 12 s.
      _scanTimer = Timer(const Duration(seconds: 12), () {
        if (_status == FrameConnectionStatus.connecting) {
          _scanSub?.cancel();
          _scanSub = null;
          FlutterBluePlus.stopScan();
          _fail('Scan timed out – Frame not found nearby');
        }
      });
    } catch (e) {
      _fail('Bluetooth error: $e');
    }
  }

  /// Disconnects from Frame and resets state.
  Future<void> disconnect() async {
    _scanTimer?.cancel();
    _scanTimer = null;
    await _scanSub?.cancel();
    _scanSub = null;
    await _connStateSub?.cancel();
    _connStateSub = null;
    await FlutterBluePlus.stopScan();
    try {
      await _device?.disconnect();
    } catch (_) {}
    _device = null;
    _connecting = false;
    _clearError();
    _setStatus(FrameConnectionStatus.disconnected);
  }

  /// Sends [displayText] to the Frame glasses display.
  ///
  /// Each '\n'-delimited line is rendered on the Frame 640×400 display.
  /// Returns true on success. Returns false silently if not connected.
  Future<bool> sendText(String displayText) async {
    _lastSendFailed = false;
    if (!isConnected || _device == null) {
      _lastSendFailed = true;
      notifyListeners();
      return false;
    }
    try {
      final lua = _buildFrameLua(displayText);
      await _device!.sendString(lua, awaitResponse: false);
      notifyListeners();
      return true;
    } catch (e) {
      _lastError = 'Send failed: $e';
      _lastSendFailed = true;
      notifyListeners();
      return false;
    }
  }

  // ── Frame Lua builder ───────────────────────────────────────────────────────

  String _buildFrameLua(String displayText) {
    final lines = displayText.split('\n');
    final buf = StringBuffer();
    const lineHeight = 68;

    for (var i = 0; i < lines.length && i < 4; i++) {
      final escaped = lines[i].replaceAll("'", r"\'");
      final y = 1 + (i * lineHeight);
      buf.write("frame.display.text('$escaped',1,$y);");
    }
    buf.write('frame.display.show()');
    return buf.toString();
  }

  // ── Private helpers ─────────────────────────────────────────────────────────

  void _monitorConnectionState() {
    _connStateSub = _device!.connectionState.listen(
      (updatedDevice) {
        if (updatedDevice.state == BrilliantConnectionState.disconnected) {
          _device = null;
          _connStateSub?.cancel();
          _connStateSub = null;
          _connecting = false;
          _lastError = 'Frame disconnected';
          _setStatus(FrameConnectionStatus.disconnected);
        } else {
          _device = updatedDevice;
          _setStatus(FrameConnectionStatus.connected);
        }
      },
      onError: (Object e) {
        _device = null;
        _connStateSub = null;
        _connecting = false;
        _fail('Frame connection lost');
      },
    );
  }

  void _setStatus(FrameConnectionStatus s) {
    _status = s;
    notifyListeners();
  }

  void _fail(String error) {
    _lastError = error;
    _connecting = false;
    _setStatus(FrameConnectionStatus.disconnected);
  }

  void _clearError() {
    _lastError = null;
  }

  @override
  void dispose() {
    _scanTimer?.cancel();
    _scanSub?.cancel();
    _connStateSub?.cancel();
    super.dispose();
  }
}
