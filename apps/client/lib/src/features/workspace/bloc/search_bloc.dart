import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vio_core/vio_core.dart';

import '../../../gen/vio/v1/branch.pb.dart' as branch_pb;
import '../../../gen/vio/v1/commit.pb.dart' as commit_pb;
import '../../../gen/vio/v1/pullrequest.pb.dart' as pr_pb;
import '../../assets/bloc/asset_bloc.dart';
import '../../canvas/bloc/canvas_bloc.dart';
import '../../version_control/bloc/version_control_bloc.dart';

part 'search_event.dart';
part 'search_state.dart';

const _queryDebounceDelay = Duration(milliseconds: 300);
const _maxResultsPerSection = 30;

/// Coordinates and filters workspace search data from Canvas, Assets,
/// and Version Control domains.
class SearchBloc extends Bloc<SearchEvent, SearchState> {
  SearchBloc({
    required CanvasBloc canvasBloc,
    required AssetBloc assetBloc,
    required VersionControlBloc versionControlBloc,
  })  : _canvasBloc = canvasBloc,
        _assetBloc = assetBloc,
        _versionControlBloc = versionControlBloc,
        _cachedShapes = canvasBloc.state.shapeList,
        _cachedAssets = assetBloc.state.assets,
        _cachedColors = assetBloc.state.colors,
        _cachedBranches = versionControlBloc.state.branches,
        _cachedCommits = versionControlBloc.state.commits,
        _cachedPullRequests = versionControlBloc.state.pullRequests,
        super(const SearchState()) {
    on<SearchQueryChanged>(_onQueryChanged);
    on<SearchCleared>(_onCleared);
    on<_SearchRecomputeRequested>(_onRecomputeRequested);
    on<_SearchSourcesUpdated>(_onSourcesUpdated);

    _canvasSubscription = _canvasBloc.stream.listen(_onCanvasStateChanged);
    _assetSubscription = _assetBloc.stream.listen(_onAssetStateChanged);
    _versionControlSubscription =
        _versionControlBloc.stream.listen(_onVersionControlStateChanged);
  }

  final CanvasBloc _canvasBloc;
  final AssetBloc _assetBloc;
  final VersionControlBloc _versionControlBloc;

  StreamSubscription<CanvasState>? _canvasSubscription;
  StreamSubscription<AssetState>? _assetSubscription;
  StreamSubscription<VersionControlState>? _versionControlSubscription;
  Timer? _queryDebounceTimer;

  List<Shape> _cachedShapes;
  List<ProjectAsset> _cachedAssets;
  List<ProjectColor> _cachedColors;
  List<branch_pb.Branch> _cachedBranches;
  List<commit_pb.Commit> _cachedCommits;
  List<pr_pb.PullRequest> _cachedPullRequests;

