// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'time_tracker_bloc.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$TimeTrackerEvent {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TimeTrackerEvent);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'TimeTrackerEvent()';
}


}

/// @nodoc
class $TimeTrackerEventCopyWith<$Res>  {
$TimeTrackerEventCopyWith(TimeTrackerEvent _, $Res Function(TimeTrackerEvent) __);
}


/// Adds pattern-matching-related methods to [TimeTrackerEvent].
extension TimeTrackerEventPatterns on TimeTrackerEvent {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( TimeTrackerLoaded value)?  loaded,TResult Function( TimeTrackerStarted value)?  started,TResult Function( TimeTrackerStopped value)?  stopped,TResult Function( TimeTrackerActiveEntryUpdated value)?  activeEntryUpdated,TResult Function( TimeTrackerEntryDeleted value)?  entryDeleted,TResult Function( TimeTrackerEntryCreated value)?  entryCreated,TResult Function( TimeTrackerEntryUpdated value)?  entryUpdated,required TResult orElse(),}){
final _that = this;
switch (_that) {
case TimeTrackerLoaded() when loaded != null:
return loaded(_that);case TimeTrackerStarted() when started != null:
return started(_that);case TimeTrackerStopped() when stopped != null:
return stopped(_that);case TimeTrackerActiveEntryUpdated() when activeEntryUpdated != null:
return activeEntryUpdated(_that);case TimeTrackerEntryDeleted() when entryDeleted != null:
return entryDeleted(_that);case TimeTrackerEntryCreated() when entryCreated != null:
return entryCreated(_that);case TimeTrackerEntryUpdated() when entryUpdated != null:
return entryUpdated(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( TimeTrackerLoaded value)  loaded,required TResult Function( TimeTrackerStarted value)  started,required TResult Function( TimeTrackerStopped value)  stopped,required TResult Function( TimeTrackerActiveEntryUpdated value)  activeEntryUpdated,required TResult Function( TimeTrackerEntryDeleted value)  entryDeleted,required TResult Function( TimeTrackerEntryCreated value)  entryCreated,required TResult Function( TimeTrackerEntryUpdated value)  entryUpdated,}){
final _that = this;
switch (_that) {
case TimeTrackerLoaded():
return loaded(_that);case TimeTrackerStarted():
return started(_that);case TimeTrackerStopped():
return stopped(_that);case TimeTrackerActiveEntryUpdated():
return activeEntryUpdated(_that);case TimeTrackerEntryDeleted():
return entryDeleted(_that);case TimeTrackerEntryCreated():
return entryCreated(_that);case TimeTrackerEntryUpdated():
return entryUpdated(_that);}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( TimeTrackerLoaded value)?  loaded,TResult? Function( TimeTrackerStarted value)?  started,TResult? Function( TimeTrackerStopped value)?  stopped,TResult? Function( TimeTrackerActiveEntryUpdated value)?  activeEntryUpdated,TResult? Function( TimeTrackerEntryDeleted value)?  entryDeleted,TResult? Function( TimeTrackerEntryCreated value)?  entryCreated,TResult? Function( TimeTrackerEntryUpdated value)?  entryUpdated,}){
final _that = this;
switch (_that) {
case TimeTrackerLoaded() when loaded != null:
return loaded(_that);case TimeTrackerStarted() when started != null:
return started(_that);case TimeTrackerStopped() when stopped != null:
return stopped(_that);case TimeTrackerActiveEntryUpdated() when activeEntryUpdated != null:
return activeEntryUpdated(_that);case TimeTrackerEntryDeleted() when entryDeleted != null:
return entryDeleted(_that);case TimeTrackerEntryCreated() when entryCreated != null:
return entryCreated(_that);case TimeTrackerEntryUpdated() when entryUpdated != null:
return entryUpdated(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  loaded,TResult Function( String? projectId,  String? taskId,  String? comment)?  started,TResult Function()?  stopped,TResult Function( String? projectId,  String? taskId,  String? comment)?  activeEntryUpdated,TResult Function( String id)?  entryDeleted,TResult Function( TimeEntry entry)?  entryCreated,TResult Function( TimeEntry entry)?  entryUpdated,required TResult orElse(),}) {final _that = this;
switch (_that) {
case TimeTrackerLoaded() when loaded != null:
return loaded();case TimeTrackerStarted() when started != null:
return started(_that.projectId,_that.taskId,_that.comment);case TimeTrackerStopped() when stopped != null:
return stopped();case TimeTrackerActiveEntryUpdated() when activeEntryUpdated != null:
return activeEntryUpdated(_that.projectId,_that.taskId,_that.comment);case TimeTrackerEntryDeleted() when entryDeleted != null:
return entryDeleted(_that.id);case TimeTrackerEntryCreated() when entryCreated != null:
return entryCreated(_that.entry);case TimeTrackerEntryUpdated() when entryUpdated != null:
return entryUpdated(_that.entry);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  loaded,required TResult Function( String? projectId,  String? taskId,  String? comment)  started,required TResult Function()  stopped,required TResult Function( String? projectId,  String? taskId,  String? comment)  activeEntryUpdated,required TResult Function( String id)  entryDeleted,required TResult Function( TimeEntry entry)  entryCreated,required TResult Function( TimeEntry entry)  entryUpdated,}) {final _that = this;
switch (_that) {
case TimeTrackerLoaded():
return loaded();case TimeTrackerStarted():
return started(_that.projectId,_that.taskId,_that.comment);case TimeTrackerStopped():
return stopped();case TimeTrackerActiveEntryUpdated():
return activeEntryUpdated(_that.projectId,_that.taskId,_that.comment);case TimeTrackerEntryDeleted():
return entryDeleted(_that.id);case TimeTrackerEntryCreated():
return entryCreated(_that.entry);case TimeTrackerEntryUpdated():
return entryUpdated(_that.entry);}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  loaded,TResult? Function( String? projectId,  String? taskId,  String? comment)?  started,TResult? Function()?  stopped,TResult? Function( String? projectId,  String? taskId,  String? comment)?  activeEntryUpdated,TResult? Function( String id)?  entryDeleted,TResult? Function( TimeEntry entry)?  entryCreated,TResult? Function( TimeEntry entry)?  entryUpdated,}) {final _that = this;
switch (_that) {
case TimeTrackerLoaded() when loaded != null:
return loaded();case TimeTrackerStarted() when started != null:
return started(_that.projectId,_that.taskId,_that.comment);case TimeTrackerStopped() when stopped != null:
return stopped();case TimeTrackerActiveEntryUpdated() when activeEntryUpdated != null:
return activeEntryUpdated(_that.projectId,_that.taskId,_that.comment);case TimeTrackerEntryDeleted() when entryDeleted != null:
return entryDeleted(_that.id);case TimeTrackerEntryCreated() when entryCreated != null:
return entryCreated(_that.entry);case TimeTrackerEntryUpdated() when entryUpdated != null:
return entryUpdated(_that.entry);case _:
  return null;

}
}

}

