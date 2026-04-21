import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:task_manager_app/constants/app_colors.dart';
import 'package:task_manager_app/constants/app_styles.dart';
import 'package:task_manager_app/models/task.dart';
import 'package:task_manager_app/widgets/task_card.dart';
import 'package:task_manager_app/screens/add_edit_task_screen.dart';
class OverdueTasksScreen extends StatefulWidget {
  const OverdueTasksScreen({super.key});

  @override
  State<OverdueTasksScreen> createState() => _OverdueTasksScreenState();
}

class _OverdueTasksScreenState extends State<OverdueTasksScreen> {
  final user = FirebaseAuth.instance.currentUser!;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now(); // Use current time instead of midnight

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('tasks')
          .where('userId', isEqualTo: user.uid)
          .where('isCompleted', isEqualTo: false)
          .orderBy('dueDate', descending: false) // closest first
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}', style: AppStyles.bodyText1));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final tasks = snapshot.data!.docs
            .map((doc) => Task.fromMap(doc.id, doc.data() as Map<String, dynamic>))
            .where((task) => task.dueDate != null && task.dueDate!.isBefore(now))
            .toList();

        if (tasks.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.task_alt, size: 80, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text('No overdue tasks!', style: AppStyles.heading3.copyWith(color: Colors.grey.shade400)),
                const SizedBox(height: 8),
                Text('Good job!', style: AppStyles.bodyText2.copyWith(color: Colors.grey.shade400)),
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
                  // reload will happen via stream
                }
              },
              onDelete: () => _showDeleteDialog(context, task),
              onToggle: (value) => _toggleTaskStatus(task, value ?? false),
            );
          },
        );
      },
    );
  }

  Future<void> _toggleTaskStatus(Task task, bool value) async {
    try {
      await FirebaseFirestore.instance.collection('tasks').doc(task.id).update({'isCompleted': value});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating task: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _showDeleteDialog(BuildContext context, Task task) async {
    bool isDeleting = false;
    
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Delete Task'),
          content: isDeleting 
            ? const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(width: 16),
                  Text('Deleting...'),
                ],
              )
            : Text('Are you sure you want to delete "${task.title}"?'),
          actions: [
            TextButton(
              onPressed: isDeleting ? null : () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: isDeleting
                ? null
                : () async {
                    setState(() => isDeleting = true);
                    try {
                      await FirebaseFirestore.instance.collection('tasks').doc(task.id).delete();
                      if (mounted) {
                        Navigator.pop(dialogContext);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Task deleted successfully'), backgroundColor: AppColors.success),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        setState(() => isDeleting = false);
                        Navigator.pop(dialogContext);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error deleting task: $e'), backgroundColor: AppColors.error),
                        );
                      }
                    }
                  },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                disabledBackgroundColor: AppColors.error.withOpacity(0.5),
              ),
              child: const Text('Delete'),
            ),
          ],
        ),
      ),
    );
  }
}