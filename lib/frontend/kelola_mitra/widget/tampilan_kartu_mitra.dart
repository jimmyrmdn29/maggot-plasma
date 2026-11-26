import 'package:flutter/material.dart';

import '../../../backend/mitra_item.dart';

// ============================================================================
// TAMPILAN: KARTU SATU MITRA (dengan menu aksi)
// ============================================================================
class TampilanKartuMitra extends StatelessWidget {
  final MitraItem mitra;
  final VoidCallback onReset;
  final VoidCallback onHapus;

  const TampilanKartuMitra({
    super.key,
    required this.mitra,
    required this.onReset,
    required this.onHapus,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFF455A64),
                  foregroundColor: Colors.white,
                  child: Text(
                    mitra.inisial,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    mitra.nama,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _buildActionMenu(context),
              ],
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.layers_outlined,
                        size: 15,
                        color: Colors.blueGrey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        "Tray Aktif: ${mitra.siklus.length}",
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    "ID: #${mitra.counterTray}",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionMenu(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, size: 20, color: Colors.grey),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      itemBuilder: (ctx) => [
        const PopupMenuItem(
          value: 'reset',
          child: Row(
            children: [
              Icon(Icons.refresh, size: 18, color: Colors.blueGrey),
              SizedBox(width: 8),
              Text("Reset Counter"),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'hapus',
          child: Row(
            children: [
              Icon(Icons.delete_outline, size: 18, color: Colors.red),
              SizedBox(width: 8),
              Text("Hapus Mitra", style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ],
      onSelected: (val) {
        if (val == 'reset') {
          onReset();
        } else if (val == 'hapus') {
          onHapus();
        }
      },
    );
  }
}
