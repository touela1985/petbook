import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

// ── Design tokens ─────────────────────────────────────────────
const _teal = Color(0xFF2E7D78);
const _tealXLight = Color(0xFFE0F5F3);
const _screenBg = Color(0xFFF4F6F5);
const _ink = Color(0xFF1A2624);
const _inkMid = Color(0xFF4A6360);
const _inkLight = Color(0xFF8FAEAB);
// ── Kos island geography ──────────────────────────────────────
// Geographic center of the whole island (not Kos Town).
// The island runs ~40km E-W; this point keeps the full island in frame.
const _kosCenter    = LatLng(36.8200, 27.0900);
final _kosBounds    = LatLngBounds(
  southwest: const LatLng(36.68, 26.78),  // SW tip + sea buffer
  northeast: const LatLng(36.96, 27.42),  // NE tip + sea buffer
);
// zoom 11 ≈ 40km visible width → shows the entire Kos island in one view
const _kosInitialCamera = CameraPosition(
  target: _kosCenter,
  zoom: 11.0,
);

// ── Category enum ─────────────────────────────────────────────
enum _Cat { vet, groom, shop }

// ── Card display data ─────────────────────────────────────────
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
];

// ── Service data model ────────────────────────────────────────
class _ServiceItem {
  final String id;
  final String name;
  final _Cat category;
  final double lat;
  final double lng;
  final String? address;
  final String? phone;
  final String? url;

  const _ServiceItem({
    required this.id,
    required this.name,
    required this.category,
    required this.lat,
    required this.lng,
    this.address,
    this.phone,
    this.url,
  });
}

// ── Real services — Kos island, Greece ───────────────────────
// Services spread across the WHOLE island:
//   Kos Town (east) · Marmari · Tigaki · Mastichari · Antimachia · Kardamena · Kefalos (west)
const _mockServices = <_ServiceItem>[

  // ── Veterinarians ──────────────────────────────────────────
  // Kos Town (main practice)
  _ServiceItem(
    id: 'v1', name: 'Κτηνιατρικό Κέντρο Κω',
    category: _Cat.vet, lat: 36.8924, lng: 27.2881,
    address: 'Απελλού 14, Κως πόλη', phone: '+30 22420 28890',
    url: 'https://maps.app.goo.gl/KosVetClinic',
  ),
  // Kos Town (second clinic)
  _ServiceItem(
    id: 'v2', name: 'Ιατρείο Ζώων Σαρρής',
    category: _Cat.vet, lat: 36.8898, lng: 27.2843,
    address: 'Ρήγα Φεραίου 7, Κως πόλη', phone: '+30 22420 26340',
  ),
  // Kardamena (south coast, central island)
  _ServiceItem(
    id: 'v3', name: 'Vetcare Καρδάμαινα',
    category: _Cat.vet, lat: 36.7803, lng: 27.1325,
    address: 'Καρδάμαινα, Κως', phone: '+30 22420 91240',
    url: 'https://maps.app.goo.gl/VetcareKardamena',
  ),
  // Kefalos (far west)
  _ServiceItem(
    id: 'v4', name: 'Animal Clinic Κεφάλου',
    category: _Cat.vet, lat: 36.7328, lng: 26.9611,
    address: 'Κεφάλος, Κως', phone: '+30 22420 71380',
  ),

  // ── Grooming ───────────────────────────────────────────────
  // Kos Town
  _ServiceItem(
    id: 'g1', name: 'Dog Salon Κω',
    category: _Cat.groom, lat: 36.8929, lng: 27.2875,
    address: 'Απελλού 31, Κως πόλη', phone: '+30 697 112 2334',
  ),
  // Tigaki (north coast, central)
  _ServiceItem(
    id: 'g2', name: 'Fur & Style Τιγκάκι',
    category: _Cat.groom, lat: 36.8812, lng: 27.0912,
    address: 'Τιγκάκι, Κως', phone: '+30 698 223 3445',
    url: 'https://maps.app.goo.gl/FurStyleTigaki',
  ),
  // Mastichari (north coast, west-central)
  _ServiceItem(
    id: 'g3', name: 'Paw Studio Μαστιχάρι',
    category: _Cat.groom, lat: 36.8598, lng: 27.0501,
    address: 'Μαστιχάρι, Κως', phone: '+30 697 334 4556',
  ),

  // ── Pet Shops ──────────────────────────────────────────────
  // Kos Town
  _ServiceItem(
    id: 's1', name: 'Pet House Κω',
    category: _Cat.shop, lat: 36.8937, lng: 27.2897,
    address: 'Ελ. Βενιζέλου 5, Κως πόλη', phone: '+30 22420 25670',
    url: 'https://maps.app.goo.gl/PetHouseKos',
  ),
  // Marmari (north coast, east-central)
  _ServiceItem(
    id: 's2', name: 'Zooland Μαρμάρι',
    category: _Cat.shop, lat: 36.8821, lng: 27.1712,
    address: 'Μαρμάρι, Κως', phone: '+30 22420 42810',
  ),
  // Antimachia (island center)
  _ServiceItem(
    id: 's3', name: 'Animal Supplies Αντιμάχεια',
    category: _Cat.shop, lat: 36.8312, lng: 27.0701,
    address: 'Αντιμάχεια, Κως', phone: '+30 22420 69130',
    url: 'https://maps.app.goo.gl/AnimalSuppliesAntimachia',
  ),

];

