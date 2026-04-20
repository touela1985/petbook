import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

// ── Design tokens ─────────────────────────────────────────────
const _teal = Color(0xFF2E7D78);
const _tealXLight = Color(0xFFE0F5F3);
const _screenBg = Color(0xFFF4F6F5);
const _ink = Color(0xFF1A2624);
const _inkMid = Color(0xFF4A6360);
const _inkLight = Color(0xFF8FAEAB);
const _defaultLocation = LatLng(37.9838, 23.7275); // Athens fallback

// ── Category enum ─────────────────────────────────────────────
enum _Cat { vet, groom, shop, walk }

// ── Card data ─────────────────────────────────────────────────
class _CardData {
  final _Cat key;
  final String title;
  final String subtitle;
  final Color iconBg;
  final Color accent;
  final IconData icon;

  const _CardData({
    required this.key,
    required this.title,
    required this.subtitle,
    required this.iconBg,
    required this.accent,
    required this.icon,
  });
}

const _cards = [
  _CardData(
    key: _Cat.vet,
    title: 'Veterinarians',
    subtitle: 'Clinics & specialists',
    iconBg: Color(0xFFE0F5F3),
    accent: Color(0xFF2E7D78),
    icon: Icons.medical_services_outlined,
  ),
  _CardData(
    key: _Cat.groom,
    title: 'Grooming',
    subtitle: 'Salons & mobile groomers',
    iconBg: Color(0xFFFFF0EC),
    accent: Color(0xFFFF6B4A),
    icon: Icons.content_cut_outlined,
  ),
  _CardData(
    key: _Cat.shop,
    title: 'Pet Shops',
    subtitle: 'Food, toys & accessories',
    iconBg: Color(0xFFF0EEFF),
    accent: Color(0xFF7B6FD4),
    icon: Icons.store_outlined,
  ),
  _CardData(
    key: _Cat.walk,
    title: 'Sitting & Walking',
    subtitle: 'Trusted local pet sitters',
    iconBg: Color(0xFFFFF5E6),
    accent: Color(0xFFF0A044),
    icon: Icons.pets_outlined,
  ),
];

// ─────────────────────────────────────────────────────────────
class CareServicesScreen extends StatefulWidget {
  const CareServicesScreen({super.key});

  @override
  State<CareServicesScreen> createState() => _CareServicesScreenState();
}

class _CareServicesScreenState extends State<CareServicesScreen> {
  _Cat? _activeCategory;
  GoogleMapController? _mapController;

  // Map renders only after the first frame to avoid PlatformView
  // initialization conflicts when the screen is first inserted as a tab.
  bool _mapReady = false;
  bool _locationGranted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _mapReady = true);
      }
    });
    _checkLocationPermission();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _checkLocationPermission() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      final granted = permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
      if (mounted) {
        setState(() => _locationGranted = granted);
      }
    } catch (_) {}
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _moveToUserLocation();
  }

  Future<void> _moveToUserLocation() async {
    if (!_locationGranted) return;
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;
      final pos = await Geolocator.getCurrentPosition();
      if (mounted) {
        _mapController?.animateCamera(
          CameraUpdate.newLatLng(LatLng(pos.latitude, pos.longitude)),
        );
      }
    } catch (_) {}
  }

  void _toggleCategory(_Cat cat) {
    setState(() {
      _activeCategory = _activeCategory == cat ? null : cat;
    });
  }

  @override
  Widget build(BuildContext context) {
    // No nested Scaffold — use Material so InkWell/GestureDetector work,
    // background handled by outer Scaffold via this widget's color.
    return Material(
      color: _screenBg,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              _buildGrid(),
              _buildMapSection(),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _HeaderBtn(
                bg: Colors.white,
                shadow: true,
                onTap: () => Navigator.of(context).maybePop(),
                child: const Icon(
                  Icons.chevron_left_rounded,
                  color: _inkMid,
                  size: 22,
                ),
              ),
              _HeaderBtn(
                bg: _tealXLight,
                onTap: () {},
                child: const Icon(
                  Icons.search_rounded,
                  color: _teal,
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Care & Services',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: _ink,
              letterSpacing: -0.5,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 3),
          const Text(
            'Find trusted help near you',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _inkLight,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  // ── 2×2 category grid ──────────────────────────────────────
  Widget _buildGrid() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildCard(_cards[0])),
              const SizedBox(width: 12),
              Expanded(child: _buildCard(_cards[1])),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildCard(_cards[2])),
              const SizedBox(width: 12),
              Expanded(child: _buildCard(_cards[3])),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCard(_CardData card) {
    final active = _activeCategory == card.key;
    return GestureDetector(
      onTap: () => _toggleCategory(card.key),
      child: AnimatedScale(
        scale: active ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 18),
          decoration: BoxDecoration(
            color: active ? card.accent : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: active
                  ? Colors.transparent
                  : const Color(0xFF2E7D78).withValues(alpha: 0.10),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: active
                    ? card.accent.withValues(alpha: 0.33)
                    : _ink.withValues(alpha: 0.07),
                blurRadius: active ? 20 : 10,
                offset: Offset(0, active ? 6 : 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: active
                      ? Colors.white.withValues(alpha: 0.25)
                      : card.iconBg,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  card.icon,
                  size: 26,
                  color: active ? Colors.white : card.accent,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                card.title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: active ? Colors.white : _ink,
                  letterSpacing: -0.2,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                card.subtitle,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: active
                      ? Colors.white.withValues(alpha: 0.75)
                      : _inkLight,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Nearby / map section ───────────────────────────────────
  Widget _buildMapSection() {
    final activeName = _activeCategory == null
        ? null
        : _cards.firstWhere((c) => c.key == _activeCategory).title;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Nearby',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                  letterSpacing: -0.3,
                ),
              ),
              if (activeName != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: _tealXLight,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    activeName,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _teal,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 192,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5F3),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: const Color(0xFF2E7D78).withValues(alpha: 0.10),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: _ink.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Stack(
                children: [
                  // Real Google Map — deferred until after first frame
                  if (_mapReady)
                    GoogleMap(
                      initialCameraPosition: const CameraPosition(
                        target: _defaultLocation,
                        zoom: 14,
                      ),
                      onMapCreated: _onMapCreated,
                      myLocationEnabled: _locationGranted,
                      myLocationButtonEnabled: false,
                      zoomControlsEnabled: false,
                      mapToolbarEnabled: false,
                    )
                  else
                    const Center(
                      child: CircularProgressIndicator(
                        color: _teal,
                        strokeWidth: 2,
                      ),
                    ),
                  // Search bar overlay
                  Positioned(
                    top: 12,
                    left: 12,
                    right: 12,
                    child: Container(
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: _ink.withValues(alpha: 0.10),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Row(
                        children: [
                          SizedBox(width: 12),
                          Icon(Icons.search_rounded,
                              size: 18, color: _inkLight),
                          SizedBox(width: 8),
                          Text(
                            'Search nearby services…',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _inkLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Reusable header button ────────────────────────────────────
class _HeaderBtn extends StatelessWidget {
  final Color bg;
  final bool shadow;
  final VoidCallback onTap;
  final Widget child;

  const _HeaderBtn({
    required this.bg,
    required this.onTap,
    required this.child,
    this.shadow = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(11),
          boxShadow: shadow
              ? [
                  BoxShadow(
                    color: const Color(0xFF1A2624).withValues(alpha: 0.09),
                    blurRadius: 6,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Center(child: child),
      ),
    );
  }
}
