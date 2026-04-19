import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import 'package:task_manager_app/constants/app_colors.dart';
import 'package:task_manager_app/constants/app_styles.dart';
import 'package:task_manager_app/models/task.dart';

class TaskCard extends StatelessWidget {
  final Task task;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final Function(bool?) onToggle;

  const TaskCard({
    Key? key,
    required this.task,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  }) : super(key: key);

  Color _getPriorityColor(String? priority) {
    switch (priority) {
      case 'High':
        return AppColors.priorityHigh;
      case 'Medium':
        return AppColors.priorityMedium;
      case 'Low':
        return AppColors.priorityLow;
      default:
        return Colors.grey;
    }
  }

  String _formatDueDateTime(DateTime dueDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDay = DateTime(dueDate.year, dueDate.month, dueDate.day);

    String dateStr;
    if (dueDay == today) {
      dateStr = 'Today';
    } else if (dueDay == today.add(const Duration(days: 1))) {
      dateStr = 'Tomorrow';
    } else {
      dateStr = DateFormat('MMM dd').format(dueDate);
    }

    // Only show time if it's not 00:00 (midnight)
    final hasTime = dueDate.hour != 0 || dueDate.minute != 0;
    if (hasTime) {
      final timeStr = DateFormat('h:mm a').format(dueDate);
      return 'Due: $dateStr at $timeStr';
    } else {
      return 'Due: $dateStr';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyMedium!.color!;
    final mutedColor = textColor.withOpacity(0.6);
    final cardColor = theme.cardColor;

    return Slidable(
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        children: [
          SlidableAction(
            onPressed: (context) => onEdit(),
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            icon: Icons.edit,
            label: 'Edit',
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(20)),
          ),
          SlidableAction(
            onPressed: (context) => onDelete(),
            backgroundColor: AppColors.error,
            foregroundColor: Colors.white,
            icon: Icons.delete,
            label: 'Delete',
            borderRadius: const BorderRadius.horizontal(right: Radius.circular(20)),
          ),
        ],
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
          border: task.isCompleted
              ? Border.all(color: AppColors.success.withOpacity(0.3))
              : null,
        ),
        child: Row(
          children: [
            Checkbox(
              value: task.isCompleted,
              onChanged: onToggle,
              activeColor: AppColors.success,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          task.title,
                          style: AppStyles.heading3.copyWith(
                            decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                            color: task.isCompleted ? mutedColor : textColor,
                          ),
                        ),
                      ),
                      if (task.priority != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _getPriorityColor(task.priority).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _getPriorityColor(task.priority),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            task.priority!,
                            style: AppStyles.caption.copyWith(
                              color: _getPriorityColor(task.priority),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (task.description.isNotEmpty) ...[
                    Text(
                      task.description,
                      style: AppStyles.bodyText2.copyWith(color: mutedColor),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                  ],
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 14,
                        color: mutedColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('MMM dd, yyyy').format(task.createdAt),
                        style: AppStyles.caption.copyWith(color: mutedColor),
                      ),
                      if (task.dueDate != null) ...[
                        const SizedBox(width: 12),
                        Icon(
                          Icons.event,
                          size: 14,
                          color: task.dueDate!.isBefore(DateTime.now())
                              ? AppColors.error
                              : AppColors.primary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            _formatDueDateTime(task.dueDate!),
                            style: AppStyles.caption.copyWith(
                              color: task.dueDate!.isBefore(DateTime.now())
                                  ? AppColors.error
                                  : AppColors.primary,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}