/// @nodoc


class TimeTrackerLoaded extends TimeTrackerEvent {
  const TimeTrackerLoaded(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TimeTrackerLoaded);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'TimeTrackerEvent.loaded()';
}


}




/// @nodoc


class TimeTrackerStarted extends TimeTrackerEvent {
  const TimeTrackerStarted({this.projectId, this.taskId, this.comment}): super._();
  

 final  String? projectId;
 final  String? taskId;
 final  String? comment;

/// Create a copy of TimeTrackerEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TimeTrackerStartedCopyWith<TimeTrackerStarted> get copyWith => _$TimeTrackerStartedCopyWithImpl<TimeTrackerStarted>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TimeTrackerStarted&&(identical(other.projectId, projectId) || other.projectId == projectId)&&(identical(other.taskId, taskId) || other.taskId == taskId)&&(identical(other.comment, comment) || other.comment == comment));
}


@override
int get hashCode => Object.hash(runtimeType,projectId,taskId,comment);

@override
String toString() {
  return 'TimeTrackerEvent.started(projectId: $projectId, taskId: $taskId, comment: $comment)';
}


}

/// @nodoc
abstract mixin class $TimeTrackerStartedCopyWith<$Res> implements $TimeTrackerEventCopyWith<$Res> {
  factory $TimeTrackerStartedCopyWith(TimeTrackerStarted value, $Res Function(TimeTrackerStarted) _then) = _$TimeTrackerStartedCopyWithImpl;
@useResult
$Res call({
 String? projectId, String? taskId, String? comment
});




}
/// @nodoc
class _$TimeTrackerStartedCopyWithImpl<$Res>
    implements $TimeTrackerStartedCopyWith<$Res> {
  _$TimeTrackerStartedCopyWithImpl(this._self, this._then);

  final TimeTrackerStarted _self;
  final $Res Function(TimeTrackerStarted) _then;

/// Create a copy of TimeTrackerEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? projectId = freezed,Object? taskId = freezed,Object? comment = freezed,}) {
  return _then(TimeTrackerStarted(
projectId: freezed == projectId ? _self.projectId : projectId // ignore: cast_nullable_to_non_nullable
as String?,taskId: freezed == taskId ? _self.taskId : taskId // ignore: cast_nullable_to_non_nullable
as String?,comment: freezed == comment ? _self.comment : comment // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc


class TimeTrackerStopped extends TimeTrackerEvent {
  const TimeTrackerStopped({this.at}): super._();


 final  DateTime? at;



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TimeTrackerStopped&&(identical(other.at, at) || other.at == at));
}


@override
int get hashCode => Object.hash(runtimeType,at);

@override
String toString() {
  return 'TimeTrackerEvent.stopped(at: $at)';
}


}




/// @nodoc


class TimeTrackerActiveEntryUpdated extends TimeTrackerEvent {
  const TimeTrackerActiveEntryUpdated({this.projectId, this.taskId, this.comment}): super._();
  

 final  String? projectId;
 final  String? taskId;
 final  String? comment;

/// Create a copy of TimeTrackerEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TimeTrackerActiveEntryUpdatedCopyWith<TimeTrackerActiveEntryUpdated> get copyWith => _$TimeTrackerActiveEntryUpdatedCopyWithImpl<TimeTrackerActiveEntryUpdated>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TimeTrackerActiveEntryUpdated&&(identical(other.projectId, projectId) || other.projectId == projectId)&&(identical(other.taskId, taskId) || other.taskId == taskId)&&(identical(other.comment, comment) || other.comment == comment));
}


@override
int get hashCode => Object.hash(runtimeType,projectId,taskId,comment);

@override
String toString() {
  return 'TimeTrackerEvent.activeEntryUpdated(projectId: $projectId, taskId: $taskId, comment: $comment)';
}


}

