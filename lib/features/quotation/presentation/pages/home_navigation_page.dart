import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'quotation_list_page.dart';
import '../../../design_builder/presentation/pages/catalog_page.dart';
import '../../../admin/presentation/pages/admin_panel_page.dart';
import '../../../auth/presentation/pages/profile_page.dart';

class HomeNavigationPage extends StatefulWidget {
  const HomeNavigationPage({super.key});

  @override
  State<HomeNavigationPage> createState() => _HomeNavigationPageState();
}

class _HomeNavigationPageState extends State<HomeNavigationPage> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final isOwner = user?.email == 'satriodkm97@gmail.com';

    final List<Widget> pages = [
      const QuotationListPage(),
      const CatalogPage(),
      if (isOwner) const AdminPanelPage(),
      const ProfilePage(),
    ];

    // Safe boundary check
    if (_currentIndex >= pages.length) {
      _currentIndex = 0;
    }

    final List<BottomNavigationBarItem> navItems = [
      const BottomNavigationBarItem(
        icon: Icon(Icons.request_quote_outlined),
        activeIcon: Icon(Icons.request_quote, color: Color(0xFFFF6D00)),
        label: 'Penawaran',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.menu_book_outlined),
        activeIcon: Icon(Icons.menu_book, color: Color(0xFFFF6D00)),
        label: 'Katalog',
      ),
      if (isOwner)
        const BottomNavigationBarItem(
          icon: Icon(Icons.admin_panel_settings_outlined),
          activeIcon: Icon(Icons.admin_panel_settings, color: Color(0xFFFF6D00)),
          label: 'Admin',
        ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.person_outline),
        activeIcon: Icon(Icons.person, color: Color(0xFFFF6D00)),
        label: 'Profil',
      ),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(50),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          backgroundColor: const Color(0xFF1E1E1E),
          selectedItemColor: const Color(0xFFFF6D00),
          unselectedItemColor: Colors.white54,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontSize: 12),
          type: BottomNavigationBarType.fixed,
          items: navItems,
        ),
      ),
    );
  }
}

