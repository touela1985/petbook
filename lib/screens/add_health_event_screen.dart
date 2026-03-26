import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../data/pet_health_repository.dart';
import '../models/pet_health_event.dart';
import '../theme/app_theme.dart';

class AddHealthEventScreen extends StatefulWidget {
  final String petId;
  final PetHealthEvent? existingEvent;

  const AddHealthEventScreen({
    super.key,
    required this.petId,
    this.existingEvent,
  });

  @override
  State<AddHealthEventScreen> createState() => _AddHealthEventScreenState();
}

class _AddHealthEventScreenState extends State<AddHealthEventScreen> {
  final PetHealthRepository _repo = PetHealthRepository();
  final _uuid = const Uuid();

  final _nameController = TextEditingController();
  final _secondaryController = TextEditingController();
  final _tertiaryController = TextEditingController();
  final _notesController = TextEditingController();
  final _weightController = TextEditingController();

  String _selectedType = 'vaccine';
  String _weightUnit = 'kg';

  DateTime _selectedDate = DateTime.now();
  bool _hasReminder = false;
  DateTime? _reminderDate;

  bool get _isEditMode => widget.existingEvent != null;
  bool get _isEl => Localizations.localeOf(context).languageCode == 'el';

  bool get _supportsReminder =>
      _selectedType == 'vaccine' ||
      _selectedType == 'medication' ||
      _selectedType == 'vet_visit' ||
      _selectedType == 'surgery' ||
      _selectedType == 'treatment';

  bool get _isWeightType => _selectedType == 'weight';
  bool get _isReminderType => _selectedType == 'reminder';
  bool get _showPrimaryNameField =>
      _selectedType != 'weight' && _selectedType != 'reminder';

  @override
  void initState() {
    super.initState();
    final event = widget.existingEvent;
    if (event != null) {
      _loadExistingEvent(event);
    }
  }

  void _loadExistingEvent(PetHealthEvent event) {
    _selectedType = event.type;
    _selectedDate = event.date;
    _reminderDate = event.reminderDate;
    _hasReminder = event.reminderDate != null;

    switch (event.type) {
      case 'vaccine':
        _nameController.text = event.title;
        _notesController.text = event.notes;
        break;

      case 'medication':
        _nameController.text = event.title;
        _secondaryController.text = _extractLabeledValue(
          event.value,
          _isEl ? 'Δοσολογία:' : 'Dosage:',
        );
        _tertiaryController.text = _extractLabeledValue(
          event.value,
          _isEl ? 'Συχνότητα:' : 'Frequency:',
        );
        _notesController.text = event.notes;
        break;

      case 'vet_visit':
        _nameController.text = event.title;
        _secondaryController.text = _extractLabeledValue(
          event.value,
          _isEl ? 'Κτηνίατρος/Κλινική:' : 'Vet/Clinic:',
        );
        _notesController.text = event.notes;
        break;

      case 'weight':
        final raw = event.title.trim().isNotEmpty ? event.title : (event.value ?? '');
        _weightController.text = _extractWeightNumber(raw);
        _weightUnit = raw.toLowerCase().contains('lb') ? 'lb' : 'kg';
        _notesController.text = event.notes;
        break;

      case 'reminder':
        _nameController.text = event.title;
        _notesController.text = event.notes;
        break;

      case 'allergy':
        _nameController.text = event.title;
        _secondaryController.text = _extractLabeledValue(
          event.value,
          _isEl ? 'Αντίδραση:' : 'Reaction:',
        );
        _notesController.text = event.notes;
        break;

      case 'surgery':
        _nameController.text = event.title;
        _secondaryController.text = _extractLabeledValue(
          event.value,
          _isEl ? 'Κλινική/Κτηνίατρος:' : 'Clinic/Vet:',
        );
        _notesController.text = event.notes;
        break;

      case 'treatment':
        _nameController.text = event.title;
        _secondaryController.text = _extractLabeledValue(
          event.value,
          _isEl ? 'Οδηγίες:' : 'Instructions:',
        );
        _notesController.text = event.notes;
        break;

      case 'note':
        _nameController.text = event.title;
        _notesController.text = event.notes;
        break;

      default:
        _nameController.text = event.title;
        _secondaryController.text = event.value ?? '';
        _notesController.text = event.notes;
        break;
    }

    if (!_supportsReminder) {
      _hasReminder = false;
      _reminderDate = null;
    }
  }