/// @nodoc
abstract mixin class $TimeTrackerActiveEntryUpdatedCopyWith<$Res> implements $TimeTrackerEventCopyWith<$Res> {
  factory $TimeTrackerActiveEntryUpdatedCopyWith(TimeTrackerActiveEntryUpdated value, $Res Function(TimeTrackerActiveEntryUpdated) _then) = _$TimeTrackerActiveEntryUpdatedCopyWithImpl;
@useResult
$Res call({
 String? projectId, String? taskId, String? comment
});




}
/// @nodoc
class _$TimeTrackerActiveEntryUpdatedCopyWithImpl<$Res>
    implements $TimeTrackerActiveEntryUpdatedCopyWith<$Res> {
  _$TimeTrackerActiveEntryUpdatedCopyWithImpl(this._self, this._then);

  final TimeTrackerActiveEntryUpdated _self;
  final $Res Function(TimeTrackerActiveEntryUpdated) _then;

/// Create a copy of TimeTrackerEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? projectId = freezed,Object? taskId = freezed,Object? comment = freezed,}) {
  return _then(TimeTrackerActiveEntryUpdated(
projectId: freezed == projectId ? _self.projectId : projectId // ignore: cast_nullable_to_non_nullable
as String?,taskId: freezed == taskId ? _self.taskId : taskId // ignore: cast_nullable_to_non_nullable
as String?,comment: freezed == comment ? _self.comment : comment // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc


class TimeTrackerEntryDeleted extends TimeTrackerEvent {
  const TimeTrackerEntryDeleted(this.id): super._();
  

 final  String id;

/// Create a copy of TimeTrackerEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TimeTrackerEntryDeletedCopyWith<TimeTrackerEntryDeleted> get copyWith => _$TimeTrackerEntryDeletedCopyWithImpl<TimeTrackerEntryDeleted>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TimeTrackerEntryDeleted&&(identical(other.id, id) || other.id == id));
}


@override
int get hashCode => Object.hash(runtimeType,id);

@override
String toString() {
  return 'TimeTrackerEvent.entryDeleted(id: $id)';
}


}

/// @nodoc
abstract mixin class $TimeTrackerEntryDeletedCopyWith<$Res> implements $TimeTrackerEventCopyWith<$Res> {
  factory $TimeTrackerEntryDeletedCopyWith(TimeTrackerEntryDeleted value, $Res Function(TimeTrackerEntryDeleted) _then) = _$TimeTrackerEntryDeletedCopyWithImpl;
@useResult
$Res call({
 String id
});




}
/// @nodoc
class _$TimeTrackerEntryDeletedCopyWithImpl<$Res>
    implements $TimeTrackerEntryDeletedCopyWith<$Res> {
  _$TimeTrackerEntryDeletedCopyWithImpl(this._self, this._then);

  final TimeTrackerEntryDeleted _self;
  final $Res Function(TimeTrackerEntryDeleted) _then;

/// Create a copy of TimeTrackerEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? id = null,}) {
  return _then(TimeTrackerEntryDeleted(
null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class TimeTrackerEntryCreated extends TimeTrackerEvent {
  const TimeTrackerEntryCreated(this.entry): super._();
  

 final  TimeEntry entry;

/// Create a copy of TimeTrackerEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TimeTrackerEntryCreatedCopyWith<TimeTrackerEntryCreated> get copyWith => _$TimeTrackerEntryCreatedCopyWithImpl<TimeTrackerEntryCreated>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TimeTrackerEntryCreated&&(identical(other.entry, entry) || other.entry == entry));
}


@override
int get hashCode => Object.hash(runtimeType,entry);

@override
String toString() {
  return 'TimeTrackerEvent.entryCreated(entry: $entry)';
}


}

/// @nodoc
abstract mixin class $TimeTrackerEntryCreatedCopyWith<$Res> implements $TimeTrackerEventCopyWith<$Res> {
  factory $TimeTrackerEntryCreatedCopyWith(TimeTrackerEntryCreated value, $Res Function(TimeTrackerEntryCreated) _then) = _$TimeTrackerEntryCreatedCopyWithImpl;
@useResult
$Res call({
 TimeEntry entry
});




}
/// @nodoc
class _$TimeTrackerEntryCreatedCopyWithImpl<$Res>
    implements $TimeTrackerEntryCreatedCopyWith<$Res> {
  _$TimeTrackerEntryCreatedCopyWithImpl(this._self, this._then);

  final TimeTrackerEntryCreated _self;
  final $Res Function(TimeTrackerEntryCreated) _then;

/// Create a copy of TimeTrackerEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? entry = null,}) {
  return _then(TimeTrackerEntryCreated(
null == entry ? _self.entry : entry // ignore: cast_nullable_to_non_nullable
as TimeEntry,
  ));
}


}

/// @nodoc


class TimeTrackerEntryUpdated extends TimeTrackerEvent {
  const TimeTrackerEntryUpdated(this.entry): super._();
  

 final  TimeEntry entry;

/// Create a copy of TimeTrackerEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TimeTrackerEntryUpdatedCopyWith<TimeTrackerEntryUpdated> get copyWith => _$TimeTrackerEntryUpdatedCopyWithImpl<TimeTrackerEntryUpdated>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TimeTrackerEntryUpdated&&(identical(other.entry, entry) || other.entry == entry));
}


@override
int get hashCode => Object.hash(runtimeType,entry);

@override
String toString() {
  return 'TimeTrackerEvent.entryUpdated(entry: $entry)';
}


}

/// @nodoc
abstract mixin class $TimeTrackerEntryUpdatedCopyWith<$Res> implements $TimeTrackerEventCopyWith<$Res> {
  factory $TimeTrackerEntryUpdatedCopyWith(TimeTrackerEntryUpdated value, $Res Function(TimeTrackerEntryUpdated) _then) = _$TimeTrackerEntryUpdatedCopyWithImpl;
@useResult
$Res call({
 TimeEntry entry
});




}
/// @nodoc
class _$TimeTrackerEntryUpdatedCopyWithImpl<$Res>
    implements $TimeTrackerEntryUpdatedCopyWith<$Res> {
  _$TimeTrackerEntryUpdatedCopyWithImpl(this._self, this._then);

  final TimeTrackerEntryUpdated _self;
  final $Res Function(TimeTrackerEntryUpdated) _then;

/// Create a copy of TimeTrackerEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? entry = null,}) {
  return _then(TimeTrackerEntryUpdated(
null == entry ? _self.entry : entry // ignore: cast_nullable_to_non_nullable
as TimeEntry,
  ));
}


}

/// @nodoc
mixin _$TimeTrackerBlocState {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TimeTrackerBlocState);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'TimeTrackerBlocState()';
}


}

