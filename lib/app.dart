import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:assisthub/providers/core/theme/app_theme.dart';
import 'package:assisthub/providers/core/theme/theme_provider.dart';
import 'package:assisthub/providers/core/constants/app_routes.dart';
import 'package:assisthub/presentation/splash/splash_screen.dart';
import 'package:assisthub/presentation/auth/role_selection_screen.dart';
import 'package:assisthub/presentation/auth/login_screen.dart';
import 'package:assisthub/presentation/auth/register_screen.dart';
import 'package:assisthub/presentation/customer/customer_main_screen.dart';
import 'package:assisthub/presentation/employee/employee_main_screen.dart';
import 'package:assisthub/presentation/employee/registration/employee_registration_screen.dart';
import 'package:assisthub/presentation/auth/role_picker_screen.dart';
import 'package:assisthub/presentation/customer/chat/chat_list_screen.dart';
import 'package:assisthub/presentation/customer/chat/chat_screen.dart';

class AssistHubApp extends StatelessWidget {
  const AssistHubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'AssistHub',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.themeMode,
          initialRoute: AppRoutes.splash,
          routes: {
            AppRoutes.splash: (_) => const SplashScreen(),
            AppRoutes.roleSelection: (_) => const RoleSelectionScreen(),
            AppRoutes.login: (_) => const LoginScreen(),
            AppRoutes.register: (_) => const RegisterScreen(),
            AppRoutes.customerMain: (_) => const CustomerMainScreen(),
            AppRoutes.employeeMain: (_) => const EmployeeMainScreen(),
            AppRoutes.employeeRegistration: (_) => const EmployeeRegistrationScreen(),
            AppRoutes.rolePicker: (_) => const RolePickerScreen(),
            AppRoutes.chatList: (_) => const ChatListScreen(),
          },
          // AppRoutes.chat isn't in the routes map above because it needs
          // arguments (chatRoomId, otherUserId, etc.) passed through —
          // onGenerateRoute is the standard way to handle that; it's only
          // consulted for route names not already found in `routes`.
          onGenerateRoute: (settings) {
            if (settings.name == AppRoutes.chat) {
              return MaterialPageRoute(
                builder: (_) => ChatScreen.fromRouteArgs(settings.arguments),
                settings: settings,
              );
            }
            return null;
          },
        );
      },
    );
  }
}