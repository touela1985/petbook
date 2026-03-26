import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class PickLocationScreen extends StatefulWidget {
  const PickLocationScreen({super.key});

  @override
  State<PickLocationScreen> createState() => _PickLocationScreenState();
}

class _PickLocationScreenState extends State<PickLocationScreen> {

  LatLng? _selectedLocation;

  static const CameraPosition _initialCameraPosition = CameraPosition(
    target: LatLng(36.8927, 27.2877), // Kos
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

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: const Text("Select Location"),
      ),

      body: GoogleMap(
        initialCameraPosition: _initialCameraPosition,
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
        label: const Text("Confirm Location"),
        icon: const Icon(Icons.check),
      ),
    );
  }
}
