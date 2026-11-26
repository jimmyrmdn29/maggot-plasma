import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'backend/auth_service.dart';
import 'frontend/auth/router_pengguna.dart';
import 'frontend/login_page.dart';
import 'frontend/widget/loading_screen.dart';

class AplikasiMaggot extends StatelessWidget {
  const AplikasiMaggot({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.green,
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: StreamBuilder<User?>(
        stream: AuthService().userStream,
        builder: (context, authSnapshot) {
          if (authSnapshot.connectionState == ConnectionState.waiting) {
            return const LoadingScreen();
          }

          final User? user = authSnapshot.data;
          if (user == null) return const LoginPage();

          return UserRoleRouter(user: user);
        },
      ),
    );
  }
}