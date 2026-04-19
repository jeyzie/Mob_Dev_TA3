import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:task_manager_app/constants/app_colors.dart';
import 'package:task_manager_app/constants/app_styles.dart';
import 'package:task_manager_app/screens/tasks_screen.dart';
import 'package:task_manager_app/screens/overdue_tasks_screen.dart';
import 'package:task_manager_app/screens/settings_screen.dart';
import 'package:task_manager_app/screens/profile_screen.dart';
import 'package:task_manager_app/services/quote_service.dart';
import 'package:task_manager_app/screens/add_edit_task_screen.dart';
import 'package:task_manager_app/providers/user_provider.dart';
import 'package:task_manager_app/providers/task_provider.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = const [
    TasksScreen(),
    OverdueTasksScreen(),
    SizedBox.shrink(), // placeholder for quote button
    SettingsScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Load user data after first build (user is already signed in)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<UserProvider>(context, listen: false).loadUserData();
      Provider.of<TaskProvider>(context, listen: false).loadTasks();
    });
  }

  void _onItemTapped(int index) {
    if (index == 2) {
      _showQuoteDialog();
    } else {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  Future<void> _showQuoteDialog() async {
  // Show loading indicator
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => const Center(child: CircularProgressIndicator()),
  );

  try {
    // The service now returns quickly (≤2 seconds) thanks to the optimized timeouts.
    final quote = await QuoteService.fetchMotivationalQuote().timeout(
      const Duration(seconds: 2), // safety net, rarely hit
      onTimeout: () => 'Fetching quote took too long. Please try again.',
    );

    if (!mounted) return;
    Navigator.pop(context); // close loader

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.auto_awesome, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Inspiration'),
          ],
        ),
        content: Text(quote, style: Theme.of(context).textTheme.bodyMedium),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  } catch (e) {
    if (mounted) Navigator.pop(context); // close loader
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Failed to fetch quote: $e'), backgroundColor: AppColors.error),
    );
  }
}

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final avatarPath = userProvider.avatarPath;
    final displayName = userProvider.displayName;
    final bool showHeader = _selectedIndex == 0 || _selectedIndex == 1;
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyMedium!.color!;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            if (showHeader)
              Padding(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 8,
                  left: 20,
                  right: 20,
                  bottom: 8,
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ProfileScreen()),
                        );
                        // No need to reload – UserProvider already updated during profile edits
                      },
                      child: CircleAvatar(
                        radius: 24,
                        backgroundImage: avatarPath.isNotEmpty
                            ? AssetImage(avatarPath)
                            : null,
                        child: avatarPath.isEmpty
                            ? const Icon(Icons.person, size: 28)
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hello, $displayName!',
                            style: AppStyles.heading2.copyWith(
                              fontSize: 18,
                              color: textColor,
                            ),
                          ),
                          Text(
                            'Ready to conquer your tasks?',
                            style: TextStyle(
                              color: textColor.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: _screens[_selectedIndex],
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: Colors.grey,
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.task), label: 'Tasks'),
          const BottomNavigationBarItem(icon: Icon(Icons.warning), label: 'Overdue'),
          BottomNavigationBarItem(
            icon: Image.asset(
              'assets/app-icon/icon.png',
              width: 55,
              height: 55,
            ),
            activeIcon: Image.asset(
              'assets/app-icon/icon.png',
              width: 55,
              height: 55,
            ),
            label: 'Quote',
          ),
          const BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
          const BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton.extended(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AddEditTaskScreen()),
                );
                if (result == true && mounted) {
                  // Refresh will happen via stream
                }
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Task'),
              backgroundColor: AppColors.primary,
            )
          : null,
    );
  }
}