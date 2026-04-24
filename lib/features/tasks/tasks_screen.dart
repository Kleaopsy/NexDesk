import 'package:flutter/material.dart';
import 'package:nexdesk/core/l10n/app_strings.dart';

class TasksScreen extends StatelessWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    AppStrings s = AppStrings.of(context);

    return Center(
      child: Text(s.tasks, style: Theme.of(context).textTheme.headlineMedium),
    );
  }
}
