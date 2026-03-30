part of 'search_bloc.dart';

enum SearchStatus {
  idle,
  searching,
  ready,
}

class SearchState extends Equatable {
  const SearchState({
    this.query = '',
    this.status = SearchStatus.idle,
    this.layerResults = const [],
    this.assetResults = const [],
    this.colorResults = const [],
    this.branchResults = const [],
    this.commitResults = const [],
    this.pullRequestResults = const [],
  });

  final String query;
  final SearchStatus status;
  final List<SearchLayerResult> layerResults;
  final List<SearchAssetResult> assetResults;
  final List<SearchColorResult> colorResults;
  final List<SearchBranchResult> branchResults;
  final List<SearchCommitResult> commitResults;
  final List<SearchPullRequestResult> pullRequestResults;

  bool get hasQuery => query.isNotEmpty;

  int get totalResults =>
      layerResults.length +
      assetResults.length +
      colorResults.length +
      branchResults.length +
      commitResults.length +
      pullRequestResults.length;

  SearchState copyWith({
    String? query,
    SearchStatus? status,
    List<SearchLayerResult>? layerResults,
    List<SearchAssetResult>? assetResults,
    List<SearchColorResult>? colorResults,
    List<SearchBranchResult>? branchResults,
    List<SearchCommitResult>? commitResults,
    List<SearchPullRequestResult>? pullRequestResults,
    bool clearResults = false,
  }) {
    return SearchState(
      query: query ?? this.query,
      status: status ?? this.status,
      layerResults:
          clearResults ? const [] : (layerResults ?? this.layerResults),
      assetResults:
          clearResults ? const [] : (assetResults ?? this.assetResults),
      colorResults:
          clearResults ? const [] : (colorResults ?? this.colorResults),
      branchResults:
          clearResults ? const [] : (branchResults ?? this.branchResults),
      commitResults:
          clearResults ? const [] : (commitResults ?? this.commitResults),
      pullRequestResults: clearResults
          ? const []
          : (pullRequestResults ?? this.pullRequestResults),
    );
  }

  @override
  List<Object?> get props => [
        query,
        status,
        layerResults,
        assetResults,
        colorResults,
        branchResults,
        commitResults,
        pullRequestResults,
      ];
}

class SearchLayerResult extends Equatable {
  const SearchLayerResult({
    required this.shapeId,
    required this.title,
    required this.subtitle,
    required this.shapeType,
  });

  final String shapeId;
  final String title;
  final String subtitle;
  final ShapeType shapeType;

  @override
  List<Object?> get props => [shapeId, title, subtitle, shapeType];
}

class SearchAssetResult extends Equatable {
  const SearchAssetResult({
    required this.title,
    required this.subtitle,
    required this.isSvg,
  });

  final String title;
  final String subtitle;
  final bool isSvg;

  @override
  List<Object?> get props => [title, subtitle, isSvg];
}

class SearchColorResult extends Equatable {
  const SearchColorResult({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  List<Object?> get props => [title, subtitle];
}

class SearchBranchResult extends Equatable {
  const SearchBranchResult({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  List<Object?> get props => [title, subtitle];
}

class SearchCommitResult extends Equatable {
  const SearchCommitResult({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  List<Object?> get props => [title, subtitle];
}

class SearchPullRequestResult extends Equatable {
  const SearchPullRequestResult({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  List<Object?> get props => [title, subtitle];
}
