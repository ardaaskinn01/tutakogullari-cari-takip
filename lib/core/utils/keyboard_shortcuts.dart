import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Keyboard shortcuts helper for desktop platforms
class KeyboardShortcuts extends StatelessWidget {
  final Widget child;
  final VoidCallback? onSave;
  final VoidCallback? onEscape;
  final VoidCallback? onEnter;

  const KeyboardShortcuts({
    super.key,
    required this.child,
    this.onSave,
    this.onEscape,
    this.onEnter,
  });

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        if (onSave != null)
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyS): const _SaveIntent(),
        if (onEscape != null)
          LogicalKeySet(LogicalKeyboardKey.escape): const _EscapeIntent(),
        if (onEnter != null)
          LogicalKeySet(LogicalKeyboardKey.enter): const _EnterIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          if (onSave != null)
            _SaveIntent: CallbackAction<_SaveIntent>(
              onInvoke: (_) {
                onSave?.call();
                return null;
              },
            ),
          if (onEscape != null)
            _EscapeIntent: CallbackAction<_EscapeIntent>(
              onInvoke: (_) {
                onEscape?.call();
                return null;
              },
            ),
          if (onEnter != null)
            _EnterIntent: CallbackAction<_EnterIntent>(
              onInvoke: (_) {
                onEnter?.call();
                return null;
              },
            ),
        },
        child: child,
      ),
    );
  }
}

class _SaveIntent extends Intent {
  const _SaveIntent();
}

class _EscapeIntent extends Intent {
  const _EscapeIntent();
}

class _EnterIntent extends Intent {
  const _EnterIntent();
}
