import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../data/found_pet_report_repository.dart';
import '../models/found_pet_report.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import 'pick_location_screen.dart';

class AddFoundPetReportScreen extends StatefulWidget {
  final FoundPetReport? initialReport;

  const AddFoundPetReportScreen({
    super.key,
    this.initialReport,
  });

  @override
  State<AddFoundPetReportScreen> createState() =>
      _AddFoundPetReportScreenState();
}

class _AddFoundPetReportScreenState extends State<AddFoundPetReportScreen> {
  final _typeController = TextEditingController();
  final _locationController = TextEditingController();
  final _notesController = TextEditingController();
  final _phoneController = TextEditingController();
  final FoundPetReportRepository _repo = FoundPetReportRepository();
  final ImagePicker _picker = ImagePicker();
  final Uuid _uuid = const Uuid();

  DateTime _selectedDate = DateTime.now();
  XFile? _selectedImage;
  double? _selectedLatitude;
  double? _selectedLongitude;
  bool _isSubmitting = false;

  bool get _isEditing => widget.initialReport != null;
  bool get _isEl => Localizations.localeOf(context).languageCode == 'el';

  @override
  void initState() {
    super.initState();
    final report = widget.initialReport;
    if (report != null) {
      _typeController.text = report.type;
      _locationController.text = report.locationFound;
      _notesController.text = report.notes;
      _phoneController.text = report.contactPhone;
      _selectedDate = report.foundDate;
      _selectedLatitude = report.latitude;
      _selectedLongitude = report.longitude;
    }
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (image != null) {
      setState(() {
        _selectedImage = image;
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _pickLocationOnMap() async {
    final LatLng? pickedLocation = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(
        builder: (_) => const PickLocationScreen(),
      ),
    );

    if (pickedLocation == null) return;

    setState(() {
      _selectedLatitude = pickedLocation.latitude;
      _selectedLongitude = pickedLocation.longitude;
      _locationController.text =
          '${pickedLocation.latitude.toStringAsFixed(5)}, ${pickedLocation.longitude.toStringAsFixed(5)}';
    });
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;

    if (_locationController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEl
                ? 'Συμπλήρωσε τα απαραίτητα πεδία'
                : 'Please fill the required fields.',
          ),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final existing = widget.initialReport;

      if (existing == null) {
        final reportId = _uuid.v4();
        String? photoUrl;
        if (_selectedImage != null) {
          final bytes = await _selectedImage!.readAsBytes();
          photoUrl = await StorageService.uploadFoundPetImage(bytes, reportId);
        }
        final report = FoundPetReport(
          id: reportId,
          type: _typeController.text.trim(),
          locationFound: _locationController.text.trim(),
          foundDate: _selectedDate,
          notes: _notesController.text.trim(),
          contactPhone: _phoneController.text.trim(),
          isResolved: false,
          photoPath: _selectedImage?.path,
          photoUrl: photoUrl,
          latitude: _selectedLatitude,
          longitude: _selectedLongitude,
          userId: FirebaseAuth.instance.currentUser?.uid,
        );
        await _repo.addReport(report);
      } else {
        String? photoUrl = existing.photoUrl;
        if (_selectedImage != null) {
          final bytes = await _selectedImage!.readAsBytes();
          photoUrl = await StorageService.uploadFoundPetImage(bytes, existing.id)
              ?? existing.photoUrl;
        }
        final updatedReport = FoundPetReport(
          id: existing.id,
          type: _typeController.text.trim(),
          locationFound: _locationController.text.trim(),
          foundDate: _selectedDate,
          notes: _notesController.text.trim(),
          contactPhone: _phoneController.text.trim(),
          isResolved: existing.isResolved,
          photoPath: _selectedImage?.path ?? existing.photoPath,
          photoUrl: photoUrl,
          latitude: _selectedLatitude,
          longitude: _selectedLongitude,
          userId: existing.userId,
        );
        await _repo.updateReport(updatedReport);
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String _formatDate(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    final y = date.year.toString();
    return '$d/$m/$y';
  }

  Widget _buildImagePreview() {
    if (_selectedImage == null) {
      return Container(
        height: 90,
        width: 90,
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
        ),
        child: const Icon(Icons.photo),
      );
    }

    if (kIsWeb) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.network(
          _selectedImage!.path,
          height: 90,
          width: 90,
          fit: BoxFit.cover,
        ),
      );
    }

    return FutureBuilder<Uint8List>(
      future: _selectedImage!.readAsBytes(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Container(
            height: 90,
            width: 90,
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border),
            ),
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }

        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.memory(
            snapshot.data!,
            height: 90,
            width: 90,
            fit: BoxFit.cover,
          ),
        );
      },
    );
  }

  Widget _photoSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildImagePreview(),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isEl ? 'Φωτογραφία ζώου' : 'Animal photo',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _selectedImage == null
                      ? (_isEl
                          ? 'Πρόσθεσε φωτογραφία του ζώου που βρήκες.'
                          : 'Add a photo of the animal you found.')
                      : (_isEl
                          ? 'Η φωτογραφία επιλέχθηκε.'
                          : 'Photo selected successfully.'),
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.photo),
                  label: Text(
                    _selectedImage == null
                        ? (_isEl ? 'Προσθήκη φωτογραφίας' : 'Add Photo')
                        : (_isEl ? 'Αλλαγή' : 'Change'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationSection() {
    return Column(
      children: [
        TextField(
          controller: _locationController,
          decoration: InputDecoration(
            labelText: _isEl
                ? 'Τοποθεσία που βρέθηκε *'
                : 'Location found *',
          ),
        ),
        const SizedBox(height: 10),
        ElevatedButton(
          onPressed: _pickLocationOnMap,
          child: Text(_isEl ? 'Επιλογή από χάρτη' : 'Pick on map'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _typeController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomSafePadding = MediaQuery.of(context).padding.bottom;
    final isEl = _isEl;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          _isEditing
              ? (isEl ? 'Επεξεργασία εύρεσης' : 'Edit Found Pet Report')
              : (isEl ? 'Βρέθηκε ζώο' : 'Found Pet Report'),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 16, 16, bottomSafePadding + 28),
          children: [
            _photoSection(),
            const SizedBox(height: 16),
            TextField(
              controller: _typeController,
              decoration: InputDecoration(
                labelText: isEl ? 'Τύπος / ράτσα' : 'Type / breed',
              ),
            ),
            const SizedBox(height: 12),
            _buildLocationSection(),
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.border),
                  borderRadius: BorderRadius.circular(12),
                  color: AppTheme.surface,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isEl
                            ? 'Ημερομηνία: ${_formatDate(_selectedDate)}'
                            : 'Date: ${_formatDate(_selectedDate)}',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneController,
              decoration: InputDecoration(
                labelText: isEl
                    ? 'Τηλέφωνο επικοινωνίας (προαιρετικό)'
                    : 'Contact phone (optional)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: isEl ? 'Σημειώσεις' : 'Notes',
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _submit,
                icon: _isSubmitting
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.campaign),
                label: Text(
                  _isEditing
                      ? (isEl ? 'Ενημέρωση' : 'Update report')
                      : (isEl ? 'Δημιουργία' : 'Create report'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
