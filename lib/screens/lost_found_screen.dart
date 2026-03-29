import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../data/found_pet_report_repository.dart';
import '../data/lost_pet_report_repository.dart';
import '../models/found_pet_report.dart';
import '../models/lost_pet_report.dart';
import '../theme/app_theme.dart';
import 'add_found_pet_report_screen.dart';
import 'add_lost_pet_report_screen.dart';
import 'found_pet_report_details_screen.dart';
import 'lost_pet_report_details_screen.dart';
import 'lost_reports_map_screen.dart';
import 'nearby_lost_pets_screen.dart';
import 'send_found_pet_message_screen.dart';
import 'send_lost_pet_message_screen.dart';

class LostFoundScreen extends StatefulWidget {
  const LostFoundScreen({super.key});

  @override
  State<LostFoundScreen> createState() => _LostFoundScreenState();
}

class _LostFoundScreenState extends State<LostFoundScreen> {
  final LostPetReportRepository _lostRepo = LostPetReportRepository();
  final FoundPetReportRepository _foundRepo = FoundPetReportRepository();
  final Uuid _uuid = const Uuid();

  Position? _userPosition;
  bool _isLoadingUserLocation = true;

  late Future<List<LostPetReport>> _lostReportsFuture;
  late Future<List<FoundPetReport>> _foundReportsFuture;

  static const double _nearYouRadiusKm = 2.0;

  @override
  void initState() {
    super.initState();
    _lostReportsFuture = _loadLostReports();
    _foundReportsFuture = _loadFoundReports();
    _loadUserLocation();
  }

  Future<void> _refreshScreen() async {
    if (!mounted) return;
    setState(() {
      _lostReportsFuture = _loadLostReports();
      _foundReportsFuture = _loadFoundReports();
      _isLoadingUserLocation = true;
    });
    await _loadUserLocation();
  }

