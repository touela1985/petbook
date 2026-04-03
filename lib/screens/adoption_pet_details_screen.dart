import 'package:flutter/material.dart';

import '../models/adoption_pet.dart';
import '../theme/app_theme.dart';
import '../widgets/pet_image_widget.dart';

class AdoptionPetDetailsScreen extends StatelessWidget {
  final AdoptionPet pet;

  const AdoptionPetDetailsScreen({
    super.key,
    required this.pet,
  });

  bool _isEl(BuildContext context) {
    return Localizations.localeOf(context).languageCode == 'el';
  }

  void _openFullImage(BuildContext context) {
    final provider = petImageProvider(
      photoUrl: pet.photoUrl,
      photoPath: pet.photoPath,
    );
    if (provider == null) return;

    showDialog(
      context: context,
      builder: (_) {
        return Dialog(
          backgroundColor: Colors.black,
          insetPadding: const EdgeInsets.all(12),
          child: Stack(
            children: [
              Positioned.fill(
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4,
                  child: Center(
                    child: Image(
                      image: provider,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) {
                        return const Center(
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: Colors.white70,
                            size: 48,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMainImage(bool hasPhoto, BuildContext context) {
    if (!hasPhoto) {
      return Container(
        height: 220,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppTheme.primaryTeal.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.border),
        ),
        child: const Icon(
          Icons.pets,
          size: 58,
          color: AppTheme.primaryTeal,
        ),
      );
    }

    return InkWell(
      onTap: () => _openFullImage(context),
      borderRadius: BorderRadius.circular(20),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: SizedBox(
              height: 240,
              width: double.infinity,
              child: PetImageWidget(
                photoUrl: pet.photoUrl,
                photoPath: pet.photoPath,
                height: 240,
                width: double.infinity,
                fit: BoxFit.cover,
                borderRadius: BorderRadius.circular(20),
                placeholder: Container(
                  color: AppTheme.primaryTeal.withOpacity(0.08),
                  child: const Icon(
                    Icons.pets,
                    size: 56,
                    color: AppTheme.primaryTeal,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isEl(context)
                ? 'Πάτησε τη φωτογραφία για μεγέθυνση'
                : 'Tap image to enlarge',
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppTheme.primaryTeal.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AppTheme.primaryTeal,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: AppTheme.textPrimary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEl = _isEl(context);
    final hasPhoto = hasAnyImage(photoUrl: pet.photoUrl, photoPath: pet.photoPath);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(isEl ? 'Υιοθεσία' : 'Adoption'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppTheme.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildMainImage(hasPhoto, context),
                const SizedBox(height: 18),
                Text(
                  pet.name.trim().isEmpty
                      ? (isEl ? 'Χωρίς όνομα' : 'Unnamed pet')
                      : pet.name,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (pet.type.trim().isNotEmpty) _infoChip(pet.type),
                    if (pet.age.trim().isNotEmpty) _infoChip(pet.age),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 18,
                      color: AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        pet.location.trim().isEmpty
                            ? (isEl ? 'Χωρίς τοποθεσία' : 'No location')
                            : pet.location,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
                if (pet.description.trim().isNotEmpty) ...[
                  const SizedBox(height: 22),
                  _sectionTitle(isEl ? 'Περιγραφή' : 'Description'),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.background,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Text(
                      pet.description,
                      style: const TextStyle(
                        height: 1.45,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                _sectionTitle(isEl ? 'Επικοινωνία' : 'Contact'),
                const SizedBox(height: 8),
                Text(
                  pet.contactPhone.trim().isEmpty
                      ? (isEl ? 'Δεν υπάρχει τηλέφωνο' : 'No phone provided')
                      : pet.contactPhone,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primaryTeal,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
