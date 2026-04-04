import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../data/found_pet_report_repository.dart';
import '../data/lost_pet_report_repository.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

class ProfileScreen extends StatefulWidget {
  final Future<void> Function(Locale? locale)? onChangeLocale;
  final Locale? currentLocale;

  const ProfileScreen({
    super.key,
    this.onChangeLocale,
    this.currentLocale,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final LostPetReportRepository _lostRepo = LostPetReportRepository();
  final FoundPetReportRepository _foundRepo = FoundPetReportRepository();
  final ImagePicker _picker = ImagePicker();

  String _name = '';
  String _location = '';
  String _phone = '';
  String _email = '';
  String? _photoBase64;
  String? _photoUrl;
  bool _photoUrlFailed = false;
  String _preferredContact = 'all';
  int _lostCount = 0;
  int _foundCount = 0;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final lost = await _lostRepo.getReports();
    final found = await _foundRepo.getReports();

    if (!mounted) return;

    setState(() {
      _name = prefs.getString('profile_name') ?? '';
      _location = prefs.getString('profile_location') ?? '';
      _phone = prefs.getString('profile_phone') ?? '';
      _email = prefs.getString('profile_email') ?? '';
      _photoBase64 = prefs.getString('profile_photo');
      _photoUrl = prefs.getString('profile_photo_url');
      _preferredContact =
          prefs.getString('profile_preferred_contact') ?? 'all';
      _lostCount = lost.length;
      _foundCount = found.length;
    });
  }

  Future<void> _saveProfileFields() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('profile_name', _name);
    await prefs.setString('profile_location', _location);
    await prefs.setString('profile_phone', _phone);
    await prefs.setString('profile_email', _email);
    await prefs.setString('profile_preferred_contact', _preferredContact);

    if (_photoBase64 != null && _photoBase64!.isNotEmpty) {
      await prefs.setString('profile_photo', _photoBase64!);
    } else {
      await prefs.remove('profile_photo');
    }
  }

  Future<void> _pickImage() async {
    final img = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (img == null) return;

    final bytes = await img.readAsBytes();

    if (!mounted) return;

    // Upload to Firebase Storage
    final prefs = await SharedPreferences.getInstance();
    String? profileId = prefs.getString('profile_id');
    if (profileId == null) {
      profileId = const Uuid().v4();
      await prefs.setString('profile_id', profileId);
    }
    final url = await StorageService.uploadProfileImage(bytes, profileId);
    if (url != null) {
      await prefs.setString('profile_photo_url', url);
    }

    if (!mounted) return;

    setState(() {
      _photoBase64 = base64Encode(bytes);
      if (url != null) {
        _photoUrl = url;
        _photoUrlFailed = false;
      }
    });

    await _saveProfileFields();
  }

