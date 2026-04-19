import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../data/lost_pet_report_repository.dart';
import '../data/pet_repository.dart';
import '../models/lost_pet_report.dart';
import '../widgets/pet_image_widget.dart';
import '../l10n/app_localizations.dart';
import '../models/pet.dart';
import '../theme/app_theme.dart';
import 'add_found_pet_report_screen.dart';
import 'add_lost_pet_report_screen.dart';
import 'add_pet_screen.dart';
import 'adoption_list_screen.dart';
import 'lost_found_screen.dart';
import 'lost_pet_report_details_screen.dart';
import 'pet_profile_screen.dart';
import 'reminders_screen.dart';
import 'lost_reports_map_screen.dart';
import '../data/pet_health_repository.dart';
import '../models/pet_health_event.dart';

class HomeScreen extends StatefulWidget {
  final PetRepository repo;
  final Future<void> Function(Locale? locale)? onChangeLocale;
  final Locale? currentLocale;

  const HomeScreen({
    super.key,
    required this.repo,
    this.onChangeLocale,
    this.currentLocale,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final LostPetReportRepository _lostRepo = LostPetReportRepository();
  final PetHealthRepository _healthRepo = PetHealthRepository();

  Future<List<Pet>> _loadPets() async => widget.repo.getAll();

  // ── Banner counts: distance-based nearby (<=3000m) + active-outside-nearby ──
  static const double _nearbyThresholdMeters = 3000.0;

  Future<List<int>> _loadBannerCounts() async {
    final reports = await _lostRepo.getReports();
    final activeReports = reports.where((r) => !r.isResolved).toList();

    debugPrint('[Banner] Total active lost reports: ${activeReports.length}');

    // Get user position — same pattern as lost_found_screen.dart
    Position? userPosition;
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.whileInUse ||
            permission == LocationPermission.always) {
          userPosition = await Geolocator.getCurrentPosition();
        }
      }
    } catch (e) {
      debugPrint('[Banner] Location unavailable: $e');
    }

    if (userPosition == null) {
      // No location → no nearby banner, show all active as active-only
      debugPrint(
          '[Banner] No location — nearbyCount=0, activeLostCount=${activeReports.length}');
      return [0, activeReports.length];
    }

    // Split: nearby (distanceMeters <= 3000) vs far
    final nearbyIds = <String>{};
    for (final report in activeReports) {
      if (report.latitude == null || report.longitude == null) {
        debugPrint(
            '[Banner] "${report.petName}" — no coordinates, skipped from nearby');
        continue;
      }
      final distMeters = Geolocator.distanceBetween(
        userPosition.latitude,
        userPosition.longitude,
        report.latitude!,
        report.longitude!,
      );
      debugPrint(
          '[Banner] "${report.petName}" — distanceMeters=${distMeters.toStringAsFixed(0)}');
      if (distMeters <= _nearbyThresholdMeters) {
        nearbyIds.add(report.id);
      }
    }

    final nearbyCount = nearbyIds.length;
    final activeLostCount =
        activeReports.where((r) => !nearbyIds.contains(r.id)).length;