  String _extractLabeledValue(String? value, String label) {
    if (value == null || value.trim().isEmpty) return '';
    final lines = value.split('\n');
    for (final line in lines) {
      if (line.trim().startsWith(label)) {
        return line.replaceFirst(label, '').trim();
      }
    }
    return value;
  }

  String _extractWeightNumber(String value) {
    if (value.trim().isEmpty) return '';
    var cleaned = value.toLowerCase().replaceAll('kg', '').replaceAll('lb', '').trim();
    cleaned = cleaned.replaceAll(',', '.');
    final parsed = double.tryParse(cleaned);
    if (parsed == null) return '';
    return _formatWeightNumber(parsed);
  }

  String _formatWeightNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value
        .toStringAsFixed(2)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  double? _parseWeight(String input) {
    final normalized = input.trim().replaceAll(',', '.');
    if (normalized.isEmpty) return null;
    return double.tryParse(normalized);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _clearTypeSpecificFields() {
    _nameController.clear();
    _secondaryController.clear();
    _tertiaryController.clear();
    _notesController.clear();
    _weightController.clear();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2015),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _pickReminderDate() async {
    final initial = _reminderDate ?? _selectedDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2015),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _reminderDate = picked;
      });
    }
  }

  void _onTypeChanged(String value) {
    if (value == _selectedType) return;

    setState(() {
      _selectedType = value;
      _clearTypeSpecificFields();

      if (!_supportsReminder) {
        _hasReminder = false;
        _reminderDate = null;
      }
    });
  }

  Future<void> _saveEvent() async {
    final isEl = _isEl;

    String title = '';
    String? value;
    String notes = _notesController.text.trim();
    DateTime eventDate = _selectedDate;
    DateTime? reminderDate = _supportsReminder && _hasReminder ? _reminderDate : null;

    switch (_selectedType) {
      case 'vaccine':
        final vaccineName = _nameController.text.trim();
        if (vaccineName.isEmpty) {
          _showMessage(isEl ? 'Βάλε όνομα εμβολίου' : 'Please enter vaccine name');
          return;
        }
        title = vaccineName;
        value = null;
        break;

      case 'medication':
        final medicationName = _nameController.text.trim();
        final dosage = _secondaryController.text.trim();
        final frequency = _tertiaryController.text.trim();

        if (medicationName.isEmpty) {
          _showMessage(isEl ? 'Βάλε όνομα αγωγής' : 'Please enter medication name');
          return;
        }
        if (dosage.isEmpty) {
          _showMessage(isEl ? 'Βάλε δοσολογία' : 'Please enter dosage');
          return;
        }
        if (frequency.isEmpty) {
          _showMessage(isEl ? 'Βάλε συχνότητα' : 'Please enter frequency');
          return;
        }

        title = medicationName;
        value = '${isEl ? 'Δοσολογία:' : 'Dosage:'} $dosage\n'
            '${isEl ? 'Συχνότητα:' : 'Frequency:'} $frequency';
        break;

      case 'vet_visit':
        final visitReason = _nameController.text.trim();
        final clinicName = _secondaryController.text.trim();

        if (visitReason.isEmpty) {
          _showMessage(isEl ? 'Βάλε λόγο επίσκεψης' : 'Please enter visit reason');
          return;
        }

        title = visitReason;
        value = clinicName.isEmpty
            ? null
            : '${isEl ? 'Κτηνίατρος/Κλινική:' : 'Vet/Clinic:'} $clinicName';
        break;

      case 'weight':
        final parsedWeight = _parseWeight(_weightController.text);
        if (parsedWeight == null) {
          _showMessage(isEl ? 'Βάλε βάρος' : 'Please enter a weight');
          return;
        }
        if (parsedWeight <= 0) {
          _showMessage(
            isEl
                ? 'Το βάρος πρέπει να είναι πάνω από 0'
                : 'Weight must be greater than 0',
          );
          return;
        }
        title = '${_formatWeightNumber(parsedWeight)} $_weightUnit';
        value = null;
        break;

      case 'reminder':
        final reminderTitle = _nameController.text.trim();
        if (reminderTitle.isEmpty) {
          _showMessage(isEl ? 'Βάλε τίτλο υπενθύμισης' : 'Please enter reminder title');
          return;
        }
        title = reminderTitle;
        value = null;
        break;

      case 'allergy':
        final allergyName = _nameController.text.trim();
        final reaction = _secondaryController.text.trim();

        if (allergyName.isEmpty) {
          _showMessage(isEl ? 'Βάλε όνομα αλλεργίας' : 'Please enter allergy name');
          return;
        }

        title = allergyName;
        value = reaction.isEmpty
            ? null
            : '${isEl ? 'Αντίδραση:' : 'Reaction:'} $reaction';
        break;

      case 'surgery':
        final surgeryTitle = _nameController.text.trim();
        final clinicVet = _secondaryController.text.trim();

        if (surgeryTitle.isEmpty) {
          _showMessage(isEl ? 'Βάλε τίτλο χειρουργείου' : 'Please enter surgery title');
          return;
        }

        title = surgeryTitle;
        value = clinicVet.isEmpty
            ? null
            : '${isEl ? 'Κλινική/Κτηνίατρος:' : 'Clinic/Vet:'} $clinicVet';
        break;

      case 'treatment':
        final treatmentName = _nameController.text.trim();
        final instructions = _secondaryController.text.trim();

        if (treatmentName.isEmpty) {
          _showMessage(isEl ? 'Βάλε όνομα θεραπείας' : 'Please enter treatment name');
          return;
        }

        title = treatmentName;
        value = instructions.isEmpty
            ? null
            : '${isEl ? 'Οδηγίες:' : 'Instructions:'} $instructions';
        break;

      case 'note':
        final noteTitle = _nameController.text.trim();
        if (noteTitle.isEmpty) {
          _showMessage(isEl ? 'Βάλε τίτλο σημείωσης' : 'Please enter note title');
          return;
        }
        title = noteTitle;
        value = null;
        break;

      default:
        final genericTitle = _nameController.text.trim();
        if (genericTitle.isEmpty) {
          _showMessage(isEl ? 'Βάλε τίτλο' : 'Please enter a title');
          return;
        }
        title = genericTitle;
        value = _secondaryController.text.trim().isEmpty
            ? null
            : _secondaryController.text.trim();
        break;
    }

    if (_supportsReminder && _hasReminder && reminderDate == null) {
      _showMessage(
        isEl ? 'Διάλεξε ημερομηνία υπενθύμισης' : 'Please choose a reminder date',
      );
      return;
    }

    final event = PetHealthEvent(
      id: widget.existingEvent?.id ?? _uuid.v4(),
      petId: widget.petId,
      type: _selectedType,
      title: title,
      notes: notes,
      date: eventDate,
      value: value,
      reminderDate: reminderDate,
    );

    if (_isEditMode) {
      await _repo.updateEvent(event);
    } else {
      await _repo.addEvent(event);
    }

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _secondaryController.dispose();
    _tertiaryController.dispose();
    _notesController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    return '$d/$m/${date.year}';
  }

  InputDecoration _fieldDecoration({
    required String label,
    String? hint,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 16,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: AppTheme.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: AppTheme.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: AppTheme.primaryTeal,
          width: 1.4,
        ),
      ),
    );
  }

  Widget _buildDateField({
    required String label,
    required DateTime value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: AppTheme.primaryTeal),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '$label: ${_formatDate(value)}',
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReminderToggle() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
      ),
      child: SwitchListTile(
        value: _hasReminder,
        onChanged: (value) {
          setState(() {
            _hasReminder = value;
            if (!value) {
              _reminderDate = null;
            }
          });
        },
        title: Text(
          _isEl ? 'Προσθήκη υπενθύμισης' : 'Add Reminder',
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        subtitle: Text(
          _isEl
              ? 'Ενεργοποίησέ το μόνο αν θες ειδοποίηση'
              : 'Turn on only if you want a reminder',
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 13,
          ),
        ),
        activeColor: AppTheme.primaryTeal,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      ),
    );
  }

  List<DropdownMenuItem<String>> _eventTypeItems() {
    final isEl = _isEl;
    return [
      DropdownMenuItem(
        value: 'vaccine',
        child: Text(isEl ? 'Εμβόλιο' : 'Vaccine'),
      ),
      DropdownMenuItem(
        value: 'medication',
        child: Text(isEl ? 'Αγωγή' : 'Medication'),
      ),
      DropdownMenuItem(
        value: 'vet_visit',
        child: Text(isEl ? 'Κτηνίατρος' : 'Vet Visit'),
      ),
      DropdownMenuItem(
        value: 'weight',
        child: Text(isEl ? 'Βάρος' : 'Weight'),
      ),
      DropdownMenuItem(
        value: 'reminder',
        child: Text(isEl ? 'Υπενθύμιση' : 'Reminder'),
      ),
      DropdownMenuItem(
        value: 'allergy',
        child: Text(isEl ? 'Αλλεργία' : 'Allergy'),
      ),
      DropdownMenuItem(
        value: 'surgery',
        child: Text(isEl ? 'Χειρουργείο' : 'Surgery'),
      ),
      DropdownMenuItem(
        value: 'treatment',
        child: Text(isEl ? 'Θεραπεία' : 'Treatment'),
      ),
      DropdownMenuItem(
        value: 'note',
        child: Text(isEl ? 'Σημείωση' : 'Note'),
      ),
    ];
  }

  List<Widget> _buildDynamicFields() {
    final isEl = _isEl;

    switch (_selectedType) {
      case 'vaccine':
        return [
          TextField(
            controller: _nameController,
            decoration: _fieldDecoration(
              label: isEl ? 'Όνομα εμβολίου' : 'Vaccine name',
            ),
          ),
        ];

      case 'medication':
        return [
          TextField(
            controller: _nameController,
            decoration: _fieldDecoration(
              label: isEl ? 'Όνομα αγωγής' : 'Medication name',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _secondaryController,
            decoration: _fieldDecoration(
              label: isEl ? 'Δοσολογία' : 'Dosage',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _tertiaryController,
            decoration: _fieldDecoration(
              label: isEl ? 'Συχνότητα' : 'Frequency',
            ),
          ),
        ];

      case 'vet_visit':
        return [
          TextField(
            controller: _nameController,
            decoration: _fieldDecoration(
              label: isEl ? 'Λόγος επίσκεψης' : 'Visit title / reason',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _secondaryController,
            decoration: _fieldDecoration(
              label: isEl ? 'Κτηνίατρος / Κλινική' : 'Vet / Clinic name',
            ),
          ),
        ];

      case 'weight':
        return [
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _weightController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  decoration: _fieldDecoration(
                    label: isEl ? 'Βάρος' : 'Weight value',
                    hint: isEl ? 'π.χ. 4.8' : 'e.g. 4.8',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _weightUnit,
                  decoration: _fieldDecoration(
                    label: isEl ? 'Μονάδα' : 'Unit',
                  ),
                  items: const [
                    DropdownMenuItem(value: 'kg', child: Text('kg')),
                    DropdownMenuItem(value: 'lb', child: Text('lb')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _weightUnit = value);
                  },
                ),
              ),
            ],
          ),
        ];

      case 'reminder':
        return [
          TextField(
            controller: _nameController,
            decoration: _fieldDecoration(
              label: isEl ? 'Τίτλος υπενθύμισης' : 'Reminder title',
            ),
          ),
        ];

      case 'allergy':
        return [
          TextField(
            controller: _nameController,
            decoration: _fieldDecoration(
              label: isEl ? 'Όνομα αλλεργίας' : 'Allergy name',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _secondaryController,
            decoration: _fieldDecoration(
              label: isEl ? 'Αντίδραση / λεπτομέρειες' : 'Reaction / details',
            ),
          ),
        ];

      case 'surgery':
        return [
          TextField(
            controller: _nameController,
            decoration: _fieldDecoration(
              label: isEl ? 'Τίτλος χειρουργείου' : 'Surgery title',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _secondaryController,
            decoration: _fieldDecoration(
              label: isEl ? 'Κλινική / Κτηνίατρος' : 'Clinic / Vet',
            ),
          ),
        ];

      case 'treatment':
        return [
          TextField(
            controller: _nameController,
            decoration: _fieldDecoration(
              label: isEl ? 'Όνομα θεραπείας' : 'Treatment name',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _secondaryController,
            decoration: _fieldDecoration(
              label: isEl ? 'Δοσολογία / Οδηγίες' : 'Dosage / Instructions',
            ),
          ),
        ];

      case 'note':
        return [
          TextField(
            controller: _nameController,
            decoration: _fieldDecoration(
              label: isEl ? 'Τίτλος σημείωσης' : 'Note title',
            ),
          ),
        ];

      default:
        return [
          TextField(
            controller: _nameController,
            decoration: _fieldDecoration(
              label: isEl ? 'Τίτλος' : 'Title',
            ),
          ),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEl = _isEl;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          _isEditMode
              ? (isEl ? 'Επεξεργασία καταχώρησης' : 'Edit Health Event')
              : (isEl ? 'Νέα καταχώρηση υγείας' : 'Add Health Event'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(22),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isEditMode
                      ? (isEl
                          ? 'Επεξεργασία καταχώρησης υγείας'
                          : 'Edit health record')
                      : (isEl
                          ? 'Δημιουργία καταχώρησης υγείας'
                          : 'Create health record'),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 18),
                DropdownButtonFormField<String>(
                  value: _selectedType,
                  decoration: _fieldDecoration(
                    label: isEl ? 'Τύπος καταχώρησης' : 'Event Type',
                  ),
                  items: _eventTypeItems(),
                  onChanged: (value) {
                    if (value == null) return;
                    _onTypeChanged(value);
                  },
                ),
                const SizedBox(height: 16),
                ..._buildDynamicFields(),
                const SizedBox(height: 16),
                _buildDateField(
                  label: _isReminderType
                      ? (isEl ? 'Ημερομηνία υπενθύμισης' : 'Reminder Date')
                      : (isEl ? 'Ημερομηνία συμβάντος' : 'Event Date'),
                  value: _selectedDate,
                  icon: Icons.calendar_today_rounded,
                  onTap: _pickDate,
                ),
                if (_supportsReminder) ...[
                  const SizedBox(height: 16),
                  _buildReminderToggle(),
                  if (_hasReminder) ...[
                    const SizedBox(height: 16),
                    _buildDateField(
                      label: isEl ? 'Ημερομηνία υπενθύμισης' : 'Reminder Date',
                      value: _reminderDate ?? _selectedDate,
                      icon: Icons.notifications_active_rounded,
                      onTap: _pickReminderDate,
                    ),
                  ],
                ],
                const SizedBox(height: 16),
                TextField(
                  controller: _notesController,
                  maxLines: _selectedType == 'note' ? 5 : 4,
                  decoration: _fieldDecoration(
                    label: isEl ? 'Σημειώσεις' : 'Notes',
                    hint: _selectedType == 'note'
                        ? (isEl ? 'Γράψε την περιγραφή σου' : 'Write your description')
                        : null,
                  ).copyWith(alignLabelWithHint: true),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryTeal.withOpacity(0.18),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _saveEvent,
              icon: const Icon(Icons.save_rounded),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 17),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 6,
              ),
              label: Text(
                _isEditMode
                    ? (isEl ? 'Αποθήκευση αλλαγών' : 'Save Changes')
                    : (isEl ? 'Αποθήκευση event' : 'Save Event'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
