import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:assisthub/providers/core/constants/app_colors.dart'; // Kept as relative if working
import 'package:assisthub/providers/core/constants/app_strings.dart'; // Kept as relative if working
import 'package:assisthub/providers/notification_provider.dart'; // Fixed relative path match
import 'package:assisthub/presentation/customer/home/customer_home_screen.dart';
import 'package:assisthub/presentation/customer/services/services_screen.dart';
import 'package:assisthub/presentation/customer/notifications/customer_notification_screen.dart';
import 'package:assisthub/presentation/customer/profile/customer_profile_screen.dart';
class CustomerMainScreen extends StatefulWidget {
  const CustomerMainScreen({super.key});

  @override
  State<CustomerMainScreen> createState() => _CustomerMainScreenState();
}

class _CustomerMainScreenState extends State<CustomerMainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    CustomerHomeScreen(),
    ServicesScreen(),
    CustomerNotificationsScreen(),
    CustomerProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Consumer<NotificationProvider>(
        builder: (context, notificationProvider, child) {
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
                icon: Icon(Icons.category_outlined),
                selectedIcon: Icon(Icons.category),
                label: AppStrings.services,
              ),
              NavigationDestination(
                icon: Badge(
                  isLabelVisible: notificationProvider.unreadCount > 0,
                  label: Text('${notificationProvider.unreadCount}'),
                  child: const Icon(Icons.notifications_outlined),
                ),
                selectedIcon: Badge(
                  isLabelVisible: notificationProvider.unreadCount > 0,
                  label: Text('${notificationProvider.unreadCount}'),
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
