import 'package:flutter/material.dart';

// =========================================================================
// WIDGET: APPBAR MITRA
// =========================================================================
class AppHeaderMitra extends StatelessWidget implements PreferredSizeWidget {
  final String namaMitra;
  final VoidCallback onLogout;

  const AppHeaderMitra({
    super.key,
    required this.namaMitra,
    required this.onLogout,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      elevation: 0,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('MAGG', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          Text(namaMitra, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal)),
        ],
      ),
      backgroundColor: Colors.green[700],
      foregroundColor: Colors.white,
      actions: [
        IconButton(
          onPressed: onLogout,
          icon: const Icon(Icons.logout_rounded),
          tooltip: 'Keluar Aplikasi',
        )
      ],
    );
  }
}