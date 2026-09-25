import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'package:assisthub/providers/auth_provider.dart';
import 'package:assisthub/data/repositories/auth_repository.dart';
import 'package:assisthub/providers/user_provider.dart';
import 'package:assisthub/providers/employee_provider.dart';
import 'package:assisthub/providers/booking_provider.dart';
import 'package:assisthub/providers/chat_provider.dart';
import 'package:assisthub/providers/notification_provider.dart';
import 'package:assisthub/providers/core/theme/theme_provider.dart';
import 'package:assisthub/data/services/notification_service.dart';
import 'firebase_options.dart';
import 'package:assisthub/providers/complaint_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // Offline persistence is unstable on Firestore's web SDK when many
  // real-time listeners are active at once (chat, bookings, employees,
  // complaints, notifications, etc.) — it was the likely cause of the
  // "INTERNAL ASSERTION FAILED: Unexpected state" crash. Mobile's
  // persistence implementation doesn't have this issue, so keep it
  // enabled there.
  if (!kIsWeb) {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
    );
  }
  await NotificationService.initialize();
  
  runApp(
    MultiProvider(
      providers: [
        Provider<AuthRepository>(
          create: (context) => AuthRepository(),
        ),
        ChangeNotifierProxyProvider<AuthRepository, AuthProvider>(
          create: (context) => AuthProvider(context.read<AuthRepository>()),
          update: (context, authRepository, authProvider) =>
              (authProvider ?? AuthProvider(authRepository))
                ..updateAuth(authRepository),
        ),
        ChangeNotifierProvider<ThemeProvider>(
          create: (context) => ThemeProvider(),
        ),
        ChangeNotifierProxyProvider<AuthProvider, UserProvider>(
          create: (context) => UserProvider(),
          update: (context, authProvider, userProvider) =>
              (userProvider ?? UserProvider())..updateAuth(authProvider),
        ),
        ChangeNotifierProxyProvider<AuthProvider, EmployeeProvider>(
          create: (context) => EmployeeProvider(),
          update: (context, authProvider, employeeProvider) =>
              (employeeProvider ?? EmployeeProvider())
                ..updateAuth(authProvider),
        ),
        ChangeNotifierProxyProvider<AuthProvider, BookingProvider>(
          create: (context) => BookingProvider(),
          update: (context, authProvider, bookingProvider) =>
              (bookingProvider ?? BookingProvider())..updateAuth(authProvider),
        ),
        ChangeNotifierProxyProvider<AuthProvider, ChatProvider>(
          create: (context) => ChatProvider(),
          update: (context, authProvider, chatProvider) =>
              (chatProvider ?? ChatProvider())..updateAuth(authProvider),
        ),
        ChangeNotifierProxyProvider<AuthProvider, NotificationProvider>(
          create: (context) => NotificationProvider(),
          update: (context, authProvider, notificationProvider) =>
              (notificationProvider ?? NotificationProvider())
                ..updateAuth(authProvider),
        ),
        ChangeNotifierProxyProvider<AuthProvider, ComplaintProvider>(
         create: (context) => ComplaintProvider(),
          update: (context, authProvider, complaintProvider) =>
            (complaintProvider ?? ComplaintProvider())..updateAuth(authProvider),
),
      ],
      child: const AssistHubApp(),
    ),
  );
}
