import 'package:flutter/material.dart';

class NotesScreen extends StatelessWidget {
  const NotesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Quick Notes',
        style: Theme.of(context).textTheme.headlineMedium,
      ),
    );
  }
}
