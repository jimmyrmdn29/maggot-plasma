import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'kunci_penyimpanan_panen.dart';

// ============================================================================
// 2. SERVICE LAYANAN PENYIMPANAN LOKAL (DRAFT, TRAY DIBUNGKUS, ANTREAN SYNC)
// ============================================================================
class PenyimpananPanen {
  Future<List<Map<String, dynamic>>> muatDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? draftJson = prefs.getString(KunciPenyimpananPanen.draft);
      if (draftJson == null || draftJson.isEmpty) return [];

      final List<dynamic> decoded = jsonDecode(draftJson);
      return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      debugPrint("Gagal membaca draft panen: $e");
      return [];
    }
  }

  Future<void> simpanDraft(List<Map<String, dynamic>> draft) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String jsonStr = jsonEncode(draft, toEncodable: customJsonSerializer);
      await prefs.setString(KunciPenyimpananPanen.draft, jsonStr);
    } catch (e) {
      debugPrint("Gagal menyimpan draft panen: $e");
    }
  }

  Future<void> hapusDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(KunciPenyimpananPanen.draft);
    } catch (e) {
      debugPrint("Gagal menghapus draft panen: $e");
    }
  }

  Future<Set<String>> muatTrayDibungkus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String>? listDibungkus = prefs.getStringList(KunciPenyimpananPanen.trayDibungkus);
      return listDibungkus?.toSet() ?? {};
    } catch (e) {
      debugPrint("Gagal membaca tray dibungkus: $e");
      return {};
    }
  }

  Future<void> simpanTrayDibungkus(List<String> trayDibungkus) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(KunciPenyimpananPanen.trayDibungkus, trayDibungkus);
    } catch (e) {
      debugPrint("Gagal menyimpan tray dibungkus: $e");
    }
  }

  Future<List<String>> muatAntreanSync() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList(KunciPenyimpananPanen.queue) ?? [];
    } catch (e) {
      debugPrint("Gagal membaca antrean sync: $e");
      return [];
    }
  }

  Future<void> simpanAntreanSync(List<String> antreanSync) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(KunciPenyimpananPanen.queue, antreanSync);
    } catch (e) {
      debugPrint("Gagal menyimpan antrean sync: $e");
    }
  }

  static dynamic customJsonSerializer(dynamic item) {
    if (item is Timestamp) return item.toDate().toIso8601String();
    if (item is DateTime) return item.toIso8601String();
    return item.toString();
  }
}
