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
/// HARDWARE VERIFICATION NOTES (test with physical Frame before shipping):
///   • [BrilliantBluetooth.scan()] — verify Stream<BrilliantScannedDevice> API.
///   • [BrilliantBluetooth.connect()] — verify signature; may throw on timeout.
///   • [BrilliantDevice.sendString()] — verify awaitResponse flag behaviour.
///   • [BrilliantDevice.connectionState] — verify stream exists; used in
///     [_monitorConnectionState] to detect out-of-range disconnects.
///   • Frame Lua display: test line spacing (lineHeight = 68) on real hardware.
class FrameService extends ChangeNotifier {
  FrameConnectionStatus _status = FrameConnectionStatus.disconnected;
  BrilliantDevice? _device;
  StreamSubscription<BrilliantScannedDevice>? _scanSub;
  StreamSubscription<BrilliantConnectionState>? _connStateSub;
  String? _lastError;
  bool _lastSendFailed = false;

  FrameConnectionStatus get status => _status;
  bool get isConnected => _status == FrameConnectionStatus.connected;
  String? get lastError => _lastError;
  bool get lastSendFailed => _lastSendFailed;

  String get statusLabel => switch (_status) {
        FrameConnectionStatus.disconnected => 'Frame: Disconnected',
        FrameConnectionStatus.connecting => 'Frame: Connecting…',
        FrameConnectionStatus.connected => 'Frame: Connected',
      };

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Scans for a nearby Frame device and connects to the first one found.
  ///
  /// Shows [lastError] and returns to disconnected state on any failure.
  /// Call [disconnect] first if already connected.
  Future<void> connect() async {
    if (_status != FrameConnectionStatus.disconnected) return;
    _clearError();
    _setStatus(FrameConnectionStatus.connecting);

    // Gate on BT adapter — gives a clear user-facing error if BT is off.
    final adapterState = await FlutterBluePlus.adapterState.first;
    if (adapterState != BluetoothAdapterState.on) {
      _fail('Bluetooth is off – please enable it and try again.');
      return;
    }

    try {
      // TODO(hardware): Verify BrilliantBluetooth.scan() stream type with
      // frame_ble 3.0.0. Expected: Stream<BrilliantScannedDevice>.
      _scanSub = BrilliantBluetooth.scan().listen(
        (scanned) async {
          await _scanSub?.cancel();
          _scanSub = null;
          try {
            // TODO(hardware): Verify BrilliantBluetooth.connect() signature.
            _device = await BrilliantBluetooth.connect(scanned);
            _monitorConnectionState();
            _setStatus(FrameConnectionStatus.connected);
          } catch (e) {
            _fail('Connection failed: $e');
          }
        },
        onError: (Object e) => _fail('Scan error: $e'),
        onDone: () {
          if (_status == FrameConnectionStatus.connecting) {
            _fail('No Frame found nearby – is it worn and awake?');
          }
        },
      );

      // Auto-cancel scan after 12 s if nothing is found.
      Future.delayed(const Duration(seconds: 12), () {
        if (_status == FrameConnectionStatus.connecting) {
          _scanSub?.cancel();
          _scanSub = null;
          _fail('Scan timed out – Frame not found.');
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

    // TODO(hardware): Verify BrilliantDevice.disconnect() method name/signature.
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
      // TODO(hardware): Verify BrilliantDevice.sendString() signature.
      // Expected: sendString(String luaCode, {bool awaitResponse = false})
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
  /// Frame Lua API: frame.display.text(text, x, y)
  ///   x: horizontal position (1–640), y: vertical position (1–400)
  ///   Variable-width font only; no word-wrap; no font-size control.
  ///
  /// lineHeight=68 → 3 lines fit cleanly in 400 px. Adjust if font renders
  /// differently on your hardware.
  String _buildFrameLua(String displayText) {
    final lines = displayText.split('\n');
    final buf = StringBuffer();
    const lineHeight = 68;

    for (var i = 0; i < lines.length && i < 4; i++) {
      // Single quotes must be escaped inside the Lua string literal.
      final escaped = lines[i].replaceAll("'", r"\'");
      final y = 1 + (i * lineHeight);
      buf.write("frame.display.text('$escaped',1,$y);");
    }
    buf.write('frame.display.show()');
    return buf.toString();
  }

  // ── Private helpers ─────────────────────────────────────────────────────────

  void _monitorConnectionState() {
    // TODO(hardware): Verify BrilliantDevice exposes a connectionState stream.
    // Uncomment when confirmed with frame_ble 3.0.0:
    //
    // _connStateSub = _device!.connectionState.listen((state) {
    //   if (state == BrilliantConnectionState.disconnected) {
    //     _device = null;
    //     _connStateSub?.cancel();
    //     _connStateSub = null;
    //     _lastError = 'Frame disconnected.';
    //     _setStatus(FrameConnectionStatus.disconnected);
    //   }
    // });
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
