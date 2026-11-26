import 'dart:math';

import 'package:flutter/material.dart';

import '../theme_riwayat.dart';

// ============================================================================
// TAMPILAN: PAGINASI RIWAYAT
// ============================================================================
class TampilanPaginationRiwayat extends StatelessWidget {
  final int totalData;
  final int totalHalaman;
  final int startIndex;
  final int endIndex;
  final int halamanAktif;
  final int barisPerHalaman;
  final List<int> opsiBaris;
  final ValueChanged<int> onHalamanChange;
  final ValueChanged<int> onBarisChange;

  const TampilanPaginationRiwayat({
    super.key,
    required this.totalData,
    required this.totalHalaman,
    required this.startIndex,
    required this.endIndex,
    required this.halamanAktif,
    required this.barisPerHalaman,
    required this.opsiBaris,
    required this.onHalamanChange,
    required this.onBarisChange,
  });

  @override
  Widget build(BuildContext context) {
    List<int> nomorHalaman = [];
    int startPage = max(1, halamanAktif - 2);
    int endPage = min(totalHalaman, startPage + 4);

    if (endPage - startPage < 4) {
      startPage = max(1, endPage - 4);
    }
    if (startPage < 1) startPage = 1;

    for (int i = startPage; i <= endPage; i++) {
      nomorHalaman.add(i);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(
                totalData == 0
                    ? "Menampilkan 0 data"
                    : "Menampilkan ${startIndex + 1} - $endIndex dari $totalData batch",
                style: const TextStyle(fontSize: 12, color: Color(0xFF616161), fontWeight: FontWeight.w500),
              ),
              const SizedBox(width: 16),
              Row(
                children: [
                  const Text("Baris: ", style: TextStyle(fontSize: 12, color: Colors.grey)),
                  DropdownButton<int>(
                    value: barisPerHalaman,
                    isDense: true,
                    underline: const SizedBox(),
                    items: opsiBaris.map((val) {
                      return DropdownMenuItem<int>(
                        value: val,
                        child: Text("$val", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        onBarisChange(val);
                      }
                    },
                  ),
                ],
              )
            ],
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.first_page, size: 20),
                tooltip: "Halaman Pertama",
                onPressed: halamanAktif > 1 ? () => onHalamanChange(1) : null,
              ),
              IconButton(
                icon: const Icon(Icons.chevron_left, size: 20),
                tooltip: "Sebelumnya",
                onPressed: halamanAktif > 1 ? () => onHalamanChange(halamanAktif - 1) : null,
              ),
              const SizedBox(width: 4),
              ...nomorHalaman.map((pageNo) {
                final bool isActive = pageNo == halamanAktif;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(36, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      backgroundColor: isActive ? TemaRiwayat.primary : Colors.transparent,
                      side: BorderSide(
                        color: isActive ? TemaRiwayat.primary : TemaRiwayat.borderGrey,
                        width: 1.0,
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    onPressed: () => onHalamanChange(pageNo),
                    child: Text(
                      "$pageNo",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                        color: isActive ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.chevron_right, size: 20),
                tooltip: "Berikutnya",
                onPressed: halamanAktif < totalHalaman ? () => onHalamanChange(halamanAktif + 1) : null,
              ),
              IconButton(
                icon: const Icon(Icons.last_page, size: 20),
                tooltip: "Halaman Terakhir",
                onPressed: halamanAktif < totalHalaman ? () => onHalamanChange(totalHalaman) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
