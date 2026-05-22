import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:EstimaTek/features/auth/data/repositories/auth_repository.dart';

void main() {
  late Directory tempDir;
  late AuthRepository authRepository;

  setUp(() async {
    // Mock SharedPreferences to avoid MissingPluginException during Supabase initialization
    SharedPreferences.setMockInitialValues({});

    // Setup a temp Hive directory for testing
    tempDir = await Directory.systemTemp.createTemp('hive_test_');
    Hive.init(tempDir.path);

    // Initialize Supabase with dummy credentials and EmptyLocalStorage to prevent MissingPluginException
    await Supabase.initialize(
      url: 'https://placeholder.supabase.co',
      anonKey: 'dummy-key',
      authOptions: const FlutterAuthClientOptions(
        localStorage: EmptyLocalStorage(),
      ),
    );
    
    authRepository = AuthRepository();
  });

  tearDown(() async {
    // Clean up Hive
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('AuthRepository Local License Grace Period Tests', () {
    test('Should permit access if active and last sync is within 7 days', () async {
      final box = await Hive.openBox('license_box');
      await box.put('is_active', true);
      await box.put('cached_email', 'test@example.com');
      // Sync date: 3 days ago
      final syncDate = DateTime.now().subtract(const Duration(days: 3));
      await box.put('last_sync', syncDate.toIso8601String());

      // We call checkLocalLicenseWithGracePeriod indirectly via checkLicenseStatus.
      // Since checkLicenseStatus will attempt to connect to Supabase (which is not configured/mocked here)
      // it will throw a connection exception and fall back to the Hive check.
      final isAccessPermitted = await authRepository.checkLicenseStatus();
      expect(isAccessPermitted, isTrue);
    });

    test('Should block access if marked inactive locally', () async {
      final box = await Hive.openBox('license_box');
      await box.put('is_active', false);
      await box.put('cached_email', 'test@example.com');
      final syncDate = DateTime.now().subtract(const Duration(days: 1));
      await box.put('last_sync', syncDate.toIso8601String());

      final isAccessPermitted = await authRepository.checkLicenseStatus();
      expect(isAccessPermitted, isFalse);
    });

    test('Should block access if last sync is older than 7 days', () async {
      final box = await Hive.openBox('license_box');
      await box.put('is_active', true);
      await box.put('cached_email', 'test@example.com');
      // Sync date: 8 days ago
      final syncDate = DateTime.now().subtract(const Duration(days: 8));
      await box.put('last_sync', syncDate.toIso8601String());

      final isAccessPermitted = await authRepository.checkLicenseStatus();
      expect(isAccessPermitted, isFalse);
    });

    test('Should permit access and write current date if last sync is null (first run offline)', () async {
      final box = await Hive.openBox('license_box');
      await box.put('is_active', true);
      await box.put('cached_email', 'test@example.com');
      await box.delete('last_sync'); // No last sync cached

      final isAccessPermitted = await authRepository.checkLicenseStatus();
      expect(isAccessPermitted, isTrue);

      final cachedSync = box.get('last_sync') as String?;
      expect(cachedSync, isNotNull);
      expect(DateTime.parse(cachedSync!).difference(DateTime.now()).inMinutes, 0); // approx now
    });
  });
}