  void _openEditProfileDialog(bool isEl) {
    final nameCtrl = TextEditingController(text: _name);
    final locationCtrl = TextEditingController(text: _location);

    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          backgroundColor: Colors.white,
          elevation: 6,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
          contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
          actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          title: Text(
            isEl ? 'Επεξεργασία προφίλ' : 'Edit profile',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: isEl ? 'Όνομα' : 'Name',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: locationCtrl,
                decoration: InputDecoration(
                  labelText: isEl ? 'Τοποθεσία' : 'Location',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                isEl ? 'Άκυρο' : 'Cancel',
                style: const TextStyle(
                  color: AppTheme.primaryTeal,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                setState(() {
                  _name = nameCtrl.text.trim();
                  _location = locationCtrl.text.trim();
                });
                await _saveProfileFields();
                if (mounted) Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryTeal,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(isEl ? 'Αποθήκευση' : 'Save'),
            ),
          ],
        );
      },
    );
  }

  void _openNameDialog(bool isEl) {
    final nameCtrl = TextEditingController(text: _name);

    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          backgroundColor: Colors.white,
          elevation: 6,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
          contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
          actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          title: Text(
            isEl ? 'Όνομα' : 'Name',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          content: TextField(
            controller: nameCtrl,
            decoration: InputDecoration(
              labelText: isEl ? 'Όνομα' : 'Name',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                isEl ? 'Άκυρο' : 'Cancel',
                style: const TextStyle(
                  color: AppTheme.primaryTeal,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                setState(() {
                  _name = nameCtrl.text.trim();
                });
                await _saveProfileFields();
                if (mounted) Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryTeal,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(isEl ? 'Αποθήκευση' : 'Save'),
            ),
          ],
        );
      },
    );
  }

  void _openLocationDialog(bool isEl) {
    final locationCtrl = TextEditingController(text: _location);

    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          backgroundColor: Colors.white,
          elevation: 6,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
          contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
          actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          title: Text(
            isEl ? 'Τοποθεσία' : 'Location',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          content: TextField(
            controller: locationCtrl,
            decoration: InputDecoration(
              labelText: isEl ? 'Τοποθεσία' : 'Location',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                isEl ? 'Άκυρο' : 'Cancel',
                style: const TextStyle(
                  color: AppTheme.primaryTeal,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                setState(() {
                  _location = locationCtrl.text.trim();
                });
                await _saveProfileFields();
                if (mounted) Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryTeal,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(isEl ? 'Αποθήκευση' : 'Save'),
            ),
          ],
        );
      },
    );
  }

  void _openContactDialog(bool isEl) {
    final phoneCtrl = TextEditingController(text: _phone);
    final emailCtrl = TextEditingController(text: _email);

    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          backgroundColor: const Color(0xFFF7FAF9),
          elevation: 6,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
          contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
          actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          title: Text(
            isEl ? 'Στοιχεία επικοινωνίας' : 'Contact Info',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: isEl ? 'Τηλέφωνο' : 'Phone',
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email',
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                isEl ? 'Άκυρο' : 'Cancel',
                style: const TextStyle(
                  color: AppTheme.primaryTeal,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                setState(() {
                  _phone = phoneCtrl.text.trim();
                  _email = emailCtrl.text.trim();
                });
                await _saveProfileFields();
                if (mounted) Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryTeal,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(isEl ? 'Αποθήκευση' : 'Save'),
            ),
          ],
        );
      },
    );
  }

  void _openPreferredContactDialog(bool isEl) {
    showDialog(
      context: context,
      builder: (_) {
        String tempValue = _preferredContact;

        return StatefulBuilder(
          builder: (context, setLocalState) {
            Widget optionTile({
              required String value,
              required String label,
            }) {
              final isSelected = tempValue == value;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFFE9F4F3)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: RadioListTile<String>(
                  value: value,
                  groupValue: tempValue,
                  activeColor: AppTheme.primaryTeal,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  title: Text(
                    label,
                    style: TextStyle(
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  onChanged: (newValue) {
                    if (newValue == null) return;
                    setLocalState(() => tempValue = newValue);
                  },
                ),
              );
            }

            return AlertDialog(
              backgroundColor: Colors.white,
              elevation: 6,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
              contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              title: Text(
                isEl ? 'Τρόπος επικοινωνίας' : 'Preferred Contact',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  optionTile(
                    value: 'all',
                    label: isEl ? 'Όλοι οι τρόποι' : 'All methods',
                  ),
                  optionTile(
                    value: 'text',
                    label: isEl ? 'Μήνυμα' : 'Text',
                  ),
                  optionTile(
                    value: 'call',
                    label: isEl ? 'Κλήση' : 'Call',
                  ),
                  optionTile(
                    value: 'email',
                    label: 'Email',
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    isEl ? 'Άκυρο' : 'Cancel',
                    style: const TextStyle(
                      color: AppTheme.primaryTeal,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    setState(() {
                      _preferredContact = tempValue;
                    });
                    await _saveProfileFields();
                    if (mounted) Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryTeal,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(isEl ? 'Αποθήκευση' : 'Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _openAppSettingsSheet(bool isEl) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: false,
      builder: (_) {
        final code = widget.currentLocale?.languageCode;
        final languageLabel = code == null
            ? (isEl ? 'Αυτόματο' : 'Auto')
            : code == 'el'
                ? 'Ελληνικά'
                : 'English';

        return SafeArea(
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFFF7FAF9),
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 42,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 14),
                  ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    leading: const Icon(
                      Icons.language_rounded,
                      color: AppTheme.textSecondary,
                    ),
                    title: Text(isEl ? 'Γλώσσα εφαρμογής' : 'App language'),
                    subtitle: Text(languageLabel),
                  ),
                  const SizedBox(height: 4),
                  ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    leading: const Icon(
                      Icons.info_outline_rounded,
                      color: AppTheme.textSecondary,
                    ),
                    title: Text(isEl ? 'Πληροφορίες' : 'About'),
                    subtitle: const Text('Petbook'),
                  ),
                  const SizedBox(height: 4),
                  ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    leading: const Icon(
                      Icons.close_rounded,
                      color: AppTheme.textSecondary,
                    ),
                    title: Text(isEl ? 'Κλείσιμο' : 'Close'),
                    onTap: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _onLogoutTap(bool isEl) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isEl ? 'Το logout θα προστεθεί σύντομα.' : 'Logout will be added soon.',
        ),
      ),
    );
  }

  String _preferredContactLabel(bool isEl) {
    switch (_preferredContact) {
      case 'call':
        return isEl ? 'Κλήση' : 'Call';
      case 'email':
        return 'Email';
      case 'text':
        return isEl ? 'Μήνυμα' : 'Text';
      default:
        return isEl ? 'Όλοι' : 'All';
    }
  }

  Uint8List? _profileImageBytes() {
    if (_photoBase64 == null || _photoBase64!.isEmpty) return null;

    try {
      return base64Decode(_photoBase64!);
    } catch (_) {
      return null;
    }
  }

  ImageProvider? _effectiveImage(Uint8List? imageBytes) {
    if (imageBytes != null) return MemoryImage(imageBytes);
    if (_photoUrl != null && !_photoUrlFailed) return NetworkImage(_photoUrl!);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isEl = Localizations.localeOf(context).languageCode == 'el';
    final imageBytes = _profileImageBytes();

    return Scaffold(
      backgroundColor: const Color(0xFFF3F2F7),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Row(
              children: [
                const Spacer(),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.92),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: IconButton(
                    onPressed: () => _openEditProfileDialog(isEl),
                    icon: const Icon(Icons.edit_rounded),
                    color: AppTheme.textPrimary,
                    tooltip: isEl ? 'Επεξεργασία' : 'Edit',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Center(
              child: GestureDetector(
                onTap: _pickImage,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 62,
                    backgroundColor: Colors.grey.shade200,
                    backgroundImage: _effectiveImage(imageBytes),
                    onBackgroundImageError: _effectiveImage(imageBytes) is NetworkImage
                        ? (_, __) => setState(() => _photoUrlFailed = true)
                        : null,
                    child: _effectiveImage(imageBytes) == null
                        ? const Icon(
                            Icons.person_rounded,
                            size: 62,
                            color: AppTheme.primaryTeal,
                          )
                        : null,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => _openNameDialog(isEl),
              child: Text(
                _name.isEmpty ? (isEl ? 'Πρόσθεσε όνομα' : 'Add name') : _name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () => _openLocationDialog(isEl),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.location_on_rounded,
                    size: 18,
                    color: AppTheme.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _location.isEmpty
                        ? (isEl ? 'Πρόσθεσε τοποθεσία' : 'Add location')
                        : _location,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            _profileRowCard(
              leading: Icons.email_outlined,
              title: isEl ? 'Στοιχεία επικοινωνίας' : 'Contact Info',
              trailing: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _phone.isEmpty
                        ? (isEl ? 'Χωρίς τηλέφωνο' : 'No phone')
                        : _phone,
                    style: TextStyle(
                      color: AppTheme.textSecondary.withOpacity(0.82),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _email.isEmpty
                        ? (isEl ? 'Χωρίς email' : 'No email')
                        : _email,
                    style: TextStyle(
                      color: AppTheme.textSecondary.withOpacity(0.82),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              onTap: () => _openContactDialog(isEl),
            ),
            const SizedBox(height: 12),
            _profileRowCard(
              leading: Icons.chat_bubble_rounded,
              leadingColor: AppTheme.primaryTeal,
              title: isEl ? 'Τρόπος επικοινωνίας' : 'Preferred Contact',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE9F4F3),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      _preferredContactLabel(isEl),
                      style: const TextStyle(
                        color: AppTheme.primaryTeal,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                ],
              ),
              onTap: () => _openPreferredContactDialog(isEl),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: _cardDecoration(),
              child: Row(
                children: [
                  Expanded(
                    child: _statBlock(
                      title: isEl ? 'Αγγελίες χαμένων' : 'Lost Reports',
                      icon: Icons.pets_rounded,
                      value: _lostCount.toString(),
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 84,
                    color: Colors.grey.withOpacity(0.25),
                  ),
                  Expanded(
                    child: _statBlock(
                      title: isEl ? 'Αγγελίες εύρεσης' : 'Found Reports',
                      icon: Icons.search_rounded,
                      value: _foundCount.toString(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _profileRowCard(
              leading: Icons.settings_rounded,
              title: isEl ? 'Ρυθμίσεις εφαρμογής' : 'App Settings',
              trailing:
                  const Icon(Icons.chevron_right_rounded, color: Colors.grey),
              onTap: () => _openAppSettingsSheet(isEl),
            ),
            const SizedBox(height: 16),
            _profileRowCard(
              leading: Icons.logout_rounded,
              leadingColor: const Color(0xFFC95C5C),
              title: isEl ? 'Αποσύνδεση' : 'Log out',
              trailing: const Icon(
                Icons.chevron_right_rounded,
                color: Colors.grey,
              ),
              onTap: () => _onLogoutTap(isEl),
              titleColor: const Color(0xFFC95C5C),
            ),
          ],
        ),
      ),
    );
  }

  Widget _profileRowCard({
    required IconData leading,
    required String title,
    required Widget trailing,
    Color leadingColor = AppTheme.textPrimary,
    Color titleColor = AppTheme.textPrimary,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          decoration: _cardDecoration(),
          child: Row(
            children: [
              Icon(leading, color: leadingColor, size: 30),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: titleColor,
                  ),
                ),
              ),
              trailing,
            ],
          ),
        ),
      ),
    );
  }

  Widget _statBlock({
    required String title,
    required IconData icon,
    required String value,
  }) {
    final isZero = value == '0';

    return Column(
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Icon(
          icon,
          size: 40,
          color: AppTheme.primaryTeal,
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: isZero
                ? AppTheme.textPrimary.withOpacity(0.78)
                : AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.06),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }
}
