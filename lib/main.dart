import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:task_manager_app/providers/settings_provider.dart';
import 'package:task_manager_app/providers/user_provider.dart';
import 'package:task_manager_app/providers/task_provider.dart';
import 'package:task_manager_app/screens/login_screen.dart';
import 'package:task_manager_app/screens/main_screen.dart';
import 'package:task_manager_app/constants/app_colors.dart';
import 'package:task_manager_app/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Initialize notifications
  await NotificationService().initialize();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()), // no load here
        ChangeNotifierProvider(create: (_) => TaskProvider()),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          // Wait for settings to be initialized before showing the app
          if (!settings.isInitialized) {
            return const MaterialApp(
              debugShowCheckedModeBanner: false,
              home: Scaffold(
                body: Center(child: CircularProgressIndicator()),
              ),
            );
          }

          return MaterialApp(
            title: 'Task Manager',
            debugShowCheckedModeBanner: false,
            theme: ThemeData.light().copyWith(
              primaryColor: AppColors.primary,
              scaffoldBackgroundColor: AppColors.background,
              appBarTheme: const AppBarTheme(
                elevation: 0,
                centerTitle: true,
                backgroundColor: Colors.transparent,
                foregroundColor: AppColors.textPrimary,
              ),
            ),
            darkTheme: ThemeData.dark().copyWith(
              primaryColor: AppColors.primary,
              scaffoldBackgroundColor: Colors.grey[900],
              appBarTheme: const AppBarTheme(
                elevation: 0,
                centerTitle: true,
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
              ),
            ),
            themeMode: settings.themeMode,
            builder: (context, child) {
              return MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaleFactor: settings.textScaleFactor,
                ),
                child: child!,
              );
            },
            home: StreamBuilder<User?>(
              stream: FirebaseAuth.instance.authStateChanges(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.active) {
                  final user = snapshot.data;
                  if (user == null) {
                    return const LoginScreen();
                  }
                  return const MainScreen(); // user is signed in
                }
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              },
            ),
          );
        },
      ),
    );
  }
}