import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!AdminFirebaseOptions.isConfigured) {
    runApp(const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text('Firebase is not configured.\n'
              'Run with --dart-define-from-file=env/dev.json (see env/example.json).',
              textAlign: TextAlign.center),
        ),
      ),
    ));
    return;
  }
  await Firebase.initializeApp(options: AdminFirebaseOptions.current);
  runApp(const AdminApp());
}
