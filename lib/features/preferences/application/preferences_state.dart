const defaultTaskMinutes = 30;

enum PreferencesErrorKind { load, save }

class PreferencesState {
  const PreferencesState({
    this.defaultTaskMinutes = 30,
    this.isLoading = false,
    this.isSaving = false,
    this.error,
    this.errorKind,
  });

  final int defaultTaskMinutes;
  final bool isLoading;
  final bool isSaving;
  final Object? error;
  final PreferencesErrorKind? errorKind;

  PreferencesState copyWith({
    int? defaultTaskMinutes,
    bool? isLoading,
    bool? isSaving,
    Object? error = _unset,
    Object? errorKind = _unset,
  }) =>
      PreferencesState(
        defaultTaskMinutes: defaultTaskMinutes ?? this.defaultTaskMinutes,
        isLoading: isLoading ?? this.isLoading,
        isSaving: isSaving ?? this.isSaving,
        error: identical(error, _unset) ? this.error : error,
        errorKind: identical(errorKind, _unset)
            ? this.errorKind
            : errorKind as PreferencesErrorKind?,
      );
}

const _unset = Object();

bool isValidDefaultTaskMinutes(Object? value) =>
    value is int && value >= 1 && value <= 1440 && value % 5 == 0;

int normalizeDefaultTaskMinutes(Object? value) =>
    isValidDefaultTaskMinutes(value) ? value as int : defaultTaskMinutes;
