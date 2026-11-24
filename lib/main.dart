import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/home.dart';
import 'screens/loot.dart';
import 'screens/profile.dart';
import 'state.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: C.sheet,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  await appState.load();
  runApp(const LifeRpgApp());
}

class LifeRpgApp extends StatelessWidget {
  const LifeRpgApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Life RPG',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const Shell(),
    );
  }
}

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _tab = 0; // 0 schedule, 1 loot, 2 profile

  void _go(int i) => setState(() => _tab = i);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: _tab,
          children: const [HomeScreen(), LootScreen(), ProfileScreen()],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: C.sheet,
          border: Border(top: BorderSide(color: C.line)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 68,
            child: Row(
              children: [
                _NavItem(icon: Icons.calendar_month_outlined, label: 'Schedule', active: _tab == 0, onTap: () => _go(0)),
                _NavItem(
                  icon: Icons.storefront_outlined,
                  label: 'Market',
                  active: false,
                  onTap: () => showComingSoon(
                    context,
                    'Market coming soon',
                    'This feature is under development. Soon you can buy items and pets here.',
                  ),
                ),
                _NavItem(icon: Icons.inventory_2_outlined, label: 'Loot', active: _tab == 1, onTap: () => _go(1)),
                _NavItem(icon: Icons.person_outline, label: 'Profile', active: _tab == 2, onTap: () => _go(2)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.icon, required this.label, required this.active, required this.onTap});
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? C.gold : C.muted;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: active ? FontWeight.w600 : FontWeight.w400)),
          ],
        ),
      ),
    );
  }
}
