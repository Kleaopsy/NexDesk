import 'package:flutter/material.dart';

class TasksScreen extends StatelessWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text('Tasks', style: Theme.of(context).textTheme.headlineMedium),
    );
  }
}