/// @nodoc
class $TimeTrackerBlocStateCopyWith<$Res>  {
$TimeTrackerBlocStateCopyWith(TimeTrackerBlocState _, $Res Function(TimeTrackerBlocState) __);
}


/// Adds pattern-matching-related methods to [TimeTrackerBlocState].
extension TimeTrackerBlocStatePatterns on TimeTrackerBlocState {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( _TimeTrackerIdleState value)?  idle,TResult Function( _TimeTrackerLoadingState value)?  loading,TResult Function( _TimeTrackerLoadedState value)?  loaded,TResult Function( _TimeTrackerRunningState value)?  running,TResult Function( _TimeTrackerErrorState value)?  error,required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TimeTrackerIdleState() when idle != null:
return idle(_that);case _TimeTrackerLoadingState() when loading != null:
return loading(_that);case _TimeTrackerLoadedState() when loaded != null:
return loaded(_that);case _TimeTrackerRunningState() when running != null:
return running(_that);case _TimeTrackerErrorState() when error != null:
return error(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( _TimeTrackerIdleState value)  idle,required TResult Function( _TimeTrackerLoadingState value)  loading,required TResult Function( _TimeTrackerLoadedState value)  loaded,required TResult Function( _TimeTrackerRunningState value)  running,required TResult Function( _TimeTrackerErrorState value)  error,}){
final _that = this;
switch (_that) {
case _TimeTrackerIdleState():
return idle(_that);case _TimeTrackerLoadingState():
return loading(_that);case _TimeTrackerLoadedState():
return loaded(_that);case _TimeTrackerRunningState():
return running(_that);case _TimeTrackerErrorState():
return error(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( _TimeTrackerIdleState value)?  idle,TResult? Function( _TimeTrackerLoadingState value)?  loading,TResult? Function( _TimeTrackerLoadedState value)?  loaded,TResult? Function( _TimeTrackerRunningState value)?  running,TResult? Function( _TimeTrackerErrorState value)?  error,}){
final _that = this;
switch (_that) {
case _TimeTrackerIdleState() when idle != null:
return idle(_that);case _TimeTrackerLoadingState() when loading != null:
return loading(_that);case _TimeTrackerLoadedState() when loaded != null:
return loaded(_that);case _TimeTrackerRunningState() when running != null:
return running(_that);case _TimeTrackerErrorState() when error != null:
return error(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  idle,TResult Function()?  loading,TResult Function( List<TimeEntry> entries,  TimeEntry? activeEntry)?  loaded,TResult Function( List<TimeEntry> entries,  TimeEntry activeEntry)?  running,TResult Function( Object errorHandler,  List<TimeEntry> entries,  TimeEntry? activeEntry)?  error,required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TimeTrackerIdleState() when idle != null:
return idle();case _TimeTrackerLoadingState() when loading != null:
return loading();case _TimeTrackerLoadedState() when loaded != null:
return loaded(_that.entries,_that.activeEntry);case _TimeTrackerRunningState() when running != null:
return running(_that.entries,_that.activeEntry);case _TimeTrackerErrorState() when error != null:
return error(_that.errorHandler,_that.entries,_that.activeEntry);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  idle,required TResult Function()  loading,required TResult Function( List<TimeEntry> entries,  TimeEntry? activeEntry)  loaded,required TResult Function( List<TimeEntry> entries,  TimeEntry activeEntry)  running,required TResult Function( Object errorHandler,  List<TimeEntry> entries,  TimeEntry? activeEntry)  error,}) {final _that = this;
switch (_that) {
case _TimeTrackerIdleState():
return idle();case _TimeTrackerLoadingState():
return loading();case _TimeTrackerLoadedState():
return loaded(_that.entries,_that.activeEntry);case _TimeTrackerRunningState():
return running(_that.entries,_that.activeEntry);case _TimeTrackerErrorState():
return error(_that.errorHandler,_that.entries,_that.activeEntry);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  idle,TResult? Function()?  loading,TResult? Function( List<TimeEntry> entries,  TimeEntry? activeEntry)?  loaded,TResult? Function( List<TimeEntry> entries,  TimeEntry activeEntry)?  running,TResult? Function( Object errorHandler,  List<TimeEntry> entries,  TimeEntry? activeEntry)?  error,}) {final _that = this;
switch (_that) {
case _TimeTrackerIdleState() when idle != null:
return idle();case _TimeTrackerLoadingState() when loading != null:
return loading();case _TimeTrackerLoadedState() when loaded != null:
return loaded(_that.entries,_that.activeEntry);case _TimeTrackerRunningState() when running != null:
return running(_that.entries,_that.activeEntry);case _TimeTrackerErrorState() when error != null:
return error(_that.errorHandler,_that.entries,_that.activeEntry);case _:
  return null;

}
}

}

/// @nodoc


class _TimeTrackerIdleState extends TimeTrackerBlocState {
  const _TimeTrackerIdleState(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TimeTrackerIdleState);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'TimeTrackerBlocState.idle()';
}


}




