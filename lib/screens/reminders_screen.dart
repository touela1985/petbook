import 'package:flutter/material.dart';

import '../data/pet_health_repository.dart';
import '../data/pet_repository.dart';
import '../models/pet.dart';
import '../models/pet_health_event.dart';
import '../theme/app_theme.dart';

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  final PetHealthRepository _healthRepo = PetHealthRepository();
  final PetRepository _petRepo = PetRepository();

  bool get _isEl => Localizations.localeOf(context).languageCode == 'el';

  List<PetHealthEvent> _reminders = [];
  Map<String, Pet> _petsById = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadReminders();
  }

  Future<void> _loadReminders() async {
    await _petRepo.loadPets();

    final events = await _healthRepo.getAllEvents();
    final pets = _petRepo.getAll();

    final reminders =
        events.where((event) => event.reminderDate != null).toList();

    reminders.sort(
      (a, b) => a.reminderDate!.compareTo(b.reminderDate!),
    );

    final petMap = <String, Pet>{};
    for (final pet in pets) {
      petMap[pet.id] = pet;
    }

    if (!mounted) return;

    setState(() {
      _reminders = reminders;
      _petsById = petMap;
      _loading = false;
    });
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();

    return '$day/$month/$year';
  }

  int _daysUntil(DateTime date) {
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final targetOnly = DateTime(date.year, date.month, date.day);

    return targetOnly.difference(todayOnly).inDays;
  }

  String _eventTypeLabel(String type) {
    final el = _isEl;
    switch (type) {
      case 'vaccine':
        return el ? 'Εμβόλιο' : 'Vaccine';
      case 'medication':
        return el ? 'Αγωγή' : 'Medication';
      case 'vet_visit':
        return el ? 'Κτηνίατρος' : 'Vet Visit';
      case 'weight':
        return el ? 'Βάρος' : 'Weight';
      case 'reminder':
        return el ? 'Υπενθύμιση' : 'Reminder';
      case 'allergy':
        return el ? 'Αλλεργία' : 'Allergy';
      case 'surgery':
        return el ? 'Χειρουργείο' : 'Surgery';
      case 'treatment':
        return el ? 'Θεραπεία' : 'Treatment';
      case 'note':
        return el ? 'Σημείωση' : 'Note';
      default:
        return el ? 'Καταχώρηση υγείας' : 'Health Event';
    }
  }

  Color _statusColor(int days) {
    if (days < 0) return Colors.red;
    if (days <= 2) return Colors.orange;
    return AppTheme.primaryTeal;
  }

  String _statusText(int days) {
    final el = _isEl;
    if (days < 0) return el ? 'Εκπρόθεσμο' : 'Late';
    if (days == 0) return el ? 'Σήμερα' : 'Today';
    if (days == 1) return el ? 'Αύριο' : 'Tomorrow';
    return el ? 'σε $days μ.' : 'in $days d';
  }

  @override
  Widget build(BuildContext context) {
    final el = _isEl;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(el ? 'Υπενθυμίσεις' : 'Reminders'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _reminders.isEmpty
              ? Center(
                  child: Text(
                    el ? 'Δεν υπάρχουν υπενθυμίσεις' : 'No reminders yet',
                    style: const TextStyle(fontSize: 16),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadReminders,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _reminders.length,
                    itemBuilder: (context, index) {
                      final reminder = _reminders[index];
                      final pet = _petsById[reminder.petId];
                      final days = _daysUntil(reminder.reminderDate!);
                      final color = _statusColor(days);

                      final petName = pet != null && pet.name.trim().isNotEmpty
                          ? pet.name.trim()
                          : (el ? 'Άγνωστο ζώο' : 'Unknown pet');

                      final petType = pet != null && pet.type.trim().isNotEmpty
                          ? pet.type.trim()
                          : (el ? 'Ζώο' : 'Pet');

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: color.withOpacity(0.15),
                            child: Icon(
                              Icons.notifications,
                              color: color,
                            ),
                          ),
                          title: Text(
                            reminder.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text('${el ? 'Ζώο' : 'Pet'}: $petName'),
                              const SizedBox(height: 2),
                              Text('${el ? 'Τύπος' : 'Type'}: $petType'),
                              const SizedBox(height: 2),
                              Text('${el ? 'Συμβάν' : 'Event'}: ${_eventTypeLabel(reminder.type)}'),
                              const SizedBox(height: 2),
                              Text(
                                '${el ? 'Ημερομηνία' : 'Reminder'}: ${_formatDate(reminder.reminderDate!)}',
                              ),
                            ],
                          ),
                          trailing: Text(
                            _statusText(days),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: color,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
