import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Whether the current platform uses the Meta (⌘) key as its primary modifier.
///
/// Returns `true` on macOS (native or web), `false` on Windows/Linux.
bool get _isMacOS => defaultTargetPlatform == TargetPlatform.macOS;

/// Returns `true` when the platform-appropriate modifier key is pressed.
///
/// On macOS this checks the **Command (⌘)** key; on other platforms the
/// **Control** key.
bool isPlatformModifierPressed() {
  if (_isMacOS) {
    return HardwareKeyboard.instance.isMetaPressed;
  }
  return HardwareKeyboard.instance.isControlPressed;
}

/// Creates a [SingleActivator] that uses **⌘** on macOS and **Ctrl**
/// elsewhere, mirroring each platform's native conventions.
SingleActivator platformSingleActivator(
  LogicalKeyboardKey key, {
  bool shift = false,
  bool alt = false,
}) {
  return SingleActivator(
    key,
    meta: _isMacOS,
    control: !_isMacOS,
    shift: shift,
    alt: alt,
  );
}

/// Human-readable label for the platform modifier key.
///
/// Returns `'⌘'` on macOS, `'Ctrl'` on other platforms.
/// Useful for building tooltip strings.
String platformModifierLabel() => _isMacOS ? '⌘' : 'Ctrl';
