import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Network connectivity monitoring service
class ConnectivityService {
  static ConnectivityService? _instance;
  static ConnectivityService get instance => _instance ??= ConnectivityService._();
  ConnectivityService._();

  final Connectivity _connectivity = Connectivity();
  final _controller = StreamController<bool>.broadcast();
  bool _isConnected = true;
  bool _disposed = false;
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  bool get isConnected => _isConnected;
  Stream<bool> get onConnectivityChanged => _controller.stream;

  Future<void> initialize() async {
    final results = await _connectivity.checkConnectivity();
    _isConnected = results.isNotEmpty && !results.contains(ConnectivityResult.none);
    _subscription = _connectivity.onConnectivityChanged.listen(
      (results) {
        if (_disposed) return;
        final connected = results.isNotEmpty && !results.contains(ConnectivityResult.none);
        if (connected != _isConnected) {
          _isConnected = connected;
          if (!_disposed) _controller.add(connected);
        }
      },
      onError: (Object e) {
        if (!_disposed && !_controller.isClosed) {
          _controller.addError(e);
        }
      },
    );
  }

  void dispose() {
    _disposed = true;
    _subscription?.cancel();
    _subscription = null;
    if (!_controller.isClosed) {
      _controller.close();
    }
  }
}
