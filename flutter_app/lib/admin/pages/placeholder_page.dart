import 'package:flutter/material.dart';

import '../../mock_ui/theme/app_colors.dart';
import '../widgets/admin_ui.dart';

class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({super.key, required this.title, required this.description});
  final String title, description;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(32),
        child: AdminCard(
          padding: const EdgeInsets.symmetric(vertical: 72),
          child: Column(children: [
            const Icon(Icons.construction_rounded, size: 36, color: AppColors.ink4),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.ink9)),
            const SizedBox(height: 8),
            Text(description, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.ink5)),
          ]),
        ),
      );
}
