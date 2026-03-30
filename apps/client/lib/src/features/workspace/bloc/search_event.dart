part of 'search_bloc.dart';

sealed class SearchEvent extends Equatable {
  const SearchEvent();

  @override
  List<Object?> get props => [];
}

class SearchQueryChanged extends SearchEvent {
  const SearchQueryChanged(this.query);

  final String query;

  @override
  List<Object?> get props => [query];
}

class SearchCleared extends SearchEvent {
  const SearchCleared();
}

class _SearchRecomputeRequested extends SearchEvent {
  const _SearchRecomputeRequested(this.query);

  final String query;

  @override
  List<Object?> get props => [query];
}

class _SearchSourcesUpdated extends SearchEvent {
  const _SearchSourcesUpdated();
}
