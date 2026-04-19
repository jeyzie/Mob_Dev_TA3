import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:task_manager_app/constants/app_colors.dart';
import 'package:task_manager_app/providers/settings_provider.dart';
import 'package:task_manager_app/services/auth_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _showLogoutDialog(BuildContext context) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final authService = AuthService();
              await authService.signOut();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context, listen: true);
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyMedium!.color!;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.dark_mode),
              title: Text('Dark Mode', style: TextStyle(color: textColor)),
              trailing: Switch(
                value: settings.themeMode == ThemeMode.dark,
                onChanged: (value) => settings.toggleTheme(value),
                activeThumbColor: AppColors.primary,
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.text_fields),
              title: Text('Text Size', style: TextStyle(color: textColor)),
              subtitle: Text(
                'Current: ${settings.textScaleFactor.toStringAsFixed(1)}x',
                style: TextStyle(color: textColor.withValues(alpha: 0.6)),
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => _showTextSizeDialog(context, settings),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout', style: TextStyle(color: Colors.red)),
              onTap: () => _showLogoutDialog(context),
            ),
          ],
        ),
      ),
    );
  }

  void _showTextSizeDialog(BuildContext context, SettingsProvider settings) {
    double tempScale = settings.textScaleFactor;
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Adjust Text Size'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Slider(
                  value: tempScale,
                  min: 0.8,
                  max: 1.5,
                  divisions: 7,
                  label: '${tempScale.toStringAsFixed(1)}x',
                  onChanged: (value) {
                    setState(() => tempScale = value);
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  'Preview text size',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 16 * tempScale,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  settings.setTextScaleFactor(tempScale);
                  Navigator.pop(context);
                },
                child: const Text('Apply'),
              ),
            ],
          );
        },
      ),
    );
  }
}