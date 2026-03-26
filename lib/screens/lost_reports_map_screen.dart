import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/lost_pet_report.dart';
import '../theme/app_theme.dart';
import 'lost_pet_report_details_screen.dart';

class LostReportsMapScreen extends StatelessWidget {
  final List<LostPetReport> reports;

  const LostReportsMapScreen({
    super.key,
    required this.reports,
  });

  List<LostPetReport> get _reportsWithLocation {
    return reports
        .where((report) => report.latitude != null && report.longitude != null)
        .toList();
  }

  LatLng get _initialTarget {
    if (_reportsWithLocation.isNotEmpty) {
      final first = _reportsWithLocation.first;
      return LatLng(first.latitude!, first.longitude!);
    }

    return const LatLng(36.8920, 27.2878);
  }

  Set<Marker> _buildMarkers(BuildContext context) {
    return _reportsWithLocation.map((report) {
      final petName =
          report.petName.trim().isEmpty ? 'Lost pet' : report.petName.trim();

      return Marker(
        markerId: MarkerId(report.id),
        position: LatLng(report.latitude!, report.longitude!),
        infoWindow: InfoWindow(
          title: petName,
          snippet: report.lastSeenLocation,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => LostPetReportDetailsScreen(report: report),
              ),
            );
          },
        ),
      );
    }).toSet();
  }

  @override
  Widget build(BuildContext context) {
    final reportsWithLocation = _reportsWithLocation;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Lost Pets Map'),
      ),
      body: reportsWithLocation.isEmpty
          ? Center(
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.border),
                ),
                child: const Text(
                  'No lost reports with location yet.',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            )
          : Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _initialTarget,
                    zoom: 13,
                  ),
                  markers: _buildMarkers(context),
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  zoomControlsEnabled: false,
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  top: 16,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Text(
                      '${reportsWithLocation.length} active lost pin${reportsWithLocation.length == 1 ? '' : 's'}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
