import 'package:flutter/material.dart';
import 'package:nexdesk/core/l10n/app_strings.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    AppStrings s = AppStrings.of(context);

    return Center(
      child: Text(
        s.dashboard,
        style: Theme.of(context).textTheme.headlineMedium,
      ),
    );
  }
}
