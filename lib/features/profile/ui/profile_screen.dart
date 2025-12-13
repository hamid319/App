import 'package:flutter/material.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            CircleAvatar(
              radius: 36,
              child: Icon(Icons.person, size: 40),
            ),
            SizedBox(height: 16),
            Text('Your Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
            SizedBox(height: 8),
            Text('you@email.com'),
            SizedBox(height: 18),
            Text('Favorites:', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            Text('- Grand Park'),
            Text('- City Art Museum'),
          ],
        ),
      ),
    );
  }
}
