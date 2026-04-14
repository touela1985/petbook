import 'package:flutter/material.dart';

import '../data/lost_pet_report_repository.dart';
import '../data/pet_repository.dart';
import '../widgets/pet_image_widget.dart';
import '../l10n/app_localizations.dart';
import '../models/pet.dart';
import '../theme/app_theme.dart';
import 'add_found_pet_report_screen.dart';
import 'add_lost_pet_report_screen.dart';
import 'add_pet_screen.dart';
import 'adoption_list_screen.dart';
import 'lost_found_screen.dart';
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

  Future<int> _loadLostAlertCount() async {
    final reports = await _lostRepo.getReports();
    final now = DateTime.now();
    final last24Hours = now.subtract(const Duration(hours: 24));

    int count = 0;
    for (final report in reports) {
      try {
        if (report.lastSeenDate.isAfter(last24Hours)) {
          count++;
        }
      } catch (_) {}
    }
    return count;
  }

  Future<int> _loadActiveLostCount() async {
    final reports = await _lostRepo.getReports();
    return reports.where((report) => !report.isResolved).length;
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
          _loadLostAlertCount(),
          _loadActiveLostCount(),
        ]),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final pets = snap.data![0] as List<Pet>;
          final alertCount = snap.data![1] as int;
          final activeLostCount = snap.data![2] as int;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              _HomeLostAlertBar(
                isEl: isEl,
                alertCount: alertCount,
                onTap: _openLostFound,
              ),
              const SizedBox(height: 10),
              _HomeActiveLostBanner(
                isEl: isEl,
                activeCount: activeLostCount,
                onTap: _openActiveLostMap,
              ),
              const SizedBox(height: 24),
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

class _HomeLostAlertBar extends StatelessWidget {
  final bool isEl;
  final int alertCount;
  final VoidCallback onTap;

  const _HomeLostAlertBar({
    required this.isEl,
    required this.alertCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasAlerts = alertCount > 0;

    final String title = hasAlerts
        ? (isEl
            ? '$alertCount ειδοποίηση${alertCount > 1 ? 'σεις' : ''} κοντά σου'
            : '$alertCount alert${alertCount > 1 ? 's' : ''} near you')
        : (isEl ? 'Δεν υπάρχουν κοντινές ειδοποιήσεις' : 'No alerts nearby');

    final String subtitle = hasAlerts
        ? (isEl ? 'Πάτησε για όλες τις δηλώσεις' : 'Tap to view all reports')
        : (isEl ? 'Πάτησε για να δεις δηλώσεις' : 'Tap to explore reports');

    final IconData icon =
        hasAlerts ? Icons.warning_amber_rounded : Icons.check_circle_rounded;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Color(0xFFF34A3A),
                Color(0xFFF26A2E),
                Color(0xFFF6A62C),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFF26A2E).withOpacity(0.22),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                left: -20,
                bottom: -24,
                child: Container(
                  height: 110,
                  width: 140,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              Positioned(
                right: 96,
                top: 10,
                child: Icon(
                  Icons.pets,
                  size: 20,
                  color: Colors.white.withOpacity(0.10),
                ),
              ),
              Positioned(
                right: 66,
                top: 34,
                child: Icon(
                  Icons.favorite,
                  size: 22,
                  color: Colors.white.withOpacity(0.10),
                ),
              ),
              Positioned(
                right: 24,
                top: 18,
                child: Icon(
                  Icons.pets,
                  size: 30,
                  color: Colors.white.withOpacity(0.10),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                child: Row(
                  children: [
                    _PulsingAlertBadge(icon: icon),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.95),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.92),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            isEl ? 'Άνοιγμα' : 'Open',
                            style: const TextStyle(
                              color: Color(0xFF37474F),
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: Color(0xFF37474F),
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
        height: 54,
        width: 54,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.22),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.white.withOpacity(0.10),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Icon(
          widget.icon,
          color: Colors.white,
          size: 34,
        ),
      ),
    );
  }
}

class _HomeActiveLostBanner extends StatelessWidget {
  final bool isEl;
  final int activeCount;
  final VoidCallback onTap;

  const _HomeActiveLostBanner({
    required this.isEl,
    required this.activeCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final title = isEl ? 'ΕΝΕΡΓΕΣ ΑΓΓΕΛΙΕΣ ΑΠΩΛΕΙΑΣ' : 'ACTIVE LOST ALERTS';
    final subtitle = isEl
        ? '$activeCount ζώα αγνοούνται κοντά σου'
        : '$activeCount pets currently missing near you';

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Color(0xFFF34A3A),
                Color(0xFFF26A2E),
                Color(0xFFF6A62C),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFF26A2E).withOpacity(0.16),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                height: 48,
                width: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.location_searching_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.92),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.map_outlined,
                      color: Color(0xFF5B5147),
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isEl ? 'Χάρτης' : 'Map',
                      style: const TextStyle(
                        color: Color(0xFF5B5147),
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
