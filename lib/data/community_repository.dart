import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/community_place.dart';
import '../models/community_tip.dart';

class CommunityRepository {
  static const String _placesKey = 'community_places';
  static const String _tipsKey = 'community_tips';

  Future<List<CommunityPlace>> getPlaces() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_placesKey);

    if (raw == null || raw.isEmpty) return [];

    final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((item) => CommunityPlace.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<CommunityTip>> getTips() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_tipsKey);

    if (raw == null || raw.isEmpty) return [];

    final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((item) => CommunityTip.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> savePlaces(List<CommunityPlace> places) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(
      places.map((place) => place.toJson()).toList(),
    );
    await prefs.setString(_placesKey, encoded);
  }

  Future<void> saveTips(List<CommunityTip> tips) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(
      tips.map((tip) => tip.toJson()).toList(),
    );
    await prefs.setString(_tipsKey, encoded);
  }

  Future<void> addPlace(CommunityPlace place) async {
    final places = await getPlaces();
    places.insert(0, place);
    await savePlaces(places);
  }

  Future<void> addTip(CommunityTip tip) async {
    final tips = await getTips();
    tips.insert(0, tip);
    await saveTips(tips);
  }

  Future<void> updatePlace(CommunityPlace updatedPlace) async {
    final places = await getPlaces();
    final index = places.indexWhere((place) => place.id == updatedPlace.id);
    if (index == -1) return;

    places[index] = updatedPlace;
    await savePlaces(places);
  }

  Future<void> updateTip(CommunityTip updatedTip) async {
    final tips = await getTips();
    final index = tips.indexWhere((tip) => tip.id == updatedTip.id);
    if (index == -1) return;

    tips[index] = updatedTip;
    await saveTips(tips);
  }

  Future<void> deletePlace(String placeId) async {
    final places = await getPlaces();
    places.removeWhere((place) => place.id == placeId);
    await savePlaces(places);
  }

  Future<void> deleteTip(String tipId) async {
    final tips = await getTips();
    tips.removeWhere((tip) => tip.id == tipId);
    await saveTips(tips);
  }

  Future<void> clearAllCommunityData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_placesKey);
    await prefs.remove(_tipsKey);
  }
}
