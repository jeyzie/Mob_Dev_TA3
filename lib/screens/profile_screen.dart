import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:task_manager_app/constants/app_colors.dart';
import 'package:task_manager_app/providers/user_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final user = FirebaseAuth.instance.currentUser!;
  final firestore = FirebaseFirestore.instance;

  String _displayName = '';
  String _avatarPath = '';
  bool _isLoading = false;

  final List<String> _avatars = [
    'assets/avatars/avatar1.png',
    'assets/avatars/avatar2.png',
    'assets/avatars/avatar3.png',
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final doc = await firestore.collection('users').doc(user.uid).get();
    if (doc.exists) {
      setState(() {
        _displayName = doc.data()?['displayName'] ?? user.email!;
        _avatarPath = doc.data()?['avatarPath'] ?? _avatars[0];
      });
    } else {
      await firestore.collection('users').doc(user.uid).set({
        'email': user.email,
        'displayName': user.email,
        'avatarPath': _avatars[0],
        'createdAt': FieldValue.serverTimestamp(),
      });
      _displayName = user.email!;
      _avatarPath = _avatars[0];
    }
  }

  Future<void> _updateDisplayName() async {
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Name'),
        content: TextField(
          controller: TextEditingController(text: _displayName),
          onChanged: (value) => _displayName = value,
          decoration: const InputDecoration(hintText: 'Enter your name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, _displayName),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (newName != null && newName.isNotEmpty) {
      setState(() => _isLoading = true);
      try {
        await firestore.collection('users').doc(user.uid).update({
          'displayName': newName,
        });
        // Update the provider so the main screen updates instantly
        Provider.of<UserProvider>(context, listen: false).updateUser(displayName: newName);
        setState(() {
          _displayName = newName;
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Name updated'), backgroundColor: AppColors.success),
        );
      } catch (e) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  void _showAvatarPicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose Avatar'),
        content: SizedBox(
          width: double.maxFinite,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: _avatars.map((path) {
              return GestureDetector(
                onTap: () async {
                  setState(() => _isLoading = true);
                  try {
                    await firestore.collection('users').doc(user.uid).update({'avatarPath': path});
                    // Update the provider so the main screen updates instantly
                    Provider.of<UserProvider>(context, listen: false).updateUser(avatarPath: path);
                    setState(() {
                      _avatarPath = path;
                      _isLoading = false;
                    });
                    if (mounted) Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Avatar updated'), backgroundColor: AppColors.success),
                    );
                  } catch (e) {
                    setState(() => _isLoading = false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
                    );
                  }
                },
                child: CircleAvatar(
                  radius: 40,
                  backgroundImage: AssetImage(path),
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyMedium!.color!;
    final mutedColor = textColor.withOpacity(0.6);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: _showAvatarPicker,
                    child: CircleAvatar(
                      radius: 60,
                      backgroundImage: AssetImage(_avatarPath),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _showAvatarPicker,
                    child: Text('Change Avatar', style: TextStyle(color: AppColors.primary)),
                  ),
                  const SizedBox(height: 20),
                  ListTile(
                    leading: const Icon(Icons.person),
                    title: Text('Display Name', style: TextStyle(color: textColor)),
                    subtitle: Text(_displayName, style: TextStyle(color: mutedColor)),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: _updateDisplayName,
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.email),
                    title: Text('Email', style: TextStyle(color: textColor)),
                    subtitle: Text(user.email!, style: TextStyle(color: mutedColor)),
                  ),
                ],
              ),
            ),
    );
  }
}