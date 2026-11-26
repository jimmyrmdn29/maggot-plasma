import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../dashboard_admin_web.dart';
import '../email_verification_page.dart';
import '../profil_tidak_ditemukan_page.dart';
import '../navigasi/halaman_navigasi.dart';
import '../widget/loading_screen.dart';

class UserRoleRouter extends StatelessWidget {
  final User user;

  const UserRoleRouter({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
      builder: (context, userSnap) {
        if (!userSnap.hasData) return const LoadingScreen();

        final userData = userSnap.data!.data() as Map<String, dynamic>?;
        if (userData == null) return const ProfilTidakDitemukanPage();

        if (userData['role'] == 'admin') {
          return const DashboardAdminWeb();
        }

        if (!user.emailVerified) {
          return const EmailVerificationPage();
        }

        return const HalamanNavigasi();
      },
    );
  }
}