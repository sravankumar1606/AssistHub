import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:assisthub/providers/core/constants/app_strings.dart';
import 'package:assisthub/providers/notification_provider.dart';
import 'package:assisthub/providers/chat_provider.dart';
import 'package:assisthub/presentation/employee/home/employee_home_screen.dart';
import 'package:assisthub/presentation/employee/booking/employee_booking_screen.dart';
import 'package:assisthub/presentation/employee/notification/employee_notifications_screen.dart';
import 'package:assisthub/presentation/employee/profile/employee_profile_screen.dart';
class EmployeeMainScreen extends StatefulWidget {
  const EmployeeMainScreen({super.key});

  @override
  State<EmployeeMainScreen> createState() => _EmployeeMainScreenState();
}

class _EmployeeMainScreenState extends State<EmployeeMainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    EmployeeHomeScreen(),
    EmployeeBookingsScreen(),
    EmployeeNotificationsScreen(),
    EmployeeProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Consumer2<NotificationProvider, ChatProvider>(
        builder: (context, notificationProvider, chatProvider, child) {
          final combinedUnread =
              notificationProvider.unreadCount + chatProvider.unreadCount;

          return NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (index) {
              setState(() => _currentIndex = index);
            },
            destinations: [
              const NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: AppStrings.home,
              ),
              const NavigationDestination(
                icon: Icon(Icons.calendar_today_outlined),
                selectedIcon: Icon(Icons.calendar_today),
                label: AppStrings.bookings,
              ),
              NavigationDestination(
                icon: Badge(
                  isLabelVisible: combinedUnread > 0,
                  label: Text('$combinedUnread'),
                  child: const Icon(Icons.notifications_outlined),
                ),
                selectedIcon: Badge(
                  isLabelVisible: combinedUnread > 0,
                  label: Text('$combinedUnread'),
                  child: const Icon(Icons.notifications),
                ),
                label: AppStrings.notifications,
              ),
              const NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: AppStrings.profile,
              ),
            ],
          );
        },
      ),
    );
  }
}