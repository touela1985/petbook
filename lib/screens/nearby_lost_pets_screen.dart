import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../models/lost_pet_report.dart';
import '../theme/app_theme.dart';
import '../widgets/pet_image_widget.dart';
import 'lost_pet_report_details_screen.dart';

class NearbyLostPetsScreen extends StatelessWidget {
  final List<LostPetReport> reports;
  final Position? userPosition;

  const NearbyLostPetsScreen({
    super.key,
    required this.reports,
    required this.userPosition,
  });

  List<LostPetReport> _sortedReports() {
    final sorted = List<LostPetReport>.from(reports);

    if (userPosition == null) {
      sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return sorted;
    }

    sorted.sort((a, b) {
      final aDistance = _distanceInMeters(a);
      final bDistance = _distanceInMeters(b);

      if (aDistance == null && bDistance == null) {
        return b.createdAt.compareTo(a.createdAt);
      }
      if (aDistance == null) return 1;
      if (bDistance == null) return -1;
      return aDistance.compareTo(bDistance);
    });

    return sorted;
  }

  double? _distanceInMeters(LostPetReport report) {
    if (userPosition == null ||
        report.latitude == null ||
        report.longitude == null) {
      return null;
    }

    return Geolocator.distanceBetween(
      userPosition!.latitude,
      userPosition!.longitude,
      report.latitude!,
      report.longitude!,
    );
  }

  String? _distanceText(LostPetReport report, {required bool isEl}) {
    final meters = _distanceInMeters(report);
    if (meters == null) return null;

    if (meters < 1000) {
      return isEl ? '${meters.round()} μ μακριά' : '${meters.round()} m away';
    }

    final km = meters / 1000;
    return isEl ? '${km.toStringAsFixed(1)} χλμ μακριά' : '${km.toStringAsFixed(1)} km away';
  }

  String _petName(LostPetReport report, {required bool isEl}) {
    final name = report.petName.trim();
    return name.isEmpty ? (isEl ? 'Χαμένο ζώο' : 'Lost pet') : name;
  }

  String _typeText(LostPetReport report, {required bool isEl}) {
    final type = report.type.trim();
    return type.isEmpty ? (isEl ? 'Αναφορά ζώου' : 'Pet report') : type;
  }

  Widget _buildThumbnail(LostPetReport report) {
    return PetImageWidget(
      photoUrl: report.photoUrl,
      photoPath: report.photoPath,
      width: 92,
      height: 92,
      fit: BoxFit.cover,
      borderRadius: BorderRadius.circular(18),
      placeholder: Container(
        height: 92,
        width: 92,
        decoration: BoxDecoration(
          color: AppTheme.lostFound.withOpacity(0.10),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Icon(
          Icons.pets,
          color: AppTheme.lostFound,
          size: 34,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEl = Localizations.localeOf(context).languageCode == 'el';
    final sortedReports = _sortedReports();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(isEl ? 'Κοντινά χαμένα ζώα' : 'Nearby Lost Pets'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFF44336),
                    Color(0xFFF45C2C),
                    Color(0xFFFFA726),
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.10),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    height: 54,
                    width: 54,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(
                      Icons.notifications_active_rounded,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEl ? 'Κοντινές ειδοποιήσεις' : 'Nearby Lost Alerts',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isEl
                              ? '${sortedReports.length} κοντινές αναφορές'
                              : '${sortedReports.length} nearby report${sortedReports.length == 1 ? '' : 's'}',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.95),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            ...sortedReports.map((report) {
              final distanceText = _distanceText(report, isEl: isEl);

              return Container(
                margin: const EdgeInsets.only(bottom: 14),
                child: Material(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(22),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(22),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              LostPetReportDetailsScreen(report: report),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: AppTheme.border),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildThumbnail(report),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 7,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppTheme.lostFound
                                                .withOpacity(0.10),
                                            borderRadius:
                                                BorderRadius.circular(999),
                                            border: Border.all(
                                              color: AppTheme.lostFound
                                                  .withOpacity(0.24),
                                            ),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.warning_amber_rounded,
                                                size: 13,
                                                color: AppTheme.lostFound,
                                              ),
                                              SizedBox(width: 5),
                                              Text(
                                                'LOST',
                                                style: TextStyle(
                                                  color: AppTheme.lostFound,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w800,
                                                  letterSpacing: 0.3,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const Spacer(),
                                        if (distanceText != null)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 11,
                                              vertical: 7,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppTheme.primaryTeal
                                                  .withOpacity(0.10),
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                              border: Border.all(
                                                color: AppTheme.primaryTeal
                                                    .withOpacity(0.20),
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(
                                                  Icons.location_on_rounded,
                                                  size: 14,
                                                  color: AppTheme.primaryTeal,
                                                ),
                                                const SizedBox(width: 5),
                                                Text(
                                                  distanceText,
                                                  style: const TextStyle(
                                                    color:
                                                        AppTheme.primaryTeal,
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _petName(report, isEl: isEl),
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                        color: AppTheme.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _typeText(report, isEl: isEl),
                                      style: const TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Padding(
                                          padding: EdgeInsets.only(top: 2),
                                          child: Icon(
                                            Icons.location_on_outlined,
                                            size: 16,
                                            color: AppTheme.lostFound,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            report.lastSeenLocation,
                                            style: const TextStyle(
                                              color: AppTheme.textSecondary,
                                              height: 1.3,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryTeal.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    isEl ? 'Άνοιγμα ειδοποίησης' : 'Open alert details',
                                    style: const TextStyle(
                                      color: AppTheme.primaryTeal,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                const Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 18,
                                  color: AppTheme.primaryTeal,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
