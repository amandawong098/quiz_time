import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/widgets/byte_mascot.dart';
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
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthRepository>().currentUser;
    _nameController.text = user?.userMetadata?['name'] ?? '';
    _emailController.text = user?.email ?? '';
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
      if (msg.contains('already registered') ||
          error.code == 'user_already_exists') {
        return 'This email address is already in use by another account.';
      }
      if (msg.contains('password') &&
          (msg.contains('6') || msg.contains('short'))) {
        return 'Password must be at least 6 characters long.';
      }
      return error.message;
    }
    final errorStr = error.toString();
    if (errorStr.contains('email_address_invalid') ||
        errorStr.toLowerCase().contains('is invalid')) {
      return 'Please enter a valid email address.';
    }
    if (errorStr.contains('user_already_exists') ||
        errorStr.toLowerCase().contains('already registered')) {
      return 'This email address is already in use by another account.';
    }
    if (errorStr.toLowerCase().contains('password') &&
        (errorStr.contains('6') || errorStr.toLowerCase().contains('short'))) {
      return 'Password must be at least 6 characters long.';
    }
    final match = RegExp(r'message:\s*([^,]+)').firstMatch(errorStr);
    if (match != null && match.group(1) != null) {
      return match.group(1)!.trim();
    }
    return errorStr.replaceAll(RegExp(r'AuthApiException\(|\)'), '').trim();
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
            updateAvatar: false,
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
    final isAdmin = context.watch<AuthRepository>().isAdmin;

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
              child: Column(
                children: [
                  UserByteAvatar(
                    isCurrentUser: true,
                    radius: 56,
                    onTap: isAdmin ? null : () => context.push('/space-cabin'),
                  ),
                  if (!isAdmin) ...[
                    const SizedBox(height: 10),
                    TextButton.icon(
                      onPressed: () => context.push('/space-cabin'),
                      icon: const Icon(Icons.videogame_asset_rounded, size: 18),
                      label: const Text(
                        'Customize Byte Avatar',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
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
