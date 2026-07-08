// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'mini_tracker_cubit.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$MiniTrackerState {

 bool get isRunning; TimeEntry? get activeEntry; List<TimeEntry> get allEntries; List<Task> get tasks; List<Project> get projects; int get lastTimestamp;
/// Create a copy of MiniTrackerState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MiniTrackerStateCopyWith<MiniTrackerState> get copyWith => _$MiniTrackerStateCopyWithImpl<MiniTrackerState>(this as MiniTrackerState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MiniTrackerState&&(identical(other.isRunning, isRunning) || other.isRunning == isRunning)&&(identical(other.activeEntry, activeEntry) || other.activeEntry == activeEntry)&&const DeepCollectionEquality().equals(other.allEntries, allEntries)&&const DeepCollectionEquality().equals(other.tasks, tasks)&&const DeepCollectionEquality().equals(other.projects, projects)&&(identical(other.lastTimestamp, lastTimestamp) || other.lastTimestamp == lastTimestamp));
}


@override
int get hashCode => Object.hash(runtimeType,isRunning,activeEntry,const DeepCollectionEquality().hash(allEntries),const DeepCollectionEquality().hash(tasks),const DeepCollectionEquality().hash(projects),lastTimestamp);

@override
String toString() {
  return 'MiniTrackerState(isRunning: $isRunning, activeEntry: $activeEntry, allEntries: $allEntries, tasks: $tasks, projects: $projects, lastTimestamp: $lastTimestamp)';
}


}

/// @nodoc
abstract mixin class $MiniTrackerStateCopyWith<$Res>  {
  factory $MiniTrackerStateCopyWith(MiniTrackerState value, $Res Function(MiniTrackerState) _then) = _$MiniTrackerStateCopyWithImpl;
@useResult
$Res call({
 bool isRunning, TimeEntry? activeEntry, List<TimeEntry> allEntries, List<Task> tasks, List<Project> projects, int lastTimestamp
});




}
/// @nodoc
class _$MiniTrackerStateCopyWithImpl<$Res>
    implements $MiniTrackerStateCopyWith<$Res> {
  _$MiniTrackerStateCopyWithImpl(this._self, this._then);

  final MiniTrackerState _self;
  final $Res Function(MiniTrackerState) _then;

/// Create a copy of MiniTrackerState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? isRunning = null,Object? activeEntry = freezed,Object? allEntries = null,Object? tasks = null,Object? projects = null,Object? lastTimestamp = null,}) {
  return _then(_self.copyWith(
isRunning: null == isRunning ? _self.isRunning : isRunning // ignore: cast_nullable_to_non_nullable
as bool,activeEntry: freezed == activeEntry ? _self.activeEntry : activeEntry // ignore: cast_nullable_to_non_nullable
as TimeEntry?,allEntries: null == allEntries ? _self.allEntries : allEntries // ignore: cast_nullable_to_non_nullable
as List<TimeEntry>,tasks: null == tasks ? _self.tasks : tasks // ignore: cast_nullable_to_non_nullable
as List<Task>,projects: null == projects ? _self.projects : projects // ignore: cast_nullable_to_non_nullable
as List<Project>,lastTimestamp: null == lastTimestamp ? _self.lastTimestamp : lastTimestamp // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [MiniTrackerState].
extension MiniTrackerStatePatterns on MiniTrackerState {
/// A variant of `map` that fallback to returning `orElse`.
@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MiniTrackerState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MiniTrackerState() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MiniTrackerState value)  $default,){
final _that = this;
switch (_that) {
case _MiniTrackerState():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MiniTrackerState value)?  $default,){
final _that = this;
switch (_that) {
case _MiniTrackerState() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool isRunning,  TimeEntry? activeEntry,  List<TimeEntry> allEntries,  List<Task> tasks,  List<Project> projects,  int lastTimestamp)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MiniTrackerState() when $default != null:
return $default(_that.isRunning,_that.activeEntry,_that.allEntries,_that.tasks,_that.projects,_that.lastTimestamp);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool isRunning,  TimeEntry? activeEntry,  List<TimeEntry> allEntries,  List<Task> tasks,  List<Project> projects,  int lastTimestamp)  $default,) {final _that = this;
switch (_that) {
case _MiniTrackerState():
return $default(_that.isRunning,_that.activeEntry,_that.allEntries,_that.tasks,_that.projects,_that.lastTimestamp);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool isRunning,  TimeEntry? activeEntry,  List<TimeEntry> allEntries,  List<Task> tasks,  List<Project> projects,  int lastTimestamp)?  $default,) {final _that = this;
switch (_that) {
case _MiniTrackerState() when $default != null:
return $default(_that.isRunning,_that.activeEntry,_that.allEntries,_that.tasks,_that.projects,_that.lastTimestamp);case _:
  return null;

}
}

}

