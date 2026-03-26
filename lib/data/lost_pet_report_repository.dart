import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/lost_pet_report.dart';

class LostPetReportRepository {
  static const String _storageKey = 'lost_pet_reports';

  Future<List<LostPetReport>> getReports() async {
    final prefs = await SharedPreferences.getInstance();
    final String? reportsJson = prefs.getString(_storageKey);

    if (reportsJson == null || reportsJson.isEmpty) {
      return [];
    }

    final List<dynamic> decoded = jsonDecode(reportsJson);

    return decoded.map((item) => LostPetReport.fromJson(item)).toList()
      ..sort((a, b) => b.lastSeenDate.compareTo(a.lastSeenDate));
  }

  Future<void> saveReports(List<LostPetReport> reports) async {
    final prefs = await SharedPreferences.getInstance();

    final String encoded = jsonEncode(
      reports.map((report) => report.toJson()).toList(),
    );

    await prefs.setString(_storageKey, encoded);
  }

  Future<void> addReport(LostPetReport report) async {
    final reports = await getReports();
    reports.add(report);
    await saveReports(reports);
  }

  Future<void> deleteReport(String reportId) async {
    final reports = await getReports();
    reports.removeWhere((report) => report.id == reportId);
    await saveReports(reports);
  }

  Future<void> updateReport(LostPetReport updatedReport) async {
    final reports = await getReports();

    final index = reports.indexWhere((report) => report.id == updatedReport.id);

    if (index == -1) {
      return;
    }

    reports[index] = updatedReport;
    await saveReports(reports);
  }
}