    debugPrint(
        '[Banner] nearbyCount=$nearbyCount, activeLostCount=$activeLostCount');
    return [nearbyCount, activeLostCount];
  }

  Future<void> _setLanguage(Locale? locale) async {
    if (widget.onChangeLocale == null) return;
    await widget.onChangeLocale!(locale);
    if (mounted) setState(() {});
  }

  Future<PetHealthEvent?> _getNextReminder() async {
    final events =
        await _healthRepo.getAllEvents(); // αν δεν έχεις αυτή τη method πες μου

    final now = DateTime.now();

    final reminders = events.where((e) => e.reminderDate != null).toList();

    if (reminders.isEmpty) return null;

    final future = reminders.where((e) {
      final d = e.reminderDate!;
      return !DateTime(d.year, d.month, d.day)
          .isBefore(DateTime(now.year, now.month, now.day));
    }).toList();

    if (future.isEmpty) return null;

    future.sort((a, b) => a.reminderDate!.compareTo(b.reminderDate!));

    return future.first;
  }

  String _langLabel() {
    final code = widget.currentLocale?.languageCode;
    if (code == null) return 'AUTO';
    if (code == 'el') return 'ΕΛ';
    return 'EN';
  }

  void _openAddPet() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddPetScreen(repo: widget.repo)),
    );
    if (mounted) setState(() {});
  }

  void _openPetProfile(Pet pet) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PetProfileScreen(repo: widget.repo, petId: pet.id),
      ),
    );
    if (mounted) setState(() {});
  }

  void _openLostFound() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const LostFoundScreen(),
      ),
    );
    if (mounted) setState(() {});
  }

  /// Nearby banner primary CTA → opens the NEAREST nearby report directly.
  /// Falls back to the generic list only if location is unavailable or
  /// no reports are found within threshold.
  void _openNearestNearbyReport() async {
    final reports = await _lostRepo.getReports();
    final activeReports = reports.where((r) => !r.isResolved).toList();

    Position? userPosition;
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.whileInUse ||
            permission == LocationPermission.always) {
          userPosition = await Geolocator.getCurrentPosition();
        }
      }
    } catch (_) {}

    // No location → fall back to generic list
    if (userPosition == null) {
      _openLostFound();
      return;
    }

    // Build nearby list with distances
    final nearby = <LostPetReport>[];
    final distances = <String, double>{};
    for (final report in activeReports) {
      if (report.latitude == null || report.longitude == null) continue;
      final dist = Geolocator.distanceBetween(
        userPosition.latitude,
        userPosition.longitude,
        report.latitude!,
        report.longitude!,
      );
      if (dist <= _nearbyThresholdMeters) {
        nearby.add(report);
        distances[report.id] = dist;
      }
    }

    // No nearby reports found → fall back to generic list
    if (nearby.isEmpty) {
      _openLostFound();
      return;
    }

    // Sort ascending by distance — nearest first
    nearby.sort((a, b) => distances[a.id]!.compareTo(distances[b.id]!));
    final nearest = nearby.first;

    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LostPetReportDetailsScreen(report: nearest),
      ),
    );
    if (mounted) setState(() {});
  }

  void _openLostPetReport() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AddLostPetReportScreen(),
      ),
    );
    if (mounted) setState(() {});
  }

  void _openFoundPetReport() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AddFoundPetReportScreen(),
      ),
    );
    if (mounted) setState(() {});
  }

  void _openAdoptions() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AdoptionListScreen(),
      ),
    );
    if (mounted) setState(() {});
  }

  void _openReminders() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const RemindersScreen(),
      ),
    );
  }

  void _openActiveLostMap() async {
    final reports = await _lostRepo.getReports();
    final activeLostReports =
        reports.where((report) => !report.isResolved).toList();

    if (!mounted || activeLostReports.isEmpty) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LostReportsMapScreen(reports: activeLostReports),
      ),
    );

    if (mounted) setState(() {});
  }

  String _ageGenderText(Pet pet, {required bool isEl}) {
    final parts = <String>[];

    final a = pet.age;
    if (a != null) {
      final s = a.toString().trim();
      if (s.isNotEmpty && s != '0' && s != '0.0') {
        parts.add(s);
      }
    }

    final g = pet.gender;
    if (g != null) {
      final s = g.toString().trim();
      final low = s.toLowerCase();

      if (s.isNotEmpty && low != 'null' && s != '0') {
        if (isEl) {
          if (low == 'female' || low == 'f' || s.contains('θηλ')) {
            parts.add('Θηλυκό');
          } else if (low == 'male' || low == 'm' || s.contains('αρσ')) {
            parts.add('Αρσενικό');
          } else {
            parts.add(s);
          }
        } else {
          if (low.contains('θηλ') || low == 'f' || low == 'female') {
            parts.add('Female');
          } else if (low.contains('αρσ') || low == 'm' || low == 'male') {
            parts.add('Male');
          } else {
            parts.add(s);
          }
        }
      }
    }

    return parts.join(' • ');
  }

  @override
  Widget build(BuildContext context) {
    final localeCode = Localizations.localeOf(context).languageCode;
    final isEl = localeCode == 'el';
    final t = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              height: 38,
              width: 38,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.16),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.pets, size: 20),
            ),
            const SizedBox(width: 10),
            const Text(
              'Petbook',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: isEl ? 'Υπενθυμίσεις' : 'Reminders',
            onPressed: _openReminders,
            icon: const Icon(Icons.notifications_outlined),
          ),
          PopupMenuButton<String>(
            tooltip: isEl ? 'Γλώσσα' : 'Language',
            onSelected: (v) async {
              if (v == 'auto') await _setLanguage(null);
              if (v == 'el') await _setLanguage(const Locale('el'));
              if (v == 'en') await _setLanguage(const Locale('en'));
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'auto', child: Text('Auto')),
              PopupMenuItem(value: 'el', child: Text('Ελληνικά')),
              PopupMenuItem(value: 'en', child: Text('English')),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  const Icon(Icons.language, size: 20),
                  const SizedBox(width: 6),
                  Text(
                    _langLabel(),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 2),
                  const Icon(Icons.arrow_drop_down, size: 20),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: FutureBuilder<List<dynamic>>(
        future: Future.wait<dynamic>([
          _loadPets(),
          _loadBannerCounts(), // [nearbyCount, activeLostOutsideNearby]
        ]),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final pets = snap.data![0] as List<Pet>;
          final bannerCounts = snap.data![1] as List<int>;
          // alertCount  = reports within 3000m of user
          // activeLostCount = active reports outside the 3000m radius
          final alertCount = bannerCounts[0];
          final activeLostCount = bannerCounts[1];

          // Explicit banner conditions — never show both at the same time
          final hasNearbyBanner = alertCount > 0;
          final hasActiveBanner = !hasNearbyBanner && activeLostCount > 0;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              // ── TOP ALERT BANNER — one state shown at a time ──────────────
              if (hasNearbyBanner) ...[
                _HomeAlertBanner(
                  isEl: isEl,
                  alertCount: alertCount,
                  activeCount: activeLostCount,
                  showNearby: true,
                  // Opens the NEAREST nearby report directly — NOT the generic list
                  onOpenReports: _openNearestNearbyReport,
                  onOpenMap: _openActiveLostMap,
                ),
                const SizedBox(height: 20),
              ] else if (hasActiveBanner) ...[
                _HomeAlertBanner(
                  isEl: isEl,
                  alertCount: alertCount,
                  activeCount: activeLostCount,
                  showNearby: false,
                  onOpenReports: _openLostFound,
                  onOpenMap: _openActiveLostMap,
                ),
                const SizedBox(height: 20),
              ],
              // (if !hasAnyBanner → no banner, no spacing)
              // ── REPORT LOST / REPORT FOUND (unchanged) ───────────────────
              Row(
                children: [
                  Expanded(
                    child: _QuickActionCard(
                      title: isEl ? 'Report Lost' : 'Report Lost',
                      subtitle: isEl
                          ? 'Δήλωσε ένα χαμένο ζώο'
                          : 'Report a missing pet',
                      icon: Icons.pets_rounded,
                      iconColor: Colors.white,
                      backgroundColor: const Color(0xFFE4574E),
                      secondaryColor: const Color(0xFFF06D58),
                      iconBackgroundColor: Colors.white.withOpacity(0.18),
                      textColor: Colors.white,
                      subtitleColor: Colors.white.withOpacity(0.92),
                      onTap: _openLostPetReport,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _QuickActionCard(
                      title: isEl ? 'Report Found' : 'Report Found',
                      subtitle: isEl
                          ? 'Δήλωσε ζώο που βρέθηκε και βοήθησε στην επανένωση'
                          : 'Report a found pet and help reunite it',
                      icon: Icons.location_on_rounded,
                      iconColor: Colors.white,
                      backgroundColor: const Color(0xFF26A69A),
                      secondaryColor: const Color(0xFF45B9AE),
                      iconBackgroundColor: Colors.white.withOpacity(0.18),
                      textColor: Colors.white,
                      subtitleColor: Colors.white.withOpacity(0.92),
                      onTap: _openFoundPetReport,
                    ),
                  ),
                ],
              ),
              // ── CARE & SERVICES (new) ─────────────────────────────────────
              const SizedBox(height: 14),
              _CareServicesCard(isEl: isEl),
              // ── REMINDER STRIP ────────────────────────────────────────────
              FutureBuilder<PetHealthEvent?>(
                future: _getNextReminder(),
                builder: (context, reminderSnap) {
                  if (!reminderSnap.hasData || reminderSnap.data == null) {
                    return const SizedBox();
                  }

                  final event = reminderSnap.data!;
                  final now = DateTime.now();
                  final today = DateTime(now.year, now.month, now.day);
                  final reminderDay = DateTime(
                    event.reminderDate!.year,
                    event.reminderDate!.month,
                    event.reminderDate!.day,
                  );
                  final days = reminderDay.difference(today).inDays;

                  String title = isEl ? 'Σύντομη υπενθύμιση' : 'Reminder soon';
                  String subtitle;

                  if (days <= 0) {
                    subtitle = isEl
                        ? '${event.title} • σήμερα'
                        : '${event.title} • today';
                  } else if (days == 1) {
                    subtitle = isEl
                        ? '${event.title} • αύριο'
                        : '${event.title} • tomorrow';
                  } else {
                    subtitle = isEl
                        ? '${event.title} • σε $days ημέρες'
                        : '${event.title} • in $days days';
                  }

                  return Padding(
                    padding: const EdgeInsets.only(top: 16, bottom: 24),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PetProfileScreen(
                                repo: widget.repo,
                                petId: event.petId,
                              ),
                            ),
                          );
                          if (mounted) setState(() {});
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF3E0),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(0xFFF0CC80),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.03),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                height: 40,
                                width: 40,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFE7BF),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.notifications_active_rounded,
                                  color: Color(0xFFE09A1A),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15,
                                        color: AppTheme.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      subtitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontWeight: FontWeight.w500,
                                        fontSize: 12.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.chevron_right_rounded,
                                color: AppTheme.textSecondary,
                                size: 22,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 32),
              // ── MY PETS (unchanged) ───────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: Text(
                      t.myPets,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ),
                  _DashboardAddPetButton(
                    label: t.addPet,
                    onTap: _openAddPet,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (pets.isEmpty)
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppTheme.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        height: 64,
                        width: 64,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryTeal.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(
                          Icons.pets,
                          color: AppTheme.primaryTeal,
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        t.noPets,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isEl
                            ? 'Πρόσθεσε το πρώτο σου κατοικίδιο και ξεκίνα να παρακολουθείς υγεία, υπενθυμίσεις και πολλά ακόμα.'
                            : 'Add your first pet and start tracking health, reminders and more.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _openAddPet,
                          icon: const Icon(Icons.add),
                          label: Text(
                            isEl
                                ? 'Πρόσθεσε το πρώτο σου κατοικίδιο'
                                : 'Add your first pet',
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                SizedBox(
                  height: 292,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: pets.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, i) {
                      final pet = pets[i];
                      final meta = _ageGenderText(pet, isEl: isEl);

                      return _PetMiniCard(
                        pet: pet,
                        meta: meta,
                        onTap: () => _openPetProfile(pet),
                        isEl: isEl,
                      );
                    },
                  ),
                ),
              const SizedBox(height: 22),
              // ── ADOPTION (unchanged) ──────────────────────────────────────
              _AdoptionPromoCard(
                isEl: isEl,
                onTap: _openAdoptions,
                title: t.adoption,
                ctaLabel: t.explore,
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// UNIFIED ALERT BANNER
// Logic:
//   alertCount > 0            → nearby version (open + map buttons)
//   alertCount == 0, active>0 → active-only version (map button)
//   both == 0                 → caller hides via `if (hasBanner)` guard
// ─────────────────────────────────────────────────────────────────────────────
class _HomeAlertBanner extends StatelessWidget {
  final bool isEl;
  final int alertCount;
  final int activeCount;
  /// Explicit: true = show nearby version, false = show active version
  final bool showNearby;
  final VoidCallback onOpenReports;
  final VoidCallback onOpenMap;

  const _HomeAlertBanner({
    required this.isEl,
    required this.alertCount,
    required this.activeCount,
    required this.showNearby,
    required this.onOpenReports,
    required this.onOpenMap,
  });

  // Shared gradient: soft aqua → teal → warm orange
  static const _gradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [
      Color(0xFF26C6DA), // aqua / cyan 400
      Color(0xFF4DB6AC), // teal 300
      Color(0xFFFF8A65), // deep-orange 300 (warm)
    ],
  );

  static const _shadowColor = Color(0xFF26C6DA);

  Widget _buildNearbyContent(bool isEl) {
    final count = alertCount;
    // Correct singular/plural — avoid broken string interpolation inside suffixes
    final title = isEl
        ? (count == 1
            ? '1 ειδοποίηση κοντά σου'
            : '$count ειδοποιήσεις κοντά σου')
        : (count == 1 ? '1 alert near you' : '$count alerts near you');
    // Short subtitle — prevents layout overflow on small screens
    final subtitle =
        isEl ? 'Πάτησε για προβολή' : 'Tap to open';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _PulsingAlertBadge(icon: Icons.warning_amber_rounded),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // FittedBox → scales down title gracefully if it doesn't fit,
              // never truncates mid-word
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.22),
                        blurRadius: 6,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.86),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  shadows: [
                    Shadow(
                      color: Colors.black.withOpacity(0.14),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        // Both buttons in same Row — same height, same style
        _BannerButton(
          label: isEl ? 'Άνοιγμα' : 'Open',
          icon: Icons.chevron_right_rounded,
          onTap: onOpenReports,
        ),
        const SizedBox(width: 6),
        _BannerButton(
          label: isEl ? 'Χάρτης' : 'Map',
          icon: Icons.map_outlined,
          onTap: onOpenMap,
        ),
      ],
    );
  }

  Widget _buildActiveContent(bool isEl) {
    // Shorter title — fits even on narrow screens
    final title = isEl ? 'Ενεργές απώλειες' : 'Active lost alerts';
    // Correct singular/plural per spec
    final subtitle = isEl
        ? (activeCount == 1
            ? '1 ζώο αγνοείται κοντά σου'
            : '$activeCount ζώα αγνοούνται κοντά σου')
        : (activeCount == 1
            ? '1 pet missing near you'
            : '$activeCount pets missing near you');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Circular icon — matches nearby badge for visual consistency
        Container(
          height: 56,
          width: 56,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.24),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.white.withOpacity(0.16),
                blurRadius: 10,
                spreadRadius: 1,
              ),
            ],
          ),
          child: const Icon(
            Icons.location_searching_rounded,
            color: Colors.white,
            size: 32,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // FittedBox → title scales down gracefully, never truncates
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.22),
                        blurRadius: 6,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 2),
              // Subtitle also uses FittedBox for safety
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.86),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.14),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _BannerButton(
          label: isEl ? 'Χάρτης' : 'Map',
          icon: Icons.map_outlined,
          onTap: onOpenMap,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: showNearby ? onOpenReports : onOpenMap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: _gradient,
            boxShadow: [
              BoxShadow(
                color: _shadowColor.withOpacity(0.28),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          // Direct content — no Stack needed, avoids clipping of decorative elements
          child: showNearby
              ? _buildNearbyContent(isEl)
              : _buildActiveContent(isEl),
        ),
      ),
    );
  }
}

