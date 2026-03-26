import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/pet_health_repository.dart';
import '../data/pet_repository.dart';
import '../l10n/app_localizations.dart';
import '../models/pet.dart';
import '../models/pet_health_event.dart';
import '../screens/add_health_event_screen.dart';
import '../screens/edit_pet_screen.dart';
import '../theme/app_theme.dart';

class PetProfileScreen extends StatefulWidget {
  final PetRepository repo;
  final String petId;

  const PetProfileScreen({
    super.key,
    required this.repo,
    required this.petId,
  });

  @override
  State<PetProfileScreen> createState() => _PetProfileScreenState();
}

class _PetProfileScreenState extends State<PetProfileScreen> {
  final PetHealthRepository _healthRepository = PetHealthRepository();

  List<PetHealthEvent> _healthEvents = [];
  bool _isLoadingHealthEvents = true;
  String _selectedHealthFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadHealthEvents();
  }

  Future<void> _loadHealthEvents() async {
    final events = await _healthRepository.getEventsForPet(widget.petId);

    if (!mounted) return;

    setState(() {
      _healthEvents = events;
      _isLoadingHealthEvents = false;
    });
  }

  Future<void> _openAddHealthEventScreen() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddHealthEventScreen(
          petId: widget.petId,
        ),
      ),
    );

    if (result == true) {
      await _loadHealthEvents();
    }
  }

  Future<void> _openEditHealthEventScreen(PetHealthEvent event) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddHealthEventScreen(
          petId: widget.petId,
          existingEvent: event,
        ),
      ),
    );

    if (result == true) {
      await _loadHealthEvents();
    }
  }

  Future<void> _deleteHealthEvent(PetHealthEvent event) async {
    final isEl = Localizations.localeOf(context).languageCode == 'el';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            isEl ? 'Διαγραφή καταχώρησης υγείας' : 'Delete health event',
          ),
          content: Text(
            isEl
                ? 'Θέλεις σίγουρα να διαγράψεις αυτή την καταχώρηση;'
                : 'Are you sure you want to delete this event?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(isEl ? 'Ακύρωση' : 'Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(isEl ? 'Διαγραφή' : 'Delete'),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      await _healthRepository.deleteEvent(event.id);
      await _loadHealthEvents();
    }
  }

  Future<void> _openEditPetScreen(Pet pet) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => EditPetScreen(
          repo: widget.repo,
          petId: pet.id,
        ),
      ),
    );

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  Future<void> _deletePet(Pet pet) async {
    final isEl = Localizations.localeOf(context).languageCode == 'el';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isEl ? 'Διαγραφή ζώου' : 'Delete pet'),
          content: Text(
            isEl
                ? 'Θέλεις σίγουρα να διαγράψεις αυτό το προφίλ;'
                : 'Are you sure you want to delete this pet profile?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(isEl ? 'Ακύρωση' : 'Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(isEl ? 'Διαγραφή' : 'Delete'),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      await widget.repo.deletePet(pet.id);

      if (!mounted) return;
      Navigator.pop(context, true);
    }
  }

  void _openPhotoViewer(Pet pet) {
    if (pet.photoBase64 == null || pet.photoBase64!.isEmpty) return;

    final bytes = base64Decode(pet.photoBase64!);

    showDialog(
      context: context,
      builder: (_) {
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          backgroundColor: Colors.black,
          child: Stack(
            children: [
              InteractiveViewer(
                minScale: 0.8,
                maxScale: 4,
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Image.memory(
                    bytes,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day/$month/$year';
  }

  String _formatShortDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month';
  }

  int _daysUntil(DateTime date) {
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final targetOnly = DateTime(date.year, date.month, date.day);
    return targetOnly.difference(todayOnly).inDays;
  }

  IconData _iconForEventType(String type) {
    switch (type) {
      case 'vaccine':
        return Icons.vaccines_rounded;
      case 'vet_visit':
        return Icons.medical_services_rounded;
      case 'weight':
        return Icons.monitor_weight_rounded;
      case 'medication':
        return Icons.medication_rounded;
      case 'reminder':
        return Icons.notifications_active_rounded;
      case 'allergy':
        return Icons.warning_amber_rounded;
      case 'surgery':
        return Icons.healing_rounded;
      case 'treatment':
        return Icons.local_hospital_rounded;
      case 'note':
        return Icons.sticky_note_2_rounded;
      default:
        return Icons.pets_rounded;
    }
  }

  String _labelForEventType(String type, bool isEl) {
    switch (type) {
      case 'vaccine':
        return isEl ? 'Εμβόλιο' : 'Vaccine';
      case 'vet_visit':
        return isEl ? 'Κτηνίατρος' : 'Vet Visit';
      case 'weight':
        return isEl ? 'Βάρος' : 'Weight';
      case 'medication':
        return isEl ? 'Αγωγή' : 'Medication';
      case 'reminder':
        return isEl ? 'Υπενθύμιση' : 'Reminder';
      case 'allergy':
        return isEl ? 'Αλλεργία' : 'Allergy';
      case 'surgery':
        return isEl ? 'Χειρουργείο' : 'Surgery';
      case 'treatment':
        return isEl ? 'Θεραπεία' : 'Treatment';
      case 'note':
        return isEl ? 'Σημείωση' : 'Note';
      default:
        return isEl ? 'Καταχώρηση υγείας' : 'Health Event';
    }
  }

  List<PetHealthEvent> _filteredHealthEvents() {
    final events = List<PetHealthEvent>.from(_healthEvents)
      ..sort((a, b) => b.date.compareTo(a.date));

    if (_selectedHealthFilter == 'all') {
      return events;
    }

    return events.where((event) => event.type == _selectedHealthFilter).toList();
  }

  PetHealthEvent? _latestEventOfType(String type) {
    final events = _healthEvents.where((e) => e.type == type).toList();

    if (events.isEmpty) return null;

    events.sort((a, b) => b.date.compareTo(a.date));
    return events.first;
  }

  PetHealthEvent? _nextReminder() {
    final today = DateTime.now();
    final reminderEvents =
        _healthEvents.where((e) => e.reminderDate != null).toList();

    if (reminderEvents.isEmpty) return null;

    final futureOrToday = reminderEvents
        .where(
          (e) => !DateTime(
            e.reminderDate!.year,
            e.reminderDate!.month,
            e.reminderDate!.day,
          ).isBefore(DateTime(today.year, today.month, today.day)),
        )
        .toList();

    if (futureOrToday.isNotEmpty) {
      futureOrToday.sort((a, b) => a.reminderDate!.compareTo(b.reminderDate!));
      return futureOrToday.first;
    }

    reminderEvents.sort((a, b) => b.reminderDate!.compareTo(a.reminderDate!));
    return reminderEvents.first;
  }

  List<PetHealthEvent> _weightEvents() {
    final weights = _healthEvents.where((e) => e.type == 'weight').toList();
    weights.sort((a, b) => b.date.compareTo(a.date));
    return weights;
  }

  List<PetHealthEvent> _weightEventsAscending() {
    final weights = _weightEvents();
    return weights.reversed.toList();
  }

  double? _parseWeightValueFromEvent(PetHealthEvent event) {
    final raw = event.title.trim().isNotEmpty ? event.title : (event.value ?? '');
    return _parseWeightString(raw);
  }

  double? _parseWeightString(String? value) {
    if (value == null || value.trim().isEmpty) return null;

    final cleaned = value.toLowerCase().replaceAll('kg', '').replaceAll('lb', '').trim();
    final normalized = cleaned.replaceAll(',', '.');

    return double.tryParse(normalized);
  }

  String _formatWeight(double value, {String unit = 'kg'}) {
    if (value == value.roundToDouble()) {
      return '${value.toInt()} $unit';
    }

    final text = value
        .toStringAsFixed(2)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');

    return '$text $unit';
  }

  String _normalizedPetType(Pet pet, bool isEl) {
    final type = pet.type.trim();
    if (type.isEmpty) return isEl ? 'Ζώο' : 'Pet';

    final lower = type.toLowerCase();
    if (lower == 'cat') return isEl ? 'Γάτα' : 'Cat';
    if (lower == 'dog') return isEl ? 'Σκύλος' : 'Dog';
    return type[0].toUpperCase() + type.substring(1);
  }

  String _normalizedGender(Pet pet, bool isEl) {
    final gender = (pet.gender ?? '').trim();
    if (gender.isEmpty) return '-';

    final lower = gender.toLowerCase();
    if (lower == 'male' || lower == 'm' || lower.contains('αρσ')) {
      return isEl ? 'Αρσενικό' : 'Male';
    }
    if (lower == 'female' || lower == 'f' || lower.contains('θηλ')) {
      return isEl ? 'Θηλυκό' : 'Female';
    }
    return gender;
  }

  IconData _petTypeIcon(Pet pet) {
    return Icons.pets;
  }

  IconData _genderIcon(Pet pet) {
    final lower = (pet.gender ?? '').trim().toLowerCase();
    if (lower == 'female' || lower == 'f' || lower.contains('θηλ')) {
      return Icons.female_rounded;
    }
    return Icons.male_rounded;
  }

  String? _extractDetailLine(PetHealthEvent event, bool isEl) {
    final value = event.value?.trim();
    if (value == null || value.isEmpty) return null;

    String extract(String elLabel, String enLabel) {
      final lines = value.split('\n');
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.startsWith(elLabel)) {
          return trimmed.replaceFirst(elLabel, '').trim();
        }
        if (trimmed.startsWith(enLabel)) {
          return trimmed.replaceFirst(enLabel, '').trim();
        }
      }
      return '';
    }

    switch (event.type) {
      case 'medication':
        final dosage = extract('Δοσολογία:', 'Dosage:');
        final frequency = extract('Συχνότητα:', 'Frequency:');
        if (dosage.isNotEmpty && frequency.isNotEmpty) {
          return isEl
              ? 'Δοσολογία: $dosage • Συχνότητα: $frequency'
              : 'Dosage: $dosage • Frequency: $frequency';
        }
        if (dosage.isNotEmpty) {
          return isEl ? 'Δοσολογία: $dosage' : 'Dosage: $dosage';
        }
        if (frequency.isNotEmpty) {
          return isEl ? 'Συχνότητα: $frequency' : 'Frequency: $frequency';
        }
        return value;

      case 'vet_visit':
        final clinic = extract('Κτηνίατρος/Κλινική:', 'Vet/Clinic:');
        return clinic.isEmpty
            ? null
            : (isEl ? 'Κτηνίατρος/Κλινική: $clinic' : 'Vet/Clinic: $clinic');

      case 'allergy':
        final reaction = extract('Αντίδραση:', 'Reaction:');
        return reaction.isEmpty
            ? null
            : (isEl ? 'Αντίδραση: $reaction' : 'Reaction: $reaction');

      case 'surgery':
        final clinicVet = extract('Κλινική/Κτηνίατρος:', 'Clinic/Vet:');
        return clinicVet.isEmpty
            ? null
            : (isEl
                ? 'Κλινική/Κτηνίατρος: $clinicVet'
                : 'Clinic/Vet: $clinicVet');

      case 'treatment':
        final instructions = extract('Οδηγίες:', 'Instructions:');
        return instructions.isEmpty
            ? null
            : (isEl ? 'Οδηγίες: $instructions' : 'Instructions: $instructions');

      default:
        return value;
    }
  }

  String _displayTitleForEvent(PetHealthEvent event, bool isEl) {
    if (event.type == 'weight') {
      final parsed = _parseWeightValueFromEvent(event);
      if (parsed != null) {
        final unit = event.title.toLowerCase().contains('lb') ? 'lb' : 'kg';
        return _formatWeight(parsed, unit: unit);
      }
    }
    return event.title.trim().isEmpty
        ? _labelForEventType(event.type, isEl)
        : event.title;
  }

  String? _summaryPrimary(PetHealthEvent event, bool isEl) {
    switch (event.type) {
      case 'weight':
        final parsed = _parseWeightValueFromEvent(event);
        if (parsed != null) {
          final unit = event.title.toLowerCase().contains('lb') ? 'lb' : 'kg';
          return _formatWeight(parsed, unit: unit);
        }
        return event.title;

      case 'vaccine':
        return event.title;

      case 'medication':
        return event.title;

      default:
        return event.title;
    }
  }

  String? _summarySecondary(PetHealthEvent event, bool isEl) {
    switch (event.type) {
      case 'weight':
        return _formatDate(event.date);

      case 'vaccine':
        if (event.reminderDate != null) {
          return isEl
              ? 'Υπενθύμιση ${_formatDate(event.reminderDate!)}'
              : 'Reminder ${_formatDate(event.reminderDate!)}';
        }
        return _formatDate(event.date);

      case 'medication':
        final detail = _extractDetailLine(event, isEl);
        return detail ?? _formatDate(event.date);

      default:
        return _formatDate(event.date);
    }
  }

  Widget _buildPetPhoto(Pet pet) {
    if (pet.photoBase64 != null && pet.photoBase64!.isNotEmpty) {
      final bytes = base64Decode(pet.photoBase64!);

      return GestureDetector(
        onTap: () => _openPhotoViewer(pet),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.surface,
            border: Border.all(color: AppTheme.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: CircleAvatar(
            radius: 54,
            backgroundImage: MemoryImage(bytes),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppTheme.surface,
        border: Border.all(color: AppTheme.border),
      ),
      child: CircleAvatar(
        radius: 54,
        backgroundColor: AppTheme.primaryTeal.withOpacity(0.10),
        child: Text(
          pet.name.isNotEmpty ? pet.name[0].toUpperCase() : '?',
          style: const TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w700,
            color: AppTheme.primaryTeal,
          ),
        ),
      ),
    );
  }

  Widget _buildProfileInfoChip({
    required IconData icon,
    required String label,
    required String value,
    Color? iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            height: 34,
            width: 34,
            decoration: BoxDecoration(
              color: (iconColor ?? AppTheme.primaryTeal).withOpacity(0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: iconColor ?? AppTheme.primaryTeal,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(Pet pet, AppLocalizations t, bool isEl) {
    final typeText = _normalizedPetType(pet, isEl);
    final genderText = _normalizedGender(pet, isEl);
    final ageText = (pet.age ?? '').toString().trim().isEmpty
        ? '-'
        : pet.age.toString().trim();

    final isFemale =
        genderText.toLowerCase() == 'female' || genderText.contains('Θηλυ');

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Center(child: _buildPetPhoto(pet)),
          const SizedBox(height: 16),
          Text(
            pet.name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            t.petProfile,
            style: TextStyle(
              color: AppTheme.textSecondary.withOpacity(0.9),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _buildProfileInfoChip(
                  icon: _petTypeIcon(pet),
                  label: isEl ? 'Τύπος' : 'Type',
                  value: typeText,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildProfileInfoChip(
                  icon: Icons.cake_outlined,
                  label: isEl ? 'Ηλικία' : 'Age',
                  value: ageText,
                  iconColor: Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildProfileInfoChip(
            icon: _genderIcon(pet),
            label: isEl ? 'Φύλο' : 'Gender',
            value: genderText,
            iconColor: isFemale ? Colors.purple : AppTheme.primaryTeal,
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingReminder(bool isEl) {
    final reminder = _nextReminder();

    if (reminder == null) return const SizedBox();

    final days = _daysUntil(reminder.reminderDate!);

    String title;
    String subtitle;
    Color color;
    IconData icon;

    if (days < 0) {
      title = isEl ? 'Υπενθύμιση σε καθυστέρηση' : 'Reminder overdue';
      subtitle = isEl
          ? '${_displayTitleForEvent(reminder, isEl)} • ${days.abs()} ημέρ. καθυστέρηση'
          : '${_displayTitleForEvent(reminder, isEl)} • ${days.abs()} day(s) late';
      color = Colors.red;
      icon = Icons.warning_rounded;
    } else if (days == 0) {
      title = isEl ? 'Υπενθύμιση σήμερα' : 'Reminder today';
      subtitle = _displayTitleForEvent(reminder, isEl);
      color = Colors.orange;
      icon = Icons.notifications_active_rounded;
    } else if (days == 1) {
      title = isEl ? 'Υπενθύμιση αύριο' : 'Reminder tomorrow';
      subtitle = _displayTitleForEvent(reminder, isEl);
      color = Colors.orange;
      icon = Icons.notifications_active_rounded;
    } else if (days <= 3) {
      title = isEl ? 'Υπενθύμιση σύντομα' : 'Reminder soon';
      subtitle = isEl
          ? '${_displayTitleForEvent(reminder, isEl)} • σε $days ημέρες'
          : '${_displayTitleForEvent(reminder, isEl)} • in $days days';
      color = Colors.orange;
      icon = Icons.notifications_active_rounded;
    } else {
      title = isEl ? 'Επόμενη υπενθύμιση' : 'Upcoming Reminder';
      subtitle = isEl
          ? '${_displayTitleForEvent(reminder, isEl)} • σε $days ημέρες'
          : '${_displayTitleForEvent(reminder, isEl)} • in $days days';
      color = AppTheme.primaryTeal;
      icon = Icons.notifications_none_rounded;
    }

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _openEditHealthEventScreen(reminder),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withOpacity(0.70)),
          ),
          child: Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(subtitle),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: color,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHealthSummaryCard({
    required String title,
    required String emptyLabel,
    required IconData icon,
    required Color accentColor,
    required PetHealthEvent? event,
    required bool isEl,
  }) {
    final primary = event == null ? emptyLabel : (_summaryPrimary(event, isEl) ?? emptyLabel);
    final secondary = event == null ? null : _summarySecondary(event, isEl);

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 34,
              width: 34,
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: accentColor, size: 18),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              primary,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: event == null ? FontWeight.w600 : FontWeight.w800,
                color: event == null
                    ? AppTheme.textSecondary
                    : AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              secondary ?? ' ',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthSummary(bool isEl) {
    final latestWeight = _latestEventOfType('weight');
    final latestVaccine = _latestEventOfType('vaccine');
    final latestMedication = _latestEventOfType('medication');

    return Row(
      children: [
        _buildHealthSummaryCard(
          title: isEl ? 'Βάρος' : 'Weight',
          emptyLabel: isEl ? 'Καμία καταγραφή' : 'No record yet',
          icon: Icons.monitor_weight_rounded,
          accentColor: AppTheme.primaryTeal,
          event: latestWeight,
          isEl: isEl,
        ),
        const SizedBox(width: 8),
        _buildHealthSummaryCard(
          title: isEl ? 'Εμβόλιο' : 'Vaccine',
          emptyLabel: isEl ? 'Κανένα εμβόλιο' : 'No vaccine yet',
          icon: Icons.vaccines_rounded,
          accentColor: Colors.orange,
          event: latestVaccine,
          isEl: isEl,
        ),
        const SizedBox(width: 8),
        _buildHealthSummaryCard(
          title: isEl ? 'Αγωγή' : 'Medication',
          emptyLabel: isEl ? 'Καμία αγωγή' : 'No medication yet',
          icon: Icons.medication_rounded,
          accentColor: Colors.purple,
          event: latestMedication,
          isEl: isEl,
        ),
      ],
    );
  }

  Widget _buildHealthFilterChips(bool isEl) {
    final filters = [
      {'key': 'all', 'label': isEl ? 'Όλα' : 'All'},
      {'key': 'vaccine', 'label': isEl ? 'Εμβόλια' : 'Vaccines'},
      {'key': 'medication', 'label': isEl ? 'Αγωγή' : 'Medication'},
      {'key': 'vet_visit', 'label': isEl ? 'Κτηνίατρος' : 'Vet'},
      {'key': 'weight', 'label': isEl ? 'Βάρος' : 'Weight'},
      {'key': 'reminder', 'label': isEl ? 'Υπενθυμίσεις' : 'Reminders'},
      {'key': 'allergy', 'label': isEl ? 'Αλλεργία' : 'Allergy'},
      {'key': 'surgery', 'label': isEl ? 'Χειρουργείο' : 'Surgery'},
      {'key': 'treatment', 'label': isEl ? 'Θεραπεία' : 'Treatment'},
      {'key': 'note', 'label': isEl ? 'Σημειώσεις' : 'Notes'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((filter) {
          final isSelected = _selectedHealthFilter == filter['key'];

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(filter['label']!),
              selected: isSelected,
              onSelected: (_) {
                setState(() {
                  _selectedHealthFilter = filter['key']!;
                });
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildWeightChangeBadge(bool isEl) {
    final weightEvents = _weightEvents();

    if (weightEvents.length < 2) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.primaryTeal.withOpacity(0.08),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppTheme.primaryTeal.withOpacity(0.20)),
        ),
        child: Text(
          isEl ? 'Χρειάζονται 2 καταγραφές' : 'Need at least 2 records',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.primaryTeal,
          ),
        ),
      );
    }

    final latest = _parseWeightValueFromEvent(weightEvents[0]);
    final previous = _parseWeightValueFromEvent(weightEvents[1]);

    if (latest == null || previous == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.primaryTeal.withOpacity(0.08),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppTheme.primaryTeal.withOpacity(0.20)),
        ),
        child: Text(
          isEl ? 'Λίγα δεδομένα' : 'Not enough data',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.primaryTeal,
          ),
        ),
      );
    }

    final difference = latest - previous;

    late final String label;
    late final IconData icon;
    late final Color color;

    if (difference > 0.01) {
      label = '+${_formatWeight(difference)}';
      icon = Icons.arrow_upward_rounded;
      color = Colors.orange;
    } else if (difference < -0.01) {
      label = '-${_formatWeight(difference.abs())}';
      icon = Icons.arrow_downward_rounded;
      color = Colors.blue;
    } else {
      label = isEl ? 'Σταθερό' : 'Stable';
      icon = Icons.remove_rounded;
      color = AppTheme.primaryTeal;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeightChartCard(bool isEl) {
    final chartEvents = _weightEventsAscending();

    if (chartEvents.length < 2) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
        ),
        child: Text(
          isEl
              ? 'Πρόσθεσε τουλάχιστον 2 καταγραφές βάρους για να δεις το γράφημα.'
              : 'Add at least 2 weight records to see the chart.',
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    final points = <_WeightChartPoint>[];

    for (final event in chartEvents) {
      final weight = _parseWeightValueFromEvent(event);
      if (weight != null) {
        points.add(
          _WeightChartPoint(
            date: event.date,
            weight: weight,
          ),
        );
      }
    }

    if (points.length < 2) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
        ),
        child: Text(
          isEl
              ? 'Δεν υπάρχουν αρκετά έγκυρα δεδομένα βάρους για το γράφημα.'
              : 'Not enough valid weight data for the chart yet.',
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    final weights = points.map((e) => e.weight).toList();
    final minWeight = weights.reduce(math.min);
    final maxWeight = weights.reduce(math.max);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isEl ? 'Γράφημα βάρους' : 'Weight Chart',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${_formatWeight(minWeight)} - ${_formatWeight(maxWeight)}',
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 180,
            child: CustomPaint(
              painter: _WeightChartPainter(
                points: points,
                lineColor: AppTheme.primaryTeal,
                gridColor: AppTheme.border,
                dotColor: AppTheme.primaryTeal,
              ),
              child: const SizedBox.expand(),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  _formatShortDate(points.first.date),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  _formatShortDate(points.last.date),
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeightHistorySection(bool isEl) {
    final weightEvents = _weightEvents();

    if (weightEvents.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.monitor_weight_outlined,
                  color: AppTheme.primaryTeal,
                ),
                const SizedBox(width: 8),
                Text(
                  isEl ? 'Ιστορικό βάρους' : 'Weight History',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              isEl
                  ? 'Δεν υπάρχουν καταγραφές βάρους ακόμα. Πρόσθεσε μία για να ξεκινήσει η παρακολούθηση.'
                  : 'No weight records yet. Add a weight entry to start tracking progress.',
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    final latestWeightValue = _parseWeightValueFromEvent(weightEvents.first);
    final latestWeightText = latestWeightValue != null
        ? _formatWeight(
            latestWeightValue,
            unit: weightEvents.first.title.toLowerCase().contains('lb') ? 'lb' : 'kg',
          )
        : weightEvents.first.title;

    final recentWeights = weightEvents.take(4).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.monitor_weight_outlined,
                color: AppTheme.primaryTeal,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isEl ? 'Ιστορικό βάρους' : 'Weight History',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              _buildWeightChangeBadge(isEl),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.primaryTeal.withOpacity(0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.primaryTeal.withOpacity(0.15),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEl ? 'Τελευταίο βάρος' : 'Latest weight',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  latestWeightText,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDate(weightEvents.first.date),
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _buildWeightChartCard(isEl),
          const SizedBox(height: 14),
          Text(
            isEl ? 'Πρόσφατες καταγραφές' : 'Recent records',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          ...recentWeights.map((event) {
            final parsedWeight = _parseWeightValueFromEvent(event);
            final displayWeight = parsedWeight != null
                ? _formatWeight(
                    parsedWeight,
                    unit: event.title.toLowerCase().contains('lb') ? 'lb' : 'kg',
                  )
                : event.title;

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryTeal.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.monitor_weight,
                      color: AppTheme.primaryTeal,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayWeight,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatDate(event.date),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildHealthEventCard(PetHealthEvent event, bool isEl) {
    final accentColor = event.type == 'vaccine'
        ? Colors.orange
        : event.type == 'medication'
            ? Colors.purple
            : event.type == 'weight'
                ? AppTheme.primaryTeal
                : event.type == 'allergy'
                    ? Colors.red
                    : AppTheme.primaryTeal;

    final title = _displayTitleForEvent(event, isEl);
    final typeLabel = _labelForEventType(event.type, isEl);
    final detail = _extractDetailLine(event, isEl);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _iconForEventType(event.type),
                color: accentColor,
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
                      fontSize: 16,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      typeLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: accentColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_rounded,
                        size: 15,
                        color: AppTheme.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _formatDate(event.date),
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  if (event.reminderDate != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.notifications_active_rounded,
                          size: 15,
                          color: Colors.orange,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            isEl
                                ? 'Υπενθύμιση: ${_formatDate(event.reminderDate!)}'
                                : 'Reminder: ${_formatDate(event.reminderDate!)}',
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (detail != null && detail.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      detail,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ],
                  if (event.notes.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      event.notes,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'edit') {
                  await _openEditHealthEventScreen(event);
                } else if (value == 'delete') {
                  await _deleteHealthEvent(event);
                }
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
      ),
    );
  }

  Widget _buildHealthTimelineSection(AppLocalizations t, bool isEl) {
    if (_isLoadingHealthEvents) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_healthEvents.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            Container(
              height: 46,
              width: 46,
              decoration: BoxDecoration(
                color: AppTheme.primaryTeal.withOpacity(0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.health_and_safety_outlined,
                color: AppTheme.primaryTeal,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.health,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isEl
                        ? 'Δεν υπάρχουν καταχωρήσεις υγείας ακόμα. Πάτησε Add Health Event για να ξεκινήσεις.'
                        : 'No health records yet. Tap Add Health Event to get started.',
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final filteredEvents = _filteredHealthEvents();

    if (filteredEvents.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.border),
        ),
        child: Text(
          isEl
              ? 'Δεν υπάρχουν καταχωρήσεις σε αυτή την κατηγορία.'
              : 'No events in this category yet.',
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    return Column(
      children: filteredEvents.map((event) {
        return _buildHealthEventCard(event, isEl);
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final isEl = Localizations.localeOf(context).languageCode == 'el';
    final Pet pet =
        widget.repo.getAll().firstWhere((p) => p.id == widget.petId);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(t.petProfile),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'edit') {
                await _openEditPetScreen(pet);
              } else if (value == 'delete') {
                await _deletePet(pet);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'edit',
                child: Text(isEl ? 'Επεξεργασία ζώου' : 'Edit Pet'),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Text(isEl ? 'Διαγραφή ζώου' : 'Delete Pet'),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddHealthEventScreen,
        icon: const Icon(Icons.add),
        label: Text(isEl ? 'Νέα καταχώρηση' : 'Add Health Event'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadHealthEvents,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            children: [
              _buildProfileHeader(pet, t, isEl),
              const SizedBox(height: 18),
              _buildUpcomingReminder(isEl),
              const SizedBox(height: 16),
              _buildHealthSummary(isEl),
              const SizedBox(height: 16),
              _buildWeightHistorySection(isEl),
              const SizedBox(height: 12),
              _buildHealthFilterChips(isEl),
              const SizedBox(height: 12),
              _buildHealthTimelineSection(t, isEl),
              const SizedBox(height: 90),
            ],
          ),
        ),
      ),
    );
  }
}

class _WeightChartPoint {
  final DateTime date;
  final double weight;

  _WeightChartPoint({
    required this.date,
    required this.weight,
  });
}

class _WeightChartPainter extends CustomPainter {
  final List<_WeightChartPoint> points;
  final Color lineColor;
  final Color gridColor;
  final Color dotColor;

  _WeightChartPainter({
    required this.points,
    required this.lineColor,
    required this.gridColor,
    required this.dotColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    const double leftPadding = 12;
    const double rightPadding = 12;
    const double topPadding = 10;
    const double bottomPadding = 16;

    final chartWidth = size.width - leftPadding - rightPadding;
    final chartHeight = size.height - topPadding - bottomPadding;

    if (chartWidth <= 0 || chartHeight <= 0) return;

    final minWeight = points.map((e) => e.weight).reduce(math.min);
    final maxWeight = points.map((e) => e.weight).reduce(math.max);

    final range = maxWeight - minWeight;
    final normalizedRange = range == 0 ? 1.0 : range;

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    for (int i = 0; i < 4; i++) {
      final y = topPadding + (chartHeight / 3) * i;
      canvas.drawLine(
        Offset(leftPadding, y),
        Offset(size.width - rightPadding, y),
        gridPaint,
      );
    }

    final pointOffsets = <Offset>[];

    for (int i = 0; i < points.length; i++) {
      final x = points.length == 1
          ? leftPadding + (chartWidth / 2)
          : leftPadding + (chartWidth * i / (points.length - 1));

      final normalizedY = (points[i].weight - minWeight) / normalizedRange;
      final y = topPadding + chartHeight - (normalizedY * chartHeight);

      pointOffsets.add(Offset(x, y));
    }

    final areaPath = Path()
      ..moveTo(pointOffsets.first.dx, topPadding + chartHeight);

    for (final offset in pointOffsets) {
      areaPath.lineTo(offset.dx, offset.dy);
    }

    areaPath
      ..lineTo(pointOffsets.last.dx, topPadding + chartHeight)
      ..close();

    final areaPaint = Paint()
      ..color = lineColor.withOpacity(0.10)
      ..style = PaintingStyle.fill;

    canvas.drawPath(areaPath, areaPaint);

    final linePath = Path()
      ..moveTo(pointOffsets.first.dx, pointOffsets.first.dy);
    for (int i = 1; i < pointOffsets.length; i++) {
      linePath.lineTo(pointOffsets[i].dx, pointOffsets[i].dy);
    }

    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(linePath, linePaint);

    final dotPaint = Paint()..color = dotColor;
    final dotBorderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (final offset in pointOffsets) {
      canvas.drawCircle(offset, 4.5, dotPaint);
      canvas.drawCircle(offset, 4.5, dotBorderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _WeightChartPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.dotColor != dotColor;
  }
}
