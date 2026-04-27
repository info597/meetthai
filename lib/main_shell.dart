import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  final _supa = Supabase.instance.client;

  int _index = 0;

  // Diese Routen müssen in deinem main.dart existieren:
  // '/home', '/discover', '/matches', '/chats', '/profile-edit'
  final List<String> _routes = const [
    '/home',
    '/discover',
    '/matches',
    '/chats',
    '/profile-edit',
  ];

  void _go(int idx) {
    if (idx == _index) return;
    setState(() => _index = idx);
    Navigator.pushReplacementNamed(context, _routes[idx]);
  }

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = _supa.auth.currentUser != null;

    return Scaffold(
      // Der eigentliche Screen wird per pushReplacementNamed angezeigt.
      // Daher hier nur BottomNav als “Rahmen”.
      body: const SizedBox.shrink(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) {
          // Profil & Chats nur wenn eingeloggt
          final needsAuth = (i == 2 || i == 3 || i == 4);
          if (needsAuth && !isLoggedIn) {
            Navigator.pushNamed(context, '/auth');
            return;
          }
          _go(i);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.explore_rounded),
            label: 'Entdecken',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_rounded),
            label: 'Matches',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_rounded),
            label: 'Chats',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_rounded),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}
