import 'package:connectivity_plus/connectivity_plus.dart';

/// Thin wrapper around [Connectivity] that reduces the platform's
/// `List<ConnectivityResult>` reporting down to a single online/offline
/// boolean.
///
/// **This is a hint, not a guarantee.** The OS only reports whether a
/// network *interface* is up (Wi-Fi, mobile data, ethernet, ...) — it has no
/// idea whether that interface actually has a working path to the internet.
/// A phone connected to a Wi-Fi network behind a captive portal, or a router
/// with no upstream link, is reported as "online" here even though no
/// request will succeed.
///
/// Consumers (in particular the sync engine) MUST treat every `true`/online
/// signal from this service as "it's worth attempting a sync now", never as
/// "the internet is definitely reachable". The ground truth for reachability
/// is whether an actual network request succeeds or fails — a failed
/// request is the real signal to fall back to offline behaviour, not the
/// absence of a connectivity event.
class ConnectivityService {
  /// Creates a [ConnectivityService].
  ///
  /// [connectivity] is injectable so tests can supply a fake/mock instead of
  /// the real `connectivity_plus` platform channel.
  ConnectivityService({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  /// A stream of online/offline hints, derived from
  /// [Connectivity.onConnectivityChanged].
  ///
  /// Emits `true` when the reported result list contains anything other
  /// than [ConnectivityResult.none] (i.e. at least one active interface),
  /// and `false` when the list contains only [ConnectivityResult.none].
  ///
  /// See the class doc: this is a hint to "attempt a sync now", not proof
  /// that the internet is reachable.
  Stream<bool> get onlineChanges =>
      _connectivity.onConnectivityChanged.map(_isOnline);

  /// One-shot check of the current connectivity hint, via
  /// [Connectivity.checkConnectivity].
  ///
  /// Same mapping as [onlineChanges]: `true` unless every reported result is
  /// [ConnectivityResult.none]. Same caveat applies — see the class doc.
  Future<bool> isOnline() async {
    final results = await _connectivity.checkConnectivity();
    return _isOnline(results);
  }

  bool _isOnline(List<ConnectivityResult> results) =>
      results.any((result) => result != ConnectivityResult.none);
}
