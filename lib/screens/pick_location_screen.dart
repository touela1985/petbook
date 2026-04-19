import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class PickLocationScreen extends StatefulWidget {
  const PickLocationScreen({super.key});

  @override
  State<PickLocationScreen> createState() => _PickLocationScreenState();
}

class _PickLocationScreenState extends State<PickLocationScreen> {
  LatLng? _selectedLocation;
  GoogleMapController? _mapController;

  bool get _isEl => Localizations.localeOf(context).languageCode == 'el';

  static const CameraPosition _initialCameraPosition = CameraPosition(
    target: LatLng(36.8927, 27.2877), // Kos — fallback
    zoom: 13,
  );

  void _selectLocation(LatLng position) {
    setState(() {
      _selectedLocation = position;
    });
  }

  void _confirmLocation() {
    if (_selectedLocation == null) return;
    Navigator.pop(context, _selectedLocation);
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _moveToUserLocation();
  }

  Future<void> _moveToUserLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 8),
        ),
      );

      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(position.latitude, position.longitude),
            zoom: 15,
          ),
        ),
      );
    } catch (_) {
      // Silently fall back to default Kos position
    }
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEl = _isEl;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEl ? 'Επιλογή τοποθεσίας' : 'Select Location'),
      ),
      body: GoogleMap(
        initialCameraPosition: _initialCameraPosition,
        onMapCreated: _onMapCreated,
        myLocationEnabled: true,
        myLocationButtonEnabled: false,
        onTap: _selectLocation,
        markers: _selectedLocation == null
            ? {}
            : {
                Marker(
                  markerId: const MarkerId("selected"),
                  position: _selectedLocation!,
                )
              },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _confirmLocation,
        label: Text(isEl ? 'Επιβεβαίωση' : 'Confirm Location'),
        icon: const Icon(Icons.check),
      ),
    );
  }
}
