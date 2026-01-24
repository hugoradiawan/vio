# Vio Design Tool

A design and prototyping tool with Git-like version control, built with Flutter (frontend) and Bun + Elysia (backend).

## 🚀 Quick Start

### Prerequisites

- [FVM](https://fvm.app/) - Flutter Version Management
- [Melos](https://melos.invertase.dev/) - Monorepo management
- [Bun](https://bun.sh/) - JavaScript runtime for backend

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
```

### Development

```bash
# Run client on web
melos run run:client:web

# Run client on Windows
melos run run:client:windows

# Run all tests
melos run test

# Analyze code
melos run analyze
```

## 📁 Project Structure

```
vio/
├── apps/
│   └── client/           # Main Flutter application
├── packages/
│   ├── core/             # Shared utilities & abstractions
│   ├── ui_kit/           # Design system components
│   └── protos/           # Protobuf definitions
├── features/
│   ├── canvas/           # Infinite canvas feature
│   ├── version_control/  # Git-like VC feature
│   ├── auth/             # Authentication feature
│   └── collaboration/    # Real-time collaboration
├── backend/
│   └── server/           # Bun + Elysia API server
├── PLAN.md               # Development roadmap
└── PROGRESS.md           # Daily progress log
```

## 🎨 Features

- **Infinite Canvas**: High-performance rendering with CustomPainter
- **Text Tool**: Inline editing, typography controls, Google Fonts rendering
- **Context Menus**: Right-click menus on canvas and layers (cut/copy/paste, group/ungroup, z-order)
- **Layers Panel**: Penpot-like row hover controls (eye/lock), drag/drop reparenting
- **Git-like Version Control**: Branches, commits, and pull requests for designs
- **Real-time Collaboration**: Cursor presence and draft state sync via gRPC
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

## 📄 License

MIT
