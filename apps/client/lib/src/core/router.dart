import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../features/assets/bloc/asset_bloc.dart';
import '../features/auth/bloc/auth_bloc.dart';
import '../features/auth/presentation/login_page.dart';
import '../features/auth/presentation/register_page.dart';
import '../features/canvas/bloc/canvas_bloc.dart';
import '../features/version_control/bloc/version_control_bloc.dart';
import '../features/workspace/bloc/workspace_bloc.dart';
import '../features/workspace/presentation/workspace_page.dart';
import 'service_locator.dart';

export 'package:go_router/go_router.dart' show GoRouter;

/// Create the app router with auth guards.
///
/// The [authBloc] is used to listen for auth state changes and redirect
/// accordingly (unauthenticated users → /login, authenticated → /).
GoRouter createRouter(AuthBloc authBloc) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: _AuthStateNotifier(authBloc),
    redirect: (context, state) {
      final authState = authBloc.state;
      final isAuthenticated =
          authState.status == AuthStatus.authenticated;
      final isAuthRoute = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';

      debugPrint(
        '[Router] redirect: status=${authState.status}, '
        'location=${state.matchedLocation}, '
        'isAuthRoute=$isAuthRoute',
      );

      // Still checking — redirect to login to avoid building workspace prematurely
      if (authState.status == AuthStatus.initial ||
          authState.status == AuthStatus.loading) {
        return isAuthRoute ? null : '/login';
      }

      // Not authenticated and not on an auth route → send to login
      if (!isAuthenticated && !isAuthRoute) {
        return '/login';
      }

      // Authenticated but on an auth route → send to workspace
      if (isAuthenticated && isAuthRoute) {
        return '/';
      }

      return null; // No redirect needed
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) {
          // Get the user from AuthBloc to derive the userId
          final authState = context.read<AuthBloc>().state;
          final userId = authState.user?.id ?? '';

          return MultiBlocProvider(
            providers: [
              BlocProvider(
                create: (_) =>
                    WorkspaceBloc()..add(const WorkspaceInitialized()),
              ),
              BlocProvider(
                create: (_) => CanvasBloc(
                  repository: ServiceLocator.instance.canvasRepository,
                ),
              ),
              BlocProvider(
                create: (_) => VersionControlBloc()
                  ..add(
                    VersionControlInitialized(
                      projectId: _demoProjectId,
                      userId: userId,
                    ),
                  ),
              ),
              BlocProvider(
                create: (context) => AssetBloc(
                  assetService: ServiceLocator.instance.assetService,
                  canvasBloc: context.read<CanvasBloc>(),
                )..add(AssetsLoadRequested(projectId: _demoProjectId)),
              ),
            ],
            child: const _CanvasVersionControlBridge(
              child: WorkspacePage(),
            ),
          );
        },
      ),
    ],
  );
}

// Demo project ID (matching backend seed script)
// const _demoProjectId = '00000000-0000-0000-0000-000000000001';
// const _demoProjectId = '11111111-0000-0000-0000-000000000003';
const _demoProjectId = '11111111-0000-0000-0000-000000000002';
// const _demoProjectId = '11111111-0000-0000-0000-000000000001';

/// Converts [AuthBloc] stream into a [ChangeNotifier] for GoRouter's
/// [refreshListenable].
class _AuthStateNotifier extends ChangeNotifier {
  _AuthStateNotifier(AuthBloc authBloc) {
    _subscription = authBloc.stream.listen((_) {
      notifyListeners();
    });
  }

  late final StreamSubscription<AuthState> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

/// Bridge widget that syncs CanvasBloc state changes to VersionControlBloc
/// for change detection (uncommitted changes tracking).
/// Also syncs VersionControlBloc branch switches back to CanvasBloc.
///
/// Duplicated from app.dart to keep the router self-contained. The original
/// in app.dart will be removed once the migration is complete.
class _CanvasVersionControlBridge extends StatelessWidget {
  const _CanvasVersionControlBridge({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        // Canvas → VersionControl: track shape changes for uncommitted detection
        BlocListener<CanvasBloc, CanvasState>(
          listenWhen: (previous, current) {
            return previous.shapes != current.shapes;
          },
          listener: (context, canvasState) {
            final vcBloc = context.read<VersionControlBloc>();
            vcBloc.add(CanvasShapesChanged(shapes: canvasState.shapes));
            debugPrint(
              '[Bridge] Canvas shapes updated: ${canvasState.shapes.length} shapes',
            );
          },
        ),
        // VersionControl → Canvas: sync shapes when branch switches OR initial load completes
        BlocListener<VersionControlBloc, VersionControlState>(
          listenWhen: (previous, current) {
            final switchCompleted =
                previous.status == VersionControlStatus.switching &&
                    current.status == VersionControlStatus.ready;
            final initialLoadCompleted =
                previous.status == VersionControlStatus.loading &&
                    current.status == VersionControlStatus.ready;
            return switchCompleted || initialLoadCompleted;
          },
          listener: (context, vcState) {
            final canvasBloc = context.read<CanvasBloc>();
            final newShapes = vcState.currentShapes;
            debugPrint(
              '[Bridge] Branch loaded/switched, updating canvas with ${newShapes.length} shapes',
            );
            for (final shape in newShapes.values) {
              debugPrint(
                '[Bridge] Shape: ${shape.id} type=${shape.type} name=${shape.name}',
              );
            }
            canvasBloc.add(ShapesReplaced(newShapes));
          },
        ),
      ],
      child: child,
    );
  }
}
