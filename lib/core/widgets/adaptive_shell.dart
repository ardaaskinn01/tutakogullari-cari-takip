import 'package:flutter/material.dart';
import 'side_menu.dart';

class AdaptiveShell extends StatelessWidget {
  final Widget child;

  const AdaptiveShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width > 900;

    if (isDesktop) {
      return Scaffold(
        body: Row(
          children: [
            const SideMenu(isDrawer: false),
            const VerticalDivider(width: 1, color: Colors.white10),
            Expanded(
              child: child,
            ),
          ],
        ),
      );
    }

    // Mobil Görünüm: Alt sayfalar kendi Scaffold'larını yönetecek (AppBar, Drawer vb.)
    return child;
  }
}
