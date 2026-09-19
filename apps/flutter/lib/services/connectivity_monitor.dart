import 'package:connectivity_plus/connectivity_plus.dart';

/// Monitor network connectivity and trigger offline/online transitions.
class ConnectivityMonitor {
  final Connectivity _connectivity = Connectivity();
  late List<ConnectivityResult> _lastResult;

  /// Callback when connection is lost
  Function()? onOffline;

  /// Callback when connection is restored
  Function()? onOnline;

  /// Check current connectivity status
  Future<bool> isConnected() async {
    try {
      final result = await _connectivity.checkConnectivity();
      _lastResult = result;
      return !result.contains(ConnectivityResult.none);
    } catch (e) {
      // If check fails, assume disconnected (fail-safe)
      return false;
    }
  }

  /// Get current connectivity status (cached)
  bool get isConnectedSync => !_lastResult.contains(ConnectivityResult.none);

  /// Start monitoring connectivity changes
  void startMonitoring() {
    _connectivity.onConnectivityChanged.listen((result) {
      final wasOnline = !_lastResult.contains(ConnectivityResult.none);
      final isOnline = !result.contains(ConnectivityResult.none);

      if (!wasOnline && isOnline) {
        // Transition: offline → online
        onOnline?.call();
      } else if (wasOnline && !isOnline) {
        // Transition: online → offline
        onOffline?.call();
      }

      _lastResult = result;
    });
  }

  /// Get friendly name for current connection type
  String getConnectionType() {
    if (_lastResult.isEmpty) return 'none';
    return _lastResult.first.toString().split('.').last;
  }
}
