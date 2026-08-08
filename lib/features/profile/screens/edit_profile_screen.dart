import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/repositories/auth_repository.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSaving = false;
  String? _avatarUrl;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthRepository>().currentUser;
    _nameController.text = user?.userMetadata?['name'] ?? '';
    _emailController.text = user?.email ?? '';
    _avatarUrl = user?.userMetadata?['avatar_url'];
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String _formatErrorMessage(dynamic error) {
    if (error is AuthException) {
      final msg = error.message.toLowerCase();
      if (msg.contains('invalid') || error.code == 'email_address_invalid') {
        return 'Please enter a valid email address.';
      }
      if (msg.contains('already registered') || error.code == 'user_already_exists') {
        return 'This email address is already in use by another account.';
      }
      if (msg.contains('password') && (msg.contains('6') || msg.contains('short'))) {
        return 'Password must be at least 6 characters long.';
      }
      return error.message;
    }
    final errorStr = error.toString();
    if (errorStr.contains('email_address_invalid') || errorStr.toLowerCase().contains('is invalid')) {
      return 'Please enter a valid email address.';
    }
    if (errorStr.contains('user_already_exists') || errorStr.toLowerCase().contains('already registered')) {
      return 'This email address is already in use by another account.';
    }
    if (errorStr.toLowerCase().contains('password') && (errorStr.contains('6') || errorStr.toLowerCase().contains('short'))) {
      return 'Password must be at least 6 characters long.';
    }
    final match = RegExp(r'message:\s*([^,]+)').firstMatch(errorStr);
    if (match != null && match.group(1) != null) {
      return match.group(1)!.trim();
    }
    return errorStr.replaceAll(RegExp(r'AuthApiException\(|\)'), '').trim();
  }

  Future<void> _showImagePickerOptions() async {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickAndUploadAvatar(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () {
                Navigator.pop(context);
                _pickAndUploadAvatar(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndUploadAvatar(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: source);
      if (pickedFile != null) {
        setState(() {
          _isSaving = true;
          _errorMessage = null;
        });
        final file = File(pickedFile.path);
        final fileName = 'avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';

        await Supabase.instance.client.storage
            .from('profile_pictures')
            .upload(fileName, file);

        final url = Supabase.instance.client.storage
            .from('profile_pictures')
            .getPublicUrl(fileName);

        setState(() {
          _avatarUrl = url;
          _isSaving = false;
        });
      }
    } catch (e) {
      setState(() {
        _isSaving = false;
        _errorMessage = _formatErrorMessage(e);
      });
    }
  }

  Future<void> _removeAvatar() async {
    setState(() => _avatarUrl = null);
  }

  Future<void> _saveChanges() async {
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final oldEmail = context.read<AuthRepository>().currentUser?.email;
    final newEmail = _emailController.text.trim();
    final newPassword = _passwordController.text;
    bool emailChanged = newEmail != oldEmail;

    if (emailChanged && newEmail.isNotEmpty) {
      final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
      if (!emailRegex.hasMatch(newEmail)) {
        setState(() {
          _isSaving = false;
          _errorMessage = 'Please enter a valid email address.';
        });
        return;
      }
    }

    if (newPassword.isNotEmpty && newPassword.length < 6) {
      setState(() {
        _isSaving = false;
        _errorMessage = 'Password must be at least 6 characters long.';
      });
      return;
    }

    try {
      await context.read<AuthRepository>().updateProfile(
        name: _nameController.text.trim(),
        email: emailChanged ? newEmail : null,
        password: newPassword.isEmpty ? null : newPassword,
        avatarUrl: _avatarUrl,
        updateAvatar: true,
      );

      if (mounted) {
        if (emailChanged) {
          await showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Verification Required'),
              content: Text(
                'A confirmation link has been sent to $newEmail. Your email will be updated once you click the link.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
        if (mounted) Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() {
        _isSaving = false;
        _errorMessage = _formatErrorMessage(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        actions: [
          if (_isSaving)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.save_rounded, color: Colors.white),
              tooltip: 'Save Profile',
              onPressed: _saveChanges,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundImage: _avatarUrl != null
                        ? NetworkImage(_avatarUrl!)
                        : null,
                    child: _avatarUrl == null
                        ? const Icon(Icons.person, size: 60)
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        color: _avatarUrl == null ? Colors.deepPurple : Colors.red,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: IconButton(
                        icon: Icon(
                          _avatarUrl == null ? Icons.camera_alt : Icons.delete,
                          size: 20,
                          color: Colors.white,
                        ),
                        onPressed: _avatarUrl == null
                            ? _showImagePickerOptions
                            : _removeAvatar,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _nameController,
              onChanged: (_) {
                if (_errorMessage != null) setState(() => _errorMessage = null);
              },
              decoration: const InputDecoration(
                labelText: 'Display Name',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emailController,
              onChanged: (_) {
                if (_errorMessage != null) setState(() => _errorMessage = null);
              },
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              onChanged: (_) {
                if (_errorMessage != null) setState(() => _errorMessage = null);
              },
              decoration: const InputDecoration(
                labelText: 'Change Password (optional)',
                prefixIcon: Icon(Icons.lock_outline),
                helperText: 'Leave blank to keep current password',
              ),
              obscureText: true,
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      color: Colors.red.shade700,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
