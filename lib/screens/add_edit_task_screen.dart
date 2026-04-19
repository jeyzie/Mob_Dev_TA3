import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:task_manager_app/constants/app_colors.dart';
import 'package:task_manager_app/constants/app_styles.dart';
import 'package:task_manager_app/models/task.dart';
import 'package:task_manager_app/widgets/custom_button.dart';
import 'package:provider/provider.dart';
import 'package:task_manager_app/providers/task_provider.dart';

class AddEditTaskScreen extends StatefulWidget {
  final Task? task;

  const AddEditTaskScreen({Key? key, this.task}) : super(key: key);

  @override
  State<AddEditTaskScreen> createState() => _AddEditTaskScreenState();
}

class _AddEditTaskScreenState extends State<AddEditTaskScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _selectedPriority;
  DateTime? _selectedDueDate;
  TimeOfDay? _selectedDueTime;

  final List<String> _priorities = ['High', 'Medium', 'Low'];

  @override
  void initState() {
    super.initState();
    if (widget.task != null) {
      _titleController.text = widget.task!.title;
      _descriptionController.text = widget.task!.description;
      _selectedPriority = widget.task!.priority;
      _selectedDueDate = widget.task!.dueDate;
      _selectedDueTime = widget.task!.dueDate != null
          ? TimeOfDay.fromDateTime(widget.task!.dueDate!)
          : null;
    }
  }

  Future<void> _saveTask() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        final taskProvider = Provider.of<TaskProvider>(context, listen: false);
        bool success;

        // Combine date and time into a single DateTime
        DateTime? combinedDueDateTime;
        if (_selectedDueDate != null) {
          if (_selectedDueTime != null) {
            combinedDueDateTime = DateTime(
              _selectedDueDate!.year,
              _selectedDueDate!.month,
              _selectedDueDate!.day,
              _selectedDueTime!.hour,
              _selectedDueTime!.minute,
            );
          } else {
            // If no time selected, use the date with default time (00:00)
            combinedDueDateTime = DateTime(
              _selectedDueDate!.year,
              _selectedDueDate!.month,
              _selectedDueDate!.day,
            );
          }
        }

        if (widget.task == null) {
          // Create new task
          success = await taskProvider.addTask(
            title: _titleController.text.trim(),
            description: _descriptionController.text.trim(),
            priority: _selectedPriority,
            dueDate: combinedDueDateTime,
          );
        } else {
          // Update existing task
          success = await taskProvider.updateTask(
            taskId: widget.task!.id,
            title: _titleController.text.trim(),
            description: _descriptionController.text.trim(),
            priority: _selectedPriority,
            dueDate: combinedDueDateTime,
          );
        }

        if (success && mounted) {
          Navigator.pop(context, true);
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error saving task: ${taskProvider.error}'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error saving task: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<void> _selectDueDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDueDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(primary: AppColors.primary),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDueDate = picked;
      });
    }
  }

  Future<void> _selectDueTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedDueTime ?? TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(primary: AppColors.primary),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDueTime = picked;
      });
    }
  }

  String _getDueDateTimeDisplay() {
    if (_selectedDueDate == null) return '';

    final dateStr = DateFormat('MMM dd, yyyy').format(_selectedDueDate!);
    final timeStr = _selectedDueTime != null ? ' at ${_selectedDueTime!.format(context)}' : '';

    return 'Due: $dateStr$timeStr';
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.task != null;
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyMedium!.color!;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Task' : 'Add New Task'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 80,
                width: 80,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isEditing ? Icons.edit : Icons.add_task,
                  size: 40,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 24),

              // Task Title field (now using the same styling as description)
              TextFormField(
                controller: _titleController,
                style: theme.textTheme.bodyMedium,
                decoration: InputDecoration(
                  labelText: 'Task Title',
                  labelStyle: AppStyles.bodyText2.copyWith(color: textColor),
                  prefixIcon: Icon(Icons.title, color: AppColors.primary),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: theme.cardColor,
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: const BorderSide(color: AppColors.primary, width: 2),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: const BorderSide(color: AppColors.error, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter task title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Description field
              TextFormField(
                controller: _descriptionController,
                maxLines: 4,
                style: theme.textTheme.bodyMedium,
                decoration: InputDecoration(
                  labelText: 'Description',
                  labelStyle: AppStyles.bodyText2.copyWith(color: textColor),
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: theme.cardColor,
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: const BorderSide(color: AppColors.primary, width: 2),
                  ),
                  contentPadding: const EdgeInsets.all(20),
                ),
              ),
              const SizedBox(height: 16),

              // Priority dropdown
              Container(
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(15),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: DropdownButtonFormField<String>(
                  value: _selectedPriority,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                  ),
                  hint: Text(
                    'Select Priority (Optional)',
                    style: AppStyles.bodyText2.copyWith(color: textColor.withOpacity(0.6)),
                  ),
                  items: _priorities.map((priority) {
                    return DropdownMenuItem(
                      value: priority,
                      child: Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: priority == 'High'
                                  ? AppColors.priorityHigh
                                  : priority == 'Medium'
                                      ? AppColors.priorityMedium
                                      : AppColors.priorityLow,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(priority, style: AppStyles.bodyText1.copyWith(color: textColor)),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedPriority = value;
                    });
                  },
                ),
              ),
              const SizedBox(height: 16),

              // Due date and time section
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Due Date & Time (Optional)',
                    style: AppStyles.bodyText2.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      // Date picker
                      Expanded(
                        child: InkWell(
                          onTap: _selectDueDate,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: theme.cardColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _selectedDueDate != null
                                    ? AppColors.primary.withOpacity(0.3)
                                    : Colors.transparent,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.calendar_today,
                                  color: AppColors.primary,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _selectedDueDate == null
                                        ? 'Select Date'
                                        : DateFormat('MMM dd, yyyy').format(_selectedDueDate!),
                                    style: AppStyles.bodyText2.copyWith(
                                      color: _selectedDueDate == null
                                          ? textColor.withOpacity(0.6)
                                          : textColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Time picker
                      Expanded(
                        child: InkWell(
                          onTap: _selectedDueDate == null ? null : _selectDueTime,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: _selectedDueDate == null
                                  ? theme.cardColor.withOpacity(0.5)
                                  : theme.cardColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _selectedDueTime != null
                                    ? AppColors.primary.withOpacity(0.3)
                                    : Colors.transparent,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.access_time,
                                  color: _selectedDueDate == null
                                      ? textColor.withOpacity(0.4)
                                      : AppColors.primary,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _selectedDueTime == null
                                        ? 'Select Time'
                                        : _selectedDueTime!.format(context),
                                    style: AppStyles.bodyText2.copyWith(
                                      color: _selectedDueDate == null
                                          ? textColor.withOpacity(0.4)
                                          : _selectedDueTime == null
                                              ? textColor.withOpacity(0.6)
                                              : textColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_selectedDueDate != null || _selectedDueTime != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _getDueDateTimeDisplay(),
                              style: AppStyles.bodyText2.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _selectedDueDate = null;
                                _selectedDueTime = null;
                              });
                            },
                            child: Text(
                              'Clear',
                              style: TextStyle(color: AppColors.error),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 32),

              CustomButton(
                text: isEditing ? 'Update Task' : 'Create Task',
                onPressed: _saveTask,
                isLoading: _isLoading,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}