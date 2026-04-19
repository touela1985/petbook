import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

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

  Future<void> _callOwner(BuildContext context) async {
    final phone = pet.contactPhone.trim();
    if (phone.isEmpty) return;
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _share(BuildContext context) async {
    final isEl = _isEl(context);
    final name = pet.name.trim().isEmpty
        ? (isEl ? 'Ζώο προς υιοθεσία' : 'Pet for adoption')
        : pet.name;
    final parts = <String>[
      isEl ? '🐾 Υιοθεσία: $name' : '🐾 Adoption: $name',
      if (pet.type.trim().isNotEmpty) pet.type,
      if (pet.age.trim().isNotEmpty)
        (isEl ? 'Ηλικία: ${pet.age}' : 'Age: ${pet.age}'),
      if (pet.location.trim().isNotEmpty)
        (isEl ? 'Τοποθεσία: ${pet.location}' : 'Location: ${pet.location}'),
      if (pet.contactPhone.trim().isNotEmpty)
        (isEl ? 'Τηλ: ${pet.contactPhone}' : 'Tel: ${pet.contactPhone}'),
    ];
    await Share.share(parts.join('\n'));
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
                if (pet.adopted) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: Colors.green.withOpacity(0.35),
                      ),
                    ),
                    child: Text(
                      isEl ? '✓ Υιοθετήθηκε' : '✓ Adopted',
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
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
                if (pet.contactPhone.trim().isEmpty)
                  Text(
                    isEl ? 'Δεν υπάρχει τηλέφωνο' : 'No phone provided',
                    style: const TextStyle(
                      fontSize: 16,
                      color: AppTheme.textSecondary,
                    ),
                  )
                else
                  GestureDetector(
                    onTap: () => _callOwner(context),
                    child: Text(
                      pet.contactPhone.trim(),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primaryTeal,
                        decoration: TextDecoration.underline,
                        decorationColor: AppTheme.primaryTeal,
                      ),
                    ),
                  ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    if (pet.contactPhone.trim().isNotEmpty) ...[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _callOwner(context),
                          icon: const Icon(Icons.call_rounded, size: 18),
                          label: Text(isEl ? 'Κλήση' : 'Call'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.green,
                            side: const BorderSide(color: Colors.green),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _share(context),
                        icon: const Icon(Icons.share_outlined, size: 18),
                        label: Text(isEl ? 'Κοινοποίηση' : 'Share'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.textSecondary,
                          side: const BorderSide(color: AppTheme.border),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
