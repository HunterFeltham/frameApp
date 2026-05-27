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
class FrameService extends ChangeNotifier {
  FrameConnectionStatus _status = FrameConnectionStatus.disconnected;
  BrilliantDevice? _device;
  StreamSubscription<BrilliantScannedDevice>? _scanSub;
  StreamSubscription<BrilliantDevice>? _connStateSub;
  String? _lastError;
  bool _lastSendFailed = false;

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

  /// Scans for a nearby Frame device and connects to the first one found.
  ///
  /// Requests Android runtime BT permissions first, then gates on adapter
  /// state. Shows [lastError] and returns to disconnected state on any failure.
  Future<void> connect() async {
    if (_status != FrameConnectionStatus.disconnected) return;
    _clearError();
    _setStatus(FrameConnectionStatus.connecting);

    // 1 ── Request Android runtime permissions (BLUETOOTH_SCAN / BLUETOOTH_CONNECT).
    //      On first launch this triggers the system permission dialog.
    //      On subsequent launches it's a no-op if already granted.
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

    // 3 ── Scan and connect.
    try {
      _scanSub = BrilliantBluetooth.scan().listen(
        (scanned) async {
          await _scanSub?.cancel();
          _scanSub = null;
          try {
            _device = await BrilliantBluetooth.connect(scanned);
            _monitorConnectionState();
            _setStatus(FrameConnectionStatus.connected);
          } catch (e) {
            _fail('Connection failed – move Frame closer and retry');
          }
        },
        onError: (Object e) {
          // Common cause: Location Services toggled off on Samsung devices.
          _fail('Scan error – enable Location Services and retry');
        },
        onDone: () {
          if (_status == FrameConnectionStatus.connecting) {
            _fail('Frame not found – off charger? Within 1 m?');
          }
        },
      );

      // Auto-cancel after 12 s (library scan itself times out at 10 s).
      Future.delayed(const Duration(seconds: 12), () {
        if (_status == FrameConnectionStatus.connecting) {
          _scanSub?.cancel();
          _scanSub = null;
          _fail('Scan timed out – Frame not found nearby');
        }
      });
    } catch (e) {
      _fail('Bluetooth error: $e');
    }
  }

  /// Disconnects from Frame and resets state.
  Future<void> disconnect() async {
    await _scanSub?.cancel();
    _scanSub = null;
    await _connStateSub?.cancel();
    _connStateSub = null;
    try {
      await _device?.disconnect();
    } catch (_) {}
    _device = null;
    _clearError();
    _setStatus(FrameConnectionStatus.disconnected);
  }

  /// Sends [displayText] to the Frame glasses display.
  ///
  /// [displayText] is a '\n'-delimited string; each line is rendered on the
  /// Frame 640×400 display using the Frame Lua display API.
  ///
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

  /// Converts a '\n'-delimited string to a Lua script that renders it on
  /// the Frame 640×400 display.
  ///
  /// lineHeight=68 → 3 lines fit cleanly in 400 px.
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

  /// Monitors the live connection state so the UI updates if Frame goes
  /// out of range or is powered off after connecting.
  void _monitorConnectionState() {
    _connStateSub = _device!.connectionState.listen(
      (updatedDevice) {
        if (updatedDevice.state == BrilliantConnectionState.disconnected) {
          _device = null;
          _connStateSub?.cancel();
          _connStateSub = null;
          _lastError = 'Frame disconnected';
          _setStatus(FrameConnectionStatus.disconnected);
        } else {
          // Reconnected after transient drop.
          _device = updatedDevice;
          _setStatus(FrameConnectionStatus.connected);
        }
      },
      onError: (Object e) {
        _device = null;
        _connStateSub = null;
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
    _setStatus(FrameConnectionStatus.disconnected);
  }

  void _clearError() {
    _lastError = null;
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    _connStateSub?.cancel();
    super.dispose();
  }
}
