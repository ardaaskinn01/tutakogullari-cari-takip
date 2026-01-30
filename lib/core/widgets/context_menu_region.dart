import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

/// Context menu region for desktop right-click actions
class ContextMenuRegion extends StatelessWidget {
  final Widget child;
  final List<ContextMenuItem> menuItems;

  const ContextMenuRegion({
    super.key,
    required this.child,
    required this.menuItems,
  });

  @override
  Widget build(BuildContext context) {
    // Only enable context menu on desktop platforms
    if (!_isDesktop()) {
      return child;
    }

    return GestureDetector(
      onSecondaryTapDown: (details) {
        _showContextMenu(context, details.globalPosition);
      },
      child: child,
    );
  }

  bool _isDesktop() {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.windows || 
           defaultTargetPlatform == TargetPlatform.macOS || 
           defaultTargetPlatform == TargetPlatform.linux;
  }

  void _showContextMenu(BuildContext context, Offset position) {
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    
    showMenu(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(position.dx, position.dy, 0, 0),
        Rect.fromLTWH(0, 0, overlay.size.width, overlay.size.height),
      ),
      items: menuItems.map((item) {
        return PopupMenuItem(
          onTap: item.onTap,
          child: Row(
            children: [
              if (item.icon != null) ...[
                Icon(item.icon, size: 18, color: item.color),
                const SizedBox(width: 12),
              ],
              Text(item.label, style: TextStyle(color: item.color)),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class ContextMenuItem {
  final String label;
  final IconData? icon;
  final VoidCallback onTap;
  final Color? color;

  const ContextMenuItem({
    required this.label,
    required this.onTap,
    this.icon,
    this.color,
  });
}