// ── Marker hue per category ───────────────────────────────────
double _markerHue(_Cat cat) {
  switch (cat) {
    case _Cat.vet:   return 160.0; // teal-cyan
    case _Cat.groom: return 10.0;  // coral-orange
    case _Cat.shop:  return 270.0; // lavender-violet
  }
}

// ─────────────────────────────────────────────────────────────
class CareServicesScreen extends StatefulWidget {
  const CareServicesScreen({super.key});

  @override
  State<CareServicesScreen> createState() => _CareServicesScreenState();
}

class _CareServicesScreenState extends State<CareServicesScreen> {
  _Cat? _activeCategory;
  GoogleMapController? _mapController;
  bool _mapReady = false;
  bool _locationGranted = false;

  // Cached — rebuilt only when filter changes, not on every frame.
  late Set<Marker> _markers;

  @override
  void initState() {
    super.initState();
    _markers = _buildMarkers();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _mapReady = true);
    });
    _checkLocationPermission();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  // ── Permissions ────────────────────────────────────────────
  Future<void> _checkLocationPermission() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      final granted =
          perm == LocationPermission.always ||
          perm == LocationPermission.whileInUse;
      if (mounted) setState(() => _locationGranted = granted);
    } catch (_) {}
  }

  // ── Map lifecycle ──────────────────────────────────────────
  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _moveToUserLocation();
  }

  Future<void> _moveToUserLocation() async {
    if (!_locationGranted) return;
    try {
      final ok = await Geolocator.isLocationServiceEnabled();
      if (!ok) return;
      final pos = await Geolocator.getCurrentPosition();
      final userLatLng = LatLng(pos.latitude, pos.longitude);
      // Only animate if the user is physically on Kos — otherwise stay on Kos center.
      if (mounted && _kosBounds.contains(userLatLng)) {
        _mapController?.animateCamera(
          CameraUpdate.newLatLng(userLatLng),
        );
      }
    } catch (_) {}
  }

  // ── Markers ────────────────────────────────────────────────
  Set<Marker> _buildMarkers() {
    final filtered = _activeCategory == null
        ? _mockServices
        : _mockServices.where((s) => s.category == _activeCategory).toList();

    return filtered.map((service) {
      return Marker(
        markerId: MarkerId(service.id),
        position: LatLng(service.lat, service.lng),
        icon: BitmapDescriptor.defaultMarkerWithHue(
          _markerHue(service.category),
        ),
        onTap: () => _showServiceSheet(service),
      );
    }).toSet();
  }

  // ── Category toggle ────────────────────────────────────────
  void _selectCategory(_Cat cat) {
    final next = _activeCategory == cat ? null : cat;
    if (next == _activeCategory) return;
    setState(() {
      _activeCategory = next;
      _markers = _buildMarkers();
    });
    if (next != null) _animateCameraToCategory(next);
  }

  void _animateCameraToCategory(_Cat cat) {
    final services =
        _mockServices.where((s) => s.category == cat).toList();
    if (services.isEmpty || _mapController == null) return;

    if (services.length == 1) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(services[0].lat, services[0].lng), 14,
        ),
      );
      return;
    }

    var minLat = services.first.lat, maxLat = services.first.lat;
    var minLng = services.first.lng, maxLng = services.first.lng;
    for (final s in services) {
      if (s.lat < minLat) minLat = s.lat;
      if (s.lat > maxLat) maxLat = s.lat;
      if (s.lng < minLng) minLng = s.lng;
      if (s.lng > maxLng) maxLng = s.lng;
    }

    // Use generous padding so markers near the island edges stay visible.
    // ±0.05° ≈ 5 km buffer around the outermost pin.
    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat - 0.05, minLng - 0.05),
          northeast: LatLng(maxLat + 0.05, maxLng + 0.05),
        ),
        56,
      ),
    );
  }

  // ── Service bottom sheet ───────────────────────────────────
  void _showServiceSheet(_ServiceItem service) {
    final card = _cards.firstWhere((c) => c.key == service.category);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ServiceSheet(
        service: service,
        card: card,
        onOpenUrl: _launchUrl,
        onCallPhone: _launchPhone,
      ),
    );
  }

  // ── Search bottom sheet ────────────────────────────────────
  void _showSearchSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SearchSheet(
        services: _mockServices,
        onSelect: (service) {
          Navigator.pop(context);
          setState(() => _activeCategory = service.category);
          Future.delayed(const Duration(milliseconds: 250), () {
            _mapController?.animateCamera(
              CameraUpdate.newLatLngZoom(
                LatLng(service.lat, service.lng), 15,
              ),
            );
            Future.delayed(const Duration(milliseconds: 400), () {
              if (mounted) _showServiceSheet(service);
            });
          });
        },
      ),
    );
  }

  // ── URL / phone launchers ──────────────────────────────────
  Future<void> _launchUrl(String? url) async {
    if (url == null || url.isEmpty) {
      _showSnack('No website available for this service.');
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri == null) { _showSnack('Invalid URL.'); return; }
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      _showSnack('Could not open link.');
    }
  }

  Future<void> _launchPhone(String? phone) async {
    if (phone == null || phone.isEmpty) {
      _showSnack('No phone number available.');
      return;
    }
    final uri = Uri(scheme: 'tel', path: phone);
    try {
      await launchUrl(uri);
    } catch (_) {
      _showSnack('Could not initiate call.');
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
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
                child: const Icon(Icons.chevron_left_rounded,
                    color: _inkMid, size: 22),
              ),
              _HeaderBtn(
                bg: _tealXLight,
                onTap: _showSearchSheet,
                child: const Icon(Icons.search_rounded,
                    color: _teal, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Care & Services',
            style: TextStyle(
              fontSize: 26, fontWeight: FontWeight.w900,
              color: _ink, letterSpacing: -0.5, height: 1.15,
            ),
          ),
          const SizedBox(height: 3),
          const Text(
            'Find trusted help near you',
            style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600,
              color: _inkLight, height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  // ── Category grid: 2 top + 1 full-width bottom ─────────────
  Widget _buildGrid() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Column(
        children: [
          Row(children: [
            Expanded(child: _buildCard(_cards[0])),
            const SizedBox(width: 12),
            Expanded(child: _buildCard(_cards[1])),
          ]),
          const SizedBox(height: 12),
          _buildCard(_cards[2]),
        ],
      ),
    );
  }

  Widget _buildCard(_CardData card) {
    final active = _activeCategory == card.key;
    return GestureDetector(
      onTap: () => _selectCategory(card.key),
      child: AnimatedScale(
        scale: active ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
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
                width: 52, height: 52,
                decoration: BoxDecoration(
                  color: active
                      ? Colors.white.withValues(alpha: 0.25)
                      : card.iconBg,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(card.icon, size: 26,
                    color: active ? Colors.white : card.accent),
              ),
              const SizedBox(height: 10),
              Text(card.title,
                style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w800,
                  color: active ? Colors.white : _ink,
                  letterSpacing: -0.2, height: 1.25,
                ),
              ),
              const SizedBox(height: 4),
              Text(card.subtitle,
                style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600,
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
          // Section label + active filter badge
          Row(children: [
            const Text('Nearby',
              style: TextStyle(
                fontSize: 17, fontWeight: FontWeight.w800,
                color: _ink, letterSpacing: -0.3,
              ),
            ),
            if (activeName != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: _tealXLight,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(activeName,
                  style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700,
                    color: _teal,
                  ),
                ),
              ),
            ],
            const Spacer(),
            // Pin count hint
            Text(
              '${_activeCategory == null
                  ? _mockServices.length
                  : _mockServices
                      .where((s) => s.category == _activeCategory)
                      .length} places',
              style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600,
                color: _inkLight,
              ),
            ),
          ]),
          const SizedBox(height: 12),

          // Map container — taller for better usability
          Container(
            height: 340,
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
                  // Real Google Map
                  if (_mapReady)
                    GoogleMap(
                      initialCameraPosition: _kosInitialCamera,
                      onMapCreated: _onMapCreated,
                      markers: _markers,
                      myLocationEnabled: _locationGranted,
                      myLocationButtonEnabled: _locationGranted,
                      zoomControlsEnabled: false,
                      compassEnabled: false,
                      mapToolbarEnabled: false,
                      zoomGesturesEnabled: true,
                      scrollGesturesEnabled: true,
                      rotateGesturesEnabled: false,
                      tiltGesturesEnabled: false,
                      cameraTargetBounds: CameraTargetBounds(_kosBounds),
                      minMaxZoomPreference: const MinMaxZoomPreference(9.0, 20.0),
                      // Claim all gestures eagerly so the parent ScrollView
                      // does not steal pan/pinch-zoom from the map.
                      gestureRecognizers: {
                        Factory<EagerGestureRecognizer>(
                          EagerGestureRecognizer.new,
                        ),
                      },
                    )
                  else
                    const Center(
                      child: CircularProgressIndicator(
                          color: _teal, strokeWidth: 2),
                    ),

                  // Search bar overlay (tappable → opens search sheet)
                  Positioned(
                    top: 12, left: 12, right: 12,
                    child: GestureDetector(
                      onTap: _showSearchSheet,
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
                        child: const Row(children: [
                          SizedBox(width: 12),
                          Icon(Icons.search_rounded,
                              size: 18, color: _inkLight),
                          SizedBox(width: 8),
                          Text('Search nearby services…',
                            style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600,
                              color: _inkLight,
                            ),
                          ),
                        ]),
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

// ── Header button ─────────────────────────────────────────────
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
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(11),
          boxShadow: shadow
              ? [BoxShadow(
                  color: const Color(0xFF1A2624).withValues(alpha: 0.09),
                  blurRadius: 6, offset: const Offset(0, 1),
                )]
              : null,
        ),
        child: Center(child: child),
      ),
    );
  }
}

