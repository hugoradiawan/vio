import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vio_core/vio_core.dart';

import 'src/app.dart';
import 'src/core/core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize logger
  VioLogger.initialize();

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
