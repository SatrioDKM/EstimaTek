import 'dart:developer' as developer;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:hive/hive.dart';

class AuthRepository {
  final SupabaseClient _supabaseClient = Supabase.instance.client;
  
  static const String _licenseBoxName = 'license_box';
  static const String _keyIsActive = 'is_active';
  static const String _keyLastSync = 'last_sync';
  
  // Singleton or simple constructor
  AuthRepository();

  // Get current user email
  String? get currentUserEmail {
    try {
      return _supabaseClient.auth.currentUser?.email ?? _cachedEmail;
    } catch (_) {
      return _cachedEmail;
    }
  }

  String? get _cachedEmail {
    try {
      final box = Hive.box(_licenseBoxName);
      return box.get('cached_email') as String?;
    } catch (_) {
      return null;
    }
  }

  // Check if current user is logged in
  bool get isLoggedIn => _supabaseClient.auth.currentUser != null;

  // Initialize Hive box
  Future<Box> _openBox() async {
    return await Hive.openBox(_licenseBoxName);
  }

  // Google Sign-In flow
  Future<User?> signInWithGoogle() async {
    try {
      final GoogleSignIn signIn = GoogleSignIn.instance;
      final GoogleSignInAccount? googleUser = await signIn.authenticate();
      if (googleUser == null) {
        // User cancelled the sign-in
        return null;
      }

      final googleAuthorization = await googleUser.authorizationClient.authorizationForScopes([]);
      final idToken = googleUser.authentication.idToken;
      final accessToken = googleAuthorization?.accessToken;

      if (idToken == null) {
        throw Exception('Google Sign-In failed: No ID token found.');
      }

      final AuthResponse response = await _supabaseClient.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      final user = response.user;
      if (user != null && user.email != null) {
        // Sync/Register user in Supabase public.users table
        await _registerOrSyncUserOnLogin(user.email!);
      }

      return user;
    } catch (e) {
      developer.log('Error in signInWithGoogle: $e', name: 'AuthRepository');
      rethrow;
    }
  }

  // Sync user in Supabase 'users' table upon initial login
  Future<void> _registerOrSyncUserOnLogin(String email) async {
    try {
      // Check if user exists in our public.users table
      final response = await _supabaseClient
          .from('users')
          .select()
          .eq('email', email)
          .maybeSingle();

      final nowString = DateTime.now().toIso8601String();

      if (response == null) {
        // Create user row if it doesn't exist (default active)
        await _supabaseClient.from('users').insert({
          'email': email,
          'is_active': true,
          'last_sync': nowString,
        });
        
        // Cache locally
        await _cacheLicenseStatus(true, DateTime.now(), email: email);
      } else {
        final isActive = response['is_active'] as bool? ?? true;
        // Update last sync in remote DB
        await _supabaseClient.from('users').update({
          'last_sync': nowString,
        }).eq('email', email);

        // Cache locally
        await _cacheLicenseStatus(isActive, DateTime.now(), email: email);
      }
    } catch (e) {
      // If sync fails during initial login (e.g. database error), we log but allow proceed
      developer.log('Error registering/syncing user in db: $e', name: 'AuthRepository');
    }
  }

  // Check user active status (Remote Kill Switch)
  // Returns true if active, false if blocked or offline grace expired
  Future<bool> checkLicenseStatus() async {
    final email = currentUserEmail;
    if (email == null) {
      return false;
    }

    try {
      // Attempt to query Supabase users table (Online check)
      final response = await _supabaseClient
          .from('users')
          .select('is_active')
          .eq('email', email)
          .maybeSingle();

      if (response != null) {
        final isActive = response['is_active'] as bool? ?? true;
        final now = DateTime.now();
        
        // Update last_sync on remote DB
        await _supabaseClient.from('users').update({
          'last_sync': now.toIso8601String(),
        }).eq('email', email);

        // Save status locally in Hive
        await _cacheLicenseStatus(isActive, now, email: email);
        return isActive;
      } else {
        // User not found in db table, meaning they were never synced
        // Let's add them as active for now
        final now = DateTime.now();
        await _supabaseClient.from('users').insert({
          'email': email,
          'is_active': true,
          'last_sync': now.toIso8601String(),
        });
        await _cacheLicenseStatus(true, now, email: email);
        return true;
      }
    } catch (e) {
      developer.log('Offline/Error checking license status from remote, falling back to Hive cache: $e', name: 'AuthRepository');
      // If we are offline or request fails, fall back to Hive cache check
      return await _checkLocalLicenseWithGracePeriod();
    }
  }

  // Cache license status locally in Hive
  Future<void> _cacheLicenseStatus(bool isActive, DateTime lastSync, {String? email}) async {
    final box = await _openBox();
    await box.put(_keyIsActive, isActive);
    await box.put(_keyLastSync, lastSync.toIso8601String());
    if (email != null) {
      await box.put('cached_email', email);
    }
  }

  // Check cached local status and enforce 7-day offline grace period
  Future<bool> _checkLocalLicenseWithGracePeriod() async {
    final box = await _openBox();
    final isActive = box.get(_keyIsActive, defaultValue: true) as bool;
    final lastSyncStr = box.get(_keyLastSync) as String?;

    if (!isActive) {
      developer.log('Local license check: User is marked inactive.', name: 'AuthRepository');
      return false;
    }

    if (lastSyncStr == null) {
      // No sync record exists, but we are offline. Let's allow access for now
      // and set current time as last sync so grace period starts.
      developer.log('Local license check: No last sync timestamp found, caching now.', name: 'AuthRepository');
      await _cacheLicenseStatus(true, DateTime.now());
      return true;
    }

    final lastSync = DateTime.parse(lastSyncStr);
    final difference = DateTime.now().difference(lastSync);
    
    if (difference.inDays >= 7) {
      developer.log('Local license check: Grace period expired (${difference.inDays} days since last sync).', name: 'AuthRepository');
      return false; // Grace period expired (>= 7 days offline)
    }

    developer.log('Local license check: User is active. Days since last sync: ${difference.inDays}. Access allowed.', name: 'AuthRepository');
    return true; // Still within grace period
  }

  // Log out
  Future<void> signOut() async {
    try {
      await _supabaseClient.auth.signOut();
      final signIn = GoogleSignIn.instance;
      try {
        await signIn.signOut();
      } catch (_) {}
      try {
        await signIn.disconnect();
      } catch (_) {}
      
      // Clear local license status
      final box = await _openBox();
      await box.delete(_keyIsActive);
      await box.delete(_keyLastSync);
      await box.delete('cached_email');
    } catch (e) {
      developer.log('Error in signOut: $e', name: 'AuthRepository');
      rethrow;
    }
  }
}
