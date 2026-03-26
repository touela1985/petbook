import 'package:flutter/material.dart';

import '../data/pet_repository.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';
import 'lost_found_screen.dart';
import 'profile_screen.dart';
import 'view_pets_screen.dart';
import 'community_screen.dart';

class MainNavigation extends StatefulWidget {
  final PetRepository repo;
  final Future<void> Function(Locale? locale)? onChangeLocale;
  final Locale? currentLocale;

  const MainNavigation({
    super.key,
    required this.repo,
    this.onChangeLocale,
    this.currentLocale,
  });

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final isEl = Localizations.localeOf(context).languageCode == 'el';

    final pages = [
      HomeScreen(
        repo: widget.repo,
        onChangeLocale: widget.onChangeLocale,
        currentLocale: widget.currentLocale,
      ),
      const CommunityScreen(),
      ViewPetsScreen(repo: widget.repo),
      const LostFoundScreen(),
      ProfileScreen(
        onChangeLocale: widget.onChangeLocale,
        currentLocale: widget.currentLocale,
      ),
    ];

    return Scaffold(
      body: pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) {
          setState(() {
            _index = i;
          });
        },
        backgroundColor: Colors.white,
        indicatorColor: AppTheme.primaryTeal.withAlpha(30),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home_rounded),
            label: isEl ? 'Αρχική' : 'Home',
          ),
          NavigationDestination(
            icon: const Icon(Icons.groups_outlined),
            selectedIcon: const Icon(Icons.groups_rounded),
            label: isEl ? 'Κοινότητα' : 'Community',
          ),
          NavigationDestination(
            icon: const Icon(Icons.pets_outlined),
            selectedIcon: const Icon(Icons.pets),
            label: isEl ? 'Ζώα' : 'Pets',
          ),
          NavigationDestination(
            icon: const Icon(Icons.search_outlined),
            selectedIcon: const Icon(Icons.search_rounded),
            label: isEl ? 'Απώλειες' : 'Lost',
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline_rounded),
            selectedIcon: const Icon(Icons.person_rounded),
            label: isEl ? 'Προφίλ' : 'Profile',
          ),
        ],
      ),
    );
  }
}


