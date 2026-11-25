import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

// =========================================================================
// 1. MODEL DATA (Mencegah Salah Ketik Key JSON / Map)
// =========================================================================
class TrayItem {
  final String beratTelur;
  final Timestamp tanggalMulai;
  final String tanggalTampil;

  const TrayItem({
    required this.beratTelur,
    required this.tanggalMulai,
    required this.tanggalTampil,
  });

  // Untuk dikirim ke Firestore / Callback
  Map<String, dynamic> toFirestoreMap() {
    return {
      "beratTelur": beratTelur,
      "tanggalMulai": tanggalMulai,
      "tanggalTampil": tanggalTampil,
    };
  }

  // Untuk disimpan ke Local Storage (SharedPreferences)
  Map<String, dynamic> toStorageMap() {
    return {
      "beratTelur": beratTelur,
      "tanggalMulaiMs": tanggalMulai.millisecondsSinceEpoch,
      "tanggalTampil": tanggalTampil,
    };
  }

  // Untuk dimuat dari Local Storage
  factory TrayItem.fromStorageMap(Map<String, dynamic> map) {
    return TrayItem(
      beratTelur: map["beratTelur"] ?? "0",
      tanggalMulai: Timestamp.fromMillisecondsSinceEpoch(map["tanggalMulaiMs"] ?? 0),
      tanggalTampil: map["tanggalTampil"] ?? "-",
    );
  }
}

// =========================================================================
// 2. SERVICE LOCAL STORAGE (Menangani Draft Tanpa Mengotori UI)
// =========================================================================
class DraftTrayStorage {
  static const String _storageKey = 'draft_antrean_tray';

  static Future<List<TrayItem>> loadDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? draftJson = prefs.getString(_storageKey);
      if (draftJson == null || draftJson.isEmpty) return [];

      final List<dynamic> decoded = json.decode(draftJson);
      return decoded.map((item) => TrayItem.fromStorageMap(item)).toList();
    } catch (e) {
      debugPrint("Gagal memuat draft tray: $e");
      return [];
    }
  }

  static Future<void> saveDraft(List<TrayItem> list) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<Map<String, dynamic>> toSave = list.map((e) => e.toStorageMap()).toList();
      await prefs.setString(_storageKey, json.encode(toSave));
    } catch (_) {}
  }

  static Future<void> clearDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
    } catch (_) {}
  }
}
