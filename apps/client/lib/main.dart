import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vio_core/vio_core.dart';

import 'src/app.dart';
import 'src/core/core.dart';
import 'src/rust/frb_generated.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize logger
  VioLogger.initialize();

  // Initialize Rust engine (flutter_rust_bridge) only when a Rust feature is
  // enabled.  On web the WASM module must have been compiled; when no Rust
  // flag is set we skip loading entirely so the app still starts.
  const useRust = bool.fromEnvironment('VIO_USE_RUST_CANVAS') ||
      bool.fromEnvironment('VIO_USE_RUST_TILES') ||
      bool.fromEnvironment('VIO_USE_RUST_BACKEND');
  if (useRust) {
    try {
      await RustLib.init();
      RustEngineService.instance.rustAvailable = true;
      VioLogger.info('Rust engine initialized');
    } catch (e, st) {
      VioLogger.error('Rust engine init failed – running without Rust', e, st);
    }
  } else {
    VioLogger.info('Rust engine skipped (no VIO_USE_RUST_* flags set)');
  }

  // Build environment config from --dart-define-from-file values
  final appConfig = AppConfig.fromEnvironment();
  VioLogger.info('Environment: ${appConfig.environment.name}');
  VioLogger.info('Config: $appConfig');

  // Initialize service locator (gRPC services, repositories)
  await ServiceLocator.instance.initialize(config: appConfig);

  // Initialize HydratedBloc storage
  // Use web storage for web platform, otherwise use application documents directory
  HydratedBloc.storage = await HydratedStorage.build(
    storageDirectory: kIsWeb
        ? HydratedStorageDirectory.web
        : HydratedStorageDirectory((await getTemporaryDirectory()).path),
  );

  // Set up Bloc observer for debugging
  Bloc.observer = const VioBlocObserver();

  VioLogger.info('Starting Vio Client...');

  // Flush pending canvas changes when the app is about to be
  // paused, hidden, or closed (covers browser tab close, mobile
  // backgrounding, desktop window close, etc.)
  AppLifecycleListener(
    onStateChange: (state) {
      if (state == AppLifecycleState.paused ||
          state == AppLifecycleState.detached ||
          state == AppLifecycleState.hidden) {
        ServiceLocator.instance.canvasRepository.sync();
      }
    },
  );

  runApp(const VioApp());
}

/// Custom BlocObserver for debugging and logging
class VioBlocObserver extends BlocObserver {
  const VioBlocObserver();

  @override
  void onCreate(BlocBase<dynamic> bloc) {
    super.onCreate(bloc);
    VioLogger.debug('Bloc created: ${bloc.runtimeType}');
  }

  @override
  void onEvent(Bloc<dynamic, dynamic> bloc, Object? event) {
    super.onEvent(bloc, event);
    VioLogger.debug('${bloc.runtimeType} event: $event');
  }

  @override
  void onChange(BlocBase<dynamic> bloc, Change<dynamic> change) {
    super.onChange(bloc, change);
    VioLogger.debug(
      '${bloc.runtimeType} change: ${change.currentState.runtimeType} -> ${change.nextState.runtimeType}',
    );
  }

  @override
  void onTransition(
    Bloc<dynamic, dynamic> bloc,
    Transition<dynamic, dynamic> transition,
  ) {
    super.onTransition(bloc, transition);
    VioLogger.debug(
      '${bloc.runtimeType} transition: ${transition.event.runtimeType}',
    );
  }

  @override
  void onError(BlocBase<dynamic> bloc, Object error, StackTrace stackTrace) {
    super.onError(bloc, error, stackTrace);
    VioLogger.error('${bloc.runtimeType} error: $error', error, stackTrace);
  }

  @override
  void onClose(BlocBase<dynamic> bloc) {
    super.onClose(bloc);
    VioLogger.debug('Bloc closed: ${bloc.runtimeType}');
  }
}
