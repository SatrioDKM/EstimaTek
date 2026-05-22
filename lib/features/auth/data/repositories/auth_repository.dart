import 'dart:developer' as developer;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:hive/hive.dart';
import '../../../../core/config/supabase_config.dart';

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
    print('[AuthRepository] starting signInWithGoogle...');
    try {
      final GoogleSignIn signIn = GoogleSignIn.instance;

      // Initialize GoogleSignIn with serverClientId (Web Client ID) to retrieve idToken on Android
      if (SupabaseConfig.googleWebClientId != 'YOUR_GOOGLE_WEB_CLIENT_ID' &&
          SupabaseConfig.googleWebClientId.isNotEmpty) {
        print('[AuthRepository] Initializing GoogleSignIn with web client ID: ${SupabaseConfig.googleWebClientId}');
        await signIn.initialize(
          serverClientId: SupabaseConfig.googleWebClientId,
        );
      } else {
        print('[AuthRepository] Warning: googleWebClientId is not set or is default!');
      }

      print('[AuthRepository] Calling signIn.authenticate()...');
      final GoogleSignInAccount? googleUser = await signIn.authenticate();
      print('[AuthRepository] signIn.authenticate() completed, googleUser: $googleUser');
      if (googleUser == null) {
        print('[AuthRepository] Google Sign-In cancelled by user.');
        return null;
      }

      print('[AuthRepository] Fetching googleUser.authentication...');
      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      print('[AuthRepository] idToken retrieved: ${idToken != null ? "FOUND" : "NULL"}');

      if (idToken == null) {
        throw Exception('Google Sign-In failed: No ID token found.');
      }

      print('[AuthRepository] Authenticating with Supabase signInWithIdToken...');
      final AuthResponse response = await _supabaseClient.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
      ).timeout(const Duration(seconds: 15), onTimeout: () {
        print('[AuthRepository] Supabase signInWithIdToken timed out!');
        throw Exception('Supabase authentication timed out. Please check your internet connection.');
      });

      final user = response.user;
      print('[AuthRepository] Supabase sign-in response user: $user');
      if (user != null && user.email != null) {
        print('[AuthRepository] Syncing user account in public.users table...');
        await _registerOrSyncUserOnLogin(user.email!);
        print('[AuthRepository] User account sync completed.');
      }

      return user;
    } catch (e) {
      print('[AuthRepository] Error in signInWithGoogle: $e');
      rethrow;
    }
  }

  // Sync user in Supabase 'users' table upon initial login
  Future<void> _registerOrSyncUserOnLogin(String email) async {
    print('[AuthRepository] _registerOrSyncUserOnLogin started for: $email');
    try {
      print('[AuthRepository] Querying users table from Supabase for sync...');
      final response = await _supabaseClient
          .from('users')
          .select()
          .eq('email', email)
          .maybeSingle()
          .timeout(const Duration(seconds: 8), onTimeout: () {
            print('[AuthRepository] Querying users table timed out during sync!');
            throw Exception('Timeout querying users database.');
          });

      print('[AuthRepository] Sync query response: $response');
      final nowString = DateTime.now().toIso8601String();

      if (response == null) {
        final bool isOwner = email == 'satriodkm97@gmail.com';
        print('[AuthRepository] User not found in users table, inserting new row (isOwner=$isOwner)...');
        await _supabaseClient.from('users').insert({
          'email': email,
          'is_active': isOwner,
          'last_sync': nowString,
        }).timeout(const Duration(seconds: 5), onTimeout: () {
          print('[AuthRepository] Inserting user row timed out!');
        });
        
        print('[AuthRepository] Caching active status locally...');
        await _cacheLicenseStatus(isOwner, DateTime.now(), email: email);
      } else {
        final isActive = response['is_active'] as bool? ?? (email == 'satriodkm97@gmail.com');
        print('[AuthRepository] User found. is_active: $isActive. Updating last_sync...');
        await _supabaseClient.from('users').update({
          'last_sync': nowString,
        }).eq('email', email).timeout(const Duration(seconds: 5), onTimeout: () {
          print('[AuthRepository] Updating user last_sync timed out!');
        });

        print('[AuthRepository] Caching status locally: active=$isActive...');
        await _cacheLicenseStatus(isActive, DateTime.now(), email: email);
      }
    } catch (e) {
      print('[AuthRepository] Error registering/syncing user in db: $e');
    }
  }

  // Check user active status (Remote Kill Switch)
  // Returns true if active, false if blocked or offline grace expired
  Future<bool> checkLicenseStatus() async {
    final email = currentUserEmail;
    print('[AuthRepository] checkLicenseStatus called for email: $email');
    if (email == null) {
      print('[AuthRepository] checkLicenseStatus email is null, returning false');
      return false;
    }

    try {
      print('[AuthRepository] Checking license status online via Supabase...');
      final response = await _supabaseClient
          .from('users')
          .select('is_active')
          .eq('email', email)
          .maybeSingle()
          .timeout(const Duration(seconds: 8), onTimeout: () {
            print('[AuthRepository] Querying checkLicenseStatus timed out!');
            throw Exception('Timeout querying license status.');
          });

      print('[AuthRepository] Online license status query response: $response');
      if (response != null) {
        final isActive = response['is_active'] as bool? ?? (email == 'satriodkm97@gmail.com');
        final now = DateTime.now();
        
        print('[AuthRepository] Updating last_sync on remote DB...');
        await _supabaseClient.from('users').update({
          'last_sync': now.toIso8601String(),
        }).eq('email', email).timeout(const Duration(seconds: 5), onTimeout: () {
          print('[AuthRepository] Updating last_sync timed out!');
        });

        print('[AuthRepository] Caching status locally: active=$isActive...');
        await _cacheLicenseStatus(isActive, now, email: email);
        return isActive;
      } else {
        print('[AuthRepository] User not found in db table during check, inserting defaults...');
        final now = DateTime.now();
        final bool isOwner = email == 'satriodkm97@gmail.com';
        await _supabaseClient.from('users').insert({
          'email': email,
          'is_active': isOwner,
          'last_sync': now.toIso8601String(),
        }).timeout(const Duration(seconds: 5), onTimeout: () {
          print('[AuthRepository] Inserting defaults timed out!');
        });
        await _cacheLicenseStatus(isOwner, now, email: email);
        return isOwner;
      }
    } catch (e) {
      print('[AuthRepository] Offline/Error checking license status, falling back to Hive cache: $e');
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