/// @nodoc


class _TimeTrackerLoadingState extends TimeTrackerBlocState {
  const _TimeTrackerLoadingState(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TimeTrackerLoadingState);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'TimeTrackerBlocState.loading()';
}


}




/// @nodoc


class _TimeTrackerLoadedState extends TimeTrackerBlocState {
  const _TimeTrackerLoadedState({final  List<TimeEntry> entries = const [], this.activeEntry}): _entries = entries,super._();
  

 final  List<TimeEntry> _entries;
@JsonKey() List<TimeEntry> get entries {
  if (_entries is EqualUnmodifiableListView) return _entries;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_entries);
}

// Список всех загруженных записей
 final  TimeEntry? activeEntry;

/// Create a copy of TimeTrackerBlocState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TimeTrackerLoadedStateCopyWith<_TimeTrackerLoadedState> get copyWith => __$TimeTrackerLoadedStateCopyWithImpl<_TimeTrackerLoadedState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TimeTrackerLoadedState&&const DeepCollectionEquality().equals(other._entries, _entries)&&(identical(other.activeEntry, activeEntry) || other.activeEntry == activeEntry));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_entries),activeEntry);

@override
String toString() {
  return 'TimeTrackerBlocState.loaded(entries: $entries, activeEntry: $activeEntry)';
}


}

