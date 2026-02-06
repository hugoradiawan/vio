# Vio Core

Shared models, math utilities, and base abstractions for the Vio design tool.

## Overview

This package provides the foundational data structures and utilities used across the Vio monorepo.

## Key Components

### Math Utilities (`lib/src/math/`)

- **Matrix2D** - 6-parameter affine transformation matrix for shape transforms
  ```dart
  Matrix2D(a: scaleX, b: skewY, c: skewX, d: scaleY, e: translateX, f: translateY)
  ```
  - `Matrix2D.rotationAt()` - Rotation around a center point
  - `Matrix2D.identity()` - Identity matrix factory

### Models (`lib/src/models/`)

- **Shape** - Base class hierarchy for all shapes
  - `RectangleShape` - Rectangle with optional corner radius
  - `EllipseShape` - Ellipse/circle shapes
  - `FrameShape` - Container frames (like Figma/Penpot)
  - `TextShape` - Text elements
  - `PathShape` - Vector paths

- **Transform** - Shape transformation data
- **Fill/Stroke** - Shape styling properties
- **Shadow** - Drop shadow and inner shadow effects

## Usage

```dart
import 'package:vio_core/vio_core.dart';

// Create a shape with transform
final shape = RectangleShape(
  id: Uuid().v4(),
  name: 'My Rectangle',
  transform: Matrix2D.identity(),
  width: 100,
  height: 50,
);

// Apply rotation around center
final rotated = shape.copyWith(
  transform: Matrix2D.rotationAt(angle: 45 * pi / 180, cx: 50, cy: 25),
);
```

## Important Notes

- Both `shape.transform` matrix AND `shape.rotation` field must stay in sync
- Use `copyWith()` for immutable updates
- Always generate new UUIDs when duplicating shapes
