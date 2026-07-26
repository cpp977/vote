import 'package:flutter/material.dart';

import 'home_page.dart';
import '../pages/my_submissions_page.dart';
import '../pages/admin_submissions_page.dart';

/// Hosts the three top-level destinations (public questions, user submissions,
/// and admin review queue) behind a single shared navigation.
///
/// Switching between them uses [setState] rather than the [Navigator]. This
/// keeps everything inside [AuthGate]'s `home`, so logging out (which swaps
/// `home` for the login screen) is never blocked by a leftover route sitting
/// on the navigation stack.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _selectedIndex = 0;

  void _onSelect(BuildContext context, String route) {
    setState(() {
      // Index 0 = public questions, 1 = own submissions, 2 = admin review queue.
      if (route == 'submissions') {
        _selectedIndex = 1;
      } else if (route == 'admin') {
        _selectedIndex = 2;
      } else {
        _selectedIndex = 0;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedIndex == 2) {
      return AdminSubmissionsPage(onNavigate: _onSelect);
    }
    if (_selectedIndex == 1) {
      return MySubmissionsPage(onNavigate: _onSelect);
    }
    return MyHomePage(title: 'Vote', onNavigate: _onSelect);
  }
}
