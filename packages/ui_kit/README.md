# Vio UI Kit

Design system and reusable UI components for the Vio design tool.

## Overview

This package provides the visual design system including colors, typography, and themed widgets.

## Theme System

### VioColors

Core color palette following a blue-accented dark theme:

```dart
import 'package:vio_ui_kit/vio_ui_kit.dart';

// Primary colors
VioColors.primary        // #4C9AFF - main accent blue
VioColors.primaryHover   // Lighter accent for hover states

// Background hierarchy
VioColors.background     // #0D1117 - darkest (app background)
VioColors.surface        // #161B22 - panels and cards
VioColors.surfaceHover   // Lighter surface for interactions

// Text colors
VioColors.textPrimary    // #E6EDF3 - high emphasis
VioColors.textSecondary  // Medium emphasis
VioColors.textTertiary   // Low emphasis / disabled

// Semantic colors
VioColors.success        // Green for success states
VioColors.warning        // Yellow for warnings
VioColors.error          // Red for errors
VioColors.info           // Blue for information
```

### VioTheme

Apply the theme using `VioTheme.dark()`:

```dart
MaterialApp(
  theme: VioTheme.dark(),
  // ...
)
```

## Components

The UI kit provides styled versions of common widgets that follow the Vio design language:

- Buttons (primary, secondary, ghost)
- Input fields
- Dropdown selectors
- Tooltips
- Panel containers

## Usage

```dart
import 'package:vio_ui_kit/vio_ui_kit.dart';

// Use colors directly
Container(
  color: VioColors.surface,
  child: Text(
    'Hello',
    style: TextStyle(color: VioColors.textPrimary),
  ),
)
```
