import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../bloc/admin_bloc.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';

class AdminPanelPage extends StatefulWidget {
  const AdminPanelPage({super.key});

  @override
  State<AdminPanelPage> createState() => _AdminPanelPageState();
}

class _AdminPanelPageState extends State<AdminPanelPage> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Dispatch initial load event
    context.read<AdminBloc>().add(LoadUsersRequested());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Format date helper
  String _formatTimestamp(String? isoTimestamp) {
    if (isoTimestamp == null) return 'Belum pernah';
    try {
      final dateTime = DateTime.parse(isoTimestamp).toLocal();
      return DateFormat('dd MMM yyyy, HH:mm').format(dateTime);
    } catch (_) {
      return isoTimestamp;
    }
  }

  // Confirmation dialog before toggling status
  Future<void> _showConfirmToggleDialog({
    required BuildContext context,
    required String email,
    required bool currentStatus,
  }) async {
    final actionWord = currentStatus ? 'menonaktifkan' : 'mengaktifkan';
    
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: Text(
            'Konfirmasi Ubah Status',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Apakah Anda yakin ingin $actionWord akun ($email)?',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text(
                'Batal',
                style: TextStyle(color: Colors.white54),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: currentStatus ? Colors.redAccent : const Color(0xFFFF6D00),
                foregroundColor: Colors.white,
              ),
              child: const Text('Ya, Lanjutkan'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      context.read<AdminBloc>().add(
        ToggleUserStatusRequested(email: email, currentStatus: currentStatus),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Premium Dark background
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text(
          'Admin Panel',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
            onPressed: () {
              context.read<AuthBloc>().add(SignOutRequested());
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Header Area
          Container(
            padding: const EdgeInsets.all(16.0),
            color: const Color(0xFF1E293B),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Cari user berdasarkan email...',
                      hintStyle: const TextStyle(color: Colors.white38),
                      prefixIcon: const Icon(Icons.search, color: Colors.white54),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: Colors.white54),
                              onPressed: () {
                                _searchController.clear();
                                context.read<AdminBloc>().add(SearchUsersRequested(''));
                                FocusScope.of(context).unfocus();
                              },
                            )
                          : null,
                      fillColor: const Color(0xFF0F172A),
                      filled: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (value) {
                      context.read<AdminBloc>().add(SearchUsersRequested(value));
                    },
                  ),
                ),
              ],
            ),
          ),
          
          // User List Area
          Expanded(
            child: BlocConsumer<AdminBloc, AdminState>(
              listener: (context, state) {
                if (state is AdminError) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(state.message),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              },
              builder: (context, state) {
                if (state is AdminLoading) {
                  return const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6D00)),
                    ),
                  );
                }
                
                if (state is AdminUsersLoaded) {
                  final users = state.users;
                  
                  if (users.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.people_outline, size: 64, color: Colors.white24),
                          const SizedBox(height: 16),
                          Text(
                            state.searchQuery.isEmpty
                                ? 'Tidak ada pengguna di database.'
                                : 'Pengguna tidak ditemukan.',
                            style: const TextStyle(color: Colors.white54, fontSize: 16),
                          ),
                        ],
                      ),
                    );
                  }
                  
                  return RefreshIndicator(
                    onRefresh: () async {
                      context.read<AdminBloc>().add(LoadUsersRequested());
                    },
                    color: const Color(0xFFFF6D00),
                    backgroundColor: const Color(0xFF1E1E1E),
                    child: ListView.builder(
                      padding: const EdgeInsets.all(12.0),
                      itemCount: users.length,
                      itemBuilder: (context, index) {
                        final user = users[index];
                        final String email = user['email'] ?? '';
                        final bool isActive = user['is_active'] as bool? ?? true;
                        final String? lastSyncStr = user['last_sync'] as String?;
                        
                        return Card(
                          color: const Color(0xFF1E293B),
                          margin: const EdgeInsets.symmetric(vertical: 6.0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: Colors.white.withAlpha(5),
                              width: 1,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                // Avatar circle / icon
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: isActive
                                        ? const Color(0xFFFF6D00).withAlpha(20)
                                        : Colors.white10,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.person,
                                    color: isActive
                                        ? const Color(0xFFFF6D00)
                                        : Colors.white30,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                
                                // User info
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        email,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          decoration: isActive
                                              ? null
                                              : TextDecoration.lineThrough,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Sync terakhir: ${_formatTimestamp(lastSyncStr)}',
                                        style: const TextStyle(
                                          color: Colors.white54,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      // Status badge
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isActive
                                              ? Colors.green.withAlpha(30)
                                              : Colors.red.withAlpha(30),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          isActive ? 'Aktif' : 'Non-aktif',
                                          style: TextStyle(
                                            color: isActive
                                                ? Colors.greenAccent
                                                : Colors.redAccent,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                
                                if (email == 'satriodkm97@gmail.com')
                                  const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 12.0),
                                    child: Tooltip(
                                      message: 'Owner tidak dapat dinonaktifkan',
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.security,
                                            color: Color(0xFFFF6D00),
                                            size: 20,
                                          ),
                                          SizedBox(width: 4),
                                          Text(
                                            'Owner',
                                            style: TextStyle(
                                              color: Color(0xFFFF6D00),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                else
                                  // Toggle Slider Switch
                                  Switch(
                                    value: isActive,
                                    activeColor: const Color(0xFFFF6D00),
                                    inactiveThumbColor: Colors.grey,
                                    inactiveTrackColor: Colors.white10,
                                    onChanged: (bool value) {
                                      // Intercept toggle with a confirmation modal dialog
                                      _showConfirmToggleDialog(
                                        context: context,
                                        email: email,
                                        currentStatus: isActive,
                                      );
                                    },
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  );
                }
                
                return const Center(
                  child: Text(
                    'Inisialisasi admin panel...',
                    style: TextStyle(color: Colors.white54),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
