import 'package:flutter_bloc/flutter_bloc.dart';

class DrawerFormState<T> {
  final T draft;
  final bool confirmingDelete;

  const DrawerFormState({required this.draft, this.confirmingDelete = false});
}

class DrawerFormCubit<T> extends Cubit<DrawerFormState<T>> {
  DrawerFormCubit(T initialDraft)
      : super(DrawerFormState<T>(draft: initialDraft));

  void updateDraft(T newDraft) => emit(DrawerFormState<T>(
        draft: newDraft,
        confirmingDelete: state.confirmingDelete,
      ));

  void reset(T newDraft) => emit(DrawerFormState<T>(draft: newDraft));

  void requestDelete() => emit(DrawerFormState<T>(
        draft: state.draft,
        confirmingDelete: true,
      ));

  void cancelDelete() => emit(DrawerFormState<T>(
        draft: state.draft,
        confirmingDelete: false,
      ));
}