/// @nodoc
abstract mixin class _$TimeTrackerLoadedStateCopyWith<$Res> implements $TimeTrackerBlocStateCopyWith<$Res> {
  factory _$TimeTrackerLoadedStateCopyWith(_TimeTrackerLoadedState value, $Res Function(_TimeTrackerLoadedState) _then) = __$TimeTrackerLoadedStateCopyWithImpl;
@useResult
$Res call({
 List<TimeEntry> entries, TimeEntry? activeEntry
});




}
/// @nodoc
class __$TimeTrackerLoadedStateCopyWithImpl<$Res>
    implements _$TimeTrackerLoadedStateCopyWith<$Res> {
  __$TimeTrackerLoadedStateCopyWithImpl(this._self, this._then);

  final _TimeTrackerLoadedState _self;
  final $Res Function(_TimeTrackerLoadedState) _then;

/// Create a copy of TimeTrackerBlocState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? entries = null,Object? activeEntry = freezed,}) {
  return _then(_TimeTrackerLoadedState(
entries: null == entries ? _self._entries : entries // ignore: cast_nullable_to_non_nullable
as List<TimeEntry>,activeEntry: freezed == activeEntry ? _self.activeEntry : activeEntry // ignore: cast_nullable_to_non_nullable
as TimeEntry?,
  ));
}


}

/// @nodoc


class _TimeTrackerRunningState extends TimeTrackerBlocState {
  const _TimeTrackerRunningState({final  List<TimeEntry> entries = const [], required this.activeEntry}): _entries = entries,super._();
  

 final  List<TimeEntry> _entries;
@JsonKey() List<TimeEntry> get entries {
  if (_entries is EqualUnmodifiableListView) return _entries;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_entries);
}

// Список всех загруженных записей
 final  TimeEntry activeEntry;

/// Create a copy of TimeTrackerBlocState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TimeTrackerRunningStateCopyWith<_TimeTrackerRunningState> get copyWith => __$TimeTrackerRunningStateCopyWithImpl<_TimeTrackerRunningState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TimeTrackerRunningState&&const DeepCollectionEquality().equals(other._entries, _entries)&&(identical(other.activeEntry, activeEntry) || other.activeEntry == activeEntry));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_entries),activeEntry);

