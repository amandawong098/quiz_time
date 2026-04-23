import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/repositories/auth_repository.dart';
import 'package:quiz_time/l10n/app_localizations.dart';

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

  Future<void> _showImagePickerOptions() async {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text(l10n.gallery),
              onTap: () {
                Navigator.pop(context);
                _pickAndUploadAvatar(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: Text(l10n.camera),
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
        setState(() => _isSaving = true);
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
      setState(() => _isSaving = false);
      _showErrorDialog(e.toString());
    }
  }

  Future<void> _removeAvatar() async {
    setState(() => _avatarUrl = null);
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(ctx)!.notification),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveChanges() async {
    setState(() => _isSaving = true);
    try {
      final oldEmail = context.read<AuthRepository>().currentUser?.email;
      final newEmail = _emailController.text.trim();
      bool emailChanged = newEmail != oldEmail;

      await context.read<AuthRepository>().updateProfile(
        name: _nameController.text.trim(),
        email: emailChanged ? newEmail : null,
        password: _passwordController.text.isEmpty
            ? null
            : _passwordController.text,
        avatarUrl: _avatarUrl,
      );

      if (mounted) {
        if (emailChanged) {
          await showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(AppLocalizations.of(ctx)!.verificationRequired),
              content: Text(
                AppLocalizations.of(ctx)!.verificationSentDesc(newEmail),
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
      setState(() => _isSaving = false);
      _showErrorDialog(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.editProfile),
        actions: [
          if (_isSaving)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _saveChanges,
              child: Text(
                l10n.save,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
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
              decoration: InputDecoration(
                labelText: l10n.displayName,
                prefixIcon: const Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: l10n.email,
                prefixIcon: const Icon(Icons.email_outlined),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(
                labelText: l10n.changePassword,
                prefixIcon: const Icon(Icons.lock_outline),
                helperText: l10n.leaveBlankToKeepCurrent,
              ),
              obscureText: true,
            ),
          ],
        ),
      ),
    );
  }
}
