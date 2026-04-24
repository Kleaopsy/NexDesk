import 'package:flutter/material.dart';
import 'package:nexdesk/core/l10n/app_strings.dart';

class ProjectsScreen extends StatelessWidget {
  const ProjectsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    AppStrings s = AppStrings.of(context);
    return Center(
      child: Text(
        s.myProjects,
        style: Theme.of(context).textTheme.headlineMedium,
      ),
    );
  }
}
