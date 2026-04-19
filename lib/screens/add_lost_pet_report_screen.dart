import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../data/lost_pet_report_repository.dart';
import '../models/lost_pet_report.dart';
import '../services/profile_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import 'pick_location_screen.dart';

class AddLostPetReportScreen extends StatefulWidget {
  final LostPetReport? initialReport;

  const AddLostPetReportScreen({
    super.key,
    this.initialReport,
  });

  @override
  State<AddLostPetReportScreen> createState() =>
      _AddLostPetReportScreenState();
}

class _AddLostPetReportScreenState
    extends State<AddLostPetReportScreen> {
  final _petNameController = TextEditingController();
  final _typeController = TextEditingController();
  final _locationController = TextEditingController();
  final _notesController = TextEditingController();
  final _phoneController = TextEditingController();

  final LostPetReportRepository _repo = LostPetReportRepository();
  final ImagePicker _picker = ImagePicker();
  final Uuid _uuid = const Uuid();

  DateTime _selectedDate = DateTime.now();
  XFile? _selectedImage;
  double? _selectedLatitude;
  double? _selectedLongitude;
  bool _isSubmitting = false;

  bool get _isEditing => widget.initialReport != null;
  bool get _isEl =>
      Localizations.localeOf(context).languageCode == 'el';

  @override
  void initState() {
    super.initState();
    final report = widget.initialReport;
    if (report != null) {
      _petNameController.text = report.petName;
      _typeController.text = report.type;
      _locationController.text = report.lastSeenLocation;
      _notesController.text = report.notes;
      _phoneController.text = report.contactPhone;
      _selectedDate = report.lastSeenDate;
      _selectedLatitude = report.latitude;
      _selectedLongitude = report.longitude;
    } else {
      _prefillFromProfile();
    }
  }

  Future<void> _prefillFromProfile() async {
    final data = await ProfileService().load();
    if (!mounted) return;
    if (data.phone.trim().isNotEmpty) {
      setState(() {
        _phoneController.text = data.phone.trim();
      });
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
      lastDate: DateTime.now(),
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

      bool imageUploadFailed = false;

      if (existing == null) {
        final reportId = _uuid.v4();

        String? uploadedUrl;
        if (_selectedImage != null) {
          final bytes = await _selectedImage!.readAsBytes();
          uploadedUrl = await StorageService.uploadLostPetImage(bytes, reportId);
          if (uploadedUrl == null) imageUploadFailed = true;
        }

        final report = LostPetReport(
          id: reportId,
          petName: _petNameController.text.trim(),
          type: _typeController.text.trim(),
          lastSeenLocation: _locationController.text.trim(),
          lastSeenDate: _selectedDate,
          notes: _notesController.text.trim(),
          contactPhone: _phoneController.text.trim(),
          isResolved: false,
          photoPath: _selectedImage?.path,
          photoUrl: uploadedUrl,
          latitude: _selectedLatitude,
          longitude: _selectedLongitude,
          userId: FirebaseAuth.instance.currentUser?.uid,
        );

        await _repo.addReport(report);
        // TODO Step 18: trigger lost_reports topic notification via Cloud Function
      } else {
        String? uploadedUrl;
        if (_selectedImage != null) {
          final bytes = await _selectedImage!.readAsBytes();
          uploadedUrl = await StorageService.uploadLostPetImage(bytes, existing.id);
          if (uploadedUrl == null) imageUploadFailed = true;
        }

        final updatedReport = LostPetReport(
          id: existing.id,
          petName: _petNameController.text.trim(),
          type: _typeController.text.trim(),
          lastSeenLocation: _locationController.text.trim(),
          lastSeenDate: _selectedDate,
          notes: _notesController.text.trim(),
          contactPhone: _phoneController.text.trim(),
          isResolved: existing.isResolved,
          photoPath: _selectedImage?.path ?? existing.photoPath,
          photoUrl: uploadedUrl ?? existing.photoUrl,
          latitude: _selectedLatitude,
          longitude: _selectedLongitude,
          createdAt: existing.createdAt,
          userId: existing.userId,
        );

        await _repo.updateReport(updatedReport);
      }

      if (!mounted) return;
      if (imageUploadFailed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEl
                  ? 'Η αναφορά αποθηκεύτηκε, αλλά η εικόνα δεν ανέβηκε (έλεγξε σύνδεση).'
                  : 'Report saved, but the photo could not be uploaded (check connection).',
            ),
            backgroundColor: Colors.orange.shade700,
          ),
        );
      }
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

  @override
  void dispose() {
    _petNameController.dispose();
    _typeController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Widget _buildImageWidget() {
    if (_selectedImage == null) {
      return Container(
        height: 88,
        width: 88,
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
        ),
        child: const Icon(
          Icons.photo,
          color: AppTheme.textSecondary,
        ),
      );
    }

    if (kIsWeb) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.network(
          _selectedImage!.path,
          height: 88,
          width: 88,
          fit: BoxFit.cover,
        ),
      );
    }

    return FutureBuilder<Uint8List>(
      future: _selectedImage!.readAsBytes(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.memory(
            snapshot.data!,
            height: 88,
            width: 88,
            fit: BoxFit.cover,
          ),
        );
      },
    );
  }

  Widget _buildPhotoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _isEl ? 'Φωτογραφία ζώου' : 'Pet photo',
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _buildImageWidget(),
            const SizedBox(width: 10),
            ElevatedButton(
              onPressed: _pickImage,
              child: Text(_isEl ? 'Προσθήκη φωτογραφίας' : 'Add Photo'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLocationSection() {
    return Column(
      children: [
        TextField(
          controller: _locationController,
          decoration: InputDecoration(
            labelText:
                _isEl ? 'Τοποθεσία που χάθηκε *' : 'Last seen location *',
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
  Widget build(BuildContext context) {
    final isEl = _isEl;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing
              ? (isEl ? 'Επεξεργασία' : 'Edit Lost Pet Report')
              : (isEl ? 'Χάθηκε ζώο' : 'Lost Pet Report'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildPhotoSection(),
          const SizedBox(height: 12),
          TextField(
            controller: _petNameController,
            decoration: InputDecoration(
              labelText: isEl
                  ? 'Όνομα ζώου (προαιρετικό)'
                  : 'Pet name (optional)',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _typeController,
            decoration: InputDecoration(
              labelText:
                  isEl ? 'Τύπος / ράτσα' : 'Type / breed',
            ),
          ),
          const SizedBox(height: 12),
          _buildLocationSection(),
          const SizedBox(height: 12),
          ListTile(
            title: Text(
              isEl
                  ? 'Ημερομηνία: ${_formatDate(_selectedDate)}'
                  : 'Date: ${_formatDate(_selectedDate)}',
            ),
            trailing: const Icon(Icons.calendar_today),
            onTap: _pickDate,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phoneController,
            decoration: InputDecoration(
              labelText: isEl
                  ? 'Τηλέφωνο επικοινωνίας'
                  : 'Contact phone',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: isEl ? 'Σημειώσεις' : 'Notes',
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _isSubmitting ? null : _submit,
            child: _isSubmitting
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    _isEditing
                        ? (isEl ? 'Ενημέρωση' : 'Update report')
                        : (isEl ? 'Δημιουργία' : 'Create report'),
                  ),
          ),
        ],
      ),
    );
  }
}
