import 'package:flutter/material.dart';

import '../data/pet_repository.dart';
import '../models/pet.dart';
import '../widgets/pet_image_widget.dart';
import 'add_pet_screen.dart';
import 'pet_profile_screen.dart';

class ViewPetsScreen extends StatefulWidget {
  final PetRepository repo;

  const ViewPetsScreen({super.key, required this.repo});

  @override
  State<ViewPetsScreen> createState() => _ViewPetsScreenState();
}

class _ViewPetsScreenState extends State<ViewPetsScreen> {
  List<Pet> pets = [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      pets = widget.repo.getAll();
    });
  }

  Future<void> _delete(String id) async {
    await widget.repo.deletePet(id);
    _refresh();
  }

  Future<void> _openPetProfile(Pet p) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PetProfileScreen(
          repo: widget.repo,
          petId: p.id,
        ),
      ),
    );
    _refresh();
  }

  Future<void> _openEditPet(Pet p) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddPetScreen(
          repo: widget.repo,
          petToEdit: p,
        ),
      ),
    );

    if (result == true) {
      _refresh();
    }
  }

  Future<void> _openAddPet() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddPetScreen(repo: widget.repo),
      ),
    );

    if (result == true) {
      _refresh();
    }
  }

  void _openMenu(Pet p) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.edit_rounded),
                  title: const Text('Edit'),
                  onTap: () async {
                    Navigator.pop(context);
                    await _openEditPet(p);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded),
                  title: const Text('Delete'),
                  onTap: () async {
                    Navigator.pop(context);
                    await _delete(p.id);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.close_rounded),
                  title: const Text('Cancel'),
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _petCard(Pet p) {
    final details = p.age == null || p.age!.trim().isEmpty
        ? p.type
        : '${p.type} • ${p.age}';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => _openPetProfile(p),
        child: Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              PetImageWidget(
                photoUrl: p.photoUrl,
                photoBase64: p.photoBase64,
                width: 88,
                height: 88,
                fit: BoxFit.cover,
                borderRadius: BorderRadius.circular(18),
                placeholder: Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE9F4F3),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.pets_rounded,
                    size: 34,
                    color: Color(0xFF0F7C82),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.2,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      details,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(
                  Icons.more_vert_rounded,
                  color: Color(0xFF374151),
                ),
                onPressed: () => _openMenu(p),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.pets_rounded,
              size: 52,
              color: Color(0xFF0F7C82),
            ),
            const SizedBox(height: 12),
            const Text(
              'No pets yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add your first pet to start managing their profiles.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: _openAddPet,
              icon: const Icon(Icons.add),
              label: const Text('Add your first pet'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F7C82),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F9),
      appBar: AppBar(
        title: const Text('My Pets'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddPet,
        backgroundColor: const Color(0xFF0F7C82),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Pet'),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
        child: pets.isEmpty
            ? _emptyState()
            : ListView.builder(
                itemCount: pets.length,
                itemBuilder: (context, i) => _petCard(pets[i]),
              ),
      ),
    );
  }
}
