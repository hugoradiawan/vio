# Vio Client

The Flutter client application for Vio - a Penpot-inspired design & prototyping tool with Git-like version control.

## Overview

This is the main composition root for the Vio design tool, providing a cross-platform UI (Web, Windows) built with Flutter.

## Architecture

The client follows a **feature-first Clean Architecture** pattern:

```
lib/src/
├── core/           # Shared infrastructure (API, theme, routing)
│   ├── api/        # REST API services & DTOs
│   └── grpc/       # gRPC services (planned)
└── features/       # Feature modules
    ├── canvas/     # Canvas editor with shape manipulation
    ├── version_control/  # Git-like branching & commits
    └── workspace/  # Project & workspace management
```

Each feature contains:
- `bloc/` - State management using flutter_bloc
- `models/` - Feature-specific data models  
- `presentation/` - Widgets and views

## Running

```bash
# Web
melos run run:client:web

# Windows
melos run run:client:windows
```

## Canvas Performance Diagnostics

Enable frontend canvas diagnostics logs (scroll/pan/zoom + frame timing):

```bash
flutter run -d chrome --dart-define=VIO_CANVAS_PERF_DIAGNOSTICS=true
```

Logs are emitted as structured JSON lines via `VioLogger` with prefix:

- `CANVAS_PERF { ...json... }`

Capture and share these lines after reproducing heavy-canvas interactions.

Summarize logs (p50/p95 by operation):

```bash
dart run tool/canvas_perf_summary.dart --input ./canvas-perf.log
```

Optional flags:

- `--operation wheel_zoom` to filter operations
- `--json` for machine-readable output

## Key Dependencies

- **flutter_bloc** - State management
- **go_router** - Declarative routing
- **dio** - HTTP client for REST API
- **grpc** - gRPC client (future version control)

## Internal Packages

- **vio_core** - Shared models, math utilities (Matrix2D, Shape hierarchy)
- **vio_ui_kit** - Design system (VioTheme, VioColors)
