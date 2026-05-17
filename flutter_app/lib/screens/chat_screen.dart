import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '../widgets/chat_panel.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _updateLocation();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _updateLocation();
  }

  Future<void> _updateLocation() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }

    try {
      final position = await Geolocator.getCurrentPosition();
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('location')
          .doc('current')
          .set({
        'lat': position.latitude,
        'lng': position.longitude,
        'updated_at': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => const ChatPanel();
}
