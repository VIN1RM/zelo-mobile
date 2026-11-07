import '../../shared/presentation/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppShell extends StatelessWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) {
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(AppIcons.shieldOutlined),
            selectedIcon: Icon(AppIcons.shield),
            label: 'Início',
          ),
          NavigationDestination(
            icon: Icon(AppIcons.peopleOutline),
            selectedIcon: Icon(AppIcons.people),
            label: 'Contatos',
          ),
          NavigationDestination(
            icon: Icon(AppIcons.history),
            label: 'Histórico',
          ),
          NavigationDestination(
            icon: Icon(AppIcons.settingsOutlined),
            selectedIcon: Icon(AppIcons.settings),
            label: 'Ajustes',
          ),
        ],
      ),
    );
  }
}
