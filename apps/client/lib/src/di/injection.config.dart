// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

import 'package:get_it/get_it.dart' as _i174;
import 'package:injectable/injectable.dart' as _i526;

import '../features/workspace/bloc/workspace_bloc.dart' as _i1;
import '../features/canvas/bloc/canvas_bloc.dart' as _i2;

extension GetItInjectableX on _i174.GetIt {
  // initializes the registration of main-scope dependencies inside of GetIt
  _i174.GetIt init({
    String? environment,
    _i526.EnvironmentFilter? environmentFilter,
  }) {
    final gh = _i526.GetItHelper(
      this,
      environment,
      environmentFilter,
    );

    gh.factory<_i1.WorkspaceBloc>(() => _i1.WorkspaceBloc());
    gh.factory<_i2.CanvasBloc>(() => _i2.CanvasBloc());

    return this;
  }
}