/// @nodoc


class _MiniTrackerState extends MiniTrackerState {
  const _MiniTrackerState({this.isRunning = false, this.activeEntry, final  List<TimeEntry> allEntries = const [], final  List<Task> tasks = const [], final  List<Project> projects = const [], this.lastTimestamp = 0}): _allEntries = allEntries,_tasks = tasks,_projects = projects,super._();


@override final  bool isRunning;
@override final  TimeEntry? activeEntry;
 final  List<TimeEntry> _allEntries;
@JsonKey() List<TimeEntry> get allEntries {
  if (_allEntries is EqualUnmodifiableListView) return _allEntries;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_allEntries);
}

 final  List<Task> _tasks;
@JsonKey() List<Task> get tasks {
  if (_tasks is EqualUnmodifiableListView) return _tasks;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_tasks);
}

 final  List<Project> _projects;
@JsonKey() List<Project> get projects {
  if (_projects is EqualUnmodifiableListView) return _projects;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_projects);
}

@override final  int lastTimestamp;

/// Create a copy of MiniTrackerState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MiniTrackerStateCopyWith<_MiniTrackerState> get copyWith => __$MiniTrackerStateCopyWithImpl<_MiniTrackerState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MiniTrackerState&&(identical(other.isRunning, isRunning) || other.isRunning == isRunning)&&(identical(other.activeEntry, activeEntry) || other.activeEntry == activeEntry)&&const DeepCollectionEquality().equals(other._allEntries, _allEntries)&&const DeepCollectionEquality().equals(other._tasks, _tasks)&&const DeepCollectionEquality().equals(other._projects, _projects)&&(identical(other.lastTimestamp, lastTimestamp) || other.lastTimestamp == lastTimestamp));
}


@override
int get hashCode => Object.hash(runtimeType,isRunning,activeEntry,const DeepCollectionEquality().hash(_allEntries),const DeepCollectionEquality().hash(_tasks),const DeepCollectionEquality().hash(_projects),lastTimestamp);

@override
String toString() {
  return 'MiniTrackerState(isRunning: $isRunning, activeEntry: $activeEntry, allEntries: $allEntries, tasks: $tasks, projects: $projects, lastTimestamp: $lastTimestamp)';
}


}

/// @nodoc
abstract mixin class _$MiniTrackerStateCopyWith<$Res> implements $MiniTrackerStateCopyWith<$Res> {
  factory _$MiniTrackerStateCopyWith(_MiniTrackerState value, $Res Function(_MiniTrackerState) _then) = __$MiniTrackerStateCopyWithImpl;
@override @useResult
$Res call({
 bool isRunning, TimeEntry? activeEntry, List<TimeEntry> allEntries, List<Task> tasks, List<Project> projects, int lastTimestamp
});




}
/// @nodoc
class __$MiniTrackerStateCopyWithImpl<$Res>
    implements _$MiniTrackerStateCopyWith<$Res> {
  __$MiniTrackerStateCopyWithImpl(this._self, this._then);

  final _MiniTrackerState _self;
  final $Res Function(_MiniTrackerState) _then;

/// Create a copy of MiniTrackerState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? isRunning = null,Object? activeEntry = freezed,Object? allEntries = null,Object? tasks = null,Object? projects = null,Object? lastTimestamp = null,}) {
  return _then(_MiniTrackerState(
isRunning: null == isRunning ? _self.isRunning : isRunning // ignore: cast_nullable_to_non_nullable
as bool,activeEntry: freezed == activeEntry ? _self.activeEntry : activeEntry // ignore: cast_nullable_to_non_nullable
as TimeEntry?,allEntries: null == allEntries ? _self._allEntries : allEntries // ignore: cast_nullable_to_non_nullable
as List<TimeEntry>,tasks: null == tasks ? _self._tasks : tasks // ignore: cast_nullable_to_non_nullable
as List<Task>,projects: null == projects ? _self._projects : projects // ignore: cast_nullable_to_non_nullable
as List<Project>,lastTimestamp: null == lastTimestamp ? _self.lastTimestamp : lastTimestamp // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
