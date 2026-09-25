import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:assisthub/providers/auth_provider.dart';
import 'package:assisthub/presentation/admin/admin_pending_employees_screen.dart';
import 'package:assisthub/presentation/admin/admin_history_screen.dart';
import 'package:assisthub/presentation/admin/admin_complaints_screen.dart';
import 'package:assisthub/presentation/admin/admin_notifications_screen.dart';

class AdminShellScreen extends StatefulWidget {
  const AdminShellScreen({super.key});

  @override
  State<AdminShellScreen> createState() => _AdminShellScreenState();
}

class _AdminShellScreenState extends State<AdminShellScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    AdminPendingEmployeesScreen(),
    AdminHistoryScreen(),
    AdminComplaintsScreen(),
    AdminNotificationsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.verified_user_outlined),
            selectedIcon: Icon(Icons.verified_user),
            label: 'Verify',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.report_outlined),
            selectedIcon: Icon(Icons.report),
            label: 'Complaints',
          ),
          NavigationDestination(
            icon: Icon(Icons.campaign_outlined),
            selectedIcon: Icon(Icons.campaign),
            label: 'Notify',
          ),
        ],
      ),
    );
  }
}
