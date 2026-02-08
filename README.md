# Vio Design Tool

A design and prototyping tool with Git-like version control, built with Flutter (frontend) and Bun + ConnectRPC (backend).

## 🚀 Quick Start

### Prerequisites

- [FVM](https://fvm.app/) - Flutter Version Management
- [Melos](https://melos.invertase.dev/) - Monorepo management
- [Bun](https://bun.sh/) - JavaScript runtime for backend
- [Podman](https://podman.io/) - Container runtime for PostgreSQL

### Setup

```bash
# Install FVM globally
dart pub global activate fvm

# Install Flutter version
fvm install

# Use the pinned Flutter version
fvm use

# Install Melos globally
dart pub global activate melos

# Bootstrap the monorepo
melos bootstrap

# Backend setup
cd backend && bun install
```

### Development

```bash
# Start PostgreSQL (required before backend)
podman machine start
podman compose up -d postgres

# Run client on web (uses config/dev.json for env)
melos run run:client:web

# Run client on Windows
melos run run:client:windows

# Run backend (with watch mode, ports 4000/4001)
cd backend && bun run dev

# Database
cd backend && bun run db:push          # Push Drizzle schema to PostgreSQL
cd backend && bun run db:seed          # Seed demo data

# Protobuf codegen (generates both backend/src/gen/ and apps/client/lib/src/gen/)
cd backend && bun run proto:generate

# Run all tests
melos run test

# Analyze code
melos run analyze

# Format backend (Biome)
cd backend && bun run format
```

## 📁 Project Structure

```
vio/
├── apps/
│   └── client/                     # Flutter app (Web/Windows)
│       └── lib/src/
│           ├── features/
│           │   ├── canvas/         # Infinite canvas (bloc, painters, widgets)
│           │   ├── version_control/ # Branch/commit/PR UI
│           │   ├── workspace/      # Shell layout, panels, toolbars
│           │   └── assets/         # Image/SVG asset management
│           ├── core/               # DI, gRPC client, repositories, config
│           └── gen/                # Generated Dart gRPC stubs
├── packages/
│   ├── core/                       # Shared models (Shape hierarchy), math (Matrix2D)
│   ├── ui_kit/                     # Design system (VioTheme, VioColors)
│   └── protos/                     # Protobuf .proto files (single source of truth)
│       └── vio/v1/                 # shape, canvas, branch, commit, pullrequest, etc.
├── backend/                        # Bun + ConnectRPC gRPC server
│   └── src/
│       ├── services/               # Service implementations (ServiceImpl<T>)
│       ├── db/schema/              # Drizzle ORM schema (PostgreSQL)
│       └── gen/                    # Generated TypeScript from protos
├── PLAN.md                         # Development roadmap
└── PROGRESS.md                     # Daily progress log
```

## 🎨 Features

- **Infinite Canvas**: High-performance rendering with CustomPainter
- **Shape Tools**: Rectangle, ellipse, frame, text, images, SVG
- **Text Tool**: Inline editing, typography controls, Google Fonts rendering
- **Context Menus**: Right-click menus on canvas and layers (cut/copy/paste, group/ungroup, z-order)
- **Layers Panel**: Penpot-like row hover controls (eye/lock), drag/drop reparenting
- **Git-like Version Control**: Branches, commits, and pull requests for designs
- **Three-way Merge**: Property-level conflict detection and resolution
- **Blue Dark Mode**: Beautiful dark theme optimized for design work

## 🖱️ Canvas Controls

- Pan: trackpad two-finger scroll / mouse wheel
- Horizontal pan: `Shift` + mouse wheel
- Zoom: `Ctrl` + mouse wheel / trackpad pinch
- Context menu: right click

## ⌨️ Keyboard Shortcuts

- `Ctrl+\` — Toggle zen mode (hide left panel + right panel + rulers)
- `Ctrl+Alt+\` — Toggle left panel
- `Ctrl+Shift+\` — Toggle right panel
- `Ctrl+Shift+R` — Toggle rulers
- `Ctrl+`` — Toggle grid
- `Ctrl+'` — Toggle snap-to-grid
- `Ctrl+C / Ctrl+X / Ctrl+V / Ctrl+D` — Copy / Cut / Paste / Duplicate
- `Ctrl+Z / Ctrl+Y` — Undo / Redo

## 📖 Documentation

- [PLAN.md](./PLAN.md) - Detailed development roadmap
- [PROGRESS.md](./PROGRESS.md) - Daily development log
