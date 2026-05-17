import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/app_providers.dart';
import '../widgets/app_colors.dart';

class ChildLocationScreen extends ConsumerStatefulWidget {
  final String childId;
  final String childName;

  const ChildLocationScreen({
    super.key,
    required this.childId,
    required this.childName,
  });

  @override
  ConsumerState<ChildLocationScreen> createState() =>
      _ChildLocationScreenState();
}

class _ChildLocationScreenState extends ConsumerState<ChildLocationScreen> {
  GoogleMapController? _mapController;

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  String _formatTime(dynamic updatedAt) {
    if (updatedAt == null) return 'Unknown';
    DateTime dt;
    if (updatedAt is Timestamp) {
      dt = updatedAt.toDate();
    } else if (updatedAt is DateTime) {
      dt = updatedAt;
    } else {
      return updatedAt.toString();
    }
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${dt.day}/${dt.month}/${dt.year} '
        '${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final locationAsync = ref.watch(locationProvider(widget.childId));

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bgSurface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.childName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            locationAsync.when(
              data: (loc) => Text(
                loc != null
                    ? 'Last updated: ${_formatTime(loc['updated_at'])}'
                    : 'No location data',
                style: TextStyle(color: AppColors.textMuted, fontSize: 11),
              ),
              loading: () => Text(
                'Loading...',
                style: TextStyle(color: AppColors.textMuted, fontSize: 11),
              ),
              error: (e, st) => Text(
                'Error loading location',
                style: TextStyle(color: AppColors.danger, fontSize: 11),
              ),
            ),
          ],
        ),
      ),
      body: locationAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Failed to load location: $e',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ),
        data: (location) {
          if (location == null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.location_off,
                      color: AppColors.textMuted, size: 52),
                  const SizedBox(height: 16),
                  Text(
                    'No location data available',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 15),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Location will appear once the child opens the app.',
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                ],
              ),
            );
          }

          final lat = (location['lat'] as num).toDouble();
          final lng = (location['lng'] as num).toDouble();
          final position = LatLng(lat, lng);

          WidgetsBinding.instance.addPostFrameCallback((_) {
            _mapController
                ?.animateCamera(CameraUpdate.newLatLngZoom(position, 15));
          });

          return GoogleMap(
            initialCameraPosition:
                CameraPosition(target: position, zoom: 15),
            markers: {
              Marker(
                markerId: const MarkerId('child_location'),
                position: position,
                infoWindow: InfoWindow(
                  title: widget.childName,
                  snippet:
                      'Updated: ${_formatTime(location['updated_at'])}',
                ),
              ),
            },
            myLocationButtonEnabled: false,
            zoomControlsEnabled: true,
            onMapCreated: (controller) => _mapController = controller,
          );
        },
      ),
    );
  }
}
