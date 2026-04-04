import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/pet_repository.dart';
import '../models/pet.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

class EditPetScreen extends StatefulWidget {
  final PetRepository repo;
  final String petId;

  const EditPetScreen({
    super.key,
    required this.repo,
    required this.petId,
  });

  @override
  State<EditPetScreen> createState() => _EditPetScreenState();
}

class _EditPetScreenState extends State<EditPetScreen> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _ageCtrl;

  String _type = 'dog';
  String _gender = 'unknown';
  String _ageUnit = 'years';

  Pet? _pet;
  XFile? _pickedImage;
  Uint8List? _imageBytes;

  @override
  void initState() {
    super.initState();

    _pet = widget.repo.getAll().firstWhere((p) => p.id == widget.petId);

    _nameCtrl = TextEditingController(text: _pet!.name);
    _type = _pet!.type;
    _gender = _pet!.gender ?? 'unknown';

    final ageText = _pet!.age?.trim() ?? '';
    if (ageText.contains(' ')) {
      final parts = ageText.split(' ');
      _ageCtrl = TextEditingController(text: parts.first);
      _ageUnit = parts.length > 1 ? parts[1] : 'years';
    } else {
      _ageCtrl = TextEditingController(text: ageText);
    }

    if (_pet!.photoBase64 != null && _pet!.photoBase64!.isNotEmpty) {
      _imageBytes = base64Decode(_pet!.photoBase64!);
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
        const SnackBar(content: Text('Write a name')),
      );
      return;
    }

    if (ageText.isNotEmpty && int.tryParse(ageText) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Age must be a number')),
      );
      return;
    }

    _pet!.name = name;
    _pet!.type = _type;
    _pet!.gender = _gender;
    _pet!.age = ageText.isEmpty ? null : '$ageText $_ageUnit';

    if (_pickedImage != null) {
      _pet!.photoPath = _pickedImage!.path;
    }

    if (_imageBytes != null) {
      _pet!.photoBase64 = base64Encode(_imageBytes!);
    }

    // Try to upload new image to Firebase Storage; keep existing photoUrl on failure.
    if (_pickedImage != null && _imageBytes != null) {
      final url = await StorageService.uploadPetImage(_imageBytes!, _pet!.id);
      if (url != null) {
        _pet!.photoUrl = url;
      }
    }

    await widget.repo.savePets();

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
      child: CircleAvatar(
        radius: 54,
        backgroundColor: AppTheme.surface,
        backgroundImage: imageProvider,
        child: imageProvider == null
            ? const Icon(Icons.add_a_photo, size: 30)
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Edit Pet'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _save,
            tooltip: 'Save',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Center(child: _buildPhotoPreview()),
            const SizedBox(height: 20),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Pet name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _type,
              decoration: const InputDecoration(
                labelText: 'Type',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'dog', child: Text('Dog')),
                DropdownMenuItem(value: 'cat', child: Text('Cat')),
                DropdownMenuItem(value: 'other', child: Text('Other')),
              ],
              onChanged: (v) => setState(() => _type = v ?? 'dog'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _gender,
              decoration: const InputDecoration(
                labelText: 'Gender',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'unknown', child: Text('Unknown')),
                DropdownMenuItem(value: 'male', child: Text('Male')),
                DropdownMenuItem(value: 'female', child: Text('Female')),
              ],
              onChanged: (v) => setState(() => _gender = v ?? 'unknown'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ageCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Age',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _ageUnit,
                    decoration: const InputDecoration(
                      labelText: 'Unit',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'months', child: Text('Months')),
                      DropdownMenuItem(value: 'years', child: Text('Years')),
                    ],
                    onChanged: (v) => setState(() => _ageUnit = v ?? 'years'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _save,
                child: const Text('Save changes'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
