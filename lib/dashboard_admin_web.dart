//dashboard_Admin_Web.dart
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("ADMIN PANEL",
            style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
              onPressed: () => AuthService().logout(),
              icon: const Icon(Icons.logout))
        ],
      ),
      body: Column(
        children: [
          Container(
            color: const Color(0xFF1A237E),
            child: Row(
              children: [
                _buildTabItem("ESTIMASI STOK", indexMenu == 0,
                    () => setState(() => indexMenu = 0)),
                _buildTabItem("AUDIT RIWAYAT", indexMenu == 1,
                    () => setState(() => indexMenu = 1)),
                _buildTabItem("KELOLA MITRA", indexMenu == 2,
                    () => setState(() => indexMenu = 2)),
              ],
            ),
          ),
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

  Widget _buildTabItem(String label, bool active, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 18),
              alignment: Alignment.center,
              child: Text(label,
                  style: TextStyle(
                      color: active ? Colors.white : Colors.white70,
                      fontWeight:
                          active ? FontWeight.bold : FontWeight.normal,
                      fontSize: 15)),
            ),
            Container(
                height: 4,
                color: active ? Colors.orange : Colors.transparent),
          ],
        ),
      ),
    );
  }
}

