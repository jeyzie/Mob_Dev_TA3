import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:task_manager_app/constants/app_colors.dart';
import 'package:task_manager_app/constants/app_styles.dart';
import 'package:task_manager_app/models/task.dart';
import 'package:task_manager_app/providers/task_provider.dart';
import 'package:task_manager_app/widgets/task_card.dart';
import 'package:task_manager_app/screens/add_edit_task_screen.dart';
import 'package:task_manager_app/services/quote_service.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  final user = FirebaseAuth.instance.currentUser!;
  String _filter = 'All';

  Future<void> _showCompletionQuote() async {
    final quote = await QuoteService.fetchMotivationalQuote();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(quote),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _toggleTaskStatus(Task task, bool value) async {
    try {
      await FirebaseFirestore.instance
          .collection('tasks')
          .doc(task.id)
          .update({'isCompleted': value});
      if (value) {
        await _showCompletionQuote();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating task: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _showDeleteDialog(BuildContext context, Task task) async {
    final theme = Theme.of(context);
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Task'),
        content: Text('Are you sure you want to delete "${task.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: theme.textTheme.bodyMedium?.color)),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await FirebaseFirestore.instance.collection('tasks').doc(task.id).delete();
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Task deleted successfully'), backgroundColor: AppColors.success),
                  );
                }
              } catch (e) {
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error deleting task: $e'), backgroundColor: AppColors.error),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyMedium!.color!;
    final mutedTextColor = textColor.withOpacity(0.6);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              FilterChip(
                label: Text('All'),
                selected: _filter == 'All',
                onSelected: (_) => setState(() => _filter = 'All'),
                selectedColor: AppColors.primary,
                checkmarkColor: Colors.white,
                labelStyle: TextStyle(
                  color: _filter == 'All' ? Colors.white : textColor,
                ),
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: Text('Active'),
                selected: _filter == 'Active',
                onSelected: (_) => setState(() => _filter = 'Active'),
                selectedColor: AppColors.warning,
                checkmarkColor: Colors.white,
                labelStyle: TextStyle(
                  color: _filter == 'Active' ? Colors.white : textColor,
                ),
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: Text('Completed'),
                selected: _filter == 'Completed',
                onSelected: (_) => setState(() => _filter = 'Completed'),
                selectedColor: AppColors.success,
                checkmarkColor: Colors.white,
                labelStyle: TextStyle(
                  color: _filter == 'Completed' ? Colors.white : textColor,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('tasks')
                .where('userId', isEqualTo: user.uid)
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}', style: AppStyles.bodyText1));
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              var tasks = snapshot.data!.docs
                  .map((doc) => Task.fromMap(doc.id, doc.data() as Map<String, dynamic>))
                  .where((task) {
                    if (_filter == 'Active') return !task.isCompleted;
                    if (_filter == 'Completed') return task.isCompleted;
                    return true;
                  })
                  .toList();

              if (tasks.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.task_alt, size: 80, color: mutedTextColor),
                      const SizedBox(height: 16),
                      Text(
                        'No tasks found',
                        style: AppStyles.heading3.copyWith(color: mutedTextColor),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _filter == 'All'
                            ? 'Tap + to add a new task'
                            : 'No $_filter tasks',
                        style: AppStyles.bodyText2.copyWith(color: mutedTextColor),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: tasks.length,
                itemBuilder: (context, index) {
                  final task = tasks[index];
                  return TaskCard(
                    task: task,
                    onEdit: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => AddEditTaskScreen(task: task)),
                      );
                      if (result == true && mounted) {
                        Provider.of<TaskProvider>(context, listen: false).loadTasks();
                      }
                    },
                    onDelete: () => _showDeleteDialog(context, task),
                    onToggle: (value) => _toggleTaskStatus(task, value ?? false),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}