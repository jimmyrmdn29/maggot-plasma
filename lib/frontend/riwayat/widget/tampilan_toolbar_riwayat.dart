import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme_riwayat.dart';

// ============================================================================
// TAMPILAN: TOOLBAR RIWAYAT (PENDIUKAN, SORTIR, FILTER TANGGAL)
// ============================================================================
class TampilanToolbarRiwayat extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onCariChanged;
  final bool sortTerbaru;
  final ValueChanged<bool> onSortChange;
  final DateTimeRange? selectedRange;
  final VoidCallback onBukaFilterTanggal;
  final VoidCallback onHapusFilterTanggal;

  const TampilanToolbarRiwayat({
    super.key,
    required this.controller,
    required this.onCariChanged,
    required this.sortTerbaru,
    required this.onSortChange,
    required this.selectedRange,
    required this.onBukaFilterTanggal,
    required this.onHapusFilterTanggal,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onCariChanged,
              decoration: InputDecoration(
                hintText: "Cari nama mitra / kode batch...",
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
          const SizedBox(width: 12),

          Container(
            height: 44,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: TemaRiwayat.surfaceGrey,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildSortTab(
                  label: "Terbaru",
                  isActive: sortTerbaru,
                  activeColor: TemaRiwayat.accentBlue,
                  onTap: () {
                    if (sortTerbaru) return;
                    onSortChange(true);
                  },
                ),
                _buildSortTab(
                  label: "Terlama",
                  isActive: !sortTerbaru,
                  activeColor: TemaRiwayat.warning,
                  onTap: () {
                    if (!sortTerbaru) return;
                    onSortChange(false);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          ElevatedButton.icon(
            onPressed: onBukaFilterTanggal,
            icon: const Icon(Icons.date_range, size: 16),
            label: Text(
              selectedRange == null
                  ? "FILTER TANGGAL"
                  : "${DateFormat('dd/MM').format(selectedRange!.start)} - ${DateFormat('dd/MM').format(selectedRange!.end)}",
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              backgroundColor: TemaRiwayat.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          if (selectedRange != null) ...[
            const SizedBox(width: 4),
            IconButton(
              tooltip: "Hapus Filter Tanggal",
              onPressed: onHapusFilterTanggal,
              icon: const Icon(Icons.close, color: Colors.red),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildSortTab({
    required String label,
    required bool isActive,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: isActive
              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4, offset: const Offset(0, 2))]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
            color: isActive ? activeColor : TemaRiwayat.textMuted,
          ),
        ),
      ),
    );
  }
}
