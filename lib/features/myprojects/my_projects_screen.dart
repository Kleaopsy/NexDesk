import 'package:flutter/material.dart';

class ProjectsScreen extends StatelessWidget {
  const ProjectsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'My Projects',
        style: Theme.of(context).textTheme.headlineMedium,
      ),
    );
  }
}