@override
String toString() {
  return 'TimeTrackerBlocState.running(entries: $entries, activeEntry: $activeEntry)';
}


}

/// @nodoc
abstract mixin class _$TimeTrackerRunningStateCopyWith<$Res> implements $TimeTrackerBlocStateCopyWith<$Res> {
  factory _$TimeTrackerRunningStateCopyWith(_TimeTrackerRunningState value, $Res Function(_TimeTrackerRunningState) _then) = __$TimeTrackerRunningStateCopyWithImpl;
@useResult
$Res call({
 List<TimeEntry> entries, TimeEntry activeEntry
});




}
/// @nodoc
class __$TimeTrackerRunningStateCopyWithImpl<$Res>
    implements _$TimeTrackerRunningStateCopyWith<$Res> {
  __$TimeTrackerRunningStateCopyWithImpl(this._self, this._then);

  final _TimeTrackerRunningState _self;
  final $Res Function(_TimeTrackerRunningState) _then;

/// Create a copy of TimeTrackerBlocState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? entries = null,Object? activeEntry = null,}) {
  return _then(_TimeTrackerRunningState(
entries: null == entries ? _self._entries : entries // ignore: cast_nullable_to_non_nullable
as List<TimeEntry>,activeEntry: null == activeEntry ? _self.activeEntry : activeEntry // ignore: cast_nullable_to_non_nullable
as TimeEntry,
  ));
}


}

/// @nodoc


class _TimeTrackerErrorState extends TimeTrackerBlocState {
  const _TimeTrackerErrorState({required this.errorHandler, final  List<TimeEntry> entries = const [], this.activeEntry}): _entries = entries,super._();
  

 final  Object errorHandler;
// Объект ошибки для обработки
 final  List<TimeEntry> _entries;
// Объект ошибки для обработки
@JsonKey() List<TimeEntry> get entries {
  if (_entries is EqualUnmodifiableListView) return _entries;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_entries);
}

// Предыдущие записи для контекста
 final  TimeEntry? activeEntry;

/// Create a copy of TimeTrackerBlocState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TimeTrackerErrorStateCopyWith<_TimeTrackerErrorState> get copyWith => __$TimeTrackerErrorStateCopyWithImpl<_TimeTrackerErrorState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TimeTrackerErrorState&&const DeepCollectionEquality().equals(other.errorHandler, errorHandler)&&const DeepCollectionEquality().equals(other._entries, _entries)&&(identical(other.activeEntry, activeEntry) || other.activeEntry == activeEntry));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(errorHandler),const DeepCollectionEquality().hash(_entries),activeEntry);

@override
String toString() {
  return 'TimeTrackerBlocState.error(errorHandler: $errorHandler, entries: $entries, activeEntry: $activeEntry)';
}


}

/// @nodoc
abstract mixin class _$TimeTrackerErrorStateCopyWith<$Res> implements $TimeTrackerBlocStateCopyWith<$Res> {
  factory _$TimeTrackerErrorStateCopyWith(_TimeTrackerErrorState value, $Res Function(_TimeTrackerErrorState) _then) = __$TimeTrackerErrorStateCopyWithImpl;
@useResult
$Res call({
 Object errorHandler, List<TimeEntry> entries, TimeEntry? activeEntry
});




}
/// @nodoc
class __$TimeTrackerErrorStateCopyWithImpl<$Res>
    implements _$TimeTrackerErrorStateCopyWith<$Res> {
  __$TimeTrackerErrorStateCopyWithImpl(this._self, this._then);

  final _TimeTrackerErrorState _self;
  final $Res Function(_TimeTrackerErrorState) _then;

/// Create a copy of TimeTrackerBlocState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? errorHandler = null,Object? entries = null,Object? activeEntry = freezed,}) {
  return _then(_TimeTrackerErrorState(
errorHandler: null == errorHandler ? _self.errorHandler : errorHandler ,entries: null == entries ? _self._entries : entries // ignore: cast_nullable_to_non_nullable
as List<TimeEntry>,activeEntry: freezed == activeEntry ? _self.activeEntry : activeEntry // ignore: cast_nullable_to_non_nullable
as TimeEntry?,
  ));
}


}

// dart format on
