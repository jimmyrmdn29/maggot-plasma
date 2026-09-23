// dashboard_Admin_Web.dart
import 'package:flutter/material.dart';

import 'page_estimasi.dart';
import 'page_riwayat.dart';
import 'page_kelola_mitra.dart';
import 'auth_service.dart';

class DashboardAdminWeb extends StatefulWidget {
  const DashboardAdminWeb({super.key});

  @override
  State<DashboardAdminWeb> createState() => _DashboardAdminWebState();
}

class _DashboardAdminWebState extends State<DashboardAdminWeb> {
  int indexMenu = 0;

  // =========================================================================
  // KONFIRMASI LOGOUT (SAFETY GUARD ANTI-ACCIDENTAL TAP)
  // =========================================================================
  void _konfirmasiLogout(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: Colors.red),
            SizedBox(width: 10),
            Text(
              "Konfirmasi Logout",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: const Text(
          "Apakah Anda yakin ingin keluar dari panel dashboard admin Aplikasi Maggot?",
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("BATAL", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await AuthService().logout();
            },
            child: const Text("LOGOUT", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.admin_panel_settings_rounded, size: 22, color: Colors.white),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "ADMIN PANEL",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    fontSize: 18,
                  ),
                ),
                Text(
                  "Aplikasi Monitoring & Panen Maggot BSF",
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white70,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          Tooltip(
            message: "Keluar dari Akun",
            child: IconButton(
              onPressed: () => _konfirmasiLogout(context),
              icon: const Icon(Icons.logout),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // TAB BAR NAVIGASI DASHBOARD
          Container(
            color: const Color(0xFF1A237E),
            child: Row(
              children: [
                _buildTabItem(
                  label: "ESTIMASI STOK",
                  icon: Icons.trending_up_rounded,
                  active: indexMenu == 0,
                  onTap: () => setState(() => indexMenu = 0),
                ),
                _buildTabItem(
                  label: "AUDIT RIWAYAT",
                  icon: Icons.receipt_long_rounded,
                  active: indexMenu == 1,
                  onTap: () => setState(() => indexMenu = 1),
                ),
                _buildTabItem(
                  label: "KELOLA MITRA",
                  icon: Icons.people_alt_rounded,
                  active: indexMenu == 2,
                  onTap: () => setState(() => indexMenu = 2),
                ),
              ],
            ),
          ),

          // INDEXED STACK (MENJAGA STATE HALAMAN TETAP HIDUP TANPA RE-FETCH BERULANG)
          Expanded(
            child: IndexedStack(
              index: indexMenu,
              children: const [
                PageEstimasi(),
                PageRiwayat(),
                PageKelolaMitra(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabItem({
    required String label,
    required IconData icon,
    required bool active,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          splashColor: Colors.white.withOpacity(0.1),
          highlightColor: Colors.white.withOpacity(0.05),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      size: 18,
                      color: active ? Colors.orange : Colors.white70,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        label,
                        style: TextStyle(
                          color: active ? Colors.white : Colors.white70,
                          fontWeight: active ? FontWeight.bold : FontWeight.normal,
                          fontSize: 14,
                          letterSpacing: 0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                height: 4,
                color: active ? Colors.orange : Colors.transparent,
              ),
            ],
          ),
        ),
      ),
    );
  }
}