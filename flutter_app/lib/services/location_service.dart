import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

/// Periodically fetches the device GPS position and writes it to
/// users/{uid}/location/current in Firestore so parents can track
/// the child's location in real time.
class LocationService {
  static const _interval = Duration(seconds: 30);

  Timer? _timer;
  bool _running = false;

  Future<void> start() async {
    if (_running) return;

    final permission = await _ensurePermission();
    if (!permission) return;

    _running = true;
    await _push(); // write immediately on start
    _timer = Timer.periodic(_interval, (_) => _push());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _running = false;
  }

  Future<bool> _ensurePermission() async {
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    return perm == LocationPermission.always ||
        perm == LocationPermission.whileInUse;
  }

  Future<void> _push() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('location')
          .doc('current')
          .set({
        'lat': pos.latitude,
        'lng': pos.longitude,
        'updated_at': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Silently ignore — network drop or permission revoked mid-session
    }
  }
}