// Small white/cream pill button used inside the banner
class _BannerButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _BannerButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        // Compact padding — gives more horizontal room to text column
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFFDF7F2),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, color: const Color(0xFF00695C), size: 13),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF00695C),
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PULSING ALERT BADGE (unchanged — used by nearby state)
// ─────────────────────────────────────────────────────────────────────────────
class _PulsingAlertBadge extends StatefulWidget {
  final IconData icon;

  const _PulsingAlertBadge({
    required this.icon,
  });

  @override
  State<_PulsingAlertBadge> createState() => _PulsingAlertBadgeState();
}

class _PulsingAlertBadgeState extends State<_PulsingAlertBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1350),
    )..repeat(reverse: true);

    _scale = Tween<double>(
      begin: 1.0,
      end: 1.06,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Container(
        height: 56,
        width: 56,
        decoration: BoxDecoration(
          // Circular — visually dominant focal point
          color: Colors.white.withOpacity(0.26),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.white.withOpacity(0.18),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Icon(
          widget.icon,
          color: Colors.white,
          size: 36,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CARE & SERVICES CARD (new)
// ─────────────────────────────────────────────────────────────────────────────
class _CareServicesCard extends StatelessWidget {
  final bool isEl;

  const _CareServicesCard({required this.isEl});

  @override
  Widget build(BuildContext context) {
    final title = isEl ? 'Φροντίδα & Υπηρεσίες' : 'Care & Services';
    final subtitle = isEl
        ? 'Κτηνίατροι, grooming & υπηρεσίες για το κατοικίδιό σου'
        : 'Vets, grooming & services for your pet';

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FAFB),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFB2EBF2), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF26C6DA).withOpacity(0.06),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Icon container
              Container(
                height: 46,
                width: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F7FA),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.medical_services_rounded,
                  color: Color(0xFF00ACC1),
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              // Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textSecondary,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Chevron
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF00ACC1),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DASHBOARD ADD PET BUTTON (unchanged)
// ─────────────────────────────────────────────────────────────────────────────
class _DashboardAddPetButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _DashboardAddPetButton({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.primaryTeal,
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.add_rounded,
                size: 22,
                color: Colors.white,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// QUICK ACTION CARD (unchanged)
// ─────────────────────────────────────────────────────────────────────────────
class _QuickActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final Color backgroundColor;
  final Color secondaryColor;
  final Color iconBackgroundColor;
  final Color textColor;
  final Color subtitleColor;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.backgroundColor,
    required this.secondaryColor,
    required this.iconBackgroundColor,
    required this.textColor,
    required this.subtitleColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(30),
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: onTap,
        child: Container(
          height: 204,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                backgroundColor,
                secondaryColor,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: backgroundColor.withOpacity(0.24),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 60,
                width: 60,
                decoration: BoxDecoration(
                  color: iconBackgroundColor,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 30,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  height: 1.05,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Text(
                  subtitle,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: subtitleColor,
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ADOPTION PROMO CARD (unchanged)
// ─────────────────────────────────────────────────────────────────────────────
class _AdoptionPromoCard extends StatelessWidget {
  final bool isEl;
  final VoidCallback onTap;
  final String title;
  final String ctaLabel;

  const _AdoptionPromoCard({
    required this.isEl,
    required this.onTap,
    required this.title,
    required this.ctaLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(26),
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: AppTheme.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                height: 52,
                width: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE9D1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.favorite_rounded,
                  color: Color(0xFFE86E4D),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isEl
                          ? 'Βρες έναν νέο φίλο και δες αγγελίες υιοθεσίας'
                          : 'Find a new friend and explore adoption posts',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 14,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                children: [
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppTheme.textSecondary,
                    size: 28,
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFE9D1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      ctaLabel,
                      style: const TextStyle(
                        color: Color(0xFFE86E4D),
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PET MINI CARD (unchanged)
// ─────────────────────────────────────────────────────────────────────────────
class _PetMiniCard extends StatelessWidget {
  final Pet pet;
  final String meta;
  final VoidCallback onTap;
  final bool isEl;

  const _PetMiniCard({
    required this.pet,
    required this.meta,
    required this.onTap,
    required this.isEl,
  });

  bool get _isFemale {
    final g = (pet.gender ?? '').toLowerCase().trim();
    return g == 'female' || g == 'f' || g.contains('θηλ');
  }

  String _petTypeBadge() {
    final type = pet.type.trim().toLowerCase();

    if (type == 'cat' || type.contains('cat')) {
      return isEl ? '🐱 Γάτα' : '🐱 Cat';
    }
    if (type == 'dog' || type.contains('dog')) {
      return isEl ? '🐶 Σκύλος' : '🐶 Dog';
    }
    if (type.isEmpty) {
      return isEl ? '🐾 Ζώο' : '🐾 Pet';
    }

    final capitalized = pet.type.trim();
    return '🐾 $capitalized';
  }

  Widget _buildPetPhoto() {
    return PetImageWidget(
      photoUrl: pet.photoUrl,
      photoBase64: pet.photoBase64,
      height: 132,
      width: double.infinity,
      fit: BoxFit.contain,
      borderRadius: BorderRadius.circular(18),
      placeholder: Container(
        height: 132,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppTheme.primaryTeal.withOpacity(0.10),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Icon(
          Icons.pets,
          color: AppTheme.primaryTeal,
          size: 40,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final badgeColor = _isFemale ? Colors.purple : AppTheme.primaryTeal;
    final badgeText = _isFemale ? '♀' : '♂';

    return SizedBox(
      width: 196,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.075),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(24),
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      _buildPetPhoto(),
                      Positioned(
                        top: 14,
                        left: 14,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.48),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            _petTypeBadge(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Container(
                          height: 30,
                          width: 30,
                          decoration: BoxDecoration(
                            color: badgeColor.withOpacity(0.95),
                            borderRadius: BorderRadius.circular(999),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.12),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              badgeText,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    pet.name.trim().isEmpty
                        ? (isEl ? 'Ζώο' : 'Pet')
                        : pet.name.trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    meta.isEmpty ? ' ' : meta,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryTeal.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            isEl ? 'Profile' : 'Profile',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.primaryTeal,
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
      ),
    );
  }
}
