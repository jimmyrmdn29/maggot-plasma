import 'package:flutter/material.dart';

import 'app.dart';
import 'backend/app_initializer.dart';

void main() async {
  await AppInitializer.init();
  runApp(const AplikasiMaggot());
}