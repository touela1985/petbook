import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

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
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
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
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                height: 56,
                width: 56,
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
              Positioned(
                right: 0,
                top: 2,
                child: Container(
                  constraints: const BoxConstraints(
                    minWidth: 24,
                    minHeight: 24,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 6),
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
                        fontSize: 12,
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.96),
                    fontSize: 15,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 14),
                InkWell(
                  onTap: onTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.94),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isEl ? 'Προβολή' : 'View Alert',
                          style: const TextStyle(
                            color: AppTheme.primaryTeal,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: AppTheme.primaryTeal,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
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
      return isEl
          ? 'Δεν υπάρχουν ενεργές απώλειες τώρα'
          : 'No active lost reports right now';
    }
    if (activeCount == 1) {
      return isEl
          ? '1 ζώο αγνοείται αυτή τη στιγμή κοντά σου'
          : '1 pet currently missing near you';
    }
    return isEl
        ? '$activeCount ζώα αγνοούνται αυτή τη στιγμή κοντά σου'
        : '$activeCount pets currently missing near you';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
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
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: 8,
            top: 0,
            child: Icon(
              Icons.pets,
              size: 30,
              color: Colors.white.withOpacity(0.10),
            ),
          ),
          Positioned(
            right: 42,
            top: 18,
            child: Icon(
              Icons.favorite_rounded,
              size: 34,
              color: Colors.white.withOpacity(0.08),
            ),
          ),
          Positioned(
            right: 88,
            top: 12,
            child: Icon(
              Icons.pets,
              size: 18,
              color: Colors.white.withOpacity(0.10),
            ),
          ),
          Positioned(
            left: -20,
            bottom: -28,
            child: Container(
              width: 180,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 56,
                width: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEl ? 'ΕΝΕΡΓΕΣ ΑΠΩΛΕΙΕΣ' : 'ACTIVE LOST ALERTS',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _subtitle,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.96),
                        fontSize: 15,
                        height: 1.25,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Material(
                        color: Colors.white.withOpacity(0.94),
                        borderRadius: BorderRadius.circular(999),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(999),
                          onTap: onTap,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 12,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.location_on_outlined,
                                  size: 18,
                                  color: Color(0xFF5D5245),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  isEl ? 'Δες στον χάρτη' : 'See on map',
                                  style: const TextStyle(
                                    color: Color(0xFF3B3B3B),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  size: 18,
                                  color: Color(0xFF3B3B3B),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
        height: 88,
        width: 88,
        decoration: BoxDecoration(
          color: accentColor.withOpacity(0.10),
          borderRadius: BorderRadius.circular(18),
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
        height: 88,
        width: 88,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: accentColor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: accentColor.withOpacity(0.16),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
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
          padding: const EdgeInsets.symmetric(vertical: 11),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
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
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _LostReportCard({
    required this.isEl,
    required this.report,
    required this.userPosition,
    required this.isLoadingUserLocation,
    required this.onTap,
    required this.onMessageTap,
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
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
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
                          const SizedBox(height: 6),
                          Text(
                            report.petName.trim().isEmpty
                                ? (isEl ? 'Χαμένο ζώο' : 'Lost pet')
                                : report.petName.trim(),
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
                          if (hasPhone) ...[
                            const SizedBox(height: 8),
                            Text(
                              isEl
                                  ? 'Επικοινωνία: ${report.contactPhone}'
                                  : 'Contact: ${report.contactPhone}',
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
