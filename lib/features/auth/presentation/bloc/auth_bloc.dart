import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/repositories/auth_repository.dart';

// --- Events ---
abstract class AuthEvent {}

class AuthCheckRequested extends AuthEvent {}

class SignInWithGoogleRequested extends AuthEvent {}

class SignOutRequested extends AuthEvent {}

class AppResumedCheck extends AuthEvent {}


// --- States ---
abstract class AuthState {}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class Unauthenticated extends AuthState {}

class AuthenticatedActive extends AuthState {
  final User user;
  AuthenticatedActive(this.user);
}

class AuthenticatedBlocked extends AuthState {
  final String email;
  final String reason;
  AuthenticatedBlocked({required this.email, required this.reason});
}

class AuthError extends AuthState {
  final String message;
  AuthError(this.message);
}


// --- BLoC ---
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _authRepository;

  AuthBloc(this._authRepository) : super(AuthInitial()) {
    on<AuthCheckRequested>(_onAuthCheckRequested);
    on<SignInWithGoogleRequested>(_onSignInWithGoogleRequested);
    on<SignOutRequested>(_onSignOutRequested);
    on<AppResumedCheck>(_onAppResumedCheck);
  }

  Future<void> _onAuthCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      if (_authRepository.isLoggedIn) {
        final email = _authRepository.currentUserEmail ?? '';
        final isLicenseActive = await _authRepository.checkLicenseStatus();
        final user = Supabase.instance.client.auth.currentUser;
        
        if (isLicenseActive && user != null) {
          emit(AuthenticatedActive(user));
        } else {
          emit(AuthenticatedBlocked(
            email: email,
            reason: 'Lisensi tidak aktif atau batas waktu offline (7 hari) telah habis.',
          ));
        }
      } else {
        emit(Unauthenticated());
      }
    } catch (e) {
      emit(AuthError('Gagal memeriksa status login: ${e.toString()}'));
      emit(Unauthenticated());
    }
  }

  Future<void> _onSignInWithGoogleRequested(
    SignInWithGoogleRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final user = await _authRepository.signInWithGoogle();
      if (user != null) {
        final isLicenseActive = await _authRepository.checkLicenseStatus();
        if (isLicenseActive) {
          emit(AuthenticatedActive(user));
        } else {
          emit(AuthenticatedBlocked(
            email: user.email ?? '',
            reason: 'Akun Anda dinonaktifkan oleh administrator.',
          ));
        }
      } else {
        emit(Unauthenticated());
      }
    } catch (e) {
      emit(AuthError('Gagal Sign-In dengan Google: ${e.toString()}'));
      emit(Unauthenticated());
    }
  }

  Future<void> _onSignOutRequested(
    SignOutRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      await _authRepository.signOut();
      emit(Unauthenticated());
    } catch (e) {
      emit(AuthError('Gagal logout: ${e.toString()}'));
      // Fallback state
      emit(Unauthenticated());
    }
  }

  Future<void> _onAppResumedCheck(
    AppResumedCheck event,
    Emitter<AuthState> emit,
  ) async {
    // Only check status if we are currently active or blocked, to verify license change
    if (state is AuthenticatedActive || state is AuthenticatedBlocked) {
      try {
        final email = _authRepository.currentUserEmail ?? '';
        final isLicenseActive = await _authRepository.checkLicenseStatus();
        final user = Supabase.instance.client.auth.currentUser;

        if (isLicenseActive && user != null) {
          if (state is! AuthenticatedActive) {
            emit(AuthenticatedActive(user));
          }
        } else {
          if (state is! AuthenticatedBlocked) {
            emit(AuthenticatedBlocked(
              email: email,
              reason: 'Lisensi tidak aktif atau batas waktu offline (7 hari) telah habis.',
            ));
          }
        }
      } catch (e) {
        // Log but don't emit error to prevent disrupting user experience
        // checkLicenseStatus handles offline fallback internally
      }
    }
  }
}
