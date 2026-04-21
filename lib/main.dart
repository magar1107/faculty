import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/login_screen.dart';
import 'utils/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: 'AIzaSyDCUzB3T_2PrwiSU3SIVjQzQsmoYW4E8Q0',
        authDomain: 'faculty-188b6.firebaseapp.com',
        databaseURL: 'https://faculty-188b6-default-rtdb.asia-southeast1.firebasedatabase.app',
        projectId: 'faculty-188b6',
        storageBucket: 'faculty-188b6.firebasestorage.app',
        messagingSenderId: '811208997285',
        appId: '1:811208997285:web:024b88378f4dcceb8a504c',
        measurementId: 'G-T2H8P142ZB',
      ),
    );
  } else {
    await Firebase.initializeApp();
  }

  runApp(const SubstituteAutoApp());
}

class SubstituteAutoApp extends StatelessWidget {
  const SubstituteAutoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Substitute Auto',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const LoginScreen(),
    );
  }
}
