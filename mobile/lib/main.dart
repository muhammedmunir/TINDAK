import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tindak/app/cloud_bootstrap.dart';
import 'package:tindak/app/tindak_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cloud = await CloudBootstrap.start();
  runApp(ProviderScope(overrides: cloud, child: const TindakApp()));
}