  Future<void> _loadUserLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() {
            _isLoadingUserLocation = false;
          });
        }
        return;
      }

      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _isLoadingUserLocation = false;
          });
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition();

      if (mounted) {
        setState(() {
          _userPosition = position;
          _isLoadingUserLocation = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingUserLocation = false;
        });
      }
    }
  }

  Future<List<LostPetReport>> _loadLostReports() async {
    return _lostRepo.getReports();
  }

  Future<List<FoundPetReport>> _loadFoundReports() async {
    return _foundRepo.getReports();
  }

  Future<void> _editLostPetReport(LostPetReport report) async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddLostPetReportScreen(initialReport: report),
      ),
    );
    if (updated == true) {
      await _refreshScreen();
    }
  }

  Future<void> _editFoundPetReport(FoundPetReport report) async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddFoundPetReportScreen(initialReport: report),
      ),
    );
    if (updated == true) {
      await _refreshScreen();
    }
  }

  Future<void> _deleteLostReport(LostPetReport report) async {
    await _lostRepo.deleteReport(report.id);
    await _refreshScreen();
  }

  Future<void> _deleteFoundReport(FoundPetReport report) async {
    await _foundRepo.deleteReport(report.id);
    await _refreshScreen();
  }

  Future<void> _openLostReportDetails(LostPetReport report) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LostPetReportDetailsScreen(report: report),
      ),
    );
    await _refreshScreen();
  }

  Future<void> _openFoundReportDetails(FoundPetReport report) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FoundPetReportDetailsScreen(report: report),
      ),
    );
    await _refreshScreen();
  }

  Future<void> _openLostMessageScreen(LostPetReport report) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => SendLostPetMessageScreen(report: report),
      ),
    );
    await _refreshScreen();
  }

  String _formatCoordinateLabel(double latitude, double longitude) {
    return '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';
  }

  Future<void> _openSightingDialog(LostPetReport report) async {
    final isEl = Localizations.localeOf(context).languageCode == 'el';

    final LatLng initialTarget =
        (report.latitude != null && report.longitude != null)
            ? LatLng(report.latitude!, report.longitude!)
            : _userPosition != null
                ? LatLng(_userPosition!.latitude, _userPosition!.longitude)
                : const LatLng(36.8926, 27.2877);

    String typedNotes = '';
    LatLng selectedLatLng = initialTarget;

    final Map<String, dynamic>? result =
        await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final media = MediaQuery.of(sheetContext);
        final bottomInset = media.viewInsets.bottom;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              top: false,
              child: AnimatedPadding(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                padding: EdgeInsets.fromLTRB(
                  16,
                  8,
                  16,
                  bottomInset > 0
                      ? bottomInset + 12
                      : media.padding.bottom + 12,
                ),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Material(
                    color: Colors.transparent,
                    child: Container(
                      constraints: BoxConstraints(
                        maxHeight: media.size.height * 0.82,
                      ),
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isEl ? 'Δήλωση θέασης' : 'Report Sighting',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              isEl
                                  ? 'Πάτησε πάνω στον χάρτη για να διαλέξεις το ακριβές σημείο και γράψε προαιρετικά μια σημείωση.'
                                  : 'Tap on the map to pick the exact sighting point and add an optional note.',
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F8F7),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: AppTheme.border),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(14),
                                    child: SizedBox(
                                      height: 170,
                                      width: double.infinity,
                                      child: GoogleMap(
                                        initialCameraPosition: CameraPosition(
                                          target: initialTarget,
                                          zoom: (report.latitude != null &&
                                                  report.longitude != null)
                                              ? 16
                                              : 13,
                                        ),
                                        myLocationButtonEnabled: false,
                                        zoomControlsEnabled: false,
                                        mapToolbarEnabled: false,
                                        onTap: (latLng) {
                                          setModalState(() {
                                            selectedLatLng = latLng;
                                          });
                                        },
                                        markers: {
                                          Marker(
                                            markerId: const MarkerId(
                                              'selected_sighting_location',
                                            ),
                                            position: selectedLatLng,
                                          ),
                                        },
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Padding(
                                        padding: EdgeInsets.only(top: 2),
                                        child: Icon(
                                          Icons.place_outlined,
                                          size: 18,
                                          color: AppTheme.primaryTeal,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          '${selectedLatLng.latitude.toStringAsFixed(5)}, ${selectedLatLng.longitude.toStringAsFixed(5)}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: AppTheme.textPrimary,
                                            height: 1.3,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              maxLines: 3,
                              textInputAction: TextInputAction.done,
                              onChanged: (value) {
                                typedNotes = value;
                              },
                              decoration: InputDecoration(
                                labelText: isEl
                                    ? 'Σημειώσεις (προαιρετικό)'
                                    : 'Notes (optional)',
                                hintText: isEl
                                    ? 'Π.χ. το είδα να κινείται προς το πάρκο'
                                    : 'e.g. I saw it moving toward the park',
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: TextButton(
                                    onPressed: () =>
                                        Navigator.of(sheetContext).pop(),
                                    child: Text(isEl ? 'Άκυρο' : 'Cancel'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () {
                                      FocusScope.of(sheetContext).unfocus();
                                      Navigator.of(sheetContext).pop({
                                        'notes': typedNotes.trim(),
                                        'latitude': selectedLatLng.latitude,
                                        'longitude': selectedLatLng.longitude,
                                      });
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primaryTeal,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    child: Text(isEl ? 'Υποβολή' : 'Submit'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (result == null) return;

    final double latitude = (result['latitude'] as num).toDouble();
    final double longitude = (result['longitude'] as num).toDouble();
    final String submittedNotes = (result['notes'] as String?) ?? '';

    final newSighting = LostPetSighting(
      id: _uuid.v4(),
      location:
          '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}',
      notes: submittedNotes,
      latitude: latitude,
      longitude: longitude,
    );

    final updatedReport = LostPetReport(
      id: report.id,
      petName: report.petName,
      type: report.type,
      lastSeenLocation: report.lastSeenLocation,
      lastSeenDate: report.lastSeenDate,
      notes: report.notes,
      contactPhone: report.contactPhone,
      isResolved: report.isResolved,
      photoPath: report.photoPath,
      latitude: report.latitude,
      longitude: report.longitude,
      createdAt: report.createdAt,
      sightings: [
        ...report.sightings,
        newSighting,
      ],
    );

    await _lostRepo.updateReport(updatedReport);

    if (!mounted) return;

    setState(() {
      _lostReportsFuture = _loadLostReports();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isEl ? 'Η θέαση αποθηκεύτηκε.' : 'Sighting saved successfully.',
        ),
      ),
    );
  }

  void _openMapPreviewScreen(List<LostPetReport> lostReports) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LostReportsMapScreen(reports: lostReports),
      ),
    );
  }

  void _openNearbyLostPetsScreen(List<LostPetReport> reports) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NearbyLostPetsScreen(
          reports: reports,
          userPosition: _userPosition,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    final y = date.year.toString();
    return '$d/$m/$y';
  }

  List<LostPetReport> _newNearbyLostReports(List<LostPetReport> reports) {
    if (_userPosition == null) return [];

    final now = DateTime.now();
    final last24Hours = now.subtract(const Duration(hours: 24));

    return reports.where((report) {
      if (report.isResolved) return false;
      if (report.createdAt.isBefore(last24Hours)) return false;
      if (report.latitude == null || report.longitude == null) return false;

      final meters = Geolocator.distanceBetween(
        _userPosition!.latitude,
        _userPosition!.longitude,
        report.latitude!,
        report.longitude!,
      );

      return meters <= _nearYouRadiusKm * 1000;
    }).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  LostPetReport? _nearestLostReport(List<LostPetReport> reports) {
    if (_userPosition == null || reports.isEmpty) return null;

    LostPetReport? nearest;
    double? nearestMeters;

    for (final report in reports) {
      if (report.latitude == null || report.longitude == null) continue;

      final meters = Geolocator.distanceBetween(
        _userPosition!.latitude,
        _userPosition!.longitude,
        report.latitude!,
        report.longitude!,
      );

      if (nearest == null || nearestMeters == null || meters < nearestMeters) {
        nearest = report;
        nearestMeters = meters;
      }
    }

    return nearest;
  }

  @override
  Widget build(BuildContext context) {
    final isEl = Localizations.localeOf(context).languageCode == 'el';

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(isEl ? 'Απώλειες & Ευρέσεις' : 'Lost & Found'),
        actions: [
          IconButton(
            onPressed: _refreshScreen,
            tooltip: isEl ? 'Ανανέωση' : 'Refresh',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder<List<dynamic>>(
          future: Future.wait([
            _lostReportsFuture,
            _foundReportsFuture,
          ]),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            final lostReports = snap.data![0] as List<LostPetReport>;
            final foundReports = snap.data![1] as List<FoundPetReport>;

            final activeLostReports =
                lostReports.where((report) => !report.isResolved).toList();

            final nearbyNewLostReports = _newNearbyLostReports(lostReports);
            final hasNewNearbyAlert = nearbyNewLostReports.isNotEmpty;
            final newestNearbyReport =
                hasNewNearbyAlert ? nearbyNewLostReports.first : null;
            final nearestNearbyReport =
                _nearestLostReport(nearbyNewLostReports);

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (hasNewNearbyAlert && newestNearbyReport != null) ...[
                  _NewLostAlertBanner(
                    isEl: isEl,
                    report: newestNearbyReport,
                    nearestReport: nearestNearbyReport ?? newestNearbyReport,
                    nearbyCount: nearbyNewLostReports.length,
                    userPosition: _userPosition,
                    onTap: () =>
                        _openNearbyLostPetsScreen(nearbyNewLostReports),
                  ),
                  const SizedBox(height: 12),
                ],
                _ActiveLostAlertsBanner(
                  isEl: isEl,
                  activeCount: activeLostReports.length,
                  onTap: () => _openMapPreviewScreen(activeLostReports),
                ),
                const SizedBox(height: 8),
                Text(
                  isEl
                      ? 'Πάτησε ανανέωση για κοντινές ειδοποιήσεις'
                      : 'Tap refresh to update nearby alerts',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  isEl ? 'Πρόσφατες απώλειες' : 'Recent lost alerts',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                if (lostReports.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Text(
                      isEl
                          ? 'Δεν υπάρχουν απώλειες ακόμα.'
                          : 'No lost alerts yet.',
                    ),
                  )
                else
                  Column(
                    children: lostReports.map((report) {
                      return _LostReportCard(
                        isEl: isEl,
                        report: report,
                        userPosition: _userPosition,
                        isLoadingUserLocation: _isLoadingUserLocation,
                        onTap: () => _openLostReportDetails(report),
                        onMessageTap: () => _openLostMessageScreen(report),
                        onSightingTap: () => _openSightingDialog(report),
                        onEdit: () => _editLostPetReport(report),
                        onDelete: () => _deleteLostReport(report),
                      );
                    }).toList(),
                  ),
                const SizedBox(height: 20),
                Text(
                  isEl ? 'Πρόσφατες ευρέσεις' : 'Recent found alerts',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                if (foundReports.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Text(
                      isEl
                          ? 'Δεν υπάρχουν ευρέσεις ακόμα.'
                          : 'No found alerts yet.',
                    ),
                  )
                else
                  Column(
                    children: foundReports.map((report) {
                      return _FoundReportCard(
                        isEl: isEl,
                        report: report,
                        formattedDate: _formatDate(report.foundDate),
                        onTap: () => _openFoundReportDetails(report),
                        onEdit: () => _editFoundPetReport(report),
                        onDelete: () => _deleteFoundReport(report),
                      );
                    }).toList(),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _NewLostAlertBanner extends StatelessWidget {
  final bool isEl;
  final LostPetReport report;
  final LostPetReport nearestReport;
  final VoidCallback onTap;
  final int nearbyCount;
  final Position? userPosition;

  const _NewLostAlertBanner({
    required this.isEl,
    required this.report,
    required this.nearestReport,
    required this.onTap,
    required this.nearbyCount,
    required this.userPosition,
  });

  String get _petName {
    final name = report.petName.trim();
    return name.isEmpty ? (isEl ? 'Χαμένο ζώο' : 'Lost pet') : name;
  }

  String? _distanceText() {
    if (userPosition == null ||
        nearestReport.latitude == null ||
        nearestReport.longitude == null) {
      return null;
    }

    final meters = Geolocator.distanceBetween(
      userPosition!.latitude,
      userPosition!.longitude,
      nearestReport.latitude!,
      nearestReport.longitude!,
    );

    if (meters < 1000) {
      return isEl ? '${meters.round()} μ. μακριά' : '${meters.round()} m away';
    }

    final km = meters / 1000;
    return isEl
        ? '${km.toStringAsFixed(1)} χλμ μακριά'
        : '${km.toStringAsFixed(1)} km away';
  }

  @override
  Widget build(BuildContext context) {
    final distanceText = _distanceText();

    final String title = nearbyCount == 1
        ? (isEl ? 'ΝΕΑ ΑΠΩΛΕΙΑ ΚΟΝΤΑ ΣΟΥ!' : 'NEW LOST PET NEAR YOU!')
        : (isEl ? 'ΝΕΕΣ ΑΠΩΛΕΙΕΣ ΚΟΝΤΑ ΣΟΥ!' : 'NEW LOST PETS NEAR YOU!');

    final String subtitle = nearbyCount == 1
        ? distanceText != null
            ? (isEl
                ? 'Το $_petName δηλώθηκε πριν λίγο • $distanceText'
                : '$_petName has just been reported nearby • $distanceText')
            : (isEl
                ? 'Το $_petName δηλώθηκε πριν λίγο κοντά σου.'
                : '$_petName has just been reported nearby.')
        : distanceText != null
            ? (isEl
                ? '$nearbyCount νέες απώλειες κοντά σου • η πιο κοντινή είναι $distanceText'
                : '$nearbyCount new lost pets nearby • nearest is $distanceText')
            : (isEl
                ? '$nearbyCount νέες απώλειες δηλώθηκαν κοντά σου.'
                : '$nearbyCount new lost pets have just been reported nearby.');

    return Container(
      constraints: const BoxConstraints(minHeight: 92),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFF44336),
            Color(0xFFFFA726),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                height: 54,
                width: 54,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.notifications_active_rounded,
                  color: Colors.white,
                  size: 29,
                ),
              ),
              Positioned(
                right: -4,
                top: -4,
                child: Container(
                  constraints: const BoxConstraints(
                    minWidth: 23,
                    minHeight: 23,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '$nearbyCount',
                      style: const TextStyle(
                        color: AppTheme.lostFound,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 14.5,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.96),
                    fontSize: 13.5,
                    height: 1.25,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Material(
            color: Colors.white.withOpacity(0.96),
            borderRadius: BorderRadius.circular(999),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(999),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isEl ? 'Προβολή' : 'View',
                      style: const TextStyle(
                        color: AppTheme.primaryTeal,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: AppTheme.primaryTeal,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveLostAlertsBanner extends StatelessWidget {
  final bool isEl;
  final int activeCount;
  final VoidCallback onTap;

  const _ActiveLostAlertsBanner({
    required this.isEl,
    required this.activeCount,
    required this.onTap,
  });

  String get _subtitle {
    if (activeCount == 0) {
      return isEl ? 'Δεν υπάρχουν ενεργές απώλειες' : 'No active lost reports';
    }
    if (activeCount == 1) {
      return isEl ? '1 ζώο αγνοείται κοντά σου' : '1 pet missing near you';
    }
    return isEl
        ? '$activeCount ζώα αγνοούνται κοντά σου'
        : '$activeCount pets missing near you';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 92),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFF44336),
            Color(0xFFFFA726),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 14,
            offset: const Offset(0, 6),
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
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEl ? 'ΕΝΕΡΓΕΣ ΑΠΩΛΕΙΕΣ' : 'ACTIVE LOST ALERTS',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 14.5,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.96),
                    fontSize: 13.5,
                    height: 1.25,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Material(
            color: Colors.white.withOpacity(0.96),
            borderRadius: BorderRadius.circular(999),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(999),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.map_outlined,
                      size: 18,
                      color: AppTheme.primaryTeal,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isEl ? 'Χάρτης' : 'Map',
                      style: const TextStyle(
                        color: AppTheme.primaryTeal,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;

  const _StatusBadge({
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: color.withOpacity(0.24),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 13,
            color: color,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _DistanceBadge extends StatelessWidget {
  final String text;
  final Color color;

  const _DistanceBadge({
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: color.withOpacity(0.20),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.location_on_rounded,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportThumbnail extends StatelessWidget {
  final String? photoPath;
  final Color accentColor;

  const _ReportThumbnail({
    required this.photoPath,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final hasPhoto = photoPath != null && photoPath!.trim().isNotEmpty;

    Widget fallback() {
      return Container(
        height: 92,
        width: 92,
        decoration: BoxDecoration(
          color: accentColor.withOpacity(0.10),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(
          Icons.pets,
          color: accentColor,
          size: 34,
        ),
      );
    }

    if (!hasPhoto) {
      return fallback();
    }

    final path = photoPath!.trim();

    Widget framed(Widget child) {
      return Container(
        height: 92,
        width: 92,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: accentColor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: accentColor.withOpacity(0.16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(17),
          child: child,
        ),
      );
    }

    if (kIsWeb) {
      final uri = Uri.tryParse(path);
      final isValidWebImage =
          uri != null && uri.hasScheme && uri.host.isNotEmpty;

      if (!isValidWebImage) {
        return fallback();
      }

      return framed(
        Image.network(
          path,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => fallback(),
        ),
      );
    }

    return framed(
      Image.file(
        File(path),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback(),
      ),
    );
  }
}

class _ActionPillButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  const _ActionPillButton({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: SizedBox(
        height: 52,
        child: OutlinedButton.icon(
          onPressed: onTap,
          icon: Icon(icon, size: 18),
          label: Text(label),
          style: OutlinedButton.styleFrom(
            foregroundColor: color,
            side: BorderSide(
              color: color.withOpacity(0.22),
            ),
            backgroundColor: color.withOpacity(0.04),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

class _LostReportCard extends StatelessWidget {
  final bool isEl;
  final LostPetReport report;
  final Position? userPosition;
  final bool isLoadingUserLocation;
  final VoidCallback onTap;
  final VoidCallback onMessageTap;
  final VoidCallback onSightingTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _LostReportCard({
    required this.isEl,
    required this.report,
    required this.userPosition,
    required this.isLoadingUserLocation,
    required this.onTap,
    required this.onMessageTap,
    required this.onSightingTap,
    required this.onEdit,
    required this.onDelete,
  });

  Future<void> _callOwner() async {
    final phone = report.contactPhone.trim();
    if (phone.isEmpty) return;

    final uri = Uri.parse('tel:$phone');
    await launchUrl(uri);
  }

  Future<void> _shareReport() async {
    final petName = report.petName.trim().isEmpty
        ? (isEl ? 'Χαμένο ζώο' : 'Lost pet')
        : report.petName.trim();
    final contact = report.contactPhone.trim().isEmpty
        ? (isEl ? 'Δεν υπάρχει τηλέφωνο' : 'No phone provided')
        : report.contactPhone.trim();

    final text = isEl
        ? '''
Ειδοποίηση απώλειας

Ζώο: $petName
Τοποθεσία: ${report.lastSeenLocation}
Επικοινωνία: $contact

Κοινοποιήθηκε μέσω Petbook
'''
        : '''
Lost pet alert

Pet: $petName
Location: ${report.lastSeenLocation}
Contact: $contact

Shared via Petbook
''';

    await Share.share(text);
  }

  String? _distanceText() {
    if (userPosition == null ||
        report.latitude == null ||
        report.longitude == null) {
      return null;
    }

    final meters = Geolocator.distanceBetween(
      userPosition!.latitude,
      userPosition!.longitude,
      report.latitude!,
      report.longitude!,
    );

    if (meters < 1000) {
      return isEl ? '${meters.round()} μ. μακριά' : '${meters.round()} m away';
    }

    final km = meters / 1000;
    return isEl
        ? '${km.toStringAsFixed(1)} χλμ μακριά'
        : '${km.toStringAsFixed(1)} km away';
  }

  @override
  Widget build(BuildContext context) {
    final hasPhone = report.contactPhone.trim().isNotEmpty;
    final distanceText = _distanceText();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
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
                    _ReportThumbnail(
                      photoPath: report.photoPath,
                      accentColor: AppTheme.lostFound,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              _StatusBadge(
                                label: report.isResolved
                                    ? (isEl ? 'ΒΡΕΘΗΚΕ' : 'FOUND')
                                    : (isEl ? 'ΧΑΘΗΚΕ' : 'LOST'),
                                color: report.isResolved
                                    ? AppTheme.primaryTeal
                                    : AppTheme.lostFound,
                                icon: report.isResolved
                                    ? Icons.check_circle_rounded
                                    : Icons.warning_amber_rounded,
                              ),
                              const Spacer(),
                              PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'edit') onEdit();
                                  if (value == 'delete') onDelete();
                                },
                                itemBuilder: (context) => [
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Text(isEl ? 'Επεξεργασία' : 'Edit'),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text(isEl ? 'Διαγραφή' : 'Delete'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            report.petName.trim().isEmpty
                                ? (isEl ? 'Χαμένο ζώο' : 'Lost pet')
                                : report.petName.trim(),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.textPrimary,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
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
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color:
                                        AppTheme.textSecondary.withOpacity(0.9),
                                    height: 1.3,
                                    fontWeight: FontWeight.w500,
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
                if (distanceText != null || isLoadingUserLocation)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: isLoadingUserLocation && distanceText == null
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : distanceText != null
                              ? _DistanceBadge(
                                  text: distanceText,
                                  color: AppTheme.primaryTeal,
                                )
                              : const SizedBox.shrink(),
                    ),
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (hasPhone)
                      _ActionPillButton(
                        label: isEl ? 'Κλήση' : 'Call',
                        icon: Icons.call_rounded,
                        onTap: _callOwner,
                        color: Colors.green,
                      ),
                    if (hasPhone) const SizedBox(width: 8),
                    _ActionPillButton(
                      label: 'Msg',
                      icon: Icons.chat_bubble_outline_rounded,
                      onTap: onMessageTap,
                      color: AppTheme.primaryTeal,
                    ),
                    const SizedBox(width: 8),
                    _ActionPillButton(
                      label: isEl ? 'Κοινοπ.' : 'Share',
                      icon: Icons.share_outlined,
                      onTap: _shareReport,
                      color: AppTheme.textSecondary,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: onSightingTap,
                    icon: const Icon(Icons.remove_red_eye_outlined),
                    label: Text(isEl ? 'Το είδα' : 'I Saw It'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryTeal,
                      side: BorderSide(
                        color: AppTheme.primaryTeal.withOpacity(0.28),
                      ),
                      backgroundColor: const Color(0xFFEAF7F5),
                      elevation: 1,
                      shadowColor: Colors.black.withOpacity(0.05),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FoundReportCard extends StatelessWidget {
  final bool isEl;
  final FoundPetReport report;
  final String formattedDate;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _FoundReportCard({
    required this.isEl,
    required this.report,
    required this.formattedDate,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  Future<void> _callFinder() async {
    final phone = report.contactPhone.trim();
    if (phone.isEmpty) return;

    final uri = Uri.parse('tel:$phone');
    await launchUrl(uri);
  }

  Future<void> _messageFinder(BuildContext context) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => SendFoundPetMessageScreen(report: report),
      ),
    );
  }

  Future<void> _shareReport() async {
    final typeText = report.type.trim().isEmpty
        ? (isEl ? 'Βρέθηκε ζώο' : 'Found pet')
        : report.type.trim();
    final contact = report.contactPhone.trim().isEmpty
        ? (isEl ? 'Δεν υπάρχει τηλέφωνο' : 'No phone provided')
        : report.contactPhone.trim();

    final text = isEl
        ? '''
Ειδοποίηση εύρεσης

Τύπος: $typeText
Τοποθεσία: ${report.locationFound}
Ημερομηνία: $formattedDate
Επικοινωνία: $contact

Κοινοποιήθηκε μέσω Petbook
'''
        : '''
Found pet alert

Type: $typeText
Location: ${report.locationFound}
Date: $formattedDate
Contact: $contact

Shared via Petbook
''';

    await Share.share(text);
  }

  @override
  Widget build(BuildContext context) {
    final hasPhone = report.contactPhone.trim().isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppTheme.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 14,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ReportThumbnail(
                      photoPath: report.photoPath,
                      accentColor: AppTheme.primaryTeal,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              _StatusBadge(
                                label: isEl ? 'ΒΡΕΘΗΚΕ' : 'FOUND',
                                color: AppTheme.primaryTeal,
                                icon: Icons.favorite_rounded,
                              ),
                              const Spacer(),
                              PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'edit') onEdit();
                                  if (value == 'delete') onDelete();
                                },
                                itemBuilder: (context) => [
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Text(isEl ? 'Επεξεργασία' : 'Edit'),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text(isEl ? 'Διαγραφή' : 'Delete'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            report.type.trim().isEmpty
                                ? (isEl ? 'Βρέθηκε ζώο' : 'Found pet')
                                : report.type.trim(),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(top: 2),
                                child: Icon(
                                  Icons.location_on_outlined,
                                  size: 16,
                                  color: AppTheme.primaryTeal,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  report.locationFound.trim().isEmpty
                                      ? (isEl
                                          ? 'Δεν υπάρχει τοποθεσία'
                                          : 'No location added')
                                      : report.locationFound,
                                  style: const TextStyle(
                                    color: AppTheme.textSecondary,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            formattedDate,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (hasPhone) ...[
                            const SizedBox(height: 8),
                            Text(
                              isEl
                                  ? 'Επικοινωνία: ${report.contactPhone.trim()}'
                                  : 'Contact: ${report.contactPhone.trim()}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (hasPhone)
                      _ActionPillButton(
                        label: isEl ? 'Κλήση' : 'Call',
                        icon: Icons.call_rounded,
                        onTap: _callFinder,
                        color: Colors.green,
                      ),
                    if (hasPhone) const SizedBox(width: 8),
                    _ActionPillButton(
                      label: 'Msg',
                      icon: Icons.chat_bubble_outline_rounded,
                      onTap: () => _messageFinder(context),
                      color: AppTheme.primaryTeal,
                    ),
                    const SizedBox(width: 8),
                    _ActionPillButton(
                      label: isEl ? 'Κοινοπ.' : 'Share',
                      icon: Icons.share_outlined,
                      onTap: _shareReport,
                      color: AppTheme.textSecondary,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0xFF96B8B4).withOpacity(0.45)
      ..strokeWidth = 1;

    final roadPaint = Paint()
      ..color = const Color(0xFFD6D0C2)
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    for (double x = 20; x < size.width; x += 36) {
      canvas.drawLine(Offset(x, 0), Offset(x - 20, size.height), gridPaint);
    }

    for (double y = 18; y < size.height; y += 28) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y + 6), gridPaint);
    }

    final path1 = Path()
      ..moveTo(12, size.height * 0.70)
      ..quadraticBezierTo(
        size.width * 0.28,
        size.height * 0.54,
        size.width * 0.56,
        size.height * 0.62,
      )
      ..quadraticBezierTo(
        size.width * 0.78,
        size.height * 0.68,
        size.width - 14,
        size.height * 0.38,
      );

    final path2 = Path()
      ..moveTo(size.width * 0.18, 8)
      ..quadraticBezierTo(
        size.width * 0.34,
        size.height * 0.24,
        size.width * 0.52,
        size.height * 0.18,
      )
      ..quadraticBezierTo(
        size.width * 0.74,
        size.height * 0.12,
        size.width * 0.90,
        size.height * 0.36,
      );

    canvas.drawPath(path1, roadPaint);
    canvas.drawPath(path2, roadPaint);

    final waterPaint = Paint()
      ..color = const Color(0xFFBFDDE2).withOpacity(0.60);

    final waterPath = Path()
      ..moveTo(size.width * 0.72, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width * 0.86, size.height * 0.84)
      ..quadraticBezierTo(
        size.width * 0.78,
        size.height * 0.62,
        size.width * 0.72,
        size.height * 0.44,
      )
      ..close();

    canvas.drawPath(waterPath, waterPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
