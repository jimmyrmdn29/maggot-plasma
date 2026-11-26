import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../riwayat_controller.dart';
import '../theme_riwayat.dart';

Future<void> tampilkanDialogFilterTanggalRiwayat(
  BuildContext context,
  RiwayatController controller,
) async {
  final now = DateTime.now();
  DateTime tempStart = controller.selectedRange?.start ?? now.subtract(const Duration(days: 7));
  DateTime tempEnd = controller.selectedRange?.end ?? now;

  await showDialog(
    context: context,
    barrierDismissible: true,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setModalState) {
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
                        "Pilih Rentang Tanggal",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                      )
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text("PILIHAN CEPAT", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 8),

                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildPresetChip("Hari Ini", () {
                        final today = DateTime(now.year, now.month, now.day);
                        controller.terapkanRentangBaru(DateTimeRange(start: today, end: today));
                        Navigator.pop(ctx);
                      }),
                      _buildPresetChip("7 Hari Terakhir", () {
                        final start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
                        final end = DateTime(now.year, now.month, now.day);
                        controller.terapkanRentangBaru(DateTimeRange(start: start, end: end));
                        Navigator.pop(ctx);
                      }),
                      _buildPresetChip("Bulan Ini", () {
                        final start = DateTime(now.year, now.month, 1);
                        final end = DateTime(now.year, now.month + 1, 0);
                        controller.terapkanRentangBaru(DateTimeRange(start: start, end: end));
                        Navigator.pop(ctx);
                      }),
                      _buildPresetChip("Bulan Lalu", () {
                        final start = DateTime(now.year, now.month - 1, 1);
                        final end = DateTime(now.year, now.month, 0);
                        controller.terapkanRentangBaru(DateTimeRange(start: start, end: end));
                        Navigator.pop(ctx);
                      }),
                    ],
                  ),

                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Divider(height: 1),
                  ),

                  const Text("RENTANG KUSTOM", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: tempStart,
                              firstDate: DateTime(now.year - 3),
                              lastDate: DateTime(now.year + 1),
                            );
                            if (picked != null) {
                              setModalState(() {
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
                                const Text("Dari", style: TextStyle(fontSize: 10, color: Colors.grey)),
                                const SizedBox(height: 2),
                                Text(
                                  DateFormat('dd MMM yyyy').format(tempStart),
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                                ),
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
                              lastDate: DateTime(now.year + 1),
                            );
                            if (picked != null) {
                              setModalState(() {
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
                                const Text("Sampai", style: TextStyle(fontSize: 10, color: Colors.grey)),
                                const SizedBox(height: 2),
                                Text(
                                  DateFormat('dd MMM yyyy').format(tempEnd),
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                                ),
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
                        backgroundColor: TemaRiwayat.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {
                        controller.terapkanRentangBaru(DateTimeRange(start: tempStart, end: tempEnd));
                        Navigator.pop(ctx);
                      },
                      child: const Text("TERAPKAN TANGGAL", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  )
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

Widget _buildPresetChip(String label, VoidCallback onTap) {
  return ActionChip(
    label: Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF37474F))),
    backgroundColor: TemaRiwayat.surfaceGrey,
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    onPressed: onTap,
  );
}