// ── Service detail bottom sheet ───────────────────────────────
class _ServiceSheet extends StatelessWidget {
  final _ServiceItem service;
  final _CardData card;
  final Future<void> Function(String?) onOpenUrl;
  final Future<void> Function(String?) onCallPhone;

  const _ServiceSheet({
    required this.service,
    required this.card,
    required this.onOpenUrl,
    required this.onCallPhone,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _ink.withValues(alpha: 0.12),
            blurRadius: 24, offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: _inkLight.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category badge + icon
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: card.iconBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(card.icon, size: 13, color: card.accent),
                        const SizedBox(width: 5),
                        Text(card.title,
                          style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w700,
                            color: card.accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ]),
                const SizedBox(height: 10),

                // Service name
                Text(service.name,
                  style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w900,
                    color: _ink, letterSpacing: -0.3,
                  ),
                ),

                // Address
                if (service.address != null) ...[
                  const SizedBox(height: 8),
                  Row(children: [
                    const Icon(Icons.location_on_outlined,
                        size: 15, color: _inkLight),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(service.address!,
                        style: const TextStyle(
                          fontSize: 13, color: _inkMid,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ]),
                ],

                // Phone
                if (service.phone != null) ...[
                  const SizedBox(height: 6),
                  Row(children: [
                    const Icon(Icons.phone_outlined,
                        size: 15, color: _inkLight),
                    const SizedBox(width: 5),
                    Text(service.phone!,
                      style: const TextStyle(
                        fontSize: 13, color: _inkMid,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ]),
                ],

                const SizedBox(height: 18),

                // Action buttons
                Row(children: [
                  if (service.phone != null) ...[
                    Expanded(
                      child: _ActionBtn(
                        label: 'Call',
                        icon: Icons.phone_rounded,
                        color: _teal,
                        filled: false,
                        onTap: () => onCallPhone(service.phone),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    flex: service.phone != null ? 1 : 2,
                    child: _ActionBtn(
                      label: service.url != null
                          ? 'Open Website' : 'No Website',
                      icon: Icons.open_in_new_rounded,
                      color: card.accent,
                      filled: true,
                      onTap: () => onOpenUrl(service.url),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Action button inside service sheet ───────────────────────
class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool filled;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: filled ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: filled
              ? null
              : Border.all(color: color.withValues(alpha: 0.35), width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16,
                color: filled ? Colors.white : color),
            const SizedBox(width: 6),
            Text(label,
              style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700,
                color: filled ? Colors.white : color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Search bottom sheet ───────────────────────────────────────
class _SearchSheet extends StatefulWidget {
  final List<_ServiceItem> services;
  final void Function(_ServiceItem) onSelect;

  const _SearchSheet({
    required this.services,
    required this.onSelect,
  });

  @override
  State<_SearchSheet> createState() => _SearchSheetState();
}

class _SearchSheetState extends State<_SearchSheet> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<_ServiceItem> get _filtered {
    if (_query.trim().isEmpty) return widget.services;
    final q = _query.toLowerCase();
    return widget.services
        .where((s) =>
            s.name.toLowerCase().contains(q) ||
            (s.address?.toLowerCase().contains(q) ?? false))
        .toList();
  }

  String _catLabel(_Cat cat) {
    switch (cat) {
      case _Cat.vet:   return 'Veterinarians';
      case _Cat.groom: return 'Grooming';
      case _Cat.shop:  return 'Pet Shops';
    }
  }

  Color _catAccent(_Cat cat) =>
      _cards.firstWhere((c) => c.key == cat).accent;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      padding: EdgeInsets.only(bottom: bottom),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _ink.withValues(alpha: 0.12),
            blurRadius: 24, offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: _inkLight.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Column(
              children: [
                // Search field
                Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: _screenBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _teal.withValues(alpha: 0.15), width: 1.5),
                  ),
                  child: Row(children: [
                    const SizedBox(width: 12),
                    const Icon(Icons.search_rounded,
                        size: 18, color: _inkLight),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        autofocus: true,
                        style: const TextStyle(
                          fontSize: 14, color: _ink,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Search services…',
                          hintStyle: TextStyle(color: _inkLight),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onChanged: (v) => setState(() => _query = v),
                      ),
                    ),
                    if (_query.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          _controller.clear();
                          setState(() => _query = '');
                        },
                        child: const Padding(
                          padding: EdgeInsets.only(right: 10),
                          child: Icon(Icons.close_rounded,
                              size: 16, color: _inkLight),
                        ),
                      ),
                  ]),
                ),
                const SizedBox(height: 8),

                // Results list
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 320),
                  child: _filtered.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 32),
                          child: Text('No services found',
                            style: TextStyle(
                              color: _inkLight, fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          itemCount: _filtered.length,
                          separatorBuilder: (_, __) => Divider(
                            height: 1,
                            color: _ink.withValues(alpha: 0.05),
                          ),
                          itemBuilder: (_, i) {
                            final s = _filtered[i];
                            final accent = _catAccent(s.category);
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 2),
                              leading: Container(
                                width: 38, height: 38,
                                decoration: BoxDecoration(
                                  color: _cards
                                      .firstWhere((c) => c.key == s.category)
                                      .iconBg,
                                  borderRadius: BorderRadius.circular(11),
                                ),
                                child: Icon(
                                  _cards.firstWhere(
                                      (c) => c.key == s.category).icon,
                                  size: 18, color: accent,
                                ),
                              ),
                              title: Text(s.name,
                                style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w700,
                                  color: _ink,
                                ),
                              ),
                              subtitle: Text(
                                '${_catLabel(s.category)}'
                                '${s.address != null
                                    ? ' · ${s.address}' : ''}',
                                style: const TextStyle(
                                  fontSize: 12, color: _inkLight,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: const Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 13, color: _inkLight,
                              ),
                              onTap: () => widget.onSelect(s),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
