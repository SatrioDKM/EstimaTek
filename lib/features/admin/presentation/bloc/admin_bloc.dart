import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/repositories/admin_repository.dart';

// --- Events ---
abstract class AdminEvent {}

class LoadUsersRequested extends AdminEvent {}

class SearchUsersRequested extends AdminEvent {
  final String query;
  SearchUsersRequested(this.query);
}

class ToggleUserStatusRequested extends AdminEvent {
  final String email;
  final bool currentStatus;
  ToggleUserStatusRequested({required this.email, required this.currentStatus});
}


// --- States ---
abstract class AdminState {}

class AdminInitial extends AdminState {}

class AdminLoading extends AdminState {}

class AdminUsersLoaded extends AdminState {
  final List<Map<String, dynamic>> users;
  final String searchQuery;
  AdminUsersLoaded({required this.users, this.searchQuery = ''});
}

class AdminError extends AdminState {
  final String message;
  AdminError(this.message);
}


// --- BLoC ---
class AdminBloc extends Bloc<AdminEvent, AdminState> {
  final AdminRepository _adminRepository;
  String _currentQuery = '';

  AdminBloc(this._adminRepository) : super(AdminInitial()) {
    on<LoadUsersRequested>(_onLoadUsersRequested);
    on<SearchUsersRequested>(_onSearchUsersRequested);
    on<ToggleUserStatusRequested>(_onToggleUserStatusRequested);
  }

  Future<void> _onLoadUsersRequested(
    LoadUsersRequested event,
    Emitter<AdminState> emit,
  ) async {
    emit(AdminLoading());
    try {
      final users = await _adminRepository.fetchUsers(searchQuery: _currentQuery);
      emit(AdminUsersLoaded(users: users, searchQuery: _currentQuery));
    } catch (e) {
      emit(AdminError('Gagal memuat pengguna: ${e.toString()}'));
    }
  }

  Future<void> _onSearchUsersRequested(
    SearchUsersRequested event,
    Emitter<AdminState> emit,
  ) async {
    _currentQuery = event.query;
    emit(AdminLoading());
    try {
      final users = await _adminRepository.fetchUsers(searchQuery: _currentQuery);
      emit(AdminUsersLoaded(users: users, searchQuery: _currentQuery));
    } catch (e) {
      emit(AdminError('Gagal mencari pengguna: ${e.toString()}'));
    }
  }

  Future<void> _onToggleUserStatusRequested(
    ToggleUserStatusRequested event,
    Emitter<AdminState> emit,
  ) async {
    try {
      final targetNewStatus = !event.currentStatus;
      await _adminRepository.toggleUserStatus(event.email, targetNewStatus);
      
      // Reload user list to reflect latest state from database
      final users = await _adminRepository.fetchUsers(searchQuery: _currentQuery);
      emit(AdminUsersLoaded(users: users, searchQuery: _currentQuery));
    } catch (e) {
      emit(AdminError('Gagal mengubah status pengguna: ${e.toString()}'));
      
      // Re-emit loaded users if possible
      if (state is AdminUsersLoaded) {
        emit(AdminUsersLoaded(
          users: (state as AdminUsersLoaded).users,
          searchQuery: _currentQuery,
        ));
      }
    }
  }
}
