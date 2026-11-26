import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../tema_estimasi.dart';

// ============================================================================
// TAMPILAN: DIALOG FILTER TANGGAL ESTIMASI (PRESET + RENTANG KUSTOM)
// ============================================================================
class DialogFilterTanggal extends StatefulWidget {
  final DateTimeRange? rangeAkhir;
  final ValueChanged<DateTimeRange> onTerapkan;

  const DialogFilterTanggal({
    super.key,
    required this.rangeAkhir,
    required this.onTerapkan,
  });

  @override
  State<DialogFilterTanggal> createState() => _DialogFilterTanggalState();
}

class _DialogFilterTanggalState extends State<DialogFilterTanggal> {
  late DateTime tempStart;
  late DateTime tempEnd;

  @override
  void initState() {
    super.initState();
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    tempStart = widget.rangeAkhir?.start ?? today;
    tempEnd = widget.rangeAkhir?.end ?? today.add(const Duration(days: 7));
  }

  void _terapkanRentangBaru(DateTimeRange range) {
    setState(() {
      tempStart = range.start;
      tempEnd = range.end;
    });
  }

  Widget _buildPresetChip(String label, VoidCallback onTap) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF37474F))),
      backgroundColor: TemaEstimasi.surfaceGrey,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      onPressed: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 4,
          child: Container(
            width: 420,
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Pilih Jadwal Estimasi Panen",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  "JADWAL ESTIMASI CEPAT",
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildPresetChip("Hari Ini", () {
                      _terapkanRentangBaru(DateTimeRange(start: today, end: today));
                      Navigator.pop(context);
                    }),
                    _buildPresetChip("7 Hari Ke Depan", () {
                      final end = today.add(const Duration(days: 6));
                      _terapkanRentangBaru(DateTimeRange(start: today, end: end));
                      Navigator.pop(context);
                    }),
                    _buildPresetChip("Bulan Ini", () {
                      final start = today;
                      final end = DateTime(now.year, now.month + 1, 0);
                      _terapkanRentangBaru(DateTimeRange(start: start, end: end));
                      Navigator.pop(context);
                    }),
                    _buildPresetChip("Bulan Depan", () {
                      final start = DateTime(now.year, now.month + 1, 1);
                      final end = DateTime(now.year, now.month + 2, 0);
                      _terapkanRentangBaru(DateTimeRange(start: start, end: end));
                      Navigator.pop(context);
                    }),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Divider(height: 1),
                ),
                const Text(
                  "RENTANG KUSTOM",
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: tempStart,
                            firstDate: today.subtract(const Duration(days: 30)),
                            lastDate: today.add(const Duration(days: 365)),
                          );
                          if (picked != null) {
                            setState(() {
                              tempStart = picked;
                              if (tempEnd.isBefore(tempStart)) {
                                tempEnd = tempStart;
                              }
                            });
                          }
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Mulai Estimasi", style: TextStyle(fontSize: 10, color: Colors.grey)),
                              const SizedBox(height: 2),
                              Text(DateFormat('dd MMM yyyy').format(tempStart), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(Icons.arrow_forward, size: 16, color: Colors.grey),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: tempEnd.isBefore(tempStart) ? tempStart : tempEnd,
                            firstDate: tempStart,
                            lastDate: today.add(const Duration(days: 365)),
                          );
                          if (picked != null) {
                            setState(() {
                              tempEnd = picked;
                            });
                          }
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Sampai Estimasi", style: TextStyle(fontSize: 10, color: Colors.grey)),
                              const SizedBox(height: 2),
                              Text(DateFormat('dd MMM yyyy').format(tempEnd), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: TemaEstimasi.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      widget.onTerapkan(DateTimeRange(start: tempStart, end: tempEnd));
                      Navigator.pop(context);
                    },
                    child: const Text("TERAPKAN RENTANG ESTIMASI", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        );
  }
}
