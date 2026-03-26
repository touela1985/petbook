import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/pet_repository.dart';
import '../models/pet.dart';
import '../theme/app_theme.dart';

class AddPetScreen extends StatefulWidget {
  final PetRepository repo;
  final Pet? petToEdit;

  const AddPetScreen({
    super.key,
    required this.repo,
    this.petToEdit,
  });

  @override
  State<AddPetScreen> createState() => _AddPetScreenState();
}

class _AddPetScreenState extends State<AddPetScreen> {
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _ageCtrl = TextEditingController();

  String _type = 'dog';
  String _gender = 'male';
  String _ageUnit = 'years';

  XFile? _pickedImage;
  Uint8List? _imageBytes;

  bool get _isEl => Localizations.localeOf(context).languageCode == 'el';
  bool get _isEditMode => widget.petToEdit != null;

  @override
  void initState() {
    super.initState();

    if (widget.petToEdit != null) {
      final p = widget.petToEdit!;
      _nameCtrl.text = p.name;
      _type = p.type;
      _gender = p.gender ?? 'male';

      if (p.age != null && p.age!.trim().isNotEmpty) {
        final parts = p.age!.trim().split(' ');
        if (parts.isNotEmpty) {
          _ageCtrl.text = parts.first;
        }
        if (parts.length > 1) {
          final unit = parts[1].toLowerCase();
          if (unit == 'months' || unit == 'month') {
            _ageUnit = 'months';
          } else {
            _ageUnit = 'years';
          }
        }
      }

      if (p.photoBase64 != null && p.photoBase64!.isNotEmpty) {
        try {
          _imageBytes = base64Decode(p.photoBase64!);
        } catch (_) {}
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );

    if (picked == null) return;

    final bytes = await picked.readAsBytes();

    setState(() {
      _pickedImage = picked;
      _imageBytes = bytes;
    });
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final ageText = _ageCtrl.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEl ? 'Γράψε όνομα' : 'Write a name'),
        ),
      );
      return;
    }

    if (ageText.isNotEmpty && int.tryParse(ageText) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEl ? 'Η ηλικία πρέπει να είναι αριθμός' : 'Age must be a number',
          ),
        ),
      );
      return;
    }

    final storedAge = ageText.isEmpty ? null : '$ageText $_ageUnit';
    final photoBase64 = _imageBytes == null ? null : base64Encode(_imageBytes!);

    if (_isEditMode) {
      final oldPet = widget.petToEdit!;
      await widget.repo.updatePet(
        id: oldPet.id,
        name: name,
        type: _type,
        age: storedAge,
        gender: _gender,
        photoPath: _pickedImage?.path ?? oldPet.photoPath,
        photoBase64: photoBase64 ?? oldPet.photoBase64,
      );
    } else {
      await widget.repo.addPet(
        name: name,
        type: _type,
        age: storedAge,
        gender: _gender,
        photoPath: _pickedImage?.path,
        photoBase64: photoBase64,
      );
    }

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  Widget _buildPhotoPreview() {
    ImageProvider? imageProvider;
    if (_imageBytes != null) {
      imageProvider = MemoryImage(_imageBytes!);
    }

    return GestureDetector(
      onTap: _pickImage,
      child: Column(
        children: [
          Container(
            height: 154,
            width: 154,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.surface,
              border: Border.all(
                color: AppTheme.primaryTeal.withOpacity(0.12),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
              image: imageProvider != null
                  ? DecorationImage(
                      image: imageProvider,
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: imageProvider == null
                ? Center(
                    child: Container(
                      height: 68,
                      width: 68,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryTeal.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.add_a_photo_rounded,
                        size: 34,
                        color: AppTheme.primaryTeal,
                      ),
                    ),
                  )
                : Align(
                    alignment: Alignment.bottomRight,
                    child: Container(
                      margin: const EdgeInsets.only(right: 10, bottom: 10),
                      height: 40,
                      width: 40,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryTeal,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryTeal.withOpacity(0.28),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.edit_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 14),
          Text(
            _isEl ? 'Πρόσθεσε φωτογραφία ζώου' : 'Add pet photo',
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _isEl
                ? 'Πάτησε για να επιλέξεις από τη συλλογή'
                : 'Tap to choose from gallery',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
  }) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: AppTheme.surface,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 18,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(color: AppTheme.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(color: AppTheme.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(
          color: AppTheme.primaryTeal,
          width: 1.6,
        ),
      ),
      labelStyle: const TextStyle(
        color: AppTheme.textSecondary,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _fieldShell({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEl = _isEl;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          _isEditMode
              ? (isEl ? 'Επεξεργασία ζώου' : 'Edit Pet')
              : (isEl ? 'Προσθήκη ζώου' : 'Add Pet'),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildPhotoPreview(),
              const SizedBox(height: 28),
              _fieldShell(
                child: TextField(
                  controller: _nameCtrl,
                  decoration: _inputDecoration(
                    label: isEl ? 'Όνομα ζώου' : 'Pet name',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _fieldShell(
                child: DropdownButtonFormField<String>(
                  value: _type,
                  decoration: _inputDecoration(
                    label: isEl ? 'Τύπος' : 'Type',
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'dog',
                      child: Text(isEl ? 'Σκύλος' : 'Dog'),
                    ),
                    DropdownMenuItem(
                      value: 'cat',
                      child: Text(isEl ? 'Γάτα' : 'Cat'),
                    ),
                    DropdownMenuItem(
                      value: 'other',
                      child: Text(isEl ? 'Άλλο' : 'Other'),
                    ),
                  ],
                  onChanged: (v) => setState(() => _type = v ?? 'dog'),
                ),
              ),
              const SizedBox(height: 16),
              _fieldShell(
                child: DropdownButtonFormField<String>(
                  value: _gender,
                  decoration: _inputDecoration(
                    label: isEl ? 'Φύλο' : 'Gender',
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'male',
                      child: Text(isEl ? 'Αρσενικό' : 'Male'),
                    ),
                    DropdownMenuItem(
                      value: 'female',
                      child: Text(isEl ? 'Θηλυκό' : 'Female'),
                    ),
                  ],
                  onChanged: (v) => setState(() => _gender = v ?? 'male'),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _fieldShell(
                      child: TextField(
                        controller: _ageCtrl,
                        keyboardType: TextInputType.number,
                        decoration: _inputDecoration(
                          label: isEl ? 'Ηλικία' : 'Age',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _fieldShell(
                      child: DropdownButtonFormField<String>(
                        value: _ageUnit,
                        decoration: _inputDecoration(
                          label: isEl ? 'Μονάδα' : 'Unit',
                        ),
                        items: [
                          DropdownMenuItem(
                            value: 'months',
                            child: Text(isEl ? 'Μήνες' : 'Months'),
                          ),
                          DropdownMenuItem(
                            value: 'years',
                            child: Text(isEl ? 'Χρόνια' : 'Years'),
                          ),
                        ],
                        onChanged: (v) =>
                            setState(() => _ageUnit = v ?? 'years'),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 110),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Container(
          margin: const EdgeInsets.only(bottom: 24),
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryTeal.withOpacity(0.20),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 8,
              ),
              child: Text(
                _isEditMode
                    ? (isEl ? 'Αποθήκευση αλλαγών' : 'Save changes')
                    : (isEl ? 'Αποθήκευση ζώου' : 'Save Pet'),
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
