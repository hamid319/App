import 'package:flutter/material.dart';

class GroupScreen extends StatelessWidget {
  const GroupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Group')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Group functionality will go here'),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {},
              child: const Text('Join or Create Group'),
            )
          ],
        ),
      ),
    );
  }
}
