import 'package:flutter/foundation.dart';

/// Bridges a hard 401 in the network layer to the auth layer without the
/// interceptor importing blocs. AuthBloc/router listens and forces logout.
class SessionExpiryNotifier extends ChangeNotifier {
  void expire() => notifyListeners();
}

/// The shared Dio also serves analytics (pre-login /events flushes 401) and
/// the public auth endpoints; those 401s are expected and must NOT log out.
bool shouldForceLogoutOn401(String path) {
  if (path.contains('/events')) return false;
  if (path.contains('/auth/')) return false;
  return true;
}
