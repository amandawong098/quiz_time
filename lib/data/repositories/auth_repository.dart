import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthRepository extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  User? _currentUser;

  AuthRepository() {
    _currentUser = _supabase.auth.currentUser;
    _supabase.auth.onAuthStateChange.listen((data) {
      _currentUser = data.session?.user;
      notifyListeners();
    });
  }

  User? get currentUser => _currentUser;

  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  Future<AuthResponse> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    final response = await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
    _currentUser = response.user;
    notifyListeners();
    return response;
  }

  Future<AuthResponse> signUpWithEmailPassword({
    required String email,
    required String password,
    required String name,
  }) async {
    final response = await _supabase.auth.signUp(
      email: email,
      password: password,
      data: {'name': name},
    );
    _currentUser = response.user;
    notifyListeners();
    return response;
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  Future<void> updateProfile({
    String? name,
    String? email,
    String? password,
    String? avatarUrl,
    bool updateAvatar = false,
  }) async {
    final Map<String, dynamic> data = {};
    if (name != null) data['name'] = name;
    if (updateAvatar) data['avatar_url'] = avatarUrl;

    final UserAttributes attributes = UserAttributes(
      email: email,
      password: password,
      data: data.isEmpty ? null : data,
    );

    await _supabase.auth.updateUser(attributes);
  }

  Future<void> deleteAccount() async {
    await _supabase.rpc('delete_user');
    await signOut();
  }
}
