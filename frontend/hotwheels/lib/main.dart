import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'providers.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AppVersionText extends StatelessWidget {
  const AppVersionText({super.key});

  Future<String> _getVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    return packageInfo.version;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        return Center(
          child: Text(
            'Hot Wheels Collector Pro v${snapshot.data!.version}',
            style: const TextStyle(color: Colors.grey, fontSize: 12),
            overflow: TextOverflow.visible,
            softWrap: false,
          ),
        );
      },
    );
  }
}

// Class untuk mengizinkan sertifikat SSL yang tidak valid (Self-Signed)
class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Aktifkan bypass SSL jika dalam mode Debug atau berjalan di perangkat Mobile
  if (!kIsWeb) {
    HttpOverrides.global = MyHttpOverrides();
  }

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hot Wheels Collector Pro',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1E88E5), brightness: Brightness.light),
        textTheme: GoogleFonts.poppinsTextTheme(),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1E88E5), brightness: Brightness.dark),
        textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends ConsumerWidget {
  const AuthWrapper({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    if (authState.loggedIn) {
      return const HomeScreen();
    } else {
      return const LoginScreen();
    }
  }
}
