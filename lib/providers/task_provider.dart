import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:task_manager_app/models/task.dart';
import 'package:task_manager_app/services/notification_service.dart';
import 'package:intl/intl.dart';
import 'dart:async';

class TaskProvider extends ChangeNotifier {
  List<Task> _tasks = [];
  bool _isLoading = false;
  String? _error;
  Timer? _overdueCheckTimer;
  final Set<String> _notifiedOverdueTasks = {}; // Track tasks we've already notified about

  List<Task> get tasks => _tasks;
  bool get isLoading => _isLoading;
  String? get error => _error;

  final NotificationService _notificationService = NotificationService();

  void _startOverdueMonitoring() {
    // Check for overdue tasks every minute
    _overdueCheckTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _checkForOverdueTasks();
    });
  }

  void _stopOverdueMonitoring() {
    _overdueCheckTimer?.cancel();
    _overdueCheckTimer = null;
  }

  Future<void> _checkForOverdueTasks() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final now = DateTime.now();
      final snapshot = await FirebaseFirestore.instance
          .collection('tasks')
          .where('userId', isEqualTo: user.uid)
          .where('isCompleted', isEqualTo: false)
          .get();

      final tasks = snapshot.docs.map((doc) => Task.fromMap(doc.id, doc.data())).toList();

      for (final task in tasks) {
        if (task.dueDate != null &&
            task.dueDate!.isBefore(now) &&
            !_notifiedOverdueTasks.contains(task.id)) {
          // Task just became overdue - send notification
          final timeOverdue = now.difference(task.dueDate!);
          String overdueMessage;

          if (timeOverdue.inMinutes < 60) {
            overdueMessage = 'Your task "${task.title}" is now ${timeOverdue.inMinutes} minutes overdue!';
          } else if (timeOverdue.inHours < 24) {
            overdueMessage = 'Your task "${task.title}" is now ${timeOverdue.inHours} hours overdue!';
          } else {
            overdueMessage = 'Your task "${task.title}" is now ${timeOverdue.inDays} days overdue!';
          }

          await _notificationService.showLocalNotification(
            title: 'Task Overdue',
            body: overdueMessage,
          );

          // Mark this task as notified
          _notifiedOverdueTasks.add(task.id);
        }
      }
    } catch (e) {
      print('Error checking for overdue tasks: $e');
    }
  }

  TaskProvider() {
    _startOverdueMonitoring();
  }

  Future<void> _scheduleTaskNotifications(Task task, DateTime dueDate) async {
    final now = DateTime.now();

    // Always schedule the main due notification
    String notificationTitle = 'Task Due';
    String notificationBody;

    if (dueDate.isBefore(now)) {
      // Task is already overdue - show notification immediately
      notificationTitle = 'Task Overdue';
      notificationBody = 'Your task "${task.title}" was due ${dueDate.isBefore(now.subtract(const Duration(days: 1))) ? 'earlier' : 'today'}';
      await _notificationService.showLocalNotification(
        title: notificationTitle,
        body: notificationBody,
      );
    } else {
      // Schedule notification for due time
      final timeUntilDue = dueDate.difference(now);

      if (timeUntilDue.inHours < 24) {
        notificationBody = 'Your task "${task.title}" is due today at ${DateFormat('h:mm a').format(dueDate)}';
      } else if (timeUntilDue.inDays == 1) {
        notificationBody = 'Your task "${task.title}" is due tomorrow at ${DateFormat('h:mm a').format(dueDate)}';
      } else {
        notificationBody = 'Your task "${task.title}" is due on ${DateFormat('MMM dd').format(dueDate)} at ${DateFormat('h:mm a').format(dueDate)}';
      }

      await _notificationService.scheduleDueNotification(
        id: task.id.hashCode,
        title: notificationTitle,
        body: notificationBody,
        scheduledDate: dueDate,
      );

      // Schedule a reminder notification based on time until due
      if (timeUntilDue.inMinutes > 1) { // Allow reminders for tasks due in more than 1 minute
        DateTime reminderTime;
        String reminderMessage;
        int reminderMinutesBefore;

        if (timeUntilDue.inMinutes <= 5) {
          // For tasks due in 2-5 minutes, send URGENT notification immediately
          reminderMessage = '🚨 URGENT: "${task.title}" is due in ${timeUntilDue.inMinutes} minutes!';
          await _notificationService.showLocalNotification(
            title: 'URGENT Task Reminder',
            body: reminderMessage,
          );
          
          // Also schedule another URGENT notification 1 minute before due time
          reminderMinutesBefore = 1;
          reminderTime = dueDate.subtract(Duration(minutes: reminderMinutesBefore));
          if (reminderTime.isAfter(now)) {
            await _notificationService.scheduleDueNotification(
              id: task.id.hashCode + 1,
              title: 'URGENT - Task Due Soon!',
              body: '🚨 URGENT: "${task.title}" is due in 1 minute!',
              scheduledDate: reminderTime,
            );
          }
        } else if (timeUntilDue.inMinutes <= 15) {
          // For tasks due in 6-15 minutes, remind 2 minutes before
          reminderMinutesBefore = 2;
          reminderTime = dueDate.subtract(Duration(minutes: reminderMinutesBefore));
          reminderMessage = 'Reminder: "${task.title}" is due in $reminderMinutesBefore minutes';
          if (reminderTime.isAfter(now)) {
            await _notificationService.scheduleDueNotification(
              id: task.id.hashCode + 1,
              title: 'Task Reminder',
              body: reminderMessage,
              scheduledDate: reminderTime,
            );
          }
        } else if (timeUntilDue.inMinutes <= 60) {
          // For tasks due in 16-60 minutes, remind 5 minutes before
          reminderMinutesBefore = 5;
          reminderTime = dueDate.subtract(Duration(minutes: reminderMinutesBefore));
          reminderMessage = 'Reminder: "${task.title}" is due in $reminderMinutesBefore minutes';
          if (reminderTime.isAfter(now)) {
            await _notificationService.scheduleDueNotification(
              id: task.id.hashCode + 1,
              title: 'Task Reminder',
              body: reminderMessage,
              scheduledDate: reminderTime,
            );
          }
        } else {
          // For tasks due in more than 1 hour, remind 15 minutes before
          reminderMinutesBefore = 15;
          reminderTime = dueDate.subtract(Duration(minutes: reminderMinutesBefore));
          reminderMessage = 'Reminder: "${task.title}" is due in 15 minutes';
          if (reminderTime.isAfter(now)) {
            await _notificationService.scheduleDueNotification(
              id: task.id.hashCode + 1,
              title: 'Task Reminder',
              body: reminderMessage,
              scheduledDate: reminderTime,
            );
          }
        }
      }
    }
  }

  Future<void> loadTasks() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _error = 'User not authenticated';
        return;
      }

      final snapshot = await FirebaseFirestore.instance
          .collection('tasks')
          .where('userId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .get();

      _tasks = snapshot.docs
          .map((doc) => Task.fromMap(doc.id, doc.data()))
          .toList();
      
      // Reset notified tasks when loading fresh data
      _notifiedOverdueTasks.clear();
      
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addTask({
    required String title,
    required String description,
    String? priority,
    DateTime? dueDate,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _error = 'User not authenticated';
        notifyListeners();
        return false;
      }

      final docRef = await FirebaseFirestore.instance.collection('tasks').add({
        'title': title,
        'description': description,
        'isCompleted': false,
        'createdAt': FieldValue.serverTimestamp(),
        'userId': user.uid,
        'priority': priority,
        'dueDate': dueDate != null ? Timestamp.fromDate(dueDate) : null,
      });

      final newTask = Task(
        id: docRef.id,
        title: title,
        description: description,
        isCompleted: false,
        createdAt: DateTime.now(),
        userId: user.uid,
        priority: priority,
        dueDate: dueDate,
      );

      _tasks.insert(0, newTask);

      // Schedule notification if due date is set
      if (dueDate != null) {
        await _scheduleTaskNotifications(newTask, dueDate);
      }

      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateTask({
    required String taskId,
    String? title,
    String? description,
    bool? isCompleted,
    String? priority,
    DateTime? dueDate,
  }) async {
    try {
      final updateData = <String, dynamic>{};
      if (title != null) updateData['title'] = title;
      if (description != null) updateData['description'] = description;
      if (isCompleted != null) updateData['isCompleted'] = isCompleted;
      if (priority != null) updateData['priority'] = priority;
      if (dueDate != null) {
        updateData['dueDate'] = Timestamp.fromDate(dueDate);
      }

      await FirebaseFirestore.instance
          .collection('tasks')
          .doc(taskId)
          .update(updateData);

      // Update local task
      final taskIndex = _tasks.indexWhere((task) => task.id == taskId);
      if (taskIndex != -1) {
        final updatedTask = _tasks[taskIndex].copyWith(
          title: title,
          description: description,
          isCompleted: isCompleted,
          priority: priority,
          dueDate: dueDate,
        );
        _tasks[taskIndex] = updatedTask;

        // Cancel existing notification and schedule new one if needed
        await _notificationService.cancelNotification(taskId.hashCode);
        await _notificationService.cancelNotification(taskId.hashCode + 1); // Cancel reminder too
        if (dueDate != null && !(isCompleted ?? false)) {
          await _scheduleTaskNotifications(updatedTask, dueDate);
        }

        // If task was completed, remove from notified set so it can notify again if needed
        if (isCompleted == true) {
          _notifiedOverdueTasks.remove(taskId);
        }
      }

      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteTask(String taskId) async {
    try {
      await FirebaseFirestore.instance.collection('tasks').doc(taskId).delete();
      _tasks.removeWhere((task) => task.id == taskId);

      // Cancel notification
      await _notificationService.cancelNotification(taskId.hashCode);
      await _notificationService.cancelNotification(taskId.hashCode + 1); // Cancel reminder too

      // Remove from notified set
      _notifiedOverdueTasks.remove(taskId);

      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _stopOverdueMonitoring();
    super.dispose();
  }
}