  void _onQueryChanged(
    SearchQueryChanged event,
    Emitter<SearchState> emit,
  ) {
    final nextQuery = event.query.trim();
    if (nextQuery == state.query) return;

    _queryDebounceTimer?.cancel();

    if (nextQuery.isEmpty) {
      emit(
        state.copyWith(
          query: '',
          status: SearchStatus.idle,
          clearResults: true,
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        query: nextQuery,
        status: SearchStatus.searching,
      ),
    );

    _queryDebounceTimer = Timer(
      _queryDebounceDelay,
      () => add(_SearchRecomputeRequested(nextQuery.toLowerCase())),
    );
  }

  void _onCleared(
    SearchCleared event,
    Emitter<SearchState> emit,
  ) {
    _queryDebounceTimer?.cancel();
    emit(
      state.copyWith(
        query: '',
        status: SearchStatus.idle,
        clearResults: true,
      ),
    );
  }

  void _onRecomputeRequested(
    _SearchRecomputeRequested event,
    Emitter<SearchState> emit,
  ) {
    if (state.query.isEmpty) return;

    final normalizedQuery = state.query.toLowerCase();
    if (event.query != normalizedQuery) return;

    final nextState = state.copyWith(
      status: SearchStatus.ready,
      layerResults: _buildLayerResults(normalizedQuery),
      assetResults: _buildAssetResults(normalizedQuery),
      colorResults: _buildColorResults(normalizedQuery),
      branchResults: _buildBranchResults(normalizedQuery),
      commitResults: _buildCommitResults(normalizedQuery),
      pullRequestResults: _buildPullRequestResults(normalizedQuery),
    );

    if (nextState == state) return;
    emit(nextState);
  }

  void _onSourcesUpdated(
    _SearchSourcesUpdated event,
    Emitter<SearchState> emit,
  ) {
    if (state.query.isEmpty) return;

    _queryDebounceTimer?.cancel();

    emit(state.copyWith(status: SearchStatus.searching));
    _queryDebounceTimer = Timer(
      _queryDebounceDelay,
      () => add(_SearchRecomputeRequested(state.query.toLowerCase())),
    );
  }

  void _onCanvasStateChanged(CanvasState canvasState) {
    final nextShapes = canvasState.shapeList;
    if (identical(nextShapes, _cachedShapes)) return;

    _cachedShapes = nextShapes;
    add(const _SearchSourcesUpdated());
  }

  void _onAssetStateChanged(AssetState assetState) {
    final nextAssets = assetState.assets;
    final nextColors = assetState.colors;
    final assetsChanged = !identical(nextAssets, _cachedAssets);
    final colorsChanged = !identical(nextColors, _cachedColors);
    if (!assetsChanged && !colorsChanged) return;

    _cachedAssets = nextAssets;
    _cachedColors = nextColors;
    add(const _SearchSourcesUpdated());
  }

  void _onVersionControlStateChanged(VersionControlState versionControlState) {
    final nextBranches = versionControlState.branches;
    final nextCommits = versionControlState.commits;
    final nextPullRequests = versionControlState.pullRequests;
    final branchesChanged = !identical(nextBranches, _cachedBranches);
    final commitsChanged = !identical(nextCommits, _cachedCommits);
    final pullRequestsChanged =
        !identical(nextPullRequests, _cachedPullRequests);

    if (!branchesChanged && !commitsChanged && !pullRequestsChanged) {
      return;
    }

    _cachedBranches = nextBranches;
    _cachedCommits = nextCommits;
    _cachedPullRequests = nextPullRequests;
    add(const _SearchSourcesUpdated());
  }

  List<SearchLayerResult> _buildLayerResults(String query) {
    final results = <SearchLayerResult>[];
    for (final shape in _cachedShapes) {
      final matches = _matches(
        query,
        [
          shape.name,
          shape.type.name,
          shape.id,
          if (shape is TextShape) shape.text,
        ],
      );

      if (!matches) continue;

      results.add(
        SearchLayerResult(
          shapeId: shape.id,
          title:
              shape.name.isEmpty ? 'Untitled ${shape.type.name}' : shape.name,
          subtitle: shape is TextShape && shape.text.isNotEmpty
              ? '${shape.type.name} · ${_truncate(shape.text, 40)}'
              : '${shape.type.name} · ${shape.id}',
          shapeType: shape.type,
        ),
      );

      if (results.length >= _maxResultsPerSection) break;
    }

    return results;
  }

  List<SearchAssetResult> _buildAssetResults(String query) {
    final results = <SearchAssetResult>[];
    for (final asset in _cachedAssets) {
      final matches =
          _matches(query, [asset.name, asset.path, asset.mimeType, asset.id]);
      if (!matches) continue;

      results.add(
        SearchAssetResult(
          title: asset.name,
          subtitle: asset.path.isEmpty
              ? asset.mimeType
              : '${asset.path} · ${asset.mimeType}',
          isSvg: asset.isSvg,
        ),
      );

      if (results.length >= _maxResultsPerSection) break;
    }

    return results;
  }

  List<SearchColorResult> _buildColorResults(String query) {
    final results = <SearchColorResult>[];
    for (final color in _cachedColors) {
      final matches = _matches(
        query,
        [color.name, color.path, color.color, color.id],
      );
      if (!matches) continue;

      results.add(
        SearchColorResult(
          title: color.name,
          subtitle: color.path.isEmpty
              ? (color.color ?? 'Gradient')
              : '${color.path} · ${color.color ?? 'Gradient'}',
        ),
      );

      if (results.length >= _maxResultsPerSection) break;
    }

    return results;
  }

  List<SearchBranchResult> _buildBranchResults(String query) {
    final results = <SearchBranchResult>[];
    for (final branch in _cachedBranches) {
      final matches =
          _matches(query, [branch.name, branch.description, branch.id]);
      if (!matches) continue;

      results.add(
        SearchBranchResult(
          title: branch.name,
          subtitle: branch.description.isEmpty
              ? branch.id
              : '${branch.description} · ${branch.id}',
        ),
      );

      if (results.length >= _maxResultsPerSection) break;
    }

    return results;
  }

  List<SearchCommitResult> _buildCommitResults(String query) {
    final results = <SearchCommitResult>[];
    for (final commit in _cachedCommits) {
      final matches = _matches(
        query,
        [commit.message, commit.authorId, commit.id, commit.branchId],
      );
      if (!matches) continue;

      results.add(
        SearchCommitResult(
          title: commit.message,
          subtitle: '${commit.authorId} · ${commit.id}',
        ),
      );

      if (results.length >= _maxResultsPerSection) break;
    }

    return results;
  }

  List<SearchPullRequestResult> _buildPullRequestResults(String query) {
    final results = <SearchPullRequestResult>[];
    for (final pullRequest in _cachedPullRequests) {
      final matches = _matches(
        query,
        [
          pullRequest.title,
          pullRequest.description,
          pullRequest.id,
          pullRequest.sourceBranchId,
          pullRequest.targetBranchId,
        ],
      );
      if (!matches) continue;

      results.add(
        SearchPullRequestResult(
          title: pullRequest.title,
          subtitle:
              '${_enumName(pullRequest.status)} · ${pullRequest.sourceBranchId} → ${pullRequest.targetBranchId}',
        ),
      );

      if (results.length >= _maxResultsPerSection) break;
    }

    return results;
  }

  bool _matches(String query, List<String?> values) {
    if (query.isEmpty) return true;
    return values.any((value) => (value ?? '').toLowerCase().contains(query));
  }

  String _truncate(String value, int maxLength) {
    final singleLine = value.replaceAll(RegExp(r'\s+'), ' ');
    if (singleLine.length <= maxLength) return singleLine;
    return '${singleLine.substring(0, maxLength)}…';
  }

  String _enumName(Object enumValue) {
    final raw = enumValue.toString();
    final dotIndex = raw.lastIndexOf('.');
    return dotIndex >= 0 ? raw.substring(dotIndex + 1) : raw;
  }

  @override
  Future<void> close() {
    _queryDebounceTimer?.cancel();
    _canvasSubscription?.cancel();
    _assetSubscription?.cancel();
    _versionControlSubscription?.cancel();
    return super.close();
  }
}
