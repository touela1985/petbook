import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../data/adoption_pet_repository.dart';
import '../models/adoption_pet.dart';
import '../theme/app_theme.dart';
import '../widgets/pet_image_widget.dart';
import 'add_adoption_pet_screen.dart';
import 'adoption_pet_details_screen.dart';

class AdoptionListScreen extends StatefulWidget {
  const AdoptionListScreen({super.key});

  @override
  State<AdoptionListScreen> createState() => _AdoptionListScreenState();
}

class _AdoptionListScreenState extends State<AdoptionListScreen> {
  final AdoptionPetRepository _repo = AdoptionPetRepository();

  late Future<List<AdoptionPet>> _petsFuture;

  bool get _isEl => Localizations.localeOf(context).languageCode == 'el';

  @override
  void initState() {
    super.initState();
    _petsFuture = _loadPets();
  }

  Future<List<AdoptionPet>> _loadPets() async {
    return _repo.getPets();
  }

  Future<void> _openAddAdoption() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const AddAdoptionPetScreen(),
      ),
    );
    if (created == true) {
      setState(() {
        _petsFuture = _loadPets();
      });
    }
  }

  Future<void> _openDetails(AdoptionPet pet) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdoptionPetDetailsScreen(pet: pet),
      ),
    );
  }

  Future<void> _editAdoption(AdoptionPet pet) async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddAdoptionPetScreen(
          initialPet: pet,
        ),
      ),
    );
    if (updated == true) {
      setState(() {
        _petsFuture = _loadPets();
      });
    }
  }

  Future<void> _markAsAdopted(AdoptionPet pet) async {
    final isEl = _isEl;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEl ? 'Σήμανση ως υιοθετήθηκε' : 'Mark as adopted'),
        content: Text(
          isEl
              ? 'Θέλεις να σημάνεις αυτή την αγγελία ως υιοθετήθηκε;'
              : 'Mark this listing as adopted?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(isEl ? 'Ακύρωση' : 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(isEl ? 'Υιοθετήθηκε' : 'Mark adopted'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final updated = AdoptionPet(
      id: pet.id,
      name: pet.name,
      type: pet.type,
      age: pet.age,
      location: pet.location,
      description: pet.description,
      contactPhone: pet.contactPhone,
      photoPath: pet.photoPath,
      photoUrl: pet.photoUrl,
      adopted: true,
      userId: pet.userId,
    );
    await _repo.updatePet(updated);
    if (mounted) {
      setState(() {
        _petsFuture = _loadPets();
      });
    }
  }

  Future<void> _deleteAdoption(AdoptionPet pet) async {
    final isEl = _isEl;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEl ? 'Διαγραφή αγγελίας' : 'Delete listing'),
        content: Text(
          isEl
              ? 'Θέλεις σίγουρα να διαγράψεις αυτή την αγγελία υιοθεσίας;'
              : 'Are you sure you want to delete this adoption listing?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(isEl ? 'Ακύρωση' : 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(isEl ? 'Διαγραφή' : 'Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await _repo.deletePet(pet.id);
    if (mounted) {
      setState(() {
        _petsFuture = _loadPets();
      });
    }
  }

  Widget _petImage(AdoptionPet pet) {
    return SizedBox(
      width: 82,
      height: 82,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: PetImageWidget(
          photoUrl: pet.photoUrl,
          photoPath: pet.photoPath,
          width: 82,
          height: 82,
          fit: BoxFit.cover,
          placeholder: Container(
            color: AppTheme.primaryTeal.withOpacity(0.10),
            child: const Icon(
              Icons.pets,
              size: 34,
              color: AppTheme.primaryTeal,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEl = _isEl;
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(isEl ? 'Υιοθεσίες' : 'Adoptions'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddAdoption,
        child: const Icon(Icons.add),
      ),
      body: FutureBuilder<List<AdoptionPet>>(
        future: _petsFuture,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final pets = snap.data!;

          if (pets.isEmpty) {
            return Center(
              child: Text(
                isEl ? 'Δεν υπάρχουν αγγελίες υιοθεσίας ακόμα' : 'No adoption listings yet',
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: pets.length,
            itemBuilder: (context, i) {
              final pet = pets[i];
              final isOwner = currentUser != null && currentUser.uid == pet.userId;

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: AppTheme.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: () => _openDetails(pet),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _petImage(pet),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      pet.name.trim().isEmpty
                                          ? (isEl ? 'Χωρίς όνομα' : 'Unnamed pet')
                                          : pet.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        color: AppTheme.textPrimary,
                                      ),
                                    ),
                                  ),
                                  if (isOwner)
                                    PopupMenuButton<_AdoptionMenuAction>(
                                      onSelected: (value) {
                                        switch (value) {
                                          case _AdoptionMenuAction.edit:
                                            _editAdoption(pet);
                                            break;
                                          case _AdoptionMenuAction.markAdopted:
                                            _markAsAdopted(pet);
                                            break;
                                          case _AdoptionMenuAction.delete:
                                            _deleteAdoption(pet);
                                            break;
                                        }
                                      },
                                      itemBuilder: (context) => [
                                        PopupMenuItem(
                                          value: _AdoptionMenuAction.edit,
                                          child: Text(isEl ? 'Επεξεργασία' : 'Edit'),
                                        ),
                                        if (!pet.adopted)
                                          PopupMenuItem(
                                            value: _AdoptionMenuAction.markAdopted,
                                            child: Text(isEl ? 'Υιοθετήθηκε ✓' : 'Mark as adopted ✓'),
                                          ),
                                        PopupMenuItem(
                                          value: _AdoptionMenuAction.delete,
                                          child: Text(isEl ? 'Διαγραφή' : 'Delete'),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                              if (pet.adopted) ...[
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
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
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                              if (pet.type.trim().isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  pet.type,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.location_on_outlined,
                                    size: 16,
                                    color: AppTheme.textSecondary,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      pet.location.trim().isEmpty
                                          ? (isEl ? 'Χωρίς τοποθεσία' : 'No location')
                                          : pet.location,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (pet.age.trim().isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryTeal.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    pet.age,
                                    style: const TextStyle(
                                      color: AppTheme.primaryTeal,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

enum _AdoptionMenuAction { edit, markAdopted, delete }
