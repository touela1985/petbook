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
    switch (type) {
      case 'vaccine':
        return 'Vaccine';
      case 'medication':
        return 'Medication';
      case 'vet_visit':
        return 'Vet Visit';
      case 'weight':
        return 'Weight';
      case 'reminder':
        return 'Reminder';
      case 'allergy':
        return 'Allergy';
      case 'surgery':
        return 'Surgery';
      case 'treatment':
        return 'Treatment';
      case 'note':
        return 'Note';
      default:
        return 'Health Event';
    }
  }

  Color _statusColor(int days) {
    if (days < 0) return Colors.red;
    if (days <= 2) return Colors.orange;
    return AppTheme.primaryTeal;
  }

  String _statusText(int days) {
    if (days < 0) return 'Late';
    if (days == 0) return 'Today';
    if (days == 1) return 'Tomorrow';
    return '$days d';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Reminders'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _reminders.isEmpty
              ? const Center(
                  child: Text(
                    'No reminders yet',
                    style: TextStyle(fontSize: 16),
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
                          : 'Unknown pet';

                      final petType = pet != null && pet.type.trim().isNotEmpty
                          ? pet.type.trim()
                          : 'Pet';

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
                              Text('Pet: $petName'),
                              const SizedBox(height: 2),
                              Text('Type: $petType'),
                              const SizedBox(height: 2),
                              Text('Event: ${_eventTypeLabel(reminder.type)}'),
                              const SizedBox(height: 2),
                              Text(
                                'Reminder: ${_formatDate(reminder.reminderDate!)}',
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
