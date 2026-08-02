import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/auth_controller.dart';
import 'login_page.dart';

class AccountLockedPage extends StatelessWidget {
  const AccountLockedPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Account Locked'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.lock_outline, size: 72, color: Colors.redAccent),
            const SizedBox(height: 16),
            const Text(
              'Your account has been locked. Please contact support to restore access.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () async {
                // Ensure local storage is cleared and navigate to login.
                final auth = Provider.of<AuthController>(context, listen: false);
                await auth.logout();
                Navigator.of(context).pushNamedAndRemoveUntil('/login', (r) => false);
              },
              child: const Text('Go to Login'),
            ),
          ],
        ),
      ),
    );
  }
}
