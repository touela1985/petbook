import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../data/adoption_pet_repository.dart';
import '../models/adoption_pet.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

class AddAdoptionPetScreen extends StatefulWidget {
  final AdoptionPet? initialPet;

  const AddAdoptionPetScreen({
    super.key,
    this.initialPet,
  });

  @override
  State<AddAdoptionPetScreen> createState() =>
      _AddAdoptionPetScreenState();
}

class _AddAdoptionPetScreenState extends State<AddAdoptionPetScreen> {
  final _nameController = TextEditingController();
  final _typeController = TextEditingController();
  final _ageController = TextEditingController();
  final _locationController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _phoneController = TextEditingController();

  final AdoptionPetRepository _repo = AdoptionPetRepository();
  final ImagePicker _picker = ImagePicker();
  final Uuid _uuid = const Uuid();

  XFile? _selectedImage;

  bool get _isEditing => widget.initialPet != null;
  bool get _isEl => Localizations.localeOf(context).languageCode == 'el';

  @override
  void initState() {
    super.initState();
    final pet = widget.initialPet;

    if (pet != null) {
      _nameController.text = pet.name;
      _typeController.text = pet.type;
      _ageController.text = pet.age;
      _locationController.text = pet.location;
      _descriptionController.text = pet.description;
      _phoneController.text = pet.contactPhone;
    }
  }

  Future<void> _pickImage() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );

    if (image != null) {
      setState(() {
        _selectedImage = image;
      });
    }
  }

  Future<void> _submit() async {
    if (_locationController.text.trim().isEmpty ||
        _phoneController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEl
                ? 'Συμπλήρωσε τα υποχρεωτικά πεδία'
                : 'Please fill required fields',
          ),
        ),
      );
      return;
    }

    final existing = widget.initialPet;

    if (existing == null) {
      final petId = _uuid.v4();

      String? photoUrl;
      if (_selectedImage != null) {
        final bytes = await _selectedImage!.readAsBytes();
        photoUrl = await StorageService.uploadAdoptionPetImage(bytes, petId);
      }

      final pet = AdoptionPet(
        id: petId,
        name: _nameController.text.trim(),
        type: _typeController.text.trim(),
        age: _ageController.text.trim(),
        location: _locationController.text.trim(),
        description: _descriptionController.text.trim(),
        contactPhone: _phoneController.text.trim(),
        photoPath: _selectedImage?.path,
        photoUrl: photoUrl,
        userId: FirebaseAuth.instance.currentUser?.uid,
      );

      await _repo.addPet(pet);
    } else {
      String? photoUrl = existing.photoUrl;
      if (_selectedImage != null) {
        final bytes = await _selectedImage!.readAsBytes();
        final uploaded = await StorageService.uploadAdoptionPetImage(bytes, existing.id);
        if (uploaded != null) photoUrl = uploaded;
      }

      final updatedPet = AdoptionPet(
        id: existing.id,
        name: _nameController.text.trim(),
        type: _typeController.text.trim(),
        age: _ageController.text.trim(),
        location: _locationController.text.trim(),
        description: _descriptionController.text.trim(),
        contactPhone: _phoneController.text.trim(),
        photoPath: _selectedImage?.path ?? existing.photoPath,
        photoUrl: photoUrl,
        adopted: existing.adopted,
        userId: existing.userId,
      );

      await _repo.updatePet(updatedPet);
    }

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  Widget _imagePreview() {
    if (_selectedImage == null) {
      return Container(
        height: 90,
        width: 90,
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
        ),
        child: const Icon(Icons.pets, size: 32),
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

    return FutureBuilder(
      future: _selectedImage!.readAsBytes(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(
            height: 90,
            width: 90,
            child: Center(child: CircularProgressIndicator()),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          _imagePreview(),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isEl ? 'Φωτογραφία ζώου' : 'Pet photo',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _selectedImage == null
                      ? (_isEl
                          ? 'Πρόσθεσε φωτογραφία για καλύτερη αγγελία.'
                          : 'Add a photo for better visibility.')
                      : (_isEl
                          ? 'Η φωτογραφία προστέθηκε'
                          : 'Photo selected'),
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
                        ? (_isEl ? 'Προσθήκη' : 'Add')
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

  InputDecoration _dec(String label) {
    return InputDecoration(labelText: label);
  }

  @override
  Widget build(BuildContext context) {
    final isEl = _isEl;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          _isEditing
              ? (isEl ? 'Επεξεργασία αγγελίας' : 'Edit Adoption Listing')
              : (isEl ? 'Νέα αγγελία υιοθεσίας' : 'Add Adoption Listing'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _photoSection(),
          const SizedBox(height: 16),

          TextField(
            controller: _nameController,
            decoration: _dec(isEl ? 'Όνομα ζώου' : 'Pet name'),
          ),

          const SizedBox(height: 12),

          TextField(
            controller: _typeController,
            decoration: _dec(isEl ? 'Είδος / ράτσα' : 'Type / breed'),
          ),

          const SizedBox(height: 12),

          TextField(
            controller: _ageController,
            decoration: _dec(isEl ? 'Ηλικία' : 'Age'),
          ),

          const SizedBox(height: 12),

          TextField(
            controller: _locationController,
            decoration: _dec(isEl ? 'Τοποθεσία *' : 'Location'),
          ),

          const SizedBox(height: 12),

          TextField(
            controller: _phoneController,
            decoration: _dec(isEl ? 'Τηλέφωνο επικοινωνίας *' : 'Contact phone'),
          ),

          const SizedBox(height: 12),

          TextField(
            controller: _descriptionController,
            maxLines: 4,
            decoration: _dec(isEl ? 'Περιγραφή' : 'Description'),
          ),

          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _submit,
              icon: const Icon(Icons.favorite),
              label: Text(
                _isEditing
                    ? (isEl ? 'Αποθήκευση αλλαγών' : 'Update adoption listing')
                    : (isEl ? 'Δημιουργία αγγελίας' : 'Create adoption listing'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
