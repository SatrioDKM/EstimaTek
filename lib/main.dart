import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import 'core/config/supabase_config.dart';
import 'core/theme/app_theme.dart';

// Repositories
import 'features/auth/data/repositories/auth_repository.dart';
import 'features/admin/data/repositories/admin_repository.dart';

// BLoCs
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/admin/presentation/bloc/admin_bloc.dart';

// Pages
import 'features/auth/presentation/pages/login_page.dart';
import 'features/auth/presentation/pages/blocked_page.dart';
import 'features/quotation/presentation/pages/home_navigation_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize local Hive cache
  await Hive.initFlutter();

  // Initialize Supabase Client
  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.supabaseAnonKey,
  );

  runApp(const EstimaTekApp());
}

class EstimaTekApp extends StatefulWidget {
  const EstimaTekApp({super.key});

  @override
  State<EstimaTekApp> createState() => _EstimaTekAppState();
}

class _EstimaTekAppState extends State<EstimaTekApp> with WidgetsBindingObserver {
  late final AuthRepository _authRepository;
  late final AdminRepository _adminRepository;
  late final AuthBloc _authBloc;
  late final AdminBloc _adminBloc;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _authRepository = AuthRepository();
    _adminRepository = AdminRepository();

    // Check authorization on app launch
    _authBloc = AuthBloc(_authRepository)..add(AuthCheckRequested());
    _adminBloc = AdminBloc(_adminRepository);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authBloc.close();
    _adminBloc.close();
    super.dispose();
  }

  // Detect app transition back to foreground (Remote Kill Switch / Silent Check)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _authBloc.add(AppResumedCheck());
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>.value(value: _authBloc),
        BlocProvider<AdminBloc>.value(value: _adminBloc),
      ],
      child: MaterialApp(
        title: 'EstimaTek V2',
        theme: AppTheme.lightTheme,
        debugShowCheckedModeBanner: false,
        home: BlocBuilder<AuthBloc, AuthState>(
          builder: (context, state) {
            if (state is AuthInitial || state is AuthLoading) {
              return const Scaffold(
                backgroundColor: Color(0xFF0F172A),
                body: Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6D00)),
                  ),
                ),
              );
            } else if (state is AuthenticatedActive) {
              return const HomeNavigationPage();
            } else if (state is AuthenticatedBlocked) {
              return BlockedPage(
                email: state.email,
                reason: state.reason,
              );
            } else if (state is Unauthenticated) {
              return const LoginPage();
            } else {
              return const LoginPage();
            }
          },
        ),
      ),
    );
  }
}


