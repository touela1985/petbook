import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/community_repository.dart';
import '../models/community_place.dart';
import '../models/community_tip.dart';
import '../services/storage_service.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  final CommunityRepository _repository = CommunityRepository();

  int _selectedTabIndex = 0;
  bool _isLoading = true;

  List<CommunityPlace> _places = [];
  List<CommunityTip> _tips = [];

  bool get _isPlacesTab => _selectedTabIndex == 0;

  @override
  void initState() {
    super.initState();
    _loadCommunityData();
  }

  Future<void> _loadCommunityData() async {
    await _repository.purgeLegacyRecords();

    final places = await _repository.getPlaces();
    final tips = await _repository.getTips();

    if (!mounted) return;

    setState(() {
      _places = places;
      _tips = tips;
      _isLoading = false;
    });
  }

  Future<void> _openAddPlace() async {
    final result = await Navigator.push<CommunityPlace>(
      context,
      MaterialPageRoute(
        builder: (_) => const AddPlaceScreen(),
      ),
    );

    if (result == null) return;

    await _repository.addPlace(result);
    await _loadCommunityData();

    if (!mounted) return;
    setState(() {
      _selectedTabIndex = 0;
    });
  }

  Future<void> _openAddTip() async {
    final result = await Navigator.push<CommunityTip>(
      context,
      MaterialPageRoute(
        builder: (_) => const AddTipScreen(),
      ),
    );

    if (result == null) return;

    await _repository.addTip(result);
    await _loadCommunityData();

    if (!mounted) return;
    setState(() {
      _selectedTabIndex = 1;
    });
  }

  Future<void> _editPlace(CommunityPlace place) async {
    final result = await Navigator.push<CommunityPlace>(
      context,
      MaterialPageRoute(
        builder: (_) => AddPlaceScreen(existingPlace: place),
      ),
    );

    if (result == null) return;

    await _repository.updatePlace(result);
    await _loadCommunityData();
  }

  Future<void> _editTip(CommunityTip tip) async {
    final result = await Navigator.push<CommunityTip>(
      context,
      MaterialPageRoute(
        builder: (_) => AddTipScreen(existingTip: tip),
      ),
    );

    if (result == null) return;

    await _repository.updateTip(result);
    await _loadCommunityData();
  }

  Future<void> _deletePlace(CommunityPlace place, bool isEl) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: Text(isEl ? 'Διαγραφή μέρους' : 'Delete place'),
          content: Text(
            isEl
                ? 'Θέλεις σίγουρα να διαγράψεις αυτό το μέρος;'
                : 'Are you sure you want to delete this place?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(isEl ? 'Άκυρο' : 'Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(isEl ? 'Διαγραφή' : 'Delete'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    await _repository.deletePlace(place.id);
    await _loadCommunityData();
  }

  Future<void> _deleteTip(CommunityTip tip, bool isEl) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: Text(isEl ? 'Διαγραφή συμβουλής' : 'Delete tip'),
          content: Text(
            isEl
                ? 'Θέλεις σίγουρα να διαγράψεις αυτή τη συμβουλή;'
                : 'Are you sure you want to delete this tip?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(isEl ? 'Άκυρο' : 'Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(isEl ? 'Διαγραφή' : 'Delete'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    await _repository.deleteTip(tip.id);
    await _loadCommunityData();
  }

  @override
  Widget build(BuildContext context) {
    final isEl = Localizations.localeOf(context).languageCode == 'el';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F3F1),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _CommunityTabs(
                      selectedIndex: _selectedTabIndex,
                      onChanged: (index) {
                        setState(() {
                          _selectedTabIndex = index;
                        });
                      },
                      isEl: isEl,
                    ),
                    const SizedBox(height: 22),
                    if (_isPlacesTab)
                      _PlacesSection(
                        isEl: isEl,
                        onAddTap: _openAddPlace,
                        places: _places,
                        onEdit: _editPlace,
                        onDelete: (place) => _deletePlace(place, isEl),
                      )
                    else
                      _TipsSection(
                        isEl: isEl,
                        onAddTap: _openAddTip,
                        tips: _tips,
                        onEdit: _editTip,
                        onDelete: (tip) => _deleteTip(tip, isEl),
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _CommunityTabs extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final bool isEl;

  const _CommunityTabs({
    required this.selectedIndex,
    required this.onChanged,
    required this.isEl,
  });

  static const Color _primaryTeal = Color(0xFF0F7C82);
  static const Color _surface = Colors.white;
  static const Color _textSecondary = Color(0xFF6B7280);
  static const Color _border = Color(0xFFE5E7EB);

  @override
  Widget build(BuildContext context) {
    Widget tab({
      required int index,
      required String label,
    }) {
      final isSelected = selectedIndex == index;

      return Expanded(
        child: GestureDetector(
          onTap: () => onChanged(index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: isSelected ? _primaryTeal : _surface,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: isSelected ? _primaryTeal : _border,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: _primaryTeal.withOpacity(0.18),
                        blurRadius: 12,
                        offset: const Offset(0, 5),
                      ),
                    ]
                  : [],
            ),
            child: Center(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isSelected ? Colors.white : _textSecondary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        tab(
          index: 0,
          label: isEl ? 'Κοινότητα' : 'Community',
        ),
        const SizedBox(width: 10),
        tab(
          index: 1,
          label: isEl ? 'Συμβουλές' : 'Community Tips',
        ),
      ],
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;

  const SectionHeader({
    super.key,
    required this.title,
  });

  static const Color _textPrimary = Color(0xFF1F2937);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        color: _textPrimary,
      ),
    );
  }
}

class _PlacesSection extends StatelessWidget {
  final bool isEl;
  final VoidCallback onAddTap;
  final List<CommunityPlace> places;
  final Future<void> Function(CommunityPlace place) onEdit;
  final Future<void> Function(CommunityPlace place) onDelete;

  const _PlacesSection({
    required this.isEl,
    required this.onAddTap,
    required this.places,
    required this.onEdit,
    required this.onDelete,
  });

  static const Color _textPrimary = Color(0xFF1F2937);
  static const Color _textSecondary = Color(0xFF6B7280);
  static const Color _border = Color(0xFFE5E7EB);
  static const Color _softOrange = Color(0xFFF9E7D4);
  static const Color _orange = Color(0xFFE38B2C);
  static const Color _primaryTeal = Color(0xFF0F7C82);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: isEl ? 'Φιλικά μέρη' : 'Pet-Friendly Places',
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF6ED),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: _border),
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
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 58,
                    width: 58,
                    decoration: BoxDecoration(
                      color: _softOrange,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(
                      Icons.place_rounded,
                      color: _orange,
                      size: 30,
                    ),
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: onAddTap,
                    icon: const Icon(Icons.add_rounded),
                    label: Text(isEl ? 'Προσθήκη' : 'Add Place'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryTeal,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                isEl
                    ? 'Μοιράσου ένα pet-friendly μέρος'
                    : 'Share a pet-friendly place',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: _textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isEl
                    ? 'Πρόσθεσε πάρκα, παραλίες, καφέ ή ασφαλή σημεία για κατοικίδια.'
                    : 'Add parks, beaches, cafés or safe outdoor spots for pets.',
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.4,
                  color: _textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (places.isEmpty)
          const _EmptyStateCard(
            icon: Icons.pets_rounded,
            titleEl: 'Δεν υπάρχουν μέρη ακόμα',
            titleEn: 'No places added yet',
            subtitleEl:
                'Όταν οι χρήστες αρχίσουν να προσθέτουν pet-friendly spots, θα εμφανίζονται εδώ.',
            subtitleEn:
                'When users start adding pet-friendly spots, they will appear here.',
          )
        else
          Builder(
            builder: (context) {
              final currentUid = FirebaseAuth.instance.currentUser?.uid;
              return Column(
                children: places
                    .map(
                      (place) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: PlaceCard(
                          place: place,
                          isEl: isEl,
                          isOwner: currentUid != null && currentUid == place.userId,
                          onEdit: () => onEdit(place),
                          onDelete: () => onDelete(place),
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
      ],
    );
  }
}

class _TipsSection extends StatelessWidget {
  final bool isEl;
  final VoidCallback onAddTap;
  final List<CommunityTip> tips;
  final Future<void> Function(CommunityTip tip) onEdit;
  final Future<void> Function(CommunityTip tip) onDelete;

  const _TipsSection({
    required this.isEl,
    required this.onAddTap,
    required this.tips,
    required this.onEdit,
    required this.onDelete,
  });

  static const Color _textPrimary = Color(0xFF1F2937);
  static const Color _textSecondary = Color(0xFF6B7280);
  static const Color _border = Color(0xFFE5E7EB);
  static const Color _softTeal = Color(0xFFE9F4F3);
  static const Color _primaryTeal = Color(0xFF0F7C82);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: isEl ? 'Συμβουλές κοινότητας' : 'Community Tips'),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFFF4FBFA),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: _border),
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
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 58,
                    width: 58,
                    decoration: BoxDecoration(
                      color: _softTeal,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(
                      Icons.lightbulb_rounded,
                      color: _primaryTeal,
                      size: 30,
                    ),
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: onAddTap,
                    icon: const Icon(Icons.add_rounded),
                    label: Text(isEl ? 'Προσθήκη' : 'Add Tip'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryTeal,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                isEl ? 'Μοιράσου ένα χρήσιμο tip' : 'Share a helpful tip',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: _textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isEl
                    ? 'Γράψε κάτι χρήσιμο για άλλους pet owners σχετικά με βόλτες, φροντίδα ή καθημερινές συμβουλές.'
                    : 'Write something helpful for other pet owners about walks, care or daily routines.',
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.4,
                  color: _textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (tips.isEmpty)
          const _EmptyStateCard(
            icon: Icons.chat_bubble_outline_rounded,
            titleEl: 'Δεν υπάρχουν tips ακόμα',
            titleEn: 'No tips yet',
            subtitleEl:
                'Τα tips που θα μοιράζονται οι χρήστες θα εμφανίζονται εδώ.',
            subtitleEn: 'Tips shared by users will appear here.',
          )
        else
          Builder(
            builder: (context) {
              final currentUid = FirebaseAuth.instance.currentUser?.uid;
              return Column(
                children: tips
                    .map(
                      (tip) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: TipCard(
                          tip: tip,
                          isEl: isEl,
                          isOwner: currentUid != null && currentUid == tip.userId,
                          onEdit: () => onEdit(tip),
                          onDelete: () => onDelete(tip),
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
      ],
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  final IconData icon;
  final String titleEl;
  final String titleEn;
  final String subtitleEl;
  final String subtitleEn;

  const _EmptyStateCard({
    required this.icon,
    required this.titleEl,
    required this.titleEn,
    required this.subtitleEl,
    required this.subtitleEn,
  });

  static const Color _surface = Colors.white;
  static const Color _textPrimary = Color(0xFF1F2937);
  static const Color _textSecondary = Color(0xFF6B7280);
  static const Color _border = Color(0xFFE5E7EB);
  static const Color _softTeal = Color(0xFFE9F4F3);
  static const Color _primaryTeal = Color(0xFF0F7C82);

  @override
  Widget build(BuildContext context) {
    final isEl = Localizations.localeOf(context).languageCode == 'el';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          Container(
            height: 58,
            width: 58,
            decoration: BoxDecoration(
              color: _softTeal,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              icon,
              color: _primaryTeal,
              size: 28,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            isEl ? titleEl : titleEn,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isEl ? subtitleEl : subtitleEn,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              height: 1.4,
              color: _textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class PlaceCard extends StatelessWidget {
  final CommunityPlace place;
  final bool isEl;
  final bool isOwner;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const PlaceCard({
    super.key,
    required this.place,
    required this.isEl,
    required this.isOwner,
    required this.onEdit,
    required this.onDelete,
  });

  static const Color _surface = Colors.white;
  static const Color _textPrimary = Color(0xFF1F2937);
  static const Color _textSecondary = Color(0xFF6B7280);
  static const Color _border = Color(0xFFE5E7EB);
  static const Color _primaryTeal = Color(0xFF0F7C82);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PlaceDetailsScreen(place: place),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if ((place.imageUrl ?? place.imagePath) != null &&
                  (place.imageUrl ?? place.imagePath)!.trim().isNotEmpty)
                GestureDetector(
                  onTap: () => openFullImage(
                      context, (place.imageUrl ?? place.imagePath)!),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: SizedBox(
                      width: 112,
                      height: 112,
                      child: () {
                        final src = (place.imageUrl ?? place.imagePath)!;
                        final isUrl =
                            kIsWeb || src.startsWith('http');
                        return isUrl
                            ? Image.network(
                                src,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: const Color(0xFFE9F4F3),
                                  alignment: Alignment.center,
                                  child: const Icon(
                                    Icons.image_not_supported_outlined,
                                    size: 28,
                                    color: _primaryTeal,
                                  ),
                                ),
                              )
                            : Image.file(
                                File(src),
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: const Color(0xFFE9F4F3),
                                  alignment: Alignment.center,
                                  child: const Icon(
                                    Icons.image_not_supported_outlined,
                                    size: 28,
                                    color: _primaryTeal,
                                  ),
                                ),
                              );
                      }(),
                    ),
                  ),
                ),
              if ((place.imageUrl ?? place.imagePath) != null &&
                  (place.imageUrl ?? place.imagePath)!.trim().isNotEmpty)
                const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            place.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: _textPrimary,
                            ),
                          ),
                        ),
                        if (isOwner)
                          PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'edit') {
                                onEdit();
                              } else if (value == 'delete') {
                                onDelete();
                              }
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'edit',
                                child: Text(isEl ? 'Επεξεργασία' : 'Edit'),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text(isEl ? 'Διαγραφή' : 'Delete'),
                              ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      place.description,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.3,
                        color: _textSecondary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F5),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      PlaceDetailsScreen(place: place),
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              child: Text(
                                isEl ? 'Λεπτομέρειες' : 'View Details',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                  color: _primaryTeal,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaceImage extends StatelessWidget {
  final String? imagePath;

  const _PlaceImage({required this.imagePath});

  static const Color _softTeal = Color(0xFFE9F4F3);
  static const Color _primaryTeal = Color(0xFF0F7C82);

  @override
  Widget build(BuildContext context) {
    final hasImage = imagePath != null && imagePath!.trim().isNotEmpty;

    Widget placeholder() {
      return Container(
        height: 112,
        width: 112,
        decoration: BoxDecoration(
          color: _softTeal,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Icon(
          Icons.park_rounded,
          color: _primaryTeal,
          size: 36,
        ),
      );
    }

    if (!hasImage) return placeholder();

    final child = kIsWeb
        ? Image.network(
            imagePath!,
            height: 112,
            width: 112,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => placeholder(),
          )
        : Image.file(
            File(imagePath!),
            height: 112,
            width: 112,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => placeholder(),
          );

    return GestureDetector(
      onTap: () => openFullImage(context, imagePath!),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: child,
      ),
    );
  }
}

class TipCard extends StatelessWidget {
  final CommunityTip tip;
  final bool isEl;
  final bool isOwner;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const TipCard({
    super.key,
    required this.tip,
    required this.isEl,
    required this.isOwner,
    required this.onEdit,
    required this.onDelete,
  });

  static const Color _surface = Colors.white;
  static const Color _textPrimary = Color(0xFF1F2937);
  static const Color _border = Color(0xFFE5E7EB);
  static const Color _primaryTeal = Color(0xFF0F7C82);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TipDetailsScreen(tip: tip),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if ((tip.imageUrl ?? tip.imagePath) != null &&
                  (tip.imageUrl ?? tip.imagePath)!.trim().isNotEmpty)
                GestureDetector(
                  onTap: () => openFullImage(
                      context, (tip.imageUrl ?? tip.imagePath)!),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: SizedBox(
                      width: 108,
                      height: 108,
                      child: () {
                        final src = (tip.imageUrl ?? tip.imagePath)!;
                        final isUrl = kIsWeb || src.startsWith('http');
                        return isUrl
                            ? Image.network(src, fit: BoxFit.cover)
                            : Image.file(File(src), fit: BoxFit.cover);
                      }(),
                    ),
                  ),
                ),
              if ((tip.imageUrl ?? tip.imagePath) != null &&
                  (tip.imageUrl ?? tip.imagePath)!.trim().isNotEmpty)
                const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const CircleAvatar(
                          radius: 18,
                          backgroundColor: Color(0xFFE9F4F3),
                          child: Icon(
                            Icons.person_rounded,
                            size: 18,
                            color: _primaryTeal,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            tip.author.isEmpty
                                ? (isEl ? 'Ανώνυμος χρήστης' : 'Anonymous user')
                                : tip.author,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: _textPrimary,
                            ),
                          ),
                        ),
                        if (isOwner)
                          PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'edit') {
                                onEdit();
                              } else if (value == 'delete') {
                                onDelete();
                              }
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'edit',
                                child: Text(isEl ? 'Επεξεργασία' : 'Edit'),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text(isEl ? 'Διαγραφή' : 'Delete'),
                              ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      tip.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: _primaryTeal,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      tip.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: _textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F5),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => TipDetailsScreen(tip: tip),
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              child: Text(
                                isEl ? 'Λεπτομέρειες' : 'View Details',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                  color: _primaryTeal,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AddPlaceScreen extends StatefulWidget {
  final CommunityPlace? existingPlace;

  const AddPlaceScreen({
    super.key,
    this.existingPlace,
  });

  @override
  State<AddPlaceScreen> createState() => _AddPlaceScreenState();
}

class _AddPlaceScreenState extends State<AddPlaceScreen> {
  static const Color _background = Color(0xFFF7F9F9);
  static const Color _primaryTeal = Color(0xFF0F7C82);

  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _descriptionCtrl = TextEditingController();

  final ImagePicker _picker = ImagePicker();
  String? _imagePath;
  XFile? _pickedImage;

  bool get _isEditing => widget.existingPlace != null;

  @override
  void initState() {
    super.initState();
    final place = widget.existingPlace;
    if (place != null) {
      _titleCtrl.text = place.title;
      _descriptionCtrl.text = place.description;
      _imagePath = place.imagePath;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null) return;

    setState(() {
      _imagePath = picked.path;
      _pickedImage = picked;
    });
  }

  Future<void> _save(bool isEl) async {
    if (_titleCtrl.text.trim().isEmpty ||
        _descriptionCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEl
                ? 'Συμπλήρωσε τίτλο και περιγραφή.'
                : 'Please fill title and description.',
          ),
        ),
      );
      return;
    }

    var result = _isEditing
        ? widget.existingPlace!.copyWith(
            title: _titleCtrl.text.trim(),
            description: _descriptionCtrl.text.trim(),
            imagePath: _imagePath,
          )
        : CommunityPlace.create(
            title: _titleCtrl.text.trim(),
            description: _descriptionCtrl.text.trim(),
            imagePath: _imagePath,
            userId: FirebaseAuth.instance.currentUser?.uid,
          );

    if (_pickedImage != null) {
      final bytes = await _pickedImage!.readAsBytes();
      final url = await StorageService.uploadCommunityImage(bytes, result.id);
      if (url != null) {
        result = result.copyWith(imageUrl: url);
      }
    }

    if (!mounted) return;
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final isEl = Localizations.localeOf(context).languageCode == 'el';

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        title: Text(
          _isEditing
              ? (isEl ? 'Επεξεργασία μέρους' : 'Edit Place')
              : (isEl ? 'Προσθήκη μέρους' : 'Add Place'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _ImagePickerCard(
              imagePath: _imagePath,
              icon: Icons.photo_library_rounded,
              title: isEl ? 'Φωτογραφία μέρους' : 'Place photo',
              subtitle: isEl
                  ? 'Πρόσθεσε φωτογραφία του pet-friendly σημείου.'
                  : 'Add a photo for this pet-friendly place.',
              buttonLabel: isEl ? 'Επιλογή φωτογραφίας' : 'Choose photo',
              onTap: _pickImage,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _titleCtrl,
              decoration: InputDecoration(
                labelText: isEl ? 'Τίτλος' : 'Title',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionCtrl,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: isEl ? 'Περιγραφή' : 'Description',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _save(isEl),
                icon: const Icon(Icons.save_rounded),
                label: Text(
                  _isEditing
                      ? (isEl ? 'Αποθήκευση αλλαγών' : 'Save Changes')
                      : (isEl ? 'Αποθήκευση μέρους' : 'Save Place'),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryTeal,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AddTipScreen extends StatefulWidget {
  final CommunityTip? existingTip;

  const AddTipScreen({
    super.key,
    this.existingTip,
  });

  @override
  State<AddTipScreen> createState() => _AddTipScreenState();
}

class _AddTipScreenState extends State<AddTipScreen> {
  static const Color _background = Color(0xFFF5F3F1);
  static const Color _primaryTeal = Color(0xFF0F7C82);

  final TextEditingController _authorCtrl = TextEditingController();
  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _bodyCtrl = TextEditingController();

  final ImagePicker _picker = ImagePicker();
  String? _imagePath;
  XFile? _pickedImage;

  bool get _isEditing => widget.existingTip != null;

  @override
  void initState() {
    super.initState();
    final tip = widget.existingTip;
    if (tip != null) {
      _authorCtrl.text = tip.author;
      _titleCtrl.text = tip.title;
      _bodyCtrl.text = tip.body;
      _imagePath = tip.imagePath;
    }
  }

  @override
  void dispose() {
    _authorCtrl.dispose();
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null) return;

    setState(() {
      _imagePath = picked.path;
      _pickedImage = picked;
    });
  }

  Future<void> _save(bool isEl) async {
    if (_titleCtrl.text.trim().isEmpty || _bodyCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEl
                ? 'Συμπλήρωσε τίτλο και κείμενο.'
                : 'Please fill title and body.',
          ),
        ),
      );
      return;
    }

    var result = _isEditing
        ? widget.existingTip!.copyWith(
            author: _authorCtrl.text.trim(),
            title: _titleCtrl.text.trim(),
            body: _bodyCtrl.text.trim(),
            imagePath: _imagePath,
          )
        : CommunityTip.create(
            author: _authorCtrl.text.trim(),
            title: _titleCtrl.text.trim(),
            body: _bodyCtrl.text.trim(),
            imagePath: _imagePath,
            userId: FirebaseAuth.instance.currentUser?.uid,
          );

    if (_pickedImage != null) {
      final bytes = await _pickedImage!.readAsBytes();
      final url = await StorageService.uploadCommunityImage(bytes, result.id);
      if (url != null) {
        result = result.copyWith(imageUrl: url);
      }
    }

    if (!mounted) return;
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final isEl = Localizations.localeOf(context).languageCode == 'el';

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        title: Text(
          _isEditing
              ? (isEl ? 'Επεξεργασία tip' : 'Edit Tip')
              : (isEl ? 'Προσθήκη tip' : 'Add Tip'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _ImagePickerCard(
              imagePath: _imagePath,
              icon: Icons.image_rounded,
              title: isEl ? 'Εικόνα tip (προαιρετική)' : 'Tip image (optional)',
              subtitle: isEl
                  ? 'Μπορείς να προσθέσεις εικόνα αν θέλεις.'
                  : 'You can add an image if you want.',
              buttonLabel: isEl ? 'Επιλογή εικόνας' : 'Choose image',
              onTap: _pickImage,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _authorCtrl,
              decoration: InputDecoration(
                labelText:
                    isEl ? 'Όνομα χρήστη (προαιρετικό)' : 'Author (optional)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _titleCtrl,
              decoration: InputDecoration(
                labelText: isEl ? 'Τίτλος tip' : 'Tip title',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bodyCtrl,
              maxLines: 6,
              decoration: InputDecoration(
                labelText: isEl ? 'Κείμενο' : 'Body',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _save(isEl),
                icon: const Icon(Icons.save_rounded),
                label: Text(
                  _isEditing
                      ? (isEl ? 'Αποθήκευση αλλαγών' : 'Save Changes')
                      : (isEl ? 'Αποθήκευση tip' : 'Save Tip'),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryTeal,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImagePickerCard extends StatelessWidget {
  final String? imagePath;
  final IconData icon;
  final String title;
  final String subtitle;
  final String buttonLabel;
  final VoidCallback onTap;

  const _ImagePickerCard({
    required this.imagePath,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.onTap,
  });

  static const Color _surface = Colors.white;
  static const Color _border = Color(0xFFE5E7EB);
  static const Color _softTeal = Color(0xFFE9F4F3);
  static const Color _primaryTeal = Color(0xFF0F7C82);
  static const Color _textPrimary = Color(0xFF1F2937);
  static const Color _textSecondary = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    final hasImage = imagePath != null && imagePath!.trim().isNotEmpty;

    Widget preview() {
      if (!hasImage) {
        return Container(
          height: 86,
          width: 86,
          decoration: BoxDecoration(
            color: _softTeal,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(
            icon,
            color: _primaryTeal,
            size: 34,
          ),
        );
      }

      final child = kIsWeb
          ? Image.network(
              imagePath!,
              height: 86,
              width: 86,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                height: 86,
                width: 86,
                decoration: BoxDecoration(
                  color: _softTeal,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  icon,
                  color: _primaryTeal,
                  size: 34,
                ),
              ),
            )
          : Image.file(
              File(imagePath!),
              height: 86,
              width: 86,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                height: 86,
                width: 86,
                decoration: BoxDecoration(
                  color: _softTeal,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  icon,
                  color: _primaryTeal,
                  size: 34,
                ),
              ),
            );

      return GestureDetector(
        onTap: () => openFullImage(context, imagePath!),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: child,
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          preview(),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: _textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: _textSecondary,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: onTap,
                  icon: const Icon(Icons.photo_library_rounded),
                  label: Text(buttonLabel),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryTeal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
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

class PlaceDetailsScreen extends StatelessWidget {
  final CommunityPlace place;

  const PlaceDetailsScreen({
    super.key,
    required this.place,
  });

  static const Color _background = Color(0xFFF5F3F1);
  static const Color _surface = Colors.white;
  static const Color _border = Color(0xFFE5E7EB);
  static const Color _textPrimary = Color(0xFF1F2937);
  static const Color _textSecondary = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    final isEl = Localizations.localeOf(context).languageCode == 'el';

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        title: Text(isEl ? 'Λεπτομέρειες μέρους' : 'Place Details'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PlaceDetailsImage(imagePath: place.imageUrl ?? place.imagePath),
              const SizedBox(height: 16),
              Text(
                place.title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: _textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                place.description,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.45,
                  color: _textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaceDetailsImage extends StatelessWidget {
  final String? imagePath;

  const _PlaceDetailsImage({required this.imagePath});

  static bool _isUrl(String path) => path.startsWith('http');

  @override
  Widget build(BuildContext context) {
    if (imagePath == null || imagePath!.trim().isEmpty) {
      return Container(
        height: 210,
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFFE9F4F3),
          borderRadius: BorderRadius.circular(22),
        ),
        child: const Center(
          child: Icon(
            Icons.park_rounded,
            size: 46,
            color: Color(0xFF0F7C82),
          ),
        ),
      );
    }

    final child = (kIsWeb || _isUrl(imagePath!))
        ? Image.network(
            imagePath!,
            height: 210,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              height: 210,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFE9F4F3),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Center(
                child: Icon(
                  Icons.image_not_supported_outlined,
                  size: 46,
                  color: Color(0xFF0F7C82),
                ),
              ),
            ),
          )
        : Image.file(
            File(imagePath!),
            height: 210,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              height: 210,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFE9F4F3),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Center(
                child: Icon(
                  Icons.image_not_supported_outlined,
                  size: 46,
                  color: Color(0xFF0F7C82),
                ),
              ),
            ),
          );

    return GestureDetector(
      onTap: () => openFullImage(context, imagePath!),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: child,
      ),
    );
  }
}

class TipDetailsScreen extends StatelessWidget {
  final CommunityTip tip;

  const TipDetailsScreen({
    super.key,
    required this.tip,
  });

  static const Color _background = Color(0xFFF5F3F1);
  static const Color _surface = Colors.white;
  static const Color _border = Color(0xFFE5E7EB);
  static const Color _textPrimary = Color(0xFF1F2937);
  static const Color _textSecondary = Color(0xFF6B7280);
  static const Color _primaryTeal = Color(0xFF0F7C82);

  @override
  Widget build(BuildContext context) {
    final isEl = Localizations.localeOf(context).languageCode == 'el';

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        title: const Text('Tip'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if ((tip.imageUrl ?? tip.imagePath) != null &&
                  (tip.imageUrl ?? tip.imagePath)!.trim().isNotEmpty)
                GestureDetector(
                  onTap: () => openFullImage(
                      context, (tip.imageUrl ?? tip.imagePath)!),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: _TipDetailsImage(
                        imagePath: (tip.imageUrl ?? tip.imagePath)!),
                  ),
                ),
              if ((tip.imageUrl ?? tip.imagePath) != null &&
                  (tip.imageUrl ?? tip.imagePath)!.trim().isNotEmpty)
                const SizedBox(height: 16),
              Text(
                tip.title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: _primaryTeal,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                tip.author.isEmpty
                    ? (isEl ? 'Ανώνυμος χρήστης' : 'Anonymous user')
                    : tip.author,
                style: const TextStyle(
                  fontSize: 14,
                  color: _textSecondary,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                tip.body,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: _textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TipDetailsImage extends StatelessWidget {
  final String imagePath;

  const _TipDetailsImage({required this.imagePath});

  static bool _isUrl(String path) => path.startsWith('http');

  @override
  Widget build(BuildContext context) {
    if (kIsWeb || _isUrl(imagePath)) {
      return Image.network(
        imagePath,
        height: 220,
        width: double.infinity,
        fit: BoxFit.cover,
      );
    }

    return Image.file(
      File(imagePath),
      height: 220,
      width: double.infinity,
      fit: BoxFit.cover,
    );
  }
}

bool _isUrlPath(String path) => path.startsWith('http');

void openFullImage(BuildContext context, String imagePath) {
  showDialog(
    context: context,
    builder: (_) {
      final child = (kIsWeb || _isUrlPath(imagePath))
          ? Image.network(
              imagePath,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Center(
                child: Icon(
                  Icons.broken_image_outlined,
                  color: Colors.white70,
                  size: 48,
                ),
              ),
            )
          : Image.file(
              File(imagePath),
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Center(
                child: Icon(
                  Icons.broken_image_outlined,
                  color: Colors.white70,
                  size: 48,
                ),
              ),
            );

      return Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 4,
                child: Center(child: child),